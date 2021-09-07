local { blkOptFromPath, blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")
local { getParametersByCrewId } = require("scripts/crew/crewSkillParameters.nut")
local { getWeaponXrayDescText } = require("scripts/weaponry/weaponryDescription.nut")
local { KGF_TO_NEWTON,
        getLastWeapon,
        isCaliberCannon,
        getCommonWeaponsBlk,
        getLastPrimaryWeapon,
        getPrimaryWeaponsList,
        getWeaponNameByBlkPath } = require("scripts/weaponry/weaponryInfo.nut")
local { topMenuHandler } = require("scripts/mainmenu/topMenuStates.nut")
local { doesLocTextExist = @(k) true } = require("dagor.localize")
local { hasLoadedModel } = require("scripts/hangarModelLoadManager.nut")
local { unique } = require("std/underscore.nut")
local { fileName } = require("std/path.nut")


/*
  ::dmViewer API:

  toggle(state = null)  - switch view_mode to state. if state == null view_mode will be increased by 1
  update()              - update dm viewer active status
                          depend on canShowDmViewer function in cur_base_gui_handler and topMenuHandler
                          and modal windows.
*/

local countMeasure = require("scripts/options/optionsMeasureUnits.nut").countMeasure

const AFTERBURNER_CHAMBER = 3

::on_check_protection <- function(params) { // called from client
  ::broadcastEvent("ProtectionAnalysisResult", params)
}

::dmViewer <- {
  [PERSISTENT_DATA_PARAMS] = [ "active", "view_mode", "_currentViewMode", "isDebugMode",
    "isVisibleExternalPartsArmor", "isVisibleExternalPartsXray" ]

  active = false
  // This is saved view mode. It is used to restore
  // view mode after player returns from somewhere.
  view_mode = ::DM_VIEWER_NONE
  unit = null
  crew = null
  unitBlk = null
  unitWeaponBlkList = null
  unitSensorsBlkList = null
  xrayRemap = {}
  difficulty = null

  modes = {
    [::DM_VIEWER_NONE]  = "none",
    [::DM_VIEWER_ARMOR] = "armor",
    [::DM_VIEWER_XRAY]  = "xray",
  }

  isVisibleExternalPartsArmor = true
  isVisibleExternalPartsXray  = true

  prevHintParams = {}

  screen = [ 0, 0 ]
  unsafe = [ 0, 0 ]
  offset = [ 0, 0 ]

  absoluteArmorThreshold = 500
  relativeArmorThreshold = 5.0

  showStellEquivForArmorClassesList = []
  armorClassToSteel = null

  prepareNameId = [
    { pattern = ::regexp2(@"_l_|_r_"),   replace = "_" },
    { pattern = ::regexp2(@"[0-9]|dm$"), replace = "" },
    { pattern = ::regexp2(@"__+"),       replace = "_" },
    { pattern = ::regexp2(@"_+$"),       replace = "" },
  ]

  crewMemberToRole = {
    commander = "commander"
    driver = "driver"
    gunner_tank = "tank_gunner"
    loader = "loader"
    machine_gunner = "radio_gunner"
  }

  xrayDescriptionCache = {}
  isDebugMode = false
  isDebugBatchExportProcess = false
  isSecondaryModsValid = false

  _currentViewMode = ::DM_VIEWER_NONE
  function getCurrentViewMode() { return _currentViewMode }
  function setCurrentViewMode(value)
  {
    _currentViewMode = value
    ::hangar_set_dm_viewer_mode(value)
    updateNoPartsNotification()
  }

  function init(handler)
  {
    screen = [ ::screen_width(), ::screen_height() ]
    unsafe = [ handler.guiScene.calcString("@bw", null), handler.guiScene.calcString("@bh", null) ]
    offset = [ screen[1] * 0.1, 0 ]

    local cfgBlk = ::configs.GUI.get()?.xray
    absoluteArmorThreshold = cfgBlk?.armor_thickness_absolute_threshold ?? absoluteArmorThreshold
    relativeArmorThreshold = cfgBlk?.armor_thickness_relative_threshold ?? relativeArmorThreshold
    showStellEquivForArmorClassesList = (cfgBlk?.show_steel_thickness_equivalent_for_armor_class
      ?? ::DataBlock()) % "o"

    updateUnitInfo()
    local timerObj = handler.getObj("dmviewer_hint")
    if (timerObj)
      timerObj.setUserData(handler) //!!FIX ME: it a bad idea link timer to handler.
                                    //better to link all timers here, and switch them off when not active.

    update()
  }

  function updateSecondaryMods()
  {
    if (isDebugBatchExportProcess) {
      isSecondaryModsValid = true
      return
    }

    if( ! unit)
      return
    isSecondaryModsValid = ::check_unit_mods_update(unit)
            && ::check_secondary_weapon_mods_recount(unit)
  }

  function onEventSecondWeaponModsUpdated(params)
  {
    if( ! unit || unit.name != params?.unit.name)
      return
    isSecondaryModsValid = true
    resetXrayCache()
    prevHintParams = {}
    reinit()
  }

  function resetXrayCache()
  {
    xrayDescriptionCache.clear()
  }

  function canUse()
  {
    local hangarUnitName = ::hangar_get_current_unit_name()
    local hangarUnit = ::getAircraftByName(hangarUnitName)
    return ::has_feature("DamageModelViewer") && hangarUnit
  }

  function reinit()
  {
    if (!::g_login.isLoggedIn())
      return

    updateUnitInfo()
    update()
  }

  function updateUnitInfo(fircedUnitId = null)
  {
    local unitId = fircedUnitId || ::hangar_get_current_unit_name()
    if (unit && unitId == unit.name)
      return
    unit = ::getAircraftByName(unitId)
    if( ! unit)
      return
    crew = ::getCrewByAir(unit)
    loadUnitBlk()
    local map = ::getTblValue("xray", unitBlk)
    xrayRemap = map ? ::u.map(map, function(val) { return val }) : {}
    armorClassToSteel = collectArmorClassToSteelMuls()
    resetXrayCache()
    clearHint()
    difficulty = ::get_difficulty_by_ediff(::get_current_ediff())
    updateSecondaryMods()
  }

  function updateNoPartsNotification()
  {
    local isShow = hasLoadedModel()
      && getCurrentViewMode() == ::DM_VIEWER_ARMOR && ::hangar_get_dm_viewer_parts_count() == 0
    local handler = ::handlersManager.getActiveBaseHandler()
    if (!handler || !::check_obj(handler.scene))
      return
    local obj = handler.scene.findObject("unit_has_no_armoring")
    if (!::check_obj(obj))
      return
    obj.show(isShow)
    clearHint()
  }

  function loadUnitBlk()
  {
    // Unit weapons and sensors are part of unit blk, should be unloaded togeter with unitBlk
    clearCachedUnitBlkNodes()
    unitBlk = ::get_full_unit_blk(unit.name)
  }

  function getUnitWeaponList()
  {
    if(unitWeaponBlkList == null)
      recacheWeapons()
    return unitWeaponBlkList
  }

  function recacheWeapons()
  {
    unitWeaponBlkList = []
    if( ! unitBlk)
      return

    local primaryList = [ getLastPrimaryWeapon(unit) ]
    foreach (modName in getPrimaryWeaponsList(unit))
      ::u.appendOnce(modName, primaryList)

    foreach(modName in primaryList)
    {
      local commonWeapons = getCommonWeaponsBlk(unitBlk, modName)
      local compareWeaponFunc = function(w1, w2)
      {
        return ::u.isEqual(w1?.trigger ?? "", w2?.trigger ?? "")
            && ::u.isEqual(w1?.blk ?? "", w2?.blk ?? "")
            && ::u.isEqual(w1?.bullets ?? "", w2?.bullets ?? "")
            && ::u.isEqual(w1?.gunDm ?? "", w2?.gunDm ?? "")
            && ::u.isEqual(w1?.barrelDP ?? "", w2?.barrelDP ?? "")
            && ::u.isEqual(w1?.breechDP ?? "", w2?.breechDP ?? "")
            && ::u.isEqual(w1?.ammoDP ?? "", w2?.ammoDP ?? "")
            && ::u.isEqual(w1?.dm ?? "", w2?.dm ?? "")
      }

      if(commonWeapons != null)
        foreach (weapon in (commonWeapons % "Weapon"))
          if (weapon?.blk && !weapon?.dummy)
            ::u.appendOnce(weapon, unitWeaponBlkList, false, compareWeaponFunc)
    }

    local curPresetName =  getLastWeapon(unit.name)
    local rawPresetsList = unitBlk.weapon_presets % "preset"
    local presetsList = ::u.filter(rawPresetsList, @(p) p?.name == curPresetName).extend(
      ::u.filter(rawPresetsList, @(p) p?.name != curPresetName))

    foreach (preset in presetsList)
    {
      if( ! ("blk" in preset))
        continue
      local presetBlk = blkFromPath(preset["blk"])
      foreach (weapon in (presetBlk % "Weapon"))  // preset can have many weapons in it or no one
        if (weapon?.blk && !weapon?.dummy)
          ::u.appendOnce(::u.copy(weapon), unitWeaponBlkList, false, ::u.isEqual)
    }
  }

  function getUnitSensorsList()
  {
    if (unitSensorsBlkList == null)
    {
      local sensorsBlk = findAnyModEffectValue("sensors")
      local isMod = sensorsBlk != null
      sensorsBlk = sensorsBlk ?? unitBlk?.sensors

      unitSensorsBlkList = []
      for (local b = 0; b < (sensorsBlk?.blockCount() ?? 0); b++)
        unitSensorsBlkList.append(sensorsBlk.getBlock(b))

      if (isDebugBatchExportProcess && isMod && unitBlk?.sensors != null)
        for (local b = 0; b < unitBlk.sensors.blockCount(); b++)
          ::u.appendOnce(unitBlk.sensors.getBlock(b), unitSensorsBlkList, false, ::u.isEqual)
    }
    return unitSensorsBlkList
  }

  function collectArmorClassToSteelMuls()
  {
    local res = {}
    local armorClassesBlk = blkFromPath("gameData/damage_model/armor_classes.blk")
    local steelArmorQuality = armorClassesBlk?.ship_structural_steel.armorQuality ?? 0
    if (unitBlk?.DamageParts == null || steelArmorQuality == 0)
      return res
    for (local i = 0; i < unitBlk.DamageParts.blockCount(); i++)
    {
      local blk = unitBlk.DamageParts.getBlock(i)
      if (showStellEquivForArmorClassesList.contains(blk?.armorClass) && res?[blk.armorClass] == null)
        res[blk.armorClass] <- (armorClassesBlk?[blk.armorClass].armorQuality ?? 0) / steelArmorQuality
    }
    return res
  }

  function toggle(state = null)
  {
    if (state == view_mode)
      return

    view_mode =
      (state == null) ? (( view_mode + 1 ) % modes.len()) :
      (state in modes) ? state :
      ::DM_VIEWER_NONE

    //need to update active status before repaint
    if (!update() && active)
      show()
    if (!active || view_mode == ::DM_VIEWER_NONE)
      clearHint()
  }

  function show(vis = true)
  {
    active = vis
    local viewMode = (active && canUse()) ? view_mode : ::DM_VIEWER_NONE
    setCurrentViewMode(viewMode)
    if (!active)
      clearHint()
    repaint()
  }

  function update()
  {
    updateNoPartsNotification()

    local newActive = canUse() && !::handlersManager.isAnyModalHandlerActive()
    if (!newActive && !active) //no need to check other conditions when not canUse and not active.
      return false

    local handler = ::handlersManager.getActiveBaseHandler()
    newActive = newActive && (handler?.canShowDmViewer() ?? false)
    if (topMenuHandler.value?.isSceneActive() ?? false)
      newActive = newActive && topMenuHandler.value.canShowDmViewer()

    if (newActive == active)
    {
      repaint()
      return false
    }

    show(newActive)
    return true
  }

  function repaint()
  {
    local handler = ::handlersManager.getActiveBaseHandler()
    if (!handler)
      return

    local obj = ::showBtn("air_info_dmviewer_listbox", canUse(), handler.scene)
    if(!::checkObj(obj))
      return

    obj.setValue(view_mode)
    obj.enable(active)

    // Protection analysis button
    if (::has_feature("DmViewerProtectionAnalysis"))
    {
      obj = handler.scene.findObject("dmviewer_protection_analysis_btn")
      if (::check_obj(obj))
        obj.show(view_mode == ::DM_VIEWER_ARMOR && (unit?.unitType.canShowProtectionAnalysis() ?? false))
    }

    // Outer parts visibility toggle in Armor and Xray modes
    if (::has_feature("DmViewerExternalArmorHiding"))
    {
      local isTankOrShip = unit != null && (unit.isTank() || unit.isShipOrBoat())
      obj = handler.scene.findObject("dmviewer_show_external_dm")
      if (::check_obj(obj))
      {
        local isShowOption = view_mode == ::DM_VIEWER_ARMOR && isTankOrShip
        obj.show(isShowOption)
        if (isShowOption)
          obj.setValue(isVisibleExternalPartsArmor)
      }
      obj = handler.scene.findObject("dmviewer_show_extra_xray")
      if (::check_obj(obj))
      {
        local isShowOption = view_mode == ::DM_VIEWER_XRAY && isTankOrShip
        obj.show(isShowOption)
        if (isShowOption)
          obj.setValue(isVisibleExternalPartsXray)
      }
    }

    // Customization navbar button
    obj = handler.scene.findObject("btn_dm_viewer")
    if(!::checkObj(obj))
      return

    local modeNameCur  = modes[ view_mode  ]
    local modeNameNext = modes[ ( view_mode + 1 ) % modes.len() ]

    obj.tooltip = ::loc("mainmenu/viewDamageModel/tooltip_" + modeNameNext)
    obj.setValue(::loc("mainmenu/btn_dm_viewer_" + modeNameNext))

    local objIcon = obj.findObject("btn_dm_viewer_icon")
    if (::checkObj(objIcon))
      objIcon["background-image"] = "#ui/gameuiskin#btn_dm_viewer_" + modeNameCur + ".svg"
  }

  function clearHint()
  {
    updateHint({ thickness = 0, name = null, posX = 0, posY = 0})
  }

  function clearCachedUnitBlkNodes()
  {
    unitWeaponBlkList = null
    unitSensorsBlkList = null
  }

  function getHintObj()
  {
    local handler = ::handlersManager.getActiveBaseHandler()
    if (!handler)
      return null
    local res = handler.scene.findObject("dmviewer_hint")
    return ::check_obj(res) ? res : null
  }

  function resetPrevHint()
  {
    prevHintParams = {}
  }

  function hasPrevHint()
  {
    return prevHintParams.len() != 0
  }

  function updateHint(params)
  {
    if (!active)
    {
      if (hasPrevHint())
      {
        resetPrevHint()
        local hintObj = getHintObj()
        if (hintObj)
          hintObj.show(false)
      }
      return
    }

    local needUpdatePos = false
    local needUpdateContent = false

    if(view_mode == ::DM_VIEWER_XRAY)
      // change tooltip info only for new unit part
      needUpdateContent = (::getTblValue("name", params, true) != ::getTblValue("name", prevHintParams, false))
    else
      foreach (key, val in params)
        if (val != ::getTblValue(key, prevHintParams))
        {
          if (key == "posX" || key == "posY")
            needUpdatePos = true
          else
            needUpdateContent = true
        }

    if (!needUpdatePos && !needUpdateContent)
      return
    prevHintParams = params

    local obj = getHintObj()
    if(!obj)
      return
    if (needUpdatePos && !needUpdateContent)
      return placeHint(obj)

    local nameId = getPartNameId(params)
    local isVisible = nameId != ""
    obj.show(isVisible)
    if (!isVisible)
      return

    local info = { title="", desc="" }
    local isUseCache = view_mode == ::DM_VIEWER_XRAY && !isDebugMode
    local cacheId = ::getTblValue("name", params, "")

    if (isUseCache && (cacheId in xrayDescriptionCache))
      info = xrayDescriptionCache[cacheId]
    else
    {
      info = getPartTooltipInfo(nameId, params)
      info.title = ::stringReplace(info.title, " ", ::nbsp)
      info.desc  = ::stringReplace(info.desc,  " ", ::nbsp)

      if (isUseCache)
        xrayDescriptionCache[cacheId] <- info
    }

    obj.findObject("dmviewer_title").setValue(info.title)
    obj.findObject("dmviewer_desc").setValue(info.desc)
    placeHint(obj)
  }

  function placeHint(obj)
  {
    if(!::checkObj(obj))
      return
    local guiScene = obj.getScene()

    guiScene.setUpdatesEnabled(true, true)
    local cursorPos = ::get_dagui_mouse_cursor_pos_RC()
    local size = obj.getSize()
    local posX = ::clamp(cursorPos[0] + offset[0], unsafe[0], ::max(unsafe[0], screen[0] - unsafe[0] - size[0]))
    local posY = ::clamp(cursorPos[1] + offset[1], unsafe[1], ::max(unsafe[1], screen[1] - unsafe[1] - size[1]))
    obj.pos = ::format("%d, %d", posX, posY)
  }

  function getPartNameId(params)
  {
    local nameId = ::getTblValue("name", params) || ""
    if (view_mode != ::DM_VIEWER_XRAY || nameId == "")
      return nameId

    nameId = ::getTblValue(nameId, xrayRemap, nameId)
    foreach(re in prepareNameId)
      nameId = re.pattern.replace(re.replace, nameId)
    if (nameId == "gunner")
      nameId += "_" + ::getUnitTypeTextByUnit(unit).tolower()
    return nameId
  }

  function getPartNameLocText(nameId)
  {
    local localizedName = ""
    local localizationSources = ["armor_class/", "dmg_msg_short/", "weapons_types/"]
    local nameVariations = [nameId]
    local idxSeparator = nameId.indexof("_")
    if(idxSeparator)
      nameVariations.append(nameId.slice(0, idxSeparator))
    if(unit != null)
      nameVariations.append(::getUnitTypeText(unit.esUnitType).tolower() + "_" + nameId)
    if (unit?.esUnitType ==::ES_UNIT_TYPE_BOAT)
      nameVariations.append($"ship_{nameId}")

    foreach(localizationSource in localizationSources)
      foreach(nameVariant in nameVariations)
      {
        local locId = "".concat(localizationSource, nameVariant)
        localizedName = doesLocTextExist(locId) ? ::loc(locId, "") : ""
        if(localizedName != "")
          return ::g_string.utf8ToUpper(localizedName, 1);
      }
    return nameId
  }

  function getPartLocNameByBlkFile(locKeyPrefix, blkFilePath, blk)
  {
    local nameLocId = $"{locKeyPrefix}/{blk?.nameLocId ?? fileName(blkFilePath).slice(0, -4)}"
    return doesLocTextExist(nameLocId) ? ::loc(nameLocId) : (blk?.name ?? nameLocId)
  }

  function getPartTooltipInfo(nameId, params)
  {
    local res = {
      title = ""
      desc  = ""
    }

    local isHuman = nameId == "steel_tankman"
    if (isHuman || nameId == "")
      return res

    params.nameId <- nameId

    switch (view_mode)
    {
      case ::DM_VIEWER_ARMOR:
        res.desc = getDescriptionInArmorMode(params)
        break
      case ::DM_VIEWER_XRAY:
        res.desc = getDescriptionInXrayMode(params)
        break
      default:
    }

    res.title = getPartNameLocText(params?.partLocId ?? params.nameId)

    return res
  }

  function getDescriptionInArmorMode(params)
  {
    local desc = []

    local solid = ::getTblValue("solid", params)
    local variableThickness = ::getTblValue("variable_thickness", params)
    local thickness = ::getTblValue("thickness", params)
    local effectiveThickness = ::getTblValue("effective_thickness", params)

    if (solid && variableThickness)
    {
      desc.append(::loc("armor_class/variable_thickness_armor"))
    }
    else if (thickness)
    {
      local thicknessStr = thickness.tostring()
      desc.append(::loc("armor_class/thickness") + ::nbsp +
        ::colorize("activeTextColor", thicknessStr) + ::nbsp + ::loc("measureUnits/mm"))
    }

    local angleValue = ::getTblValue("angle", params, null)
    if (angleValue != null)
      desc.append(::loc("armor_class/impact_angle") + ::nbsp + ::round(angleValue) + ::nbsp + ::loc("measureUnits/deg"))

    local headingAngleValue = ::getTblValue("heading_angle", params, null)
    if (headingAngleValue != null)
      desc.append("headingAngle" + ::nbsp + ::round(headingAngleValue) + ::nbsp + ::loc("measureUnits/deg"))

    if (effectiveThickness)
    {
      if (solid)
      {
        desc.append(::loc("armor_class/armor_dimensions_at_point") + ::nbsp +
          ::colorize("activeTextColor", ::round(effectiveThickness)) +
          ::nbsp + ::loc("measureUnits/mm"))

        if ((armorClassToSteel?[params.name] ?? 0) != 0)
        {
          local equivSteelMm = ::round(effectiveThickness * armorClassToSteel[params.name])
          desc.append(::loc("shop/armorThicknessEquivalent/steel",
            { thickness = "".concat(::colorize("activeTextColor", equivSteelMm), " ", ::loc("measureUnits/mm")) }))
        }
      }
      else
      {
        local effectiveThicknessClamped = ::min(effectiveThickness,
          ::min((relativeArmorThreshold * thickness).tointeger(), absoluteArmorThreshold))

        desc.append(::loc("armor_class/effective_thickness") + ::nbsp +
          (effectiveThicknessClamped < effectiveThickness ? ">" : "") +
          ::round(effectiveThicknessClamped) + ::nbsp + ::loc("measureUnits/mm"))
      }
    }

    local normalAngleValue = ::getTblValue("normal_angle", params, null)
    if (normalAngleValue != null)
      desc.append(::loc("armor_class/normal_angle") + ::nbsp +
        (normalAngleValue+0.5).tointeger() + ::nbsp + ::loc("measureUnits/deg"))

    if(isDebugMode)
      desc.append("\n" + ::colorize("badTextColor", params.nameId))

    local rawPartName = ::getTblValue("raw_name", params)
    if (rawPartName)
      desc.append(rawPartName)

    return ::g_string.implode(desc, "\n")
  }

  function getFirstFound(dataArray, getter, defValue = null)
  {
    local result = null
    foreach (data in dataArray)
    {
      result = getter(data)
      if (result != null)
        break
    }
    return result ?? defValue
  }

  function getCrewMemberBlkByDMPart(crewBlk, dmPart)
  {
    local l = crewBlk.blockCount()
    for (local i = 0; i < l; i++) {
      local memberBlk = crewBlk.getBlock(i)
      if (dmPart == memberBlk.dmPart)
        return memberBlk
    }
    return null
  }

  function findBlockByName(blk, name)
  {
    if (blk.getBlockByName(name) != null)
      return true
    for (local b = 0; b < blk.blockCount(); b++)
      if (findBlockByName(blk.getBlock(b), name))
        return true
    return false
  }

  function findBlockByNameWithParamValue(blk, blockName, paramName, paramValue)
  {
    if (blk.getBlockByName(blockName)?[paramName] == paramValue)
      return true
    for (local b = 0; b < blk.blockCount(); b++)
      if (findBlockByNameWithParamValue(blk.getBlock(b), blockName, paramName, paramValue))
        return true
    return false
  }

  function getDescriptionInXrayMode(params)
  {
    if (!unit || !unitBlk)
      return ""

    if (!::has_feature("XRayDescription") || !params?.name)
      return ""

    local partId = params?.nameId ?? ""
    local partName = params.name
    local weaponPartName = null

    local desc = []

    switch (partId)
    {
      case "commander":
      case "driver":
      case "gunner_tank":
      case "machine_gunner":
      case "loader":
        if (unit.esUnitType != ::ES_UNIT_TYPE_TANK)
          break
        local memberBlk = getCrewMemberBlkByDMPart(unitBlk.tank_crew, partName)
        if (!memberBlk)
          break
        local memberRole = crewMemberToRole[partId]
        local duplicateRoles = (memberBlk % "role")
          .filter(@(r) r != memberRole)
          .map(@(r) ::loc($"duplicate_role/{r}", ""))
          .filter(@(n) n != "")
        desc.extend(duplicateRoles)
        break

      case "engine":              // Engines
        switch (unit.esUnitType)
        {
          case ::ES_UNIT_TYPE_TANK:
            local infoBlk = findAnyModEffectValue("engine") ?? unitBlk?.VehiclePhys.engine
            if(infoBlk)
            {
              local engineModelName = getEngineModelName(infoBlk)
              desc.append(engineModelName)

              local engineConfig = []
              local engineType = infoBlk?.type ?? (engineModelName != "" ? "diesel" : "")
              if (engineType != "")
                engineConfig.append(::loc($"engine_type/{engineType}"))
              if (infoBlk?.configuration)
                engineConfig.append(::loc("engine_configuration/" + infoBlk.configuration))
              local typeText = ::loc("ui/comma").join(engineConfig, true)
              if (typeText != "")
                desc.append("".concat(::loc("plane_engine_type"), ::loc("ui/colon"), typeText))

              if (infoBlk?.displacement)
                desc.append(::loc("engine_displacement")
                          + ::loc("ui/colon")
                          + ::loc("measureUnits/displacement", { num = infoBlk.displacement.tointeger() }))
            }

            if ( ! isSecondaryModsValid)
              updateSecondaryMods()

            local currentParams = unit?.modificators[difficulty.crewSkillName]
            if (isSecondaryModsValid && currentParams && currentParams.horsePowers && currentParams.maxHorsePowersRPM)
            {
              desc.append(::format("%s %s (%s %d %s)", ::loc("engine_power") + ::loc("ui/colon"),
                ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(currentParams.horsePowers),
                ::loc("shop/unitValidCondition"), currentParams.maxHorsePowersRPM.tointeger(), ::loc("measureUnits/rpm")))
            }
            if (infoBlk)
              desc.append(getMassInfo(infoBlk))
          break;

          case ::ES_UNIT_TYPE_AIRCRAFT:
          case ::ES_UNIT_TYPE_HELICOPTER:
            local partIndex = ::to_integer_safe(trimBetween(partName, "engine", "_"), -1, false)
            if (partIndex <= 0)
              break

            local fmBlk = ::get_fm_file(unit.name, unitBlk)
            if (!fmBlk)
              break

            partIndex-- //engine1_dm -> Engine0

            local infoBlk = getInfoBlk(partName)
            desc.append(getEngineModelName(infoBlk))

            local enginePartId = infoBlk?.part_id ?? ("Engine" + partIndex.tostring())
            local engineTypeId = "EngineType" + (fmBlk?[enginePartId].Type ?? -1).tostring()
            local engineBlk = fmBlk?[engineTypeId] ?? fmBlk?[enginePartId]
            if (!engineBlk)
            { // try to find booster
              local numEngines = 0
              while(("Engine" + numEngines) in fmBlk)
                numEngines ++
              local boosterPartIndex = partIndex - numEngines //engine3_dm -> Booster0
              engineBlk = fmBlk?[$"Booster{boosterPartIndex}"]
            }
            local engineMainBlk = engineBlk?.Main

            if (!engineMainBlk)
              break
            local engineInfo = []
            local engineType = getFirstFound([infoBlk, engineMainBlk], @(b) b?.Type ?? b?.type, "").tolower()
            if (unit.esUnitType == ::ES_UNIT_TYPE_HELICOPTER && engineType == "turboprop")
              engineType = "turboshaft"
            if (engineType != "")
              engineInfo.append(::loc($"plane_engine_type/{engineType}"))
            if (engineType == "inline" || engineType == "radial")
            {
              local cylinders = getFirstFound([infoBlk, engineMainBlk], @(b) b?.Cylinders ?? b?.cylinders, 0)
              if (cylinders > 0)
                engineInfo.append(cylinders + ::loc("engine_cylinders_postfix"))
            }
            local typeText = ::loc("ui/comma").join(engineInfo, true)
            if (typeText != "")
              desc.append("".concat(::loc("plane_engine_type"), ::loc("ui/colon"), typeText))

            // display cooling type only for Inline and Radial engines
            if ((engineType == "inline" || engineType == "radial")
                && "IsWaterCooled" in engineMainBlk)           // Plane : Engine : Cooling
            {
              local coolingKey = engineMainBlk?.IsWaterCooled ? "water" : "air"
              desc.append(::loc("plane_engine_cooling_type") + ::loc("ui/colon")
              + ::loc("plane_engine_cooling_type_" + coolingKey))
            }

            if (!isSecondaryModsValid)
            {
              updateSecondaryMods()
              break;
            }
            // calculating power values
            local powerMax = 0
            local powerTakeoff = 0
            local thrustMax = 0
            local thrustTakeoff = 0
            local thrustMaxCoef = 1
            local afterburneThrustMaxCoef = 1
            local engineThrustMaxBlk = engineMainBlk?.ThrustMax

            if (engineThrustMaxBlk)
            {
              thrustMaxCoef = engineThrustMaxBlk?.ThrustMaxCoeff_0_0 ?? 1
              afterburneThrustMaxCoef = engineThrustMaxBlk?.ThrAftMaxCoeff_0_0 ?? 1
            }

            local horsePowerValue = getFirstFound([infoBlk, engineMainBlk],
              @(b) b?.ThrustMax?.PowerMax0 ?? b?.HorsePowers ?? b?.Power, 0)
            local thrustValue = getFirstFound([infoBlk, engineMainBlk], @(b) b?.ThrustMax?.ThrustMax0, 0)

            local thrustMult = 1.0
            local thrustTakeoffMult = 1.0
            local modeIdx = 0
            while (true)
            {
              local modeBlk = engineMainBlk?[$"Mode{++modeIdx}"]
              if (modeBlk?.ThrustMult == null)
                break
              if (modeBlk?.Throttle != null && modeBlk.Throttle <= 1.0)
                thrustMult = modeBlk.ThrustMult
              thrustTakeoffMult = modeBlk.ThrustMult
            }

            local throttleBoost = getFirstFound([infoBlk, engineMainBlk], @(b) b?.ThrottleBoost, 0)
            local afterburnerBoost = getFirstFound([infoBlk, engineMainBlk], @(b) b?.AfterburnerBoost, 0)
            // for planes modifications have delta values
            local thrustModDelta = (unit?.modificators[difficulty.crewSkillName].thrust ?? 0) / KGF_TO_NEWTON
            local horsepowerModDelta = unit?.modificators[difficulty.crewSkillName].horsePowers ?? 0
            switch(engineType)
            {
              case "inline":
              case "radial":
                if (throttleBoost > 1)
                {
                  powerMax = horsePowerValue
                  powerTakeoff = horsePowerValue * throttleBoost * afterburnerBoost
                }
                else
                  powerTakeoff = horsePowerValue
              break

              case "rocket":
                local sources = [infoBlk, engineMainBlk]
                local boosterMainBlk = fmBlk?["Booster" + partIndex].Main
                if (boosterMainBlk)
                  sources.insert(1, boosterMainBlk)
                thrustTakeoff = getFirstFound(sources, @(b) b?.Thrust ?? b?.thrust, 0)
              break

              case "turboprop":
                  powerMax = horsePowerValue
                  thrustMax = thrustValue * thrustMult
              break

              case "jet":
              case "pvrd":
              default:
                if (throttleBoost > 1 && afterburnerBoost > 1)
                {
                  thrustTakeoff = thrustValue * thrustTakeoffMult * afterburnerBoost
                  thrustMax = thrustValue * thrustMult
                }
                else
                  thrustTakeoff = thrustValue * thrustTakeoffMult
              break
            }

            // final values can be overriden in info block
            powerMax = ::getTblValue("power_max", infoBlk, powerMax)
            powerTakeoff = ::getTblValue("power_takeoff", infoBlk, powerTakeoff)
            thrustMax = ::getTblValue("thrust_max", infoBlk, thrustMax)
            thrustTakeoff = ::getTblValue("thrust_takeoff", infoBlk, thrustTakeoff)

            // display power values
            if (powerMax > 0)
            {
              powerMax += horsepowerModDelta
              desc.append(::loc("engine_power_max") + ::loc("ui/colon")
                + ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(powerMax))
            }
            if (powerTakeoff > 0)
            {
              powerTakeoff += horsepowerModDelta
              desc.append(::loc("engine_power_takeoff") + ::loc("ui/colon")
                + ::g_measure_type.HORSEPOWERS.getMeasureUnitsText(powerTakeoff))
            }
            if (thrustMax > 0)
            {
              thrustMax += thrustModDelta
              thrustMax *= thrustMaxCoef
              desc.append(::loc("engine_thrust_max") + ::loc("ui/colon")
                + ::g_measure_type.THRUST_KGF.getMeasureUnitsText(thrustMax))
            }
            if (thrustTakeoff > 0)
            {
              local afterburnerBlk = engineBlk?.Afterburner
              local thrustTakeoffLocId = (afterburnerBlk?.Type == AFTERBURNER_CHAMBER &&
                (afterburnerBlk?.IsControllable ?? false))
                  ? "engine_thrust_afterburner"
                  : "engine_thrust_takeoff"

              thrustTakeoff += thrustModDelta
              thrustTakeoff *= thrustMaxCoef * afterburneThrustMaxCoef
              desc.append(::loc(thrustTakeoffLocId) + ::loc("ui/colon")
                + ::g_measure_type.THRUST_KGF.getMeasureUnitsText(thrustTakeoff))
            }

            // mass
            desc.append(getMassInfo(infoBlk))
          break;
        }
        break

      case "transmission":
        local info = unitBlk?.VehiclePhys?.mechanics
        if (info)
        {
          local manufacturer = info?.manufacturer ? ::loc("transmission_manufacturer/" + info.manufacturer,
            ::loc("engine_manufacturer/" + info.manufacturer, ""))
                               : ""
          local model = info?.model ? ::loc("transmission_model/" + info.model, "") : ""
          local props = info?.type ? ::g_string.utf8ToLower(::loc("transmission_type/" + info.type, "")) : ""
          desc.append(::g_string.implode([ manufacturer, model ], " ") +
            (props == "" ? "" : ::loc("ui/parentheses/space", { text = props })))

          local maxSpeed = unit?.modificators?[difficulty.crewSkillName]?.maxSpeed ?? 0
          if (maxSpeed && info?.gearRatios)
          {
            local gearsF = 0
            local gearsB = 0
            local ratioF = 0
            local ratioB = 0
            foreach (gear in (info.gearRatios % "ratio")) {
              if (gear > 0) {
                gearsF++
                ratioF = ratioF ? ::min(ratioF, gear) : gear
              }
              else if (gear < 0) {
                gearsB++
                ratioB = ratioB ? ::min(ratioB, -gear) : -gear
              }
            }
            local maxSpeedF = maxSpeed
            local maxSpeedB = ratioB ? (maxSpeed * ratioF / ratioB) : 0
            if (maxSpeedF && gearsF)
              desc.append(::loc("xray/transmission/maxSpeed/forward") + ::loc("ui/colon") +
                countMeasure(0, maxSpeedF) + ::loc("ui/comma") +
                  ::loc("xray/transmission/gears") + ::loc("ui/colon") + gearsF)
            if (maxSpeedB && gearsB)
              desc.append(::loc("xray/transmission/maxSpeed/backward") + ::loc("ui/colon") +
                countMeasure(0, maxSpeedB) + ::loc("ui/comma") +
                  ::loc("xray/transmission/gears") + ::loc("ui/colon") + gearsB)
          }
        }
        break

      case "ammo_turret":
      case "ammo_body":
      case "ammunition_storage":
      case "ammunition_storage_shells":
      case "ammunition_storage_charges":
      case "ammunition_storage_aux":
        local isShipOrBoat = unit.isShipOrBoat()
        if (isShipOrBoat)
        {
          local ammoQuantity = getAmmoQuantityByPartName(partName)
          if (ammoQuantity > 1)
            desc.append(::loc("shop/ammo") + ::loc("ui/colon") + ammoQuantity)
        }
        local stowageInfo = getAmmoStowageInfo(null, partName, isShipOrBoat)
        if (stowageInfo.isCharges)
          params.partLocId <- isShipOrBoat ? "ship_charges_storage" : "ammo_charges"
        if (stowageInfo.firstStageCount)
        {
          local txt = ::loc(isShipOrBoat ? "xray/ammo/first_stage_ship" : "xray/ammo/first_stage")
          if (unit.isTank())
            txt += ::loc("ui/comma") + stowageInfo.firstStageCount + " " + ::loc("measureUnits/pcs")
          desc.append(txt)
        }
        if (stowageInfo.isAutoLoad)
          desc.append(::loc("xray/ammo/mechanized_ammo_rack"))
        break

      case "drive_turret_h":
      case "drive_turret_v":

        weaponPartName = ::stringReplace(partName, partId, "gun_barrel")
        local weaponInfoBlk = getWeaponByXrayPartName(weaponPartName, partName)
        if( ! weaponInfoBlk)
          break
        local isHorizontal = partId == "drive_turret_h"
        desc.extend(getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, isHorizontal, !isHorizontal))
        break

      case "pilot":

        foreach (cfg in [
          { label = "avionics_sight_turret", ccipKey = "haveCCIPForTurret", ccrpKey = "haveCCRPForTurret"  }
          { label = "avionics_sight_cannon", ccipKey = "haveCCIPForGun",    ccrpKey = "haveCCRPForGun"     }
          { label = "avionics_sight_rocket", ccipKey = "haveCCIPForRocket", ccrpKey = "haveCCRPForRocket"  }
          { label = "avionics_sight_bomb",   ccipKey = "haveCCIPForBombs",  ccrpKey = "haveCCRPForBombs"   }
        ])
        {
          local haveCcip = unitBlk?[cfg.ccipKey] ?? false
          local haveCcrp = unitBlk?[cfg.ccrpKey] ?? false
          if (haveCcip || haveCcrp)
            desc.append("".concat(::loc(cfg.label), ::loc("ui/colon"),
              ::loc("ui/comma").join([ haveCcip ? ::loc("CCIP") : "", haveCcrp ? ::loc("CCRP") : "" ], true)))
        }

        if ((unitBlk?.haveOpticTurret || unit.esUnitType == ::ES_UNIT_TYPE_HELICOPTER) && unitBlk?.gunnerOpticFps != null)
          if (unitBlk?.cockpit.sightOutFov != null || unitBlk?.cockpit.sightInFov != null)
          {
            local optics = getOpticsParams(unitBlk?.cockpit.sightOutFov ?? 0, unitBlk?.cockpit.sightInFov ?? 0)
            if (optics.zoom != "")
            {
              local nightVisionBlk = findAnyModEffectValue("nightVision")
              local visionModes = ::loc("ui/comma").join([
                { mode = "tv",   have = nightVisionBlk?.sightIr != null || nightVisionBlk?.sightThermal != null }
                { mode = "lltv", have = nightVisionBlk?.sightIr != null }
                { mode = "flir", have = nightVisionBlk?.sightThermal != null }
              ].map(@(v) v.have ? ::loc($"avionics_sight_vision/{v.mode}") : ""), true)
              desc.append("".concat(::loc("armor_class/optic"), ::loc("ui/colon"), optics.zoom,
                visionModes != "" ? ::loc("ui/parentheses/space", { text = visionModes }) : ""))
            }
          }

        foreach (sensorBlk in getUnitSensorsList())
        {
          local sensorFilePath = sensorBlk.getStr("blk", "")
          if (sensorFilePath == "")
            continue
          local sensorPropsBlk = ::DataBlock()
          sensorPropsBlk.load(sensorFilePath)
          if (!sensorPropsBlk.getBool("showOnHud", true))
            continue
          local sensorType = sensorPropsBlk.getStr("type", "")
          if (sensorType == "radar")
          {
            local isRadar = false
            local isIrst = false
            local transiversBlk = sensorPropsBlk.getBlockByName("transivers")
            for (local t = 0; t < (transiversBlk?.blockCount() ?? 0); t++)
            {
              local transiverBlk = transiversBlk.getBlock(t)
              if (transiverBlk?.visibilityType == "infraRed")
                isIrst = true
              else
                isRadar = true
            }
            if (isRadar && isIrst)
              sensorType = "radar_irst"
            else if (isRadar)
              sensorType = "radar"
            else if (isIrst)
              sensorType = "irst"
          }
          else if (sensorType == "lds")
            continue
          desc.append("".concat(::loc($"avionics_sensor_{sensorType}"), ::loc("ui/colon"),
            getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))
        }
        if (unitBlk.getBool("havePointOfInterestDesignator", false) || unit.esUnitType == ::ES_UNIT_TYPE_HELICOPTER)
          desc.append(::loc("avionics_aim_spi"))
        if (unitBlk.getBool("laserDesignator", false))
          desc.append(::loc("avionics_aim_laser_designator"))
        for (local b = 0; b < (unitBlk?.counterMeasures.blockCount() ?? 0); b++)
        {
          local counterMeasureBlk = unitBlk.counterMeasures.getBlock(b)
          local counterMeasureFilePath = counterMeasureBlk.getStr("blk", "")
          if (counterMeasureFilePath == "")
            continue
          local counterMeasurePropsBlk = ::DataBlock()
          counterMeasurePropsBlk.load(counterMeasureFilePath)
          local counterMeasureType = counterMeasurePropsBlk.getStr("type", "")
          desc.append("".concat(::loc($"avionics_countermeasure_{counterMeasureType}"), ::loc("ui/colon"),
            getPartLocNameByBlkFile("counterMeasures", counterMeasureFilePath, counterMeasurePropsBlk)))
        }
        break

      case "radar":
      case "antenna_target_location":
      case "antenna_target_tagging":
      case "optic_gun":

        // naval params are temporary disabled as they do not match to historical ones
        if (unit.isShipOrBoat())
          break

        foreach (sensorBlk in getUnitSensorsList())
        {
          if ((sensorBlk % "dmPart").findindex(@(v) v == partName) == null)
            continue

          local sensorFilePath = sensorBlk.getStr("blk", "")
          if (sensorFilePath == "")
            continue
          local sensorPropsBlk = ::DataBlock()
          sensorPropsBlk.load(sensorFilePath)
          local sensorType = sensorPropsBlk.getStr("type", "")
          if (sensorType == "radar")
          {
            desc.append("".concat(::loc("xray/model"), ::loc("ui/colon"),
              getPartLocNameByBlkFile("sensors", sensorFilePath, sensorPropsBlk)))

            local isRadar = false
            local isIrst = false
            local rangeMax = 0.0
            local radarFreqBand = 8
            local searchZoneAzimuthWidth = 0.0
            local searchZoneElevationWidth = 0.0
            local transiversBlk = sensorPropsBlk.getBlockByName("transivers")
            for (local t = 0; t < (transiversBlk?.blockCount() ?? 0); t++)
            {
              local transiverBlk = transiversBlk.getBlock(t)
              local range = transiverBlk.getReal("range", 0.0)
              rangeMax = ::max(rangeMax, range)
              if (transiverBlk?.visibilityType == "infraRed")
                isIrst = true
              else
              {
                isRadar = true
                radarFreqBand = transiverBlk.getInt("band", 8)
              }
              if (transiverBlk?.antenna != null)
              {
                if (transiverBlk.antenna?.azimuth != null && transiverBlk.antenna?.elevation != null)
                {
                  local azimuthWidth = 2.0 * (transiverBlk.antenna.azimuth?.angleHalfSens ?? 0.0)
                  local elevationWidth = 2.0 * (transiverBlk.antenna.elevation?.angleHalfSens ?? 0.0)
                  searchZoneAzimuthWidth = max(searchZoneAzimuthWidth, azimuthWidth)
                  searchZoneElevationWidth = max(searchZoneElevationWidth, elevationWidth)
                }
                else
                {
                  local width = 2.0 * (transiverBlk.antenna?.angleHalfSens ?? 0.0)
                  searchZoneAzimuthWidth = max(searchZoneAzimuthWidth, width)
                  searchZoneElevationWidth = max(searchZoneElevationWidth, width)
                }
              }
            }

            local anglesFinder = false
            local iff = false
            local lookDown = false
            local signalsBlk = sensorPropsBlk.getBlockByName("signals")
            for (local s = 0; s < (signalsBlk?.blockCount() ?? 0); s++)
            {
              local signalBlk = signalsBlk.getBlock(s)
              anglesFinder = anglesFinder || signalBlk.getBool("anglesFinder", true)
              iff = iff || signalBlk.getBool("friendFoeId", false)
              local dopplerSpeedBlk = signalBlk.getBlockByName("dopplerSpeed")
              if (dopplerSpeedBlk)
              {
                if (dopplerSpeedBlk.getBool("presents", false))
                  lookDown = true
              }
            }
            local isSearchRadar = findBlockByName(sensorPropsBlk, "addTarget")
            local isTrackRadar = findBlockByName(sensorPropsBlk, "updateActiveTargetOfInterest")

            local radarType = ""
            if (isRadar)
              radarType = "radar"
            if (isIrst)
            {
              if (radarType != "")
                radarType = radarType + "_"
              radarType = radarType + "irst"
            }
            if (isSearchRadar && isTrackRadar)
              radarType = "" + radarType
            else if (isSearchRadar)
              radarType = "search_" + radarType
            else if (isTrackRadar)
            {
              if (anglesFinder)
                radarType = "track_" + radarType
              else
                radarType = radarType + "_range_finder"
            }
            desc.append(::loc("plane_engine_type") + ::loc("ui/colon") + ::loc(radarType))
            if (isRadar)
              desc.append(::loc("radar_freq_band") + ::loc("ui/colon") + ::loc(::format("radar_freq_band_%d", radarFreqBand)))
            desc.append(::loc("radar_range_max") + ::loc("ui/colon") + ::g_measure_type.DISTANCE.getMeasureUnitsText(rangeMax))

            local scanPatternsBlk = sensorPropsBlk.getBlockByName("scanPatterns")
            for (local p = 0; p < (scanPatternsBlk?.blockCount() ?? 0); p++)
            {
              local scanPatternBlk = scanPatternsBlk.getBlock(p)
              local scanPatternType = scanPatternBlk.getStr("type", "")
              local major = 0.0
              local minor = 0.0
              local rowMajor = true
              if (scanPatternType == "cylinder")
              {
                major = 360.0
                minor = scanPatternBlk.getReal("barHeight", 0.0) * scanPatternBlk.getInt("barsCount", 0)
                rowMajor = scanPatternBlk.getBool("rowMajor", true)
              }
              else if (scanPatternType == "pyramide")
              {
                major = 2.0 * scanPatternBlk.getReal("width", 0.0)
                minor = scanPatternBlk.getReal("barHeight", 0.0) * scanPatternBlk.getInt("barsCount", 0)
                rowMajor = scanPatternBlk.getBool("rowMajor", true)
              }
              else if (scanPatternType == "cone")
              {
                major = 2.0 * scanPatternBlk.getReal("width", 0.0)
                minor = major
              }
              if (rowMajor)
              {
                searchZoneAzimuthWidth = ::max(searchZoneAzimuthWidth, major)
                searchZoneElevationWidth = ::max(searchZoneElevationWidth, minor)
              }
              else
              {
                searchZoneAzimuthWidth = ::max(searchZoneAzimuthWidth, minor)
                searchZoneElevationWidth = ::max(searchZoneElevationWidth, major)
              }
            }
            if (isSearchRadar)
              desc.append("".concat(::loc("radar_search_zone_max"), ::loc("ui/colon"),
                ::round(searchZoneAzimuthWidth), ::loc("measureUnits/deg"), ::loc("ui/multiply"),
                ::round(searchZoneElevationWidth), ::loc("measureUnits/deg")))
            if (lookDown)
              desc.append(::loc("radar_ld"))
            if (iff)
              desc.append(::loc("radar_iff"))

            if (isTrackRadar)
            {
              local hasBVR = findBlockByNameWithParamValue(sensorPropsBlk, "setDistGatePos", "source", "targetDesignation")
              if (hasBVR)
                desc.append(::loc("radar_bvr_mode"))
              local hasACM = findBlockByNameWithParamValue(sensorPropsBlk, "setDistGatePos", "source", "constRange")
              if (hasACM)
                desc.append(::loc("radar_acm_mode"))
            }
          }
        }

        if (partId == "optic_gun")
        {
          local info = unitBlk?.cockpit
          if (info?.sightName)
            desc.extend(getOpticsDesc(info))
        }
        break

      case "countermeasure":

        local counterMeasuresBlk = unitBlk?.counterMeasures
        if (counterMeasuresBlk)
        {
          for (local i = 0; i < counterMeasuresBlk.blockCount(); i++)
          {
            local cmBlk = counterMeasuresBlk.getBlock(i)
            if (cmBlk?.dmPart != partName || (cmBlk?.blk ?? "") == "")
              continue
            local info = DataBlock()
            info.load(cmBlk.blk)

            desc.append("".concat(::loc("xray/model"), ::loc("ui/colon"),
              getPartLocNameByBlkFile("counterMeasures", cmBlk.blk, info)))

            foreach (cfg in [
              { label = "xray/ircm_protected_sector/hor",  sectorKey = "azimuthSector",   directionKey = "azimuth"   }
              { label = "xray/ircm_protected_sector/vert", sectorKey = "elevationSector", directionKey = "elevation" }
            ])
            {
              local sector = ::round(info?[cfg.sectorKey] ?? 0.0)
              local direction = ::round((info?[cfg.directionKey] ?? 0.0) * 2.0) / 2
              if (sector == 0)
                continue
              local deg = ::loc("measureUnits/deg")
              local comment = ""
              if (direction != 0 && sector < 360)
              {
                direction %= 360
                if (direction < 0)
                  direction += 360
                local angles = [
                  direction - sector / 2
                  direction + sector / 2
                ].map(function(a) {
                  a %= 360
                  if (a >= 180)
                    a -= 360
                  return "".concat(a >= 0 ? "+" : "", a, deg)
                })
                comment = ::loc("ui/parentheses/space", { text = "/".join(angles) })
              }
              desc.append("".concat(::loc(cfg.label), ::loc("ui/colon"), sector, deg, comment))
            }
            break
          }
        }
        break

      case "main_caliber_turret":
      case "auxiliary_caliber_turret":
      case "aa_turret":
        weaponPartName = ::stringReplace(partName, "turret", "gun")
        foreach(weapon in getUnitWeaponList())
          if (weapon?.turret?.gunnerDm == partName && weapon?.breechDP)
          {
            weaponPartName = weapon.breechDP
            break
          }
        // No break!

      case "mg": // warning disable: -missed-break
      case "gun":
      case "mgun":
      case "cannon":
      case "mask":
      case "gun_mask":
      case "gun_barrel":
      case "cannon_breech":
      case "tt":
      case "torpedo":
      case "main_caliber_gun":
      case "auxiliary_caliber_gun":
      case "depth_charge":
      case "mine":
      case "aa_gun":

        local weaponInfoBlk = null
        local weaponTrigger = ::getTblValue("weapon_trigger", params)
        local triggerParam = "trigger"
        if (weaponTrigger)
        {
          local weaponList = getUnitWeaponList()
          foreach(weapon in weaponList)
          {
            if (triggerParam in weapon && weapon[triggerParam] == weaponTrigger)
            {
              weaponInfoBlk = weapon
              break
            }
          }
        }

        if (!weaponInfoBlk)
        {
          weaponPartName = weaponPartName || partName
          weaponInfoBlk = getWeaponByXrayPartName(weaponPartName)
        }

        if( ! weaponInfoBlk)
          break

        local isSpecialBullet = ::isInArray(partId, [ "torpedo", "depth_charge", "mine" ])
        local isSpecialBulletEmitter = ::isInArray(partId, [ "tt" ])

        local weaponBlkLink = weaponInfoBlk?.blk ?? ""
        local weaponName = getWeaponNameByBlkPath(weaponBlkLink)

        local ammo = isSpecialBullet ? 1 : getWeaponTotalBulletCount(partId, weaponInfoBlk)
        local shouldShowAmmoInTitle = isSpecialBulletEmitter
        local ammoTxt = ammo > 1 && shouldShowAmmoInTitle ? ::format(::loc("weapons/counter"), ammo) : ""

        if(weaponName != "")
          desc.append("".concat(::loc($"weapons/{weaponName}"), ammoTxt))
        if(weaponInfoBlk && ammo > 1 && !shouldShowAmmoInTitle)
          desc.append(::loc("shop/ammo") + ::loc("ui/colon") + ammo)

        if (isSpecialBullet || isSpecialBulletEmitter)
          desc[desc.len() - 1] += getWeaponXrayDescText(weaponInfoBlk, unit, ::get_current_ediff())
        else {
          local status = getWeaponStatus(weaponPartName, weaponInfoBlk)
          desc.extend(getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status))
          desc.append(getMassInfo(blkFromPath(weaponBlkLink)))
          if (status?.isPrimary || status?.isSecondary)
          {
            if (weaponInfoBlk?.autoLoader)
              desc.append(::loc("xray/ammo/auto_load"))
            local firstStageCount = getAmmoStowageInfo(weaponInfoBlk?.trigger).firstStageCount
            if (firstStageCount)
              desc.append("".concat(::loc(unit.isShipOrBoat() ? "xray/ammo/first_stage_ship" : "xray/ammo/first_stage"),
                ::loc("ui/colon"), firstStageCount))
          }
          desc.extend(getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, true, true))
        }

        checkPartLocId(partId, partName, weaponInfoBlk, params)
      break;

      case "tank":                     // aircraft fuel tank (tank's fuel tank is 'fuel_tank')
        local tankInfoTable = unit?.info?[params.name]
        if (!tankInfoTable)
          tankInfoTable = unit?.info?.tanks_params
        if (!tankInfoTable)
          break

        local tankInfo = []

        if ("protected" in tankInfoTable)
        {
          tankInfo.append(tankInfoTable.protected ?
          ::loc("fuelTank/selfsealing") :
          ::loc("fuelTank/not_selfsealing"))
        }
        if ("protected_boost" in tankInfoTable)
          tankInfo.append(::loc("fuelTank/neutralGasSystem"))
        if (tankInfo.len())
          desc.append(::g_string.implode(tankInfo, ", "))

      break

      case "composite_armor_hull":            // tank Composite armor
      case "composite_armor_turret":          // tank Composite armor
      case "ex_era_hull":                     // tank Explosive reactive armor
      case "ex_era_turret":                   // tank Explosive reactive armor
        local info = getModernArmorParamsByDmPartName(partName)

        local strUnits = ::nbsp + ::loc("measureUnits/mm")
        local strBullet = ::loc("ui/bullet")
        local strColon  = ::loc("ui/colon")

        if (info.titleLoc != "")
          params.nameId <- info.titleLoc

        foreach (data in info.referenceProtectionArray)
        {
          if (::u.isPoint2(data.angles))
            desc.append(::loc("shop/armorThicknessEquivalent/angles",
              { angle1 = ::abs(data.angles.y), angle2 = ::abs(data.angles.x) }))
          else
            desc.append(::loc("shop/armorThicknessEquivalent"))

          if (data.kineticProtectionEquivalent)
            desc.append(strBullet + ::loc("shop/armorThicknessEquivalent/kinetic") + strColon +
              ::round(data.kineticProtectionEquivalent) + strUnits)
          if (data.cumulativeProtectionEquivalent)
            desc.append(strBullet + ::loc("shop/armorThicknessEquivalent/cumulative") + strColon +
              ::round(data.cumulativeProtectionEquivalent) + strUnits)
        }

        local blockSep = desc.len() ? "\n" : ""

        if (info.isComposite && !::u.isEmpty(info.layersArray)) // composite armor
        {
          local texts = []
          foreach (layer in info.layersArray)
          {
            local thicknessText = ""
            if (::u.isFloat(layer?.armorThickness) && layer.armorThickness > 0)
              thicknessText = ::round(layer.armorThickness).tostring()
            else if (::u.isPoint2(layer?.armorThickness) && layer.armorThickness.x > 0 && layer.armorThickness.y > 0)
              thicknessText = ::round(layer.armorThickness.x).tostring() + ::loc("ui/mdash") + ::round(layer.armorThickness.y).tostring()
            if (thicknessText != "")
              thicknessText = ::loc("ui/parentheses/space", { text = thicknessText + strUnits })
            texts.append(strBullet + getPartNameLocText(layer?.armorClass) + thicknessText)
          }
          desc.append(blockSep + ::loc("xray/armor_composition") + ::loc("ui/colon") + "\n" + ::g_string.implode(texts, "\n"))
        }
        else if (!info.isComposite && !::u.isEmpty(info.armorClass)) // reactive armor
          desc.append(blockSep + ::loc("plane_engine_type") + ::loc("ui/colon") + getPartNameLocText(info.armorClass))

        break

      case "coal_bunker":
        local coalToSteelMul = armorClassToSteel?["ships_coal_bunker"] ?? 0
        if (coalToSteelMul != 0)
          desc.append(::loc("shop/armorThicknessEquivalent/coal_bunker",
            { thickness = "".concat(::round(coalToSteelMul * 1000).tostring(), " ", ::loc("measureUnits/mm")) }))
        break

      case "commander_panoramic_sight":
        if (unitBlk?.commanderView)
          desc.extend(getOpticsDesc(unitBlk.commanderView))
        break

      case "rangefinder":
      case "fire_director":
        // "partName" node may belong to only one system
        local fcBlk = getFireControlSystems("dmPart", partName)?[0]
        if (!fcBlk)
          break

        // 1. Gives fire solution for
        local weaponNames = getFireControlWeaponNames(fcBlk)
        if (weaponNames.len() == 0)
          break

        desc.append(::loc("xray/fire_control/weapons"))
        desc.extend(weaponNames
          .map(@(n) ::loc($"weapons/{n}"))
          .map(@(n) $"{::loc("ui/bullet")}{n}"))

        // 2. Measure accuracy
        local accuracy = getFireControlAccuracy(fcBlk)
        if (accuracy != -1)
          desc.append(::format("%s %d%s", ::loc("xray/fire_control/accuracy"),
            accuracy, ::loc("measureUnits/percent")))

        // 3. Fire solution calculation time
        local lockTime = fcBlk?.targetLockTime
        if (lockTime)
          desc.append(::format("%s %d%s", ::loc("xray/fire_control/lock_time"),
            lockTime, ::loc("measureUnits/seconds")))

        // 4. Fire solution update time
        local calcTime = fcBlk?.calcTime
        if (calcTime)
          desc.append(::format("%s %d%s", ::loc("xray/fire_control/calc_time"),
            calcTime, ::loc("measureUnits/seconds")))

        break

      case "fire_control_room":
      case "bridge":
        local numRangefinders = getNumFireControlNodes(partName, "rangefinder")
        local numFireDirectors = getNumFireControlNodes(partName, "fire_director")
        if (numRangefinders == 0 && numFireDirectors == 0)
          break

        desc.append(::loc("xray/fire_control/devices"))
        if (numRangefinders > 0)
          desc.append($"{::loc("ui/bullet")}{::loc("xray/fire_control/num_rangefinders", {n = numRangefinders})}")
        if (numFireDirectors > 0)
          desc.append($"{::loc("ui/bullet")}{::loc("xray/fire_control/num_fire_directors", {n = numFireDirectors})}")

        break
    }

    if (isDebugMode)
      desc.append("\n" + ::colorize("badTextColor", partName))

    local rawPartName = ::getTblValue("raw_name", params)
    if (rawPartName)
      desc.append(rawPartName)

    local description = ::g_string.implode(desc, "\n")
    return description
  }

  function getEngineModelName(infoBlk)
  {
    return " ".join([
      infoBlk?.manufacturer ? ::loc($"engine_manufacturer/{infoBlk.manufacturer}") : ""
      infoBlk?.model ? ::loc($"engine_model/{infoBlk.model}") : ""
    ], true)
  }

  function getFireControlSystems(key, node)
  {
    return getUnitSensorsList()
      .filter(@(blk) blk.getBlockName() == "fireDirecting" && (blk % key).findvalue(@(v) v == node) != null)
  }

  function getNumFireControlNodes(mainNode, nodeId)
  {
    return getFireControlSystems("dmPartMain", mainNode)
      .map(@(fcBlk) fcBlk % "dmPart")
      .map(@(nodes) nodes.filter(@(node) node.indexof(nodeId) == 0).len())
      .reduce(@(sum, num) sum + num, 0)
  }

  function getFireControlTriggerGroups(fcBlk)
  {
    local groupsBlk = fcBlk?.triggerGroupUse
    if (!groupsBlk)
      return []

    local res = []
    for (local i = 0; i < groupsBlk.paramCount(); ++i)
      if (groupsBlk.getParamValue(i))
        res.append(groupsBlk.getParamName(i))

    return res
  }

  function getFireControlWeaponNames(fcBlk)
  {
    local triggerGroups = getFireControlTriggerGroups(fcBlk)
    local weapons = getUnitWeaponList().filter(@(w) triggerGroups.contains(w?.triggerGroup) && w?.blk)
    return unique(weapons, @(w) w.blk).map(@(w) getWeaponNameByBlkPath(w.blk))
  }

  function getFireControlAccuracy(fcBlk)
  {
    local accuracy = fcBlk?.measureAccuracy
    if (!accuracy)
      return -1

    return ::round(accuracy / getModEffect("ship_rangefinder", "shipDistancePrecisionErrorMult") * 100)
  }

  function getModEffect(modId, effectId)
  {
    if (::shop_is_modification_enabled(unit.name, modId))
      return 1.0

    return ::get_modifications_blk()?.modifications[modId].effects[effectId] ?? 1.0
  }

  function findAnyModEffectValue(effectId)
  {
    for (local b = 0; b < (unitBlk?.modifications.blockCount() ?? 0); b++)
    {
      local modBlk = unitBlk.modifications.getBlock(b)
      local value = modBlk?.effects[effectId]
      if (value != null
        && (isDebugBatchExportProcess || ::shop_is_modification_enabled(unit.name, modBlk.getBlockName())))
          return value
    }
    return null
  }

  function getOpticsParams(zoomOutFov, zoomInFov)
  {
    local fovToZoom = @(fov) ::sin(80/2*PI/180)/::sin(fov/2*PI/180)
    local fovOutIn = [zoomOutFov, zoomInFov].filter(@(fov) fov > 0)
    local zoom = fovOutIn.map(@(fov) fovToZoom(fov))
    if (zoom.len() == 2 && ::abs(zoom[0] - zoom[1]) < 0.1) {
      zoom.remove(0)
      fovOutIn.remove(0)
    }
    local zoomTexts = ::u.map(zoom, @(zoom) ::format("%.1fx", zoom))
    local fovTexts = fovOutIn.map(@(fov) "".concat(::round(fov), ::loc("measureUnits/deg")))
    return {
      zoom = ::g_string.implode(zoomTexts, ::loc("ui/mdash"))
      fov  = ::g_string.implode(fovTexts,  ::loc("ui/mdash"))
    }
  }

  function getOpticsDesc(info)
  {
    local desc = []
    if (info?.sightName)
      desc.append(::loc($"sight_model/{info.sightName}", ""))
    local optics = getOpticsParams(info?.zoomOutFov ?? 0, info?.zoomInFov ?? 0)
    if (optics.zoom != "")
      desc.append("".concat(::loc("optic/zoom"), ::loc("ui/colon"), optics.zoom))
    if (optics.fov != "")
      desc.append("".concat(::loc("optic/fov"), ::loc("ui/colon"), optics.fov))
    return desc
  }

  function getWeaponTotalBulletCount(partId, weaponInfoBlk)
  {
    if (partId == "cannon_breech")
    {
      local result = 0
      local currentBreechDp = weaponInfoBlk?.breechDP
      if (!currentBreechDp)
        return result
      foreach(weapon in getUnitWeaponList())
      {
        if (weapon?.breechDP == currentBreechDp)
          result += ::getTblValue("bullets", weapon, 0)
      }
      return result
    } else
      return ::getTblValue("bullets", weaponInfoBlk, 0)
  }

  function getInfoBlk(partName = null)
  {
    local sources = [unitBlk]
    local unitTags = ::getTblValue(unit.name, ::get_unittags_blk(), null)
    if (unitTags != null)
      sources.insert(0, unitTags)
    local infoBlk = getFirstFound(sources, @(b) partName ? b?.info?[partName] : b?.info)
    if (infoBlk && partName != null && "alias" in infoBlk)
      infoBlk = getInfoBlk(infoBlk.alias)
    return infoBlk
  }

  function getXrayViewerDataByDmPartName(partName)
  {
    local dataBlk = unitBlk && unitBlk?.xray_viewer_data
    local partIdx = null
    if (dataBlk)
      for (local b = 0; b < dataBlk.blockCount(); b++)
      {
        local blk = dataBlk.getBlock(b)
        if (blk?.xrayDmPart == partName)
          return blk
        if (blk?.xrayDmPartFmt != null)
        {
          partIdx = partIdx ?? extractIndexFromDmPartName(partName)
          if (partIdx != -1
              && partIdx >= (blk?.xrayDmPartRange.x ?? -1) && partIdx <= (blk?.xrayDmPartRange.y ?? -1)
              && ::format(blk.xrayDmPartFmt, partIdx) == partName)
            return blk
        }
      }
    return null
  }

  function getAmmoQuantityByPartName(partName)
  {
    local ammoStowages = unitBlk?.ammoStowages
    if (ammoStowages)
      for (local i = 0; i < ammoStowages.blockCount(); i++)
      {
        local blk = ammoStowages.getBlock(i)
        foreach (blockName in [ "shells", "charges" ])
          foreach (shells in blk % blockName)
            if (shells?[partName])
              return shells[partName].count
      }
    return 0
  }

  function getWeaponByXrayPartName(weaponPartName, linkedPartName = null)
  {
    local turretLinkedParts = [ "horDriveDm", "verDriveDm" ]
    local partLinkSources = [ "dm", "barrelDP", "breechDP", "maskDP", "gunDm", "ammoDP", "emitter" ]
    local partLinkSourcesGenFmt = [ "emitterGenFmt", "ammoDpGenFmt" ]
    local weaponList = getUnitWeaponList()
    foreach(weapon in weaponList)
    {
      if (linkedPartName != null && weapon?.turret.barrel != null)
        foreach(partKey in turretLinkedParts)
          if(weapon.turret?[partKey] == linkedPartName)
            return weapon
      foreach(linkKey in partLinkSources)
        if(linkKey in weapon && weapon[linkKey] == weaponPartName)
          return weapon
      if (::u.isPoint2(weapon?.emitterGenRange))
      {
        local rangeMin = ::min(weapon.emitterGenRange.x, weapon.emitterGenRange.y)
        local rangeMax = ::max(weapon.emitterGenRange.x, weapon.emitterGenRange.y)
        foreach(linkKeyFmt in partLinkSourcesGenFmt)
          if (weapon?[linkKeyFmt])
          {
            if (weapon[linkKeyFmt].indexof("%02d") == null)
            {
              dagor.assertf(false, "Bad weapon param " + linkKeyFmt + "='" + weapon[linkKeyFmt] +
                "' on " + unit.name)
              continue
            }
            for(local i = rangeMin; i <= rangeMax; i++)
              if (::format(weapon[linkKeyFmt], i) == weaponPartName)
                return weapon
          }
      }
      if("partsDP" in weapon && weapon["partsDP"].indexof(weaponPartName) != null)
        return weapon
    }
    return null
  }

  function getWeaponStatus(weaponPartName, weaponInfoBlk)
  {
    local blkPath = weaponInfoBlk?.blk ?? ""
    local blk = blkFromPath(blkPath)
    switch (unit.esUnitType)
    {
      case ::ES_UNIT_TYPE_TANK:
        local isRocketGun = blk?.rocketGun
        local isMachinegun = !!blk?.bullet?.caliber && !isCaliberCannon(1000 * blk.bullet.caliber)
        local isPrimary = !isRocketGun && !isMachinegun
        if (!isPrimary)
        {
          local commonBlk = getCommonWeaponsBlk(dmViewer.unitBlk, "")
          foreach (weapon in (commonBlk % "Weapon"))
          {
            if (!weapon?.blk || weapon?.dummy)
              continue
            isPrimary = weapon.blk == blkPath
            break
          }
        }
        local isSecondary = !isPrimary && !isMachinegun
        return { isPrimary = isPrimary, isSecondary = isSecondary, isMachinegun = isMachinegun }
      case ::ES_UNIT_TYPE_BOAT:
      case ::ES_UNIT_TYPE_SHIP:
        local isPrimaryName       = ::g_string.startsWith(weaponPartName, "main")
        local isSecondaryName     = ::g_string.startsWith(weaponPartName, "auxiliary")
        local isPrimaryTrigger    = weaponInfoBlk?.triggerGroup == "primary"
        local isSecondaryTrigger  = weaponInfoBlk?.triggerGroup == "secondary"
        return {
          isPrimary     = isPrimaryTrigger   || (isPrimaryName   && !isSecondaryTrigger)
          isSecondary   = isSecondaryTrigger || (isSecondaryName && !isPrimaryTrigger)
          isMachinegun  = weaponInfoBlk?.triggerGroup == "machinegun"
        }
      case ::ES_UNIT_TYPE_AIRCRAFT:
      case ::ES_UNIT_TYPE_HELICOPTER:
        return { isPrimary = true, isSecondary = false, isMachinegun = false }
    }
    return { isPrimary = true, isSecondary = false, isMachinegun = false }
  }

  function getWeaponDriveTurretDesc(weaponPartName, weaponInfoBlk, needAxisX, needAxisY)
  {
    local desc = []
    local needSingleAxis = !needAxisX || !needAxisY
    local status = getWeaponStatus(weaponPartName, weaponInfoBlk)
    if (!needSingleAxis && unit?.isTank() && !status.isPrimary && !status.isSecondary)
      return desc

    local deg = ::loc("measureUnits/deg")
    local isInverted = weaponInfoBlk?.invertedLimitsInViewer ?? false
    local isSwaped = weaponInfoBlk?.swapLimitsInViewer ?? false
    local verticalLabel = "shop/angleVerticalGuidance"
    local horizontalLabel = "shop/angleHorizontalGuidance"

    foreach (g in [
      { need = needAxisX, angles = weaponInfoBlk?.limits?.yaw,   label = isInverted ? verticalLabel : horizontalLabel, canSwap = true }
      { need = needAxisY, angles = weaponInfoBlk?.limits?.pitch, label = isInverted ? horizontalLabel : verticalLabel, canSwap = false }
    ]) {
      if (!g.need || (!g.angles?.x && !g.angles?.y))
        continue
      local anglesText = (g.angles.x + g.angles.y == 0) ? ::format("±%d%s", g.angles.y, deg)
        : (isSwaped && g.canSwap ? ::format("-%d%s/+%d%s", ::abs(g.angles.y), deg, ::abs(g.angles.x), deg) : ::format("%d%s/+%d%s", g.angles.x, deg, g.angles.y, deg))
      desc.append(::loc(g.label) + " " + anglesText)
    }

    if (needSingleAxis || status.isPrimary || unit?.isShipOrBoat())
    {
      local unitModificators = unit?.modificators?[difficulty.crewSkillName]
      foreach (a in [
        { need = needAxisX, modifName = "turnTurretSpeed",      blkName = "speedYaw",
          shipFxName = [ "mainSpeedYawK",   "auxSpeedYawK",   "aaSpeedYawK"   ] },
        { need = needAxisY, modifName = "turnTurretSpeedPitch", blkName = "speedPitch",
          shipFxName = [ "mainSpeedPitchK", "auxSpeedPitchK", "aaSpeedPitchK" ] },
      ]) {
        if (!a.need)
          continue

        local speed = 0
        switch (unit.esUnitType)
        {
          case ::ES_UNIT_TYPE_TANK:
            local mainTurretSpeed = unitModificators?[a.modifName] ?? 0
            local value = weaponInfoBlk?[a.blkName] ?? 0
            local weapons = getUnitWeaponList()
            local mainTurretValue = weapons?[0]?[a.blkName] ?? 0
            speed = mainTurretValue ? (mainTurretSpeed * value / mainTurretValue) : mainTurretSpeed
            break
          case ::ES_UNIT_TYPE_BOAT:
          case ::ES_UNIT_TYPE_SHIP:
            local modId   = status.isPrimary    ? "new_main_caliber_turrets"
                          : status.isSecondary  ? "new_aux_caliber_turrets"
                          : status.isMachinegun ? "new_aa_caliber_turrets"
                          : ""
            local effectId = status.isPrimary    ? a.shipFxName[0]
                           : status.isSecondary  ? a.shipFxName[1]
                           : status.isMachinegun ? a.shipFxName[2]
                           : ""
            local baseSpeed = weaponInfoBlk?[a.blkName] ?? 0
            local modMul =  getModEffect(modId, effectId)
            speed = baseSpeed * modMul
            break
        }

        if (speed)
        {
          local speedTxt = speed < 10 ? ::format("%.1f", speed) : ::format("%d", ::round(speed))
          desc.append(::loc("crewSkillParameter/" + a.modifName) + ::loc("ui/colon") +
            speedTxt + ::loc("measureUnits/deg_per_sec"))
        }
      }
    }

    if (unit?.isTank())
    {
      local gunStabilizer = weaponInfoBlk?.gunStabilizer
      local isStabilizerX = needAxisX && gunStabilizer?.hasHorizontal
      local isStabilizerY = needAxisY && gunStabilizer?.hasVertical
      if (isStabilizerX || isStabilizerY)
      {
        local valueLoc = needSingleAxis ? "options/yes"
          : (isStabilizerX ? "shop/gunStabilizer/twoPlane" : "shop/gunStabilizer/vertical")
        desc.append(::loc("shop/gunStabilizer") + " " + ::loc(valueLoc))
      }
    }

    return desc
  }

  function getGunReloadTimeMax(weaponInfoBlk)
  {
    local weaponInfo = blkOptFromPath(weaponInfoBlk?.blk)
    local reloadTime = weaponInfoBlk?.reloadTime ?? weaponInfo?.reloadTime
    if (reloadTime)
      return reloadTime

    local shotFreq = weaponInfoBlk?.shotFreq ?? weaponInfo?.shotFreq
    if (shotFreq)
      return 1 / shotFreq

    return null
  }

  function getWeaponShotFreqAndReloadTimeDesc(weaponName, weaponInfoBlk, status)
  {
    local shotFreqRPM = 0.0 // rounds/min
    local reloadTimeS = 0 // sec
    local firstStageShotFreq = 0.0

    local weaponBlk = blkOptFromPath(weaponInfoBlk?.blk)
    local isCartridge = weaponBlk?.reloadTime != null
    local cyclicShotFreqS  = weaponBlk?.shotFreq ?? 0.0 // rounds/sec

    switch (unit.esUnitType)
    {
      case ::ES_UNIT_TYPE_AIRCRAFT:
      case ::ES_UNIT_TYPE_HELICOPTER:
        shotFreqRPM = cyclicShotFreqS * 60
        break

      case ::ES_UNIT_TYPE_TANK:
        if (!status.isPrimary)
          break

        local mainWeaponInfoBlk = getUnitWeaponList()?[0]
        if (!mainWeaponInfoBlk)
          break

        local mainGunReloadTime = unit?.modificators?[difficulty.crewSkillName]?.reloadTime ?? 0.0
        if (!mainGunReloadTime && crew)
        {
          local crewSkillParams = getParametersByCrewId(crew.id, unit.name)
          local crewSkill = crewSkillParams?[difficulty.crewSkillName]?.loader
          mainGunReloadTime = crewSkill?.loading_time_mult?.tankLoderReloadingTime ?? 0.0
        }

        if (weaponInfoBlk.blk == mainWeaponInfoBlk.blk)
        {
          reloadTimeS = mainGunReloadTime
          break
        }

        local thisGunReloadTimeMax = getGunReloadTimeMax(weaponInfoBlk)
        if (!thisGunReloadTimeMax)
          break

        if (weaponInfoBlk?.autoLoader)
        {
          reloadTimeS = thisGunReloadTimeMax
          break
        }

        local mainGunReloadTimeMax = getGunReloadTimeMax(mainWeaponInfoBlk)
        if (!mainGunReloadTimeMax)
          break

        reloadTimeS = mainGunReloadTime * thisGunReloadTimeMax / mainGunReloadTimeMax
        break

      case ::ES_UNIT_TYPE_BOAT:
      case ::ES_UNIT_TYPE_SHIP:
        if (isCartridge)
          if (crew)
          {
            local crewSkillParams = getParametersByCrewId(crew.id, unit.name)
            local crewSkill = crewSkillParams?[difficulty.crewSkillName]?.ship_artillery
            foreach (c in [ "main_caliber_loading_time", "aux_caliber_loading_time", "antiair_caliber_loading_time" ])
            {
              reloadTimeS = (crewSkill?[c]?[$"weapons/{weaponName}"]) ?? 0.0
              if (reloadTimeS)
                break
            }
          }
          else
          {
            local wpcostUnit = ::get_wpcost_blk()?[unit.name]
            foreach (c in [ "shipMainCaliberReloadTime", "shipAuxCaliberReloadTime", "shipAntiAirCaliberReloadTime" ])
            {
              reloadTimeS = wpcostUnit?[$"{c}_{weaponName}"] ?? 0.0
              if (reloadTimeS)
                break
            }
          }

        if (reloadTimeS)
          break
        cyclicShotFreqS = ::u.search(getCommonWeaponsBlk(dmViewer.unitBlk, "") % "Weapon",
          @(inst) inst.trigger  == weaponInfoBlk.trigger)?.shotFreq ?? cyclicShotFreqS
        shotFreqRPM = cyclicShotFreqS * 60

        if (haveFirstStageShells(weaponInfoBlk?.trigger))
        {
          firstStageShotFreq = shotFreqRPM
          shotFreqRPM *= 1/getAmmoStowageReloadTimeMult(weaponInfoBlk?.trigger)
        }
        break
    }

    local desc = []
    if (firstStageShotFreq)
      desc.append(::g_string.implode([::loc("shop/shotFreq/firstStage"),
        ::round(firstStageShotFreq),
        ::loc("measureUnits/rounds_per_min")], " "))

    if (shotFreqRPM)
    {
      shotFreqRPM = ::round(shotFreqRPM, shotFreqRPM > 600 ? -1 : 0)
      desc.append(" ".concat(::loc("shop/shotFreq"), shotFreqRPM, ::loc("measureUnits/rounds_per_min")))
    }
    if (reloadTimeS)
    {
      reloadTimeS = (reloadTimeS % 1) ? ::format("%.1f", reloadTimeS) : ::format("%d", reloadTimeS)
      desc.append(::loc("shop/reloadTime") + " " + reloadTimeS + " " + ::loc("measureUnits/seconds"))
    }
    return desc
  }

  function getAmmoStowageBlockByParam(trigger, paramName) {
    if (!unitBlk?.ammoStowages || !trigger)
      return null

    local ammoCount = unitBlk.ammoStowages.blockCount()
    for(local i = 0; i < ammoCount; i++) {
      local ammo = unitBlk.ammoStowages.getBlock(i)
      if((ammo % "weaponTrigger").findvalue(@(inst) inst == trigger))
        return (ammo % "shells").findvalue(@(inst) inst?[paramName])
    }
    return null
  }

  getAmmoStowageReloadTimeMult = @(trigger) getAmmoStowageBlockByParam(trigger, "reloadTimeMult")?.reloadTimeMult ?? 1

  haveFirstStageShells = @(trigger) getAmmoStowageBlockByParam(trigger, "firstStage") ?? false

  // Gets info either by weaponTrigger (for guns and turrets)
  // or by ammoStowageId (for tank stowage or ship ammo storage)
  function getAmmoStowageInfo(weaponTrigger, ammoStowageId = null, collectOnlyThisStowage = false)
  {
    local res = { firstStageCount = 0, isAutoLoad = false, isCharges = false }
    for (local ammoNum = 1; ammoNum <= 20; ammoNum++) // tanks use 1, ships use 1 - ~10.
    {
      local ammoId = $"ammo{ammoNum}"
      local stowage = unitBlk?.ammoStowages?[ammoId]
      if (!stowage)
        break
      if (weaponTrigger && stowage.weaponTrigger != weaponTrigger)
        continue
      if ((unitBlk.ammoStowages % ammoId).len() > 1) {
        local unitName = unit?.name // warning disable: -declared-never-used
        ::script_net_assert_once("ammoStowages_contains_non-unique_ammo", "ammoStowages contains non-unique ammo")
      }
      foreach (blockName in [ "shells", "charges" ])
      {
        foreach (block in (stowage % blockName))
        {
          if (ammoStowageId && !block?[ammoStowageId])
            continue
          res.isCharges = blockName == "charges"
          if (block?.autoLoad)
            res.isAutoLoad = true
          if (block?.firstStage || block?.autoLoad)
          {
            if (ammoStowageId && collectOnlyThisStowage)
              res.firstStageCount += block?[ammoStowageId]?.count ?? 0
            else
              for (local i = 0; i < block.blockCount(); i++)
                res.firstStageCount += block.getBlock(i)?.count ?? 0
          }
          return res
        }
      }
    }
    return res
  }

  function getModernArmorParamsByDmPartName(partName)
  {
    local res = {
      isComposite = ::g_string.startsWith(partName, "composite_armor")
      titleLoc = ""
      armorClass = ""
      referenceProtectionArray = []
      layersArray = []
    }

    local blk = getXrayViewerDataByDmPartName(partName)
    if (blk)
    {
      res.titleLoc = blk?.titleLoc ?? ""

      local referenceProtectionBlocks = blk?.referenceProtectionTable ? (blk.referenceProtectionTable % "i")
        : (blk?.kineticProtectionEquivalent || blk?.cumulativeProtectionEquivalent) ? [ blk ]
        : []
      res.referenceProtectionArray = ::u.map(referenceProtectionBlocks, @(b) {
        angles = b?.angles
        kineticProtectionEquivalent    = b?.kineticProtectionEquivalent    ?? 0
        cumulativeProtectionEquivalent = b?.cumulativeProtectionEquivalent ?? 0
      })

      local armorParams = { armorClass = "", armorThickness = 0.0 }
      local armorLayersArray = (blk?.armorArrayText ?? ::DataBlock()) % "layer"

      foreach (layer in armorLayersArray)
      {
        local info = getDamagePartParamsByDmPartName(layer?.dmPart, armorParams)
        if (layer?.xrayTextThickness != null)
          info.armorThickness = layer.xrayTextThickness
        res.layersArray.append(info)
      }
    }
    else
    {
      local armorParams = { armorClass = "", kineticProtectionEquivalent = 0, cumulativeProtectionEquivalent = 0 }
      local info = getDamagePartParamsByDmPartName(partName, armorParams)
      res.referenceProtectionArray = [{
        angles = null
        kineticProtectionEquivalent    = info.kineticProtectionEquivalent
        cumulativeProtectionEquivalent = info.cumulativeProtectionEquivalent
      }]
      res = ::u.tablesCombine(res, info, @(a, b) b == null ? a : b, null, false)
    }

    return res
  }

  function getDamagePartParamsByDmPartName(partName, paramsTbl)
  {
    local res = clone paramsTbl
    if (!unitBlk?.DamageParts)
      return res
    local dmPartsBlk = unitBlk.DamageParts
    res = ::u.tablesCombine(res, dmPartsBlk, @(a, b) b == null ? a : b, null, false)
    for (local b = 0; b < dmPartsBlk.blockCount(); b++)
    {
      local groupBlk = dmPartsBlk.getBlock(b)
      if (!groupBlk || !groupBlk?[partName])
        continue
      res = ::u.tablesCombine(res, groupBlk, @(a, b) b == null ? a : b, null, false)
      res = ::u.tablesCombine(res, groupBlk[partName], @(a, b) b == null ? a : b, null, false)
      break
    }
    return res
  }

  function extractIndexFromDmPartName(partName)
  {
    local strArr = partName.split("_")
    local l = strArr.len()
    return (l > 2 && strArr[l - 1] == "dm") ? ::to_integer_safe(strArr[l - 2], -1, false) : -1
  }

  function checkPartLocId(partId, partName, weaponInfoBlk, params)
  {
    switch (unit.esUnitType)
    {
      case ::ES_UNIT_TYPE_TANK:
        if (partId == "gun_barrel" &&  weaponInfoBlk?.blk)
        {
          local status = getWeaponStatus(partName, weaponInfoBlk)
          params.partLocId <- status.isPrimary ? "weapon/primary"
            : status.isMachinegun ? "weapon/machinegun"
            : "weapon/secondary"
        }
        break
      case ::ES_UNIT_TYPE_BOAT:
      case ::ES_UNIT_TYPE_SHIP:
        if (::g_string.startsWith(partId, "main") && weaponInfoBlk?.triggerGroup == "secondary")
          params.partLocId <- ::stringReplace(partId, "main", "auxiliary")
        if (::g_string.startsWith(partId, "auxiliary") && weaponInfoBlk?.triggerGroup == "primary")
          params.partLocId <- ::stringReplace(partId, "auxiliary", "main")
        break
      case ::ES_UNIT_TYPE_HELICOPTER:
        if (::isInArray(partId, [ "gun", "cannon" ]))
          params.partLocId <- ::g_string.startsWith(weaponInfoBlk?.trigger, "gunner") ? "turret" : "cannon"
    }
  }

  function trimBetween(source, from, to, strict = true)
  {
    local beginIndex = source.indexof(from) ?? -1
    local endIndex = source.indexof(to) ?? -1
    if(strict && (beginIndex == -1 || endIndex == -1 || beginIndex >= endIndex))
      return null
    if(beginIndex == -1)
      beginIndex = 0
    beginIndex += from.len()
    if(endIndex == -1)
      beginIndex = source.len()
    return source.slice(beginIndex, endIndex)
  }

  function getMassInfo(data)
  {
    local massPatterns = [
      { variants = ["mass", "Mass"], langKey = "mass/kg" },
      { variants = ["mass_lbs", "Mass_lbs"], langKey = "mass/lbs" }
    ]
    foreach(pattern in massPatterns)
      foreach(nameVariant in pattern.variants)
        if(nameVariant in data)
          return format(::loc("shop/tank_mass") + " " + ::loc(pattern.langKey), data[nameVariant])
    return "";
  }

  function showExternalPartsArmor(isShow)
  {
    isVisibleExternalPartsArmor = isShow
    ::hangar_show_external_dm_parts_change(isShow)
  }

  function showExternalPartsXray(isShow)
  {
    isVisibleExternalPartsXray = isShow
    ::hangar_show_hidden_xray_parts_change(isShow)
  }

  function onEventActiveHandlersChanged(p)
  {
    update()
  }

  function onEventHangarModelLoading(p)
  {
    reinit()
  }

  function onEventHangarModelLoaded(p)
  {
    reinit()
  }

  function onEventUnitModsRecount(p)
  {
    if (p?.unit != unit)
      return
    clearCachedUnitBlkNodes()
    resetXrayCache()
  }

  function onEventUnitWeaponChanged(p)
  {
    if (!unit || p?.unitName != unit.name)
      return
    clearCachedUnitBlkNodes()
    resetXrayCache()
  }

  function onEventCurrentGameModeIdChanged(p)
  {
    difficulty = ::get_difficulty_by_ediff(::get_current_ediff())
    resetXrayCache()
  }

  function onEventGameLocalizationChanged(p)
  {
    resetXrayCache()
  }
}

::g_script_reloader.registerPersistentDataFromRoot("dmViewer")
::subscribe_handler(::dmViewer, ::g_listener_priority.DEFAULT_HANDLER)

::on_hangar_damage_part_pick <- function on_hangar_damage_part_pick(params) // Called from API
{
  ::dmViewer.updateHint(params)
}

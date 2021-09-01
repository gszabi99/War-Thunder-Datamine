local { getLastWeapon, isWeaponVisible } = require("scripts/weaponry/weaponryInfo.nut")
local { getWeaponInfoText,
        getWeaponNameText } = require("scripts/weaponry/weaponryDescription.nut")
local { showedUnit } = require("scripts/slotbar/playerCurUnit.nut")
local { cutPostfix } = require("std/string.nut")

::gui_start_builder_tuner <- function gui_start_builder_tuner()
{
  ::gui_start_modal_wnd(::gui_handlers.MissionBuilderTuner)
}

class ::gui_handlers.MissionBuilderTuner extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"

  unitsBlk = null
  listA = null
  listW = null
  listS = null
  listC = null
  wtags = null
  defaultW = null
  defaultS = null

  playerUnitId = ""
  playerIdx = 0

  commonSquadSize = 4
  maxSquadSize = 4

  function initScreen()
  {
    playerUnitId = showedUnit.value.name

    guiScene.setUpdatesEnabled(false, false)

    setSceneTitle(::loc("mainmenu/btnDynamicPreview"), scene, "menu-title")

    unitsBlk = DataBlock()
    ::dynamic_get_units(::mission_settings.missionFull, unitsBlk)

    local list = createOptions()
    local listObj = scene.findObject("optionslist")
    guiScene.replaceContentFromText(listObj, list, list.len(), this)

    //mission preview
    ::g_map_preview.setMapPreview(scene.findObject("tactical-map"), ::mission_settings.missionFull)

    local misObj = ""
    misObj = ::loc(format("mb/%s/objective", ::mission_settings.mission.getStr("name", "")), "")
    scene.findObject("mission-objectives").setValue(misObj)

    guiScene.setUpdatesEnabled(true, true)

    ::move_mouse_on_obj(scene.findObject("btn_apply"))
  }

  function buildAircraftOption(id, units, selUnitId)
  {
    local value = units.indexof(selUnitId) ?? 0
    local items = units.map(@(unitId) {
      text = $"#{unitId}_shop"
      image = ::image_for_air(unitId)
    })
    return {
      markup = ::create_option_combobox(id, items, value, "onChangeAircraft", true)
      values = units
    }
  }

  function buildWeaponOption(id, unitId, selWeapon, weapTags, isFull = true)
  {
    local weapons = getWeaponsList(unitId, weapTags)
    if (weapons.values.len() == 0)
    {
      dagor.debug($"Bomber without bombs: {unitId}")
      weapons = getWeaponsList(unitId)
    }

    local value = weapons.values.indexof(selWeapon) ?? 0
    return {
      markup = ::create_option_combobox(id, weapons.items, value, null, isFull)
      values = weapons.values
    }
  }

  function buildSkinOption(id, unitId, selSkin, isFull = true)
  {
    local skins = ::g_decorator.getSkinsOption(unitId)
    local value = skins.values.indexof(selSkin) ?? 0
    return {
      markup = ::create_option_combobox(id, skins.items, value, null, isFull)
      values = skins.values
    }
  }

  function buildCountOption(id, minCount, maxCount, selCount)
  {
    local values = []
    for (local i = minCount; i <= maxCount; i++)
      values.append(i)
    local value = values.indexof(selCount) ?? 0
    return {
      markup = ::create_option_combobox(id, values.map(@(v) v.tostring()), value, null, true)
      values
    }
  }

  function mkOptionRowView(labelText, optMarkup, trParams = "")
  {
    return {
      trParams = $"optionWidthInc:t='double'; {trParams}"
      cell = [ { params = {
          id = ""
          cellType = "left"
          width = "45%pw"
          rawParam = ::format("overflow:t='hidden'; optiontext{ text:t='%s' }", ::locOrStrip(labelText))
        } }, { params = {
          id = ""
          cellType = "right"
          width = "55%pw"
          rawParam = $"padding-left:t='@optPad'; {optMarkup}"
        } } ]
    }
  }

  function createOptions()
  {
    listA = []
    listW = []
    listS = []
    listC = []
    wtags = []
    defaultW = {}
    defaultS = {}

    local rowsView = []

    local isFreeFlight = ::mission_settings.missionFull.mission_settings.mission.isFreeFlight;

    for (local i = 0; i < unitsBlk.blockCount(); i++)
    {
      local armada = unitsBlk.getBlock(i)

      // Player's squad units
      if (armada?.isPlayer ?? false)
      {
        playerIdx = i
        listA.append([playerUnitId])
        listW.append([getLastWeapon(playerUnitId)])
        listS.append([::g_decorator.getLastSkin(playerUnitId)])
        listC.append([commonSquadSize])
        wtags.append([])
        defaultW[playerUnitId] <- listW[i]
        defaultS[playerUnitId] <- listS[i]
        continue
      }

      local name = armada.getStr("name","")
      local aircraft = armada.getStr("unit_class", "");
      local weapon = armada.getStr("weapons", "");
      local skin = armada.getStr("skin", "");
      local count = armada.getInt("count", commonSquadSize);
      local army = armada.getInt("army", 1); //1-ally, 2-enemy
      local isBomber = armada.getBool("mustBeBomber", false);
      local isFighter = armada.getBool("mustBeFighter", false);
      local isAssault = armada.getBool("mustBeAssault", false);
      local minCount = armada.getInt("minCount", 1);
      local maxCount = ::max(armada.getInt("maxCount", maxSquadSize), count)
      local excludeTag = isFreeFlight ? "not_in_free_flight" : "not_in_dynamic_campaign";

      if ((name == "") || (aircraft == ""))
        break;

      // Overriding ally unit params by player's squad unit params, when class is the same.
      if (aircraft == playerUnitId)
      {
        weapon = getLastWeapon(playerUnitId)
        skin = ::g_decorator.getLastSkin(playerUnitId)
      }

      local adesc = armada.description
      local fmTags = adesc % "needFmTag"
      local weapTags = adesc % "weaponOrTag"

      local aircrafts = []

      foreach(unit in ::all_units)
      {
        if (isInArray(excludeTag, unit.tags))
          continue
        if (isInArray("aux", unit.tags))
          continue
        local tagsOk = true
        for (local k = 0; k < fmTags.len(); k++)
          if (!isInArray(fmTags[k], unit.tags))
          {
            tagsOk = false
            break
          }
        if (!tagsOk)
          continue
        if (!hasWeaponsChoice(unit, weapTags))
          continue
        aircrafts.append(unit.name)
      }
      // make sure that aircraft exists in aircrafts array
      ::u.appendOnce(aircraft, aircrafts)

      aircrafts.sort()

      //aircraft type
      local trId = "".concat(
        (army == (unitsBlk?.playerSide ?? 1) ? "ally" : "enemy"),
        (isBomber ? "Bomber" : isFighter ? "Fighter" : isAssault ? "Assault" : ""))

      local option

      wtags.append(weapTags)
      defaultW[aircraft] <- weapon
      defaultS[aircraft] <- skin

      local airSeparatorStyle = i == 0 ? "" : "margin-top:t='10@sf/@pf';"

      // Aircraft
      option = buildAircraftOption($"{i}_a", aircrafts, aircraft)
      rowsView.append(mkOptionRowView($"#options/{trId}", option.markup, $"iconType:t='aircraft'; {airSeparatorStyle}"))
      listA.append(option.values)

      // Weapon
      option = buildWeaponOption($"{i}_w", aircraft, weapon, weapTags)
      rowsView.append(mkOptionRowView("#options/secondary_weapons", option.markup))
      listW.append(option.values)

      // Skin
      option = buildSkinOption($"{i}_s", aircraft, skin)
      rowsView.append(mkOptionRowView("#options/skin", option.markup))
      listS.append(option.values)

      // Count
      option = buildCountOption($"{i}_c", minCount, maxCount, count)
      rowsView.append(mkOptionRowView("#options/count", option.markup))
      listC.append(option.values)
    }

    return ::handyman.renderCached("gui/options/optionsContainer", {
      id = "tuner_options"
      topPos = "(ph-h)/2"
      position = "absolute"
      value = 0
      row = rowsView
    })
  }

  function onChangeAircraft(obj)
  {
    local i = ::to_integer_safe(cutPostfix(obj?.id ?? "", "_a", "-1"), -1)
    if (listA?[i] == null)
      return

    local unitId = listA[i][obj.getValue()]
    local option
    local optObj

    // Weapon
    option = buildWeaponOption(null, unitId, defaultW?[unitId], wtags[i], false)
    listW[i] = option.values
    optObj = scene.findObject($"{i}_w")
    guiScene.replaceContentFromText(optObj, option.markup, option.markup.len(), this)

    // Skin
    option = buildSkinOption(null, unitId, defaultS?[unitId], false)
    listS[i] = option.values
    optObj = scene.findObject($"{i}_s")
    guiScene.replaceContentFromText(optObj, option.markup, option.markup.len(), this)
  }

  function onApply(obj)
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(::GM_BUILDER)
      }))
      return

    for (local i = 0; i < listA.len(); i++)
    {
      local isPlayer = i == playerIdx
      local armada = unitsBlk.getBlock(i)
      armada.setStr("unit_class", listA[i][isPlayer ? 0 : scene.findObject($"{i}_a").getValue()])
      armada.setStr("weapons",    listW[i][isPlayer ? 0 : scene.findObject($"{i}_w").getValue()])
      armada.setStr("skin",       listS[i][isPlayer ? 0 : scene.findObject($"{i}_s").getValue()])
      armada.setInt("count",      listC[i][isPlayer ? 0 : scene.findObject($"{i}_c").getValue()])
    }

    ::mission_settings.mission.setInt("_gameMode", ::GM_BUILDER)
    ::mission_settings.mission.player_class = playerUnitId
    ::dynamic_set_units(::mission_settings.missionFull, unitsBlk)
    ::select_mission_full(::mission_settings.mission,
       ::mission_settings.missionFull)

    ::set_context_to_player("difficulty", ::get_mission_difficulty())

    local appFunc = function()
    {
      ::broadcastEvent("BeforeStartMissionBuilder")
      if (::SessionLobby.isInRoom())
        goForward(::gui_start_mp_lobby);
      else if (::mission_settings.coop)
      {
        // ???
      }
      else
        goForward(::gui_start_flight)
    }

    if (::get_gui_option(::USEROPT_DIFFICULTY) == "custom")
      ::gui_start_cd_options(appFunc, this)
    else
      appFunc()
  }

  function onBack(obj)
  {
    goBack()
  }

  function hasWeaponsChoice(unit, weapTags)
  {
    foreach (weapon in unit.weapons)
      if (isWeaponVisible(unit, weapon, false, weapTags))
        return true
    return false
  }

  function getWeaponsList(aircraft, weapTags = null)
  {
    local descr = {
      items = []
      values = []
    }

    local unit = ::getAircraftByName(aircraft)
    if (!unit)
      return descr

    foreach(weapNo, weapon in unit.weapons)
    {
      local weaponName = weapon.name
      if (!isWeaponVisible(unit, weapon, false, weapTags))
        continue

      descr.values.append(weaponName)
      descr.items.append({
        text = getWeaponNameText(unit, false, weapNo)
        tooltip = getWeaponInfoText(unit, { isPrimary = false, weaponPreset = weapNo })
      })
    }

    return descr
  }
}
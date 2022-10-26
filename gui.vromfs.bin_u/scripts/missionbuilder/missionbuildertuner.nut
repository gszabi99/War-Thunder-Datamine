from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { get_gui_option } = require("guiOptions")

let { getLastWeapon, isWeaponVisible } = require("%scripts/weaponry/weaponryInfo.nut")
let { getWeaponInfoText,
        getWeaponNameText } = require("%scripts/weaponry/weaponryDescription.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { cutPostfix } = require("%sqstd/string.nut")

::gui_start_builder_tuner <- function gui_start_builder_tuner()
{
  ::gui_start_modal_wnd(::gui_handlers.MissionBuilderTuner)
}

::gui_handlers.MissionBuilderTuner <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsMap.blk"
  sceneNavBlkName = "%gui/options/navOptionsBack.blk"

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
    this.playerUnitId = showedUnit.value.name

    this.guiScene.setUpdatesEnabled(false, false)

    this.setSceneTitle(loc("mainmenu/btnDynamicPreview"), this.scene, "menu-title")

    this.unitsBlk = ::DataBlock()
    ::dynamic_get_units(::mission_settings.missionFull, this.unitsBlk)

    let list = this.createOptions()
    let listObj = this.scene.findObject("optionslist")
    this.guiScene.replaceContentFromText(listObj, list, list.len(), this)

    //mission preview
    ::g_map_preview.setMapPreview(this.scene.findObject("tactical-map"), ::mission_settings.missionFull)

    local misObj = ""
    misObj = loc(format("mb/%s/objective", ::mission_settings.mission.getStr("name", "")), "")
    this.scene.findObject("mission-objectives").setValue(misObj)

    this.guiScene.setUpdatesEnabled(true, true)

    ::move_mouse_on_obj(this.scene.findObject("btn_apply"))
  }

  function buildAircraftOption(id, units, selUnitId)
  {
    let value = units.indexof(selUnitId) ?? 0
    let items = units.map(@(unitId) {
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
    local weapons = this.getWeaponsList(unitId, weapTags)
    if (weapons.values.len() == 0)
    {
      log($"Bomber without bombs: {unitId}")
      weapons = this.getWeaponsList(unitId)
    }

    let value = weapons.values.indexof(selWeapon) ?? 0
    return {
      markup = ::create_option_combobox(id, weapons.items, value, null, isFull)
      values = weapons.values
    }
  }

  function buildSkinOption(id, unitId, selSkin, isFull = true)
  {
    let skins = ::g_decorator.getSkinsOption(unitId)
    let value = skins.values.indexof(selSkin) ?? 0
    return {
      markup = ::create_option_combobox(id, skins.items, value, null, isFull)
      values = skins.values
    }
  }

  function buildCountOption(id, minCount, maxCount, selCount)
  {
    let values = []
    for (local i = minCount; i <= maxCount; i++)
      values.append(i)
    let value = values.indexof(selCount) ?? 0
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
          rawParam = format("overflow:t='hidden'; optiontext{ text:t='%s' }", ::locOrStrip(labelText))
        } }, { params = {
          id = ""
          cellType = "right"
          width = "55%pw"
          rawParam = $"padding-left:t='@optPad'; {optMarkup}"
        } } ]
    }
  }


  function getSuitableUnits(excludeTag, fmTags, weapTags)
  {
    let suitableUnits = []
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
      if (!this.hasWeaponsChoice(unit, weapTags))
        continue
      suitableUnits.append(unit.name)
    }
    return suitableUnits
  }


  function createOptions()
  {
    this.listA = []
    this.listW = []
    this.listS = []
    this.listC = []
    this.wtags = []
    this.defaultW = {}
    this.defaultS = {}

    let rowsView = []

    let isFreeFlight = ::mission_settings.missionFull.mission_settings.mission.isFreeFlight;

    for (local i = 0; i < this.unitsBlk.blockCount(); i++)
    {
      let armada = this.unitsBlk.getBlock(i)

      // Player's squad units
      if (armada?.isPlayer ?? false)
      {
        this.playerIdx = i
        this.listA.append([this.playerUnitId])
        this.listW.append([getLastWeapon(this.playerUnitId)])
        this.listS.append([::g_decorator.getLastSkin(this.playerUnitId)])
        this.listC.append([this.commonSquadSize])
        this.wtags.append([])
        this.defaultW[this.playerUnitId] <- this.listW[i]
        this.defaultS[this.playerUnitId] <- this.listS[i]
        continue
      }

      let name = armada.getStr("name","")
      let aircraft = armada.getStr("unit_class", "");
      local weapon = armada.getStr("weapons", "");
      local skin = armada.getStr("skin", "");
      let count = armada.getInt("count", this.commonSquadSize);
      let army = armada.getInt("army", 1); //1-ally, 2-enemy
      let isBomber = armada.getBool("mustBeBomber", false);
      let isFighter = armada.getBool("mustBeFighter", false);
      let isAssault = armada.getBool("mustBeAssault", false);
      let minCount = armada.getInt("minCount", 1);
      let maxCount = max(armada.getInt("maxCount", this.maxSquadSize), count)
      let excludeTag = isFreeFlight ? "not_in_free_flight" : "not_in_dynamic_campaign";

      if ((name == "") || (aircraft == ""))
        break;

      // Overriding ally unit params by player's squad unit params, when class is the same.
      if (aircraft == this.playerUnitId)
      {
        weapon = getLastWeapon(this.playerUnitId)
        skin = ::g_decorator.getLastSkin(this.playerUnitId)
      }

      let adesc = armada.description
      let fmTags = adesc % "needFmTag"
      let weapTags = adesc % "weaponOrTag"

      let aircrafts = this.getSuitableUnits(excludeTag, fmTags, weapTags)
      // make sure that aircraft exists in aircrafts array
      ::u.appendOnce(aircraft, aircrafts)

      aircrafts.sort()

      //aircraft type
      let trId = "".concat(
        (army == (this.unitsBlk?.playerSide ?? 1) ? "ally" : "enemy"),
        (isBomber ? "Bomber" : isFighter ? "Fighter" : isAssault ? "Assault" : ""))

      local option

      this.wtags.append(weapTags)
      this.defaultW[aircraft] <- weapon
      this.defaultS[aircraft] <- skin

      let airSeparatorStyle = i == 0 ? "" : "margin-top:t='10@sf/@pf';"

      // Aircraft
      option = this.buildAircraftOption($"{i}_a", aircrafts, aircraft)
      rowsView.append(this.mkOptionRowView($"#options/{trId}", option.markup, $"iconType:t='aircraft'; {airSeparatorStyle}"))
      this.listA.append(option.values)

      // Weapon
      option = this.buildWeaponOption($"{i}_w", aircraft, weapon, weapTags)
      rowsView.append(this.mkOptionRowView("#options/secondary_weapons", option.markup))
      this.listW.append(option.values)

      // Skin
      option = this.buildSkinOption($"{i}_s", aircraft, skin)
      rowsView.append(this.mkOptionRowView("#options/skin", option.markup))
      this.listS.append(option.values)

      // Count
      option = this.buildCountOption($"{i}_c", minCount, maxCount, count)
      rowsView.append(this.mkOptionRowView("#options/count", option.markup))
      this.listC.append(option.values)
    }

    return ::handyman.renderCached("%gui/options/optionsContainer.tpl", {
      id = "tuner_options"
      topPos = "(ph-h)/2"
      position = "absolute"
      value = 0
      row = rowsView
    })
  }

  function onChangeAircraft(obj)
  {
    let i = ::to_integer_safe(cutPostfix(obj?.id ?? "", "_a", "-1"), -1)
    if (this.listA?[i] == null)
      return

    let unitId = this.listA[i][obj.getValue()]
    local option
    local optObj

    // Weapon
    option = this.buildWeaponOption(null, unitId, this.defaultW?[unitId], this.wtags[i], false)
    this.listW[i] = option.values
    optObj = this.scene.findObject($"{i}_w")
    this.guiScene.replaceContentFromText(optObj, option.markup, option.markup.len(), this)

    // Skin
    option = this.buildSkinOption(null, unitId, this.defaultS?[unitId], false)
    this.listS[i] = option.values
    optObj = this.scene.findObject($"{i}_s")
    this.guiScene.replaceContentFromText(optObj, option.markup, option.markup.len(), this)
  }

  function onApply(_obj)
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(GM_BUILDER)
      }))
      return

    for (local i = 0; i < this.listA.len(); i++)
    {
      let isPlayer = i == this.playerIdx
      let armada = this.unitsBlk.getBlock(i)
      armada.setStr("unit_class", this.listA[i][isPlayer ? 0 : this.scene.findObject($"{i}_a").getValue()])
      armada.setStr("weapons",    this.listW[i][isPlayer ? 0 : this.scene.findObject($"{i}_w").getValue()])
      armada.setStr("skin",       this.listS[i][isPlayer ? 0 : this.scene.findObject($"{i}_s").getValue()])
      armada.setInt("count",      this.listC[i][isPlayer ? 0 : this.scene.findObject($"{i}_c").getValue()])
    }

    ::mission_settings.mission.setInt("_gameMode", GM_BUILDER)
    ::mission_settings.mission.player_class = this.playerUnitId
    ::dynamic_set_units(::mission_settings.missionFull, this.unitsBlk)
    ::select_mission_full(::mission_settings.mission,
       ::mission_settings.missionFull)

    ::set_context_to_player("difficulty", ::get_mission_difficulty())

    let appFunc = function()
    {
      ::broadcastEvent("BeforeStartMissionBuilder")
      if (::SessionLobby.isInRoom())
        this.goForward(::gui_start_mp_lobby);
      else if (::mission_settings.coop)
      {
        // ???
      }
      else
        this.goForward(::gui_start_flight)
    }

    if (get_gui_option(::USEROPT_DIFFICULTY) == "custom")
      ::gui_start_cd_options(appFunc, this)
    else
      appFunc()
  }

  function onBack(_obj)
  {
    this.goBack()
  }

  function hasWeaponsChoice(unit, weapTags)
  {
    foreach (weapon in unit.getWeapons())
      if (isWeaponVisible(unit, weapon, false, weapTags))
        return true
    return false
  }

  function getWeaponsList(aircraft, weapTags = null)
  {
    let descr = {
      items = []
      values = []
    }

    let unit = ::getAircraftByName(aircraft)
    if (!unit)
      return descr

    foreach(weapNo, weapon in unit.getWeapons())
    {
      let weaponName = weapon.name
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

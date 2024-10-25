from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { hangar_set_dm_viewer_mode } = require("hangar")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isInMenu, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getUnitName, getUnitCountry, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { on_parse_replay, get_parsed_replay, get_replay_info, repeat_shot_from_blk,
  on_parse_temp_replay, get_temp_replay_info, get_replay_hits_dir } = require("replays")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { doesLocTextExist } = require("dagor.localize")
let { secondsToTimeSimpleString } = require("%scripts/time.nut")
let { setShowUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { image_for_air } = require("%scripts/options/optionsExt.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let DataBlock = require("DataBlock")

gui_handlers.HitsAnalysis <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/dmViewer/hitsAnalysis.blk"

  hitsData = null
  currentHitsData = []
  owners = []
  ediff = null
  selectedHit = null

  function initScreen() {
    this.setSceneTitle(loc("hitsAnalisys"))
    this.fillHitOwnerList()
  }

  function fillHitOwnerList() {
    this.owners.clear()
    let items = []
    let hitsOwner = this.scene.findObject("hits_owner")

    if (this.hitsData.findindex(@(v) v.damageRole == "offender") != null) {
      items.append({ text = loc("hitsAnalisys/myHits") })
      this.owners.append("offender")
    }
    if (this.hitsData.findindex(@(v) v.damageRole == "victim") != null) {
      items.append({ text = loc("hitsAnalisys/enemyHits") })
      this.owners.append("victim")
    }

    let data = ::create_option_combobox("hits_owner", items, 0, "onHitsOwnerChange", false)
    this.guiScene.replaceContentFromText(hitsOwner, data, data.len(), this)
    hitsOwner.setValue(0)
  }

  function fillShotsList() {
    let diff = this.ediff
    let hitsData = this.currentHitsData.map(function(h) {
      let time = secondsToTimeSimpleString(h.time)
      let unit = getAircraftByName(h.object)
      let br = unit?.getBattleRating(diff) ?? 0
      let killerProjectileName = doesLocTextExist(h.ammo) ? loc(h.ammo)
        : loc($"weapons/{h.ammo}/short", "")
      let unitAndWeapon = $"[{br}] {getUnitName(unit?.name)} - {killerProjectileName}"

      return {
        time
        unitAndWeapon
      }
    })

    let listObj = this.scene.findObject("shots_list")
    let data = handyman.renderCached("%gui/dmViewer/hitsAnalysisItems.tpl", { items = hitsData })
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    listObj.setValue(0)
  }

  function onHitsOwnerChange(obj) {
    let damageRole = this.owners[obj.getValue()]
    this.currentHitsData = this.hitsData.filter(@(v) v.damageRole == damageRole)
    this.fillShotsList()
  }

  function onItemSelect(obj) {
    this.selectedHit = this.currentHitsData[obj.getValue()]
    let unit = getAircraftByName(this.selectedHit.offenderObject)

    let unitType = $"{unit.unitType.fontIcon} {unit.unitType.getArmyLocName()}"
    let unitCountryFlag = getUnitCountryIcon(unit, true)
    let unitCountry = loc(getUnitCountry(unit))
    let unitRank = $"{get_roman_numeral(unit.rank)} {loc("shop/age")}"
    let unitIcon = image_for_air(unit)
    let unitName = $"[{unit.getBattleRating(this.ediff)}] {getUnitName(this.selectedHit.offenderObject, true)}"
    let bulletName = doesLocTextExist(this.selectedHit.ammo) ? loc(this.selectedHit.ammo)
      : loc($"weapons/{this.selectedHit.ammo}/short", "")

    this.scene.findObject("unitType").setValue(unitType)
    this.scene.findObject("unitCountryFlag")["background-image"] = unitCountryFlag
    this.scene.findObject("unitCountry").setValue(unitCountry)
    this.scene.findObject("unitRank").setValue(unitRank)
    this.scene.findObject("unitIcon")["background-image"] = unitIcon
    this.scene.findObject("unitName").setValue(unitName)

    this.scene.findObject("unitTooltip")["tooltipId"] = getTooltipType("UNIT").getTooltipId(unit.name, { showLocalState = false })
    this.scene.findObject("bulletName").setValue(bulletName)
    this.scene.findObject("shotDistance").setValue(this.selectedHit.distance)
    this.scene.findObject("shotDistanceText").setValue($"{this.selectedHit.distance} {loc("measureUnits/meters_dist")}")

    setShowUnit(getAircraftByName(this.selectedHit.object))
  }

  function onSimulateShot(_) {
    if (this.selectedHit == null)
      return

    repeat_shot_from_blk(this.selectedHit)
  }

  function onSaveShot(_) {
    if (this.selectedHit == null)
      return

    let fileName = $"{this.selectedHit.object}_{this.selectedHit.ammo}_{this.selectedHit.time}"
    let onSelectCallback = function(path) {
      let filePath = $"{get_replay_hits_dir()}\\{path}.blk"
      this.selectedHit.saveToTextFile(filePath)
    }

    handlersManager.loadHandler(gui_handlers.RenameReplayHandler, {
      baseName = fileName
      basePath = "/".concat(get_replay_hits_dir(), fileName)
      funcOwner = this
      afterRenameFunc = null
      afterFunc = onSelectCallback
      title = "filesystem/fileName"
    })
  }

  function goBack() {
    hangar_set_dm_viewer_mode(DM_VIEWER_NONE)
    base.goBack()
  }
}

function canOpenHitsAnalysisWindow() {
  return hasFeature("HitsAnalysis")
    && isInMenu()
    && !::SessionLobby.hasSessionInLobby()
}

function openHitsAnalysisWindow(path = null) {
  if (!canOpenHitsAnalysisWindow())
    return

  if (path == null)
    on_parse_temp_replay()
  else
    on_parse_replay(path)

  let parsedReplay = get_parsed_replay()
  let hitsDataDb = (parsedReplay % "context").filter(@(v) v.ammo != "")
  if (hitsDataDb.len() == 0) {
    scene_msg_box("shot_analysis", null, loc("hitsAnalisys/noHitsInReplay"), [["ok", @() null]], null)
    return
  }

  let hitsData = hitsDataDb.map(function(h) {
    let res = DataBlock()
    res.setFrom(h)
    return res
  })

  let ediff = (path == null) ? get_temp_replay_info().difficulty : get_replay_info(path).difficulty
  handlersManager.loadHandler(gui_handlers.HitsAnalysis, { hitsData, ediff })
}

return {
  canOpenHitsAnalysisWindow
  openHitsAnalysisWindow
}
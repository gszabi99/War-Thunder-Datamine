from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { mapObjectSelect } = require("%scripts/worldWar/worldWarConst.nut")
let { wwGetBattlesInfo, wwFindLastFlewOutArmyNameByAirfield, wwIsCellGenerallyPassable } = require("worldwar")
let DataBlock = require("DataBlock")
let { WwBattle } = require("%scripts/worldWar/inOperation/model/wwBattle.nut")
let actionModesManager = require("%scripts/worldWar/inOperation/wwActionModesManager.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { eventbus_send } = require("eventbus")
let { mapCellUnderCursor } = require("%appGlobals/wwObjectsUnderCursor.nut")

let sendMapEvent = @(eventName, params = {}) wwEvent($"Map{eventName}", params)

function getBattleById(battleId) {
  let blk = DataBlock()
  wwGetBattlesInfo(blk)

  if (!("battles" in blk))
    return null

  let itemCount = blk.battles.blockCount()

  for (local i = 0; i < itemCount; i++) {
    let battle = WwBattle(blk.battles.getBlock(i))
    if (battle.id == battleId && battle.isValid())
      return battle
  }
  return null
}


function selectAirfield(params) {
  if (params.airfieldIdx >= 0) {
    sendMapEvent("AirfieldSelected", params)
    get_cur_gui_scene()?.playSound("ww_airfield_select")
  }
  else
    sendMapEvent("AirfieldCleared")
}

function selectArmy(params) {
  let { armyName } = params
  wwEvent("SelectLogArmyByName", { name = armyName })
  sendMapEvent("ArmySelected", { armyName, armyType = mapObjectSelect.ARMY })
  get_cur_gui_scene()?.playSound("ww_unit_select")
}

function selectRearZone(params) {
  sendMapEvent("RearZoneSelected", params)
}

function selectBattle(params) {
  let battle = getBattleById(params?.battleName)
  if(battle != null)
    gui_handlers.WwBattleDescription.open(battle)
}

function hoverArmy(params) {
  if (params?.armyName == "")
    params.rawdelete("armyName")
  sendMapEvent("UpdateCursorByTimer", params)
}

function hoverBattle(params) {
  sendMapEvent("UpdateCursorByTimer", params)
}

function clearHovers(params) {
  sendMapEvent("UpdateCursorByTimer", params)
}

function doAction(_params) {
  let curActionMode = actionModesManager.getCurActionMode()
  if (curActionMode != null)
    curActionMode.useAction()
}

function moveArmy(params) {
  let { pos, targetArmyName, append } = params
  ::g_world_war.moveSelectedArmes(pos.x, pos.y, targetArmyName, append, mapCellUnderCursor.get())
}

function sendAircraft(params) {
  let { pos, airfieldIdx, armyTargetName } = params
  let cellIdx = mapCellUnderCursor.get()
  let checkFlewOutArmy = function() {
    let armyName = wwFindLastFlewOutArmyNameByAirfield(airfieldIdx)
    if (armyName && armyName != "") {
      eventbus_send("ww.unselectAirfield")
      eventbus_send("ww.selectArmyByName", armyName)
    }
  }

  if (wwIsCellGenerallyPassable(cellIdx))
    gui_handlers.WwAirfieldFlyOut.open(
      airfieldIdx, pos, armyTargetName, cellIdx, Callback(checkFlewOutArmy, this))
  else
    addPopup("", loc("worldwar/charError/MOVE_REJECTED"),
      null, null, null, "send_air_army_error")
}

return {
  selectAirfield
  selectArmy
  hoverArmy
  selectRearZone
  hoverBattle
  selectBattle
  clearHovers
  doAction
  moveArmy
  sendAircraft
}

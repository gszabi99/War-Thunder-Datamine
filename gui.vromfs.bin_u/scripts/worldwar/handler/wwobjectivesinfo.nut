from "worldwar" import wwGetOperationId, wwGetPlayerSide
from "%scripts/dagui_natives.nut" import ww_side_val_to_name
from "%scripts/dagui_library.nut" import *
from "%scripts/seen/seenIds.nut" import SEEN

let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { wwObjective } = require("%scripts/worldWar/inOperation/handler/wwObjective.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let seenWWMapsObjective = require("%scripts/seen/seenList.nut").get(SEEN.WW_MAPS_OBJECTIVE)
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getSidesOrder } = require("%scripts/worldWar/inOperation/wwOperationStates.nut")


let WwObjectivesInfo = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/worldWar/objectivesInfoWindow.tpl"

  staticBlk = null
  dynamicBlk = null

  teamObjectiveHandlersArray = null

  static function open() {
    handlersManager.loadHandler(get_gui_handler("WwObjectivesInfo"))
  }

  function getSceneTplView() {
    return {
      teamBlock = this.getTeamsData()
    }
  }

  function getSceneTplContainerObj() {
    return this.scene.findObject("root-box")
  }

  function initScreen() {
    this.teamObjectiveHandlersArray = []
    foreach (side in getSidesOrder())
      this.initSideBlock(side, ww_side_val_to_name(side))
    this.markSeenCurObjective()
    this.guiScene.playSound("ww_globe_battle_select")
  }

  function markSeenCurObjective() {
    let curOperation = getOperationById(wwGetOperationId())
    if (curOperation)
      seenWWMapsObjective.markSeen(curOperation.getMapId())
  }

  function initSideBlock(side, objId) {
    let operationBlockObj = this.scene.findObject(objId)
    if (!checkObj(operationBlockObj))
      return

    let objectiveHandler = handlersManager.loadHandler(wwObjective, {
      scene = operationBlockObj,
      side = side,
      needShowOperationDesc = false,
      reqFullMissionObjectsButton = false
      hasObjectiveDesc = true
    })

    if (!objectiveHandler)
      return

    this.teamObjectiveHandlersArray.append(objectiveHandler)
    this.registerSubHandler(objectiveHandler)
  }

  function getTeamsData() {
    let mySide = wwGetPlayerSide()
    let teams = []
    foreach (side in getSidesOrder()) {
      teams.append({
        teamName = ww_side_val_to_name(side)
        teamColor = side == mySide ? "blue" : "red"
      })
    }

    return teams
  }
}
register_gui_handler("WwObjectivesInfo", WwObjectivesInfo)

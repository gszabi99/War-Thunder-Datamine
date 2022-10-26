from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let seenWWMapsObjective = require("%scripts/seen/seenList.nut").get(SEEN.WW_MAPS_OBJECTIVE)
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

::gui_handlers.WwObjectivesInfo <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/worldWar/objectivesInfoWindow.tpl"

  staticBlk = null
  dynamicBlk = null

  teamObjectiveHandlersArray = null

  static function open()
  {
    ::handlersManager.loadHandler(::gui_handlers.WwObjectivesInfo)
  }

  function getSceneTplView()
  {
    return {
      teamBlock = this.getTeamsData()
    }
  }

  function getSceneTplContainerObj()
  {
    return this.scene.findObject("root-box")
  }

  function initScreen()
  {
    this.teamObjectiveHandlersArray = []
    foreach (side in ::g_world_war.getSidesOrder())
      this.initSideBlock(side, ::ww_side_val_to_name(side))
    this.markSeenCurObjective()
    this.guiScene.playSound("ww_globe_battle_select")
  }

  function markSeenCurObjective()
  {
    let curOperation = getOperationById(::ww_get_operation_id())
    if (curOperation)
      seenWWMapsObjective.markSeen(curOperation.getMapId())
  }

  function initSideBlock(side, objId)
  {
    let operationBlockObj = this.scene.findObject(objId)
    if (!checkObj(operationBlockObj))
      return

    let objectiveHandler = ::handlersManager.loadHandler(::gui_handlers.wwObjective, {
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

  function getTeamsData()
  {
    let mySide = ::ww_get_player_side()
    let teams = []
    foreach (side in ::g_world_war.getSidesOrder())
    {
      teams.append({
        teamName = ::ww_side_val_to_name(side)
        teamColor = side == mySide? "blue" : "red"
      })
    }

    return teams
  }
}

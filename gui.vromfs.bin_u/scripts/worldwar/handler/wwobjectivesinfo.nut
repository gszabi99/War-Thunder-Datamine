let seenWWMapsObjective = require("%scripts/seen/seenList.nut").get(SEEN.WW_MAPS_OBJECTIVE)
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")

::gui_handlers.WwObjectivesInfo <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/worldWar/objectivesInfoWindow"

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
      teamBlock = getTeamsData()
    }
  }

  function getSceneTplContainerObj()
  {
    return scene.findObject("root-box")
  }

  function initScreen()
  {
    teamObjectiveHandlersArray = []
    foreach (side in ::g_world_war.getSidesOrder())
      initSideBlock(side, ::ww_side_val_to_name(side))
    markSeenCurObjective()
    guiScene.playSound("ww_globe_battle_select")
  }

  function markSeenCurObjective()
  {
    let curOperation = getOperationById(::ww_get_operation_id())
    if (curOperation)
      seenWWMapsObjective.markSeen(curOperation.getMapId())
  }

  function initSideBlock(side, objId)
  {
    let operationBlockObj = scene.findObject(objId)
    if (!::checkObj(operationBlockObj))
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

    teamObjectiveHandlersArray.append(objectiveHandler)
    registerSubHandler(objectiveHandler)
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

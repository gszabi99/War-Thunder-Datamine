from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_load_mission_objectives <- function gui_load_mission_objectives(nestObj, leftAligned, typesMask = 0) {
  return ::handlersManager.loadHandler(::gui_handlers.misObjectivesView,
                                       { scene = nestObj,
                                         sceneBlkName = leftAligned ? "%gui/missions/misObjective.blk" : "%gui/missions/misObjectiveRight.blk"
                                         objTypeMask = typesMask || ::gui_handlers.misObjectivesView.typesMask
                                       })
}

::gui_handlers.misObjectivesView <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/missions/misObjective.blk"

  objTypeMask = (1 << OBJECTIVE_TYPE_PRIMARY) + (1 << OBJECTIVE_TYPE_SECONDARY)

  curList = null

  function initScreen()
  {
    curList = []
    scene.findObject("objectives_list_timer").setUserData(this)
    refreshList()
  }

  function onUpdate(obj, dt)
  {
    refreshList()
  }

  function onSceneActivate(show)
  {
    if (show)
      refreshList()
  }

  function getNewList()
  {
    let fullList = ::get_objectives_list()
    let res = []
    foreach(misObj in fullList)
      if (misObj.status > 0 && (objTypeMask & (1 << misObj.type)))
        res.append(misObj)

    res.sort(function(a, b) {
      if (a.type != b.type)
        return a.type > b.type ? 1 : -1
      if (a.id != b.id)
        return (a.id > b.id) ? 1 : -1
      return 0
    })
    return res
  }

  function refreshList()
  {
    let newList = getNewList()
    let total = max(newList.len(), curList.len())
    local lastObj = null
    for(local i = 0; i < total; i++)
    {
      let newObjective = getTblValue(i, newList)
      if (::u.isEqual(getTblValue(i, curList), newObjective))
        continue

      let obj = updateObjective(i, newObjective)
      if (obj) lastObj = obj
    }

    if (lastObj)
      lastObj.scrollToView()

    curList = newList
  }

  function updateObjective(idx, objective)
  {
    let obj = getMisObjObject(idx)
    let show = objective != null
    obj.show(show)
    if (!show)
      return null

    let status = ::g_objective_status.getObjectiveStatusByCode(objective.status)
    obj.findObject("obj_img")["background-image"] = status.missionObjImg

    local text = loc(objective.text)
    if (!::u.isEmpty(objective.mapSquare))
      text += "  " + objective.mapSquare
    obj.findObject("obj_text").setValue(text)

    ::broadcastEvent("MissionObjectiveUpdated")

    return obj
  }

  function getMisObjObject(idx)
  {
    let id = "objective_" + idx
    local obj = scene.findObject(id)
    if (checkObj(obj))
      return obj

    obj = scene.findObject("objective_teamplate").getClone(scene, this)
    obj.id = id
    return obj
  }
}
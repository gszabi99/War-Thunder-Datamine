//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")

::gui_load_mission_objectives <- function gui_load_mission_objectives(nestObj, leftAligned, typesMask = 0) {
  return ::handlersManager.loadHandler(::gui_handlers.misObjectivesView,
                                       { scene = nestObj,
                                         sceneBlkName = leftAligned ? "%gui/missions/misObjective.blk" : "%gui/missions/misObjectiveRight.blk"
                                         objTypeMask = typesMask || ::gui_handlers.misObjectivesView.typesMask
                                       })
}

::gui_handlers.misObjectivesView <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/missions/misObjective.blk"

  objTypeMask = (1 << OBJECTIVE_TYPE_PRIMARY) + (1 << OBJECTIVE_TYPE_SECONDARY)

  curList = null

  function initScreen() {
    this.curList = []
    this.scene.findObject("objectives_list_timer").setUserData(this)
    this.refreshList()
  }

  function onUpdate(_obj, _dt) {
    this.refreshList()
  }

  function onSceneActivate(show) {
    if (show)
      this.refreshList()
  }

  function getNewList() {
    let fullList = ::get_objectives_list()
    let res = []
    foreach (misObj in fullList)
      if (misObj.status > 0 && (this.objTypeMask & (1 << misObj.type)))
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

  function refreshList() {
    let newList = this.getNewList()
    let total = max(newList.len(), this.curList.len())
    local lastObj = null
    for (local i = 0; i < total; i++) {
      let newObjective = getTblValue(i, newList)
      if (u.isEqual(getTblValue(i, this.curList), newObjective))
        continue

      let obj = this.updateObjective(i, newObjective)
      if (obj)
        lastObj = obj
    }

    if (lastObj)
      lastObj.scrollToView()

    this.curList = newList
  }

  function updateObjective(idx, objective) {
    let obj = this.getMisObjObject(idx)
    let show = objective != null
    obj.show(show)
    if (!show)
      return null

    let status = ::g_objective_status.getObjectiveStatusByCode(objective.status)
    obj.findObject("obj_img")["background-image"] = status.missionObjImg

    local text = loc(objective.text)
    if (!u.isEmpty(objective.mapSquare))
      text += "  " + objective.mapSquare
    obj.findObject("obj_text").setValue(text)

    broadcastEvent("MissionObjectiveUpdated")

    return obj
  }

  function getMisObjObject(idx) {
    let id = "objective_" + idx
    local obj = this.scene.findObject(id)
    if (checkObj(obj))
      return obj

    obj = this.scene.findObject("objective_teamplate").getClone(this.scene, this)
    obj.id = id
    return obj
  }
}
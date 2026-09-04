import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "guiMission" import get_objectives_list, OBJECTIVE_TYPE_PRIMARY, OBJECTIVE_TYPE_SECONDARY
from "%scripts/dagui_library.nut" import *

let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getObjectiveStatusByCode } = require("%scripts/misObjectives/objectiveStatus.nut")

function gui_load_mission_objectives(nestObj, leftAligned, typesMask = 0) {
  return handlersManager.loadHandler(get_gui_handler("misObjectivesView"),
                                       { scene = nestObj,
                                         sceneBlkName = leftAligned ? "%gui/missions/misObjective.blk" : "%gui/missions/misObjectiveRight.blk"
                                         objTypeMask = typesMask || get_gui_handler("misObjectivesView").objTypeMask
                                       })
}

let misObjectivesView = class (BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/missions/misObjective.blk"

  objTypeMask = (1 << OBJECTIVE_TYPE_PRIMARY) | (1 << OBJECTIVE_TYPE_SECONDARY)

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
    let fullList = get_objectives_list()
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
      let newObjective = newList?[i]
      if (u.isEqual(this.curList?[i], newObjective))
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

    let status = getObjectiveStatusByCode(objective.status)
    obj.findObject("obj_img")["background-image"] = status.missionObjImg

    local text = loc(objective.text)
    if (!u.isEmpty(objective.mapSquare))
      text = "".concat(text, "  ", objective.mapSquare)
    obj.findObject("obj_text").setValue(text)

    broadcastEvent("MissionObjectiveUpdated")

    return obj
  }

  function getMisObjObject(idx) {
    let id = $"objective_{idx}"
    local obj = this.scene.findObject(id)
    if (checkObj(obj))
      return obj

    obj = this.scene.findObject("objective_teamplate").getClone(this.scene, this)
    obj.id = id
    return obj
  }
}
register_gui_handler("misObjectivesView", misObjectivesView)

return {
  gui_load_mission_objectives
}
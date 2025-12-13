from "%scripts/dagui_library.nut" import *

let { getObjIdByPrefix } = require("%scripts/utils_sa.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { parse_json } = require("json")
let { getTooltipType } = require("genericTooltipTypes.nut")
let { startsWith } = require("%sqstd/string.nut")
let { add_event_listener, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { openModalInfo, closeModalInfo } = require("%scripts/modalInfo/modalInfo.nut")

dagui_propid_add_name_id("tooltipId")

local openedTooltipObjs = []
function removeInvalidTooltipObjs() {
  openedTooltipObjs = openedTooltipObjs.filter(@(t) t.isValid())
}

function getTooltipObjId(obj) {
  return obj?.tooltipId ?? getObjIdByPrefix(obj, "tooltip_")
}

function fillTooltip(obj, handler, tooltipType, id, params) {
  local isSucceed = true
  if (tooltipType.isCustomTooltipFill)
    isSucceed = tooltipType.fillTooltip(obj, handler, id, params)
  else {
    let content = tooltipType.getTooltipContent(id, params)
    if (content.len())
      obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
    else
      isSucceed = false
  }
  return isSucceed
}

function addEventListenersTooltip(obj, handler, tooltipType, id, params) {
  let data = {
    obj         = obj
    handler     = handler
    tooltipType = tooltipType
    id          = id
    params      = params
    isValid     = function() { return checkObj(obj) && obj.isVisible() }
  }

  foreach (key, value in tooltipType)
    if (u.isFunction(value) && startsWith(key, "onEvent")) {
      let eventName = key.slice("onEvent".len())
      add_event_listener(eventName,
        @(eventParams) tooltipType[$"onEvent{eventName}"](eventParams, obj, handler, id, params), data)
    }
  return data
}

function openGenericTooltip(obj, handler) {
  removeInvalidTooltipObjs()
  if (!checkObj(obj))
    return
  obj["class"] = "empty"

  if (!handlersManager.isHandlerValid(handler))
    return
  let tooltipId = getTooltipObjId(obj)
  if (!tooltipId || tooltipId == "")
    return
  let params = parse_json(tooltipId)
  if (type(params) != "table" || !("ttype" in params) || !("id" in params))
    return

  let tooltipType = getTooltipType(params.ttype)
  let id = params.id

  if (tooltipType.isModalTooltip && hasFeature("UnitModalInfo")) {
    let realObj = openModalInfo(obj, handler, tooltipType, id, params)
    if (realObj == null)
      return false
    openedTooltipObjs.append(addEventListenersTooltip(realObj, handler, tooltipType, id, params))
    return
  }

  let isSucceed = fillTooltip(obj, handler, tooltipType, id, params)

  if (!isSucceed || !checkObj(obj))
    return

  obj["class"] = (hasFeature("UnitModalInfo") && tooltipType.isEmptyTooltipObjClass) ? "empty" : ""
  openedTooltipObjs.append(addEventListenersTooltip(obj, handler, tooltipType, id, params))
}

function closeGenericTooltip(obj, handler) {
  if (hasFeature("UnitModalInfo"))
    closeModalInfo()

  let tIdx = !obj.isValid() ? null
    : openedTooltipObjs.findindex(@(v) v.obj.isValid() && v.obj.isEqual(obj))
  if (tIdx != null) {
    let tooltipData = openedTooltipObjs[tIdx]
    tooltipData.tooltipType.onClose(obj)
    openedTooltipObjs.remove(tIdx)
  }

  if (!checkObj(obj) || !obj.childrenCount())
    return
  let guiScene = obj.getScene()
  obj.show(false)

  guiScene.performDelayed(handler, function() {
    if (!checkObj(obj) || !obj.childrenCount())
      return

    
    let dbg_event = obj?.on_tooltip_open
    if (!dbg_event)
      return

    if (!(dbg_event in handler)) {
      guiScene.replaceContentFromText(obj, "", 0, null) 
      return
    }

    guiScene.replaceContentFromText(obj, "", 0, handler)
  })
}

function removeAllGenericTooltip() {
  removeInvalidTooltipObjs()

  while (openedTooltipObjs.len()) {
    let tooltipData = openedTooltipObjs.remove(0)
    closeGenericTooltip(tooltipData.obj, tooltipData.handler)
  }
  openedTooltipObjs.clear()
}

function onEventChangedCursorVisibility(params) {
  
  if (params.isVisible)
    return

  removeAllGenericTooltip()
}

function removeOpenedModalInfo(objs) {
  removeInvalidTooltipObjs()
  foreach (obj in objs) {
    if (!obj?.isValid())
      continue
    let tIdx = openedTooltipObjs.findindex(@(v) v.obj.isEqual(obj))
    if (tIdx != null)
      openedTooltipObjs.remove(tIdx)
  }
}

addListenersWithoutEnv({
  ChangedCursorVisibility = @(p) onEventChangedCursorVisibility(p)
  RemoveOpenedModalInfo = @(p) removeOpenedModalInfo(p.objs)
})

return {
  fillTooltip
  removeAllGenericTooltip
  addEventListenersTooltip
  openGenericTooltip
  closeGenericTooltip
  getTooltipObjId
}
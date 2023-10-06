//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { parse_json } = require("json")
let { getTooltipType, UNLOCK, ITEM, INVENTORY, SUBTROPHY, UNIT,
  CREW_SPECIALIZATION, BUY_CREW_SPEC, DECORATION
} = require("genericTooltipTypes.nut")
let { startsWith } = require("%sqstd/string.nut")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

local openedTooltipObjs = []
let function removeInvalidTooltipObjs() {
  openedTooltipObjs = openedTooltipObjs.filter(@(t) t.isValid())
}

::g_tooltip <- {
  inited = false

//!!TODO: remove this functions from this module
  getIdUnlock = @(unlockId, params = null)
    UNLOCK.getTooltipId(unlockId, params)
  getIdItem = @(itemName, params = null)
    ITEM.getTooltipId(itemName, params)
  getIdInventoryItem = @(itemUid)
    INVENTORY.getTooltipId(itemUid)
//only trophy content without trophy info. for hidden trophy items content.
  getIdSubtrophy = @(itemName)
    SUBTROPHY.getTooltipId(itemName)
  getIdUnit = @(unitName, params = null)
    UNIT.getTooltipId(unitName, params)
//specTypeCode == -1  -> current crew specialization
  getIdCrewSpecialization = @(crewId, unitName, specTypeCode = -1)
    CREW_SPECIALIZATION.getTooltipId(crewId, unitName, specTypeCode)
  getIdBuyCrewSpec = @(crewId, unitName, specTypeCode = -1)
    BUY_CREW_SPEC.getTooltipId(crewId, unitName, specTypeCode)
  getIdDecorator = @(decoratorId, unlockedItemType, params = null)
    DECORATION.getTooltipId(decoratorId, unlockedItemType, params)
}

let function fillTooltip(obj, handler, tooltipType, id, params) {
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

::g_tooltip.open <- function open(obj, handler) {
  removeInvalidTooltipObjs()
  if (!checkObj(obj))
    return
  obj["class"] = "empty"

  if (!handlersManager.isHandlerValid(handler))
    return
  let tooltipId = ::getTooltipObjId(obj)
  if (!tooltipId || tooltipId == "")
    return
  let params = parse_json(tooltipId)
  if (type(params) != "table" || !("ttype" in params) || !("id" in params))
    return

  let tooltipType = getTooltipType(params.ttype)
  let id = params.id

  let isSucceed = fillTooltip(obj, handler, tooltipType, id, params)

  if (!isSucceed || !checkObj(obj))
    return

  obj["class"] = ""
  openedTooltipObjs.append(this.addEventListeners(obj, handler, tooltipType, id, params))
}

::g_tooltip.addEventListeners <- function addEventListeners(obj, handler, tooltipType, id, params) {
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
        @(eventParams) tooltipType["onEvent" + eventName](eventParams, obj, handler, id, params), data)
    }
  return data
}

::g_tooltip.close <- function close(obj) { //!!FIXME: this function can be called with wrong context. Only for replace content in correct handler
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

  guiScene.performDelayed(this, function() {
    if (!checkObj(obj) || !obj.childrenCount())
      return

    //for debug and catch rare bug
    let dbg_event = obj?.on_tooltip_open
    if (!dbg_event)
      return

    if (!(dbg_event in this)) {
      guiScene.replaceContentFromText(obj, "", 0, null) //after it tooltip dosnt open again
      return
    }

    guiScene.replaceContentFromText(obj, "", 0, this)
  })
}

::g_tooltip.init <- function init() {
  if (this.inited)
    return
  this.inited = true
  add_event_listener("ChangedCursorVisibility", this.onEventChangedCursorVisibility, this)
}

::g_tooltip.onEventChangedCursorVisibility <- function onEventChangedCursorVisibility(params) {
  // Proceed if cursor is hidden now.
  if (params.isVisible)
    return

  this.removeAll()
}

::g_tooltip.removeAll <- function removeAll() {
  removeInvalidTooltipObjs()

  while (openedTooltipObjs.len()) {
    let tooltipData = openedTooltipObjs.remove(0)
    this.close.call(tooltipData.handler, tooltipData.obj)
  }
  openedTooltipObjs.clear()
}

::g_tooltip.init()

return {
  fillTooltip
}
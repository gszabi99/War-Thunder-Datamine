::g_tooltip <- {
  openedTooltipObjs = []
  inited = false
}

g_tooltip.getIdUnlock <- function getIdUnlock(unlockId, params = null)
{
  return ::g_tooltip_type.UNLOCK.getTooltipId(unlockId, params)
}

g_tooltip.getIdItem <- function getIdItem(itemName, params = null)
{
  return ::g_tooltip_type.ITEM.getTooltipId(itemName, params)
}

g_tooltip.getIdInventoryItem <- function getIdInventoryItem(itemUid)
{
  return ::g_tooltip_type.INVENTORY.getTooltipId(itemUid)
}

//only trophy content without trophy info. for hidden trophy items content.
g_tooltip.getIdSubtrophy <- function getIdSubtrophy(itemName)
{
  return ::g_tooltip_type.SUBTROPHY.getTooltipId(itemName)
}

g_tooltip.getIdUnit <- function getIdUnit(unitName, params = null)
{
  return ::g_tooltip_type.UNIT.getTooltipId(unitName, params)
}

g_tooltip.getIdModification <- function getIdModification(unitName, modName, params = null)
{
  return ::g_tooltip_type.MODIFICATION.getTooltipId(unitName, modName, params)
}

g_tooltip.getIdSpare <- function getIdSpare(unitName)
{
  return ::g_tooltip_type.SPARE.getTooltipId(unitName)
}

//specTypeCode == -1  -> current crew specialization
g_tooltip.getIdCrewSpecialization <- function getIdCrewSpecialization(crewId, unitName, specTypeCode = -1)
{
  return ::g_tooltip_type.CREW_SPECIALIZATION.getTooltipId(crewId, unitName, specTypeCode)
}

g_tooltip.getIdBuyCrewSpec <- function getIdBuyCrewSpec(crewId, unitName, specTypeCode = -1)
{
  return ::g_tooltip_type.BUY_CREW_SPEC.getTooltipId(crewId, unitName, specTypeCode)
}

g_tooltip.getIdDecorator <- function getIdDecorator(decoratorId, unlockedItemType, params = null)
{
  return ::g_tooltip_type.DECORATION.getTooltipId(decoratorId, unlockedItemType, params)
}

g_tooltip.open <- function open(obj, handler)
{
  ::g_tooltip.removeInvalidObjs(::g_tooltip.openedTooltipObjs)

  if (!::check_obj(obj))
    return
  obj["class"] = "empty"

  if (!::handlersManager.isHandlerValid(handler))
    return
  local tooltipId = ::getTooltipObjId(obj)
  if (!tooltipId || tooltipId == "")
    return
  local params = ::parse_json(tooltipId)
  if (type(params) != "table" || !("ttype" in params) || !("id" in params))
    return

  local tooltipType = ::g_tooltip_type.getTypeByName(params.ttype)
  local id = params.id

  local isSucceed = fill(obj, handler, tooltipType, id, params)

  if (!isSucceed || !::check_obj(obj))
    return

  obj["class"] = ""
  register(obj, handler, tooltipType, id, params)
}

g_tooltip.register <- function register(obj, handler, tooltipType, id, params)
{
  local data = {
    obj         = obj
    handler     = handler
    tooltipType = tooltipType
    id          = id
    params      = params
    isValid     = function() { return ::checkObj(obj) && obj.isVisible() }
  }

  foreach (key, value in tooltipType)
    if (::u.isFunction(value) && ::g_string.startsWith(key, "onEvent"))
    {
      local eventName = key.slice("onEvent".len())
      ::add_event_listener(eventName, (@(eventName) function(eventParams) {
        tooltipType["onEvent" + eventName](eventParams, obj, handler, id, params)
      })(eventName), data)
    }

  openedTooltipObjs.append(data)
}

g_tooltip.fill <- function fill(obj, handler, tooltipType, id, params)
{
  local isSucceed = true
  if (tooltipType.isCustomTooltipFill)
    isSucceed = tooltipType.fillTooltip(obj, handler, id, params)
  else
  {
    local content = tooltipType.getTooltipContent(id, params)
    if (content.len())
      obj.getScene().replaceContentFromText(obj, content, content.len(), handler)
    else
      isSucceed = false
  }
  return isSucceed
}

g_tooltip.close <- function close(obj)
{
  local tooltipId = ::checkObj(obj) ? ::getTooltipObjId(obj) : null
  ::g_tooltip.removeInvalidObjs(::g_tooltip.openedTooltipObjs, tooltipId)

  if (!::checkObj(obj) || !obj.childrenCount())
    return
  local guiScene = obj.getScene()
  obj.show(false)

  guiScene.performDelayed(this, function() {
    if (!::checkObj(obj) || !obj.childrenCount())
      return

    //for debug and catch rare bug
    local dbg_event = obj?.on_tooltip_open
    if (!dbg_event)
      return

    if (!(dbg_event in this))
    {
      local metric = "errors.brokenTooltip." + ::toString(this) + ";" + dbg_event
      dagor.debug("Error: " + metric + ";" + ::toString(obj))
      ::statsd_counter(metric)
      guiScene.replaceContentFromText(obj, "", 0, null) //after it tooltip dosnt open again
      return
    }

    guiScene.replaceContentFromText(obj, "", 0, this)
  })
}

g_tooltip.init <- function init()
{
  if (inited)
    return
  inited = true
  ::add_event_listener("ChangedCursorVisibility", onEventChangedCursorVisibility, this)
}

g_tooltip.onEventChangedCursorVisibility <- function onEventChangedCursorVisibility(params)
{
  // Proceed if cursor is hidden now.
  if (params.newValue)
    return

  removeAll()
}

g_tooltip.removeInvalidObjs <- function removeInvalidObjs(objs, tooltipId = null)
{
  for (local i = objs.len() - 1; i >= 0; --i)
  {
    local obj = objs[i].obj
    if (!objs[i].isValid() || (tooltipId && ::getTooltipObjId(obj) == tooltipId))
      objs.remove(i)
  }
}

g_tooltip.removeAll <- function removeAll()
{
  removeInvalidObjs(openedTooltipObjs)

  while (openedTooltipObjs.len())
  {
    local tooltipData = openedTooltipObjs.remove(0)
    close.call(tooltipData.handler, tooltipData.obj)
  }
  openedTooltipObjs.clear()
}

::g_tooltip.init()

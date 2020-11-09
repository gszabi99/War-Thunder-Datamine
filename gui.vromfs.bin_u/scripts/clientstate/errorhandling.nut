local enums = ::require("sqStdlibs/helpers/enums.nut")
local callback = ::require("sqStdLibs/helpers/callback.nut")
local u = ::require("sqStdLibs/helpers/u.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")

local netAssertsList = []
::script_net_assert_once <- function script_net_assert_once(id, msg)
{
  if (::isInArray(id, netAssertsList))
    return dagor.debug(msg)

  netAssertsList.append(id)
  return script_net_assert(msg)
}

::assertf_once <- function assertf_once(id, msg)
{
  if (::isInArray(id, netAssertsList))
    return dagor.debug(msg)
  netAssertsList.append(id)
  return ::dagor.assertf(false, msg)
}

::unreachable <- function unreachable()
{
  local info = ::getstackinfos(2) // get calling function
  local id = (info?.src ?? "?") + ":" + (info?.line ?? "?") + " (" + (info?.func ?? "?") + ")"
  local msg = "Entered unreachable code: " + id
  script_net_assert_once(id, msg)
}

callback.setContextDbgNameFunction(function(context)
{
  if (!u.isTable(context))
    return ::toString(context, 0)

  foreach(key, value in ::getroottable())
    if (value == context)
      return key
  return "unknown table"
})

callback.setAssertFunction(function(cb, assertText)
{
  local eventText = ""
  local curEventName = subscriptions.getCurrentEventName()
  if (curEventName)
    eventText += ::format("event = %s, ", curEventName)
  local hudEventName = ("g_hud_event_manager" in getroottable()) ? ::g_hud_event_manager.getCurHudEventName() : null
  if (hudEventName)
    eventText += ::format("hudEvent = %s, ", hudEventName)

  ::script_net_assert_once("cb error " + eventText,
    format("Callback error ( %scontext = %s):\n%s",
      eventText, cb.getContextDbgName(), assertText
    )
  )
})

enums.setAssertFunction(::script_net_assert_once)
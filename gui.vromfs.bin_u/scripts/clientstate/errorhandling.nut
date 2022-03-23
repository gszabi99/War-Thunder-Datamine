let enums = require("%sqStdLibs/helpers/enums.nut")
let callback = require("%sqStdLibs/helpers/callback.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")

let netAssertsList = []
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
  let info = ::getstackinfos(2) // get calling function
  let id = (info?.src ?? "?") + ":" + (info?.line ?? "?") + " (" + (info?.func ?? "?") + ")"
  let msg = "Entered unreachable code: " + id
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
  let curEventName = subscriptions.getCurrentEventName()
  if (curEventName)
    eventText += ::format("event = %s, ", curEventName)
  let hudEventName = ("g_hud_event_manager" in getroottable()) ? ::g_hud_event_manager.getCurHudEventName() : null
  if (hudEventName)
    eventText += ::format("hudEvent = %s, ", hudEventName)

  ::script_net_assert_once("cb error " + eventText,
    format("Callback error ( %scontext = %s):\n%s",
      eventText, cb.getContextDbgName(), assertText
    )
  )
})

enums.setAssertFunction(::script_net_assert_once)
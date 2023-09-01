from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let callback = require("%sqStdLibs/helpers/callback.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { netAsserts, script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")

::assertf_once <- function assertf_once(id, msg) {
  if (id in netAsserts)
    return log(msg)
  netAsserts[id] <- id
  return assert(false, msg)
}

::unreachable <- function unreachable() {
  let info = ::getstackinfos(2) // get calling function
  let id = "".concat((info?.src ?? "?"), ":", (info?.line ?? "?"), " (", (info?.func ?? "?"), ")")
  let msg = $"Entered unreachable code: {id}"
  script_net_assert_once(id, msg)
}

callback.setContextDbgNameFunction(function(context) {
  if (!u.isTable(context))
    return toString(context, 0)

  foreach (key, value in getroottable())
    if (value == context)
      return key
  return "unknown table"
})

callback.setAssertFunction(function(cb, assertText) {
  local eventText = ""
  let curEventName = subscriptions.getCurrentEventName()
  if (curEventName)
    eventText = "".concat(eventText, format("event = %s, ", curEventName))
  let hudEventName = getroottable()?["g_hud_event_manager"].getCurHudEventName()
  if (hudEventName)
    eventText = "".concat(eventText, format("hudEvent = %s, ", hudEventName))

  script_net_assert_once($"cb error {eventText}",
    format("Callback error ( %scontext = %s):\n%s",
      eventText, cb.getContextDbgName(), assertText
    )
  )
})

enums.setAssertFunction(script_net_assert_once)
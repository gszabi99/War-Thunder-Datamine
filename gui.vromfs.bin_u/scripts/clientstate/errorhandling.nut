from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")
let callback = require("%sqStdLibs/helpers/callback.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")

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
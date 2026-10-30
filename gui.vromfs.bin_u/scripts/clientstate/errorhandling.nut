import "%sqStdLibs/helpers/callback.nut" as callback
import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
import "%sqStdLibs/helpers/enums.nut" as enums
import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "string" import format
from "%scripts/dagui_library.nut" import *

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")

callback.setContextDbgNameFunction(function(context) {
  if (!u.isTable(context))
    return toString(context, 0)
  return "unknown table"
})

callback.setAssertFunction(function(contextDbgName, assertText) {
  local eventText = ""
  let curEventName = subscriptions.getCurrentEventName()
  if (curEventName)
    eventText = "".concat(eventText, format("event = %s, ", curEventName))
  let hudEventName = g_hud_event_manager.getCurHudEventName()
  if (hudEventName)
    eventText = "".concat(eventText, format("hudEvent = %s, ", hudEventName))

  script_net_assert_once($"cb error {eventText}",
    format("Callback error ( %scontext = %s):\n%s",
      eventText, contextDbgName, assertText
    )
  )
})

enums.setAssertFunction(script_net_assert_once)
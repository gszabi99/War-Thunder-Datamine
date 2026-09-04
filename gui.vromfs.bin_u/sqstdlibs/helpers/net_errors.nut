from "dagor.debug" import logerr

let { script_net_assert = logerr} = require_optional("scriptErrorHandler")

let netAsserts = {}
function script_net_assert_once(id, msg) {
  if (id in netAsserts)
    return println(msg)

  netAsserts[id] <- id
  return script_net_assert(msg)
}

return {
  script_net_assert_once
  netAsserts
}
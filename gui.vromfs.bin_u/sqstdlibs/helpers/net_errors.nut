let { logerr } = require("dagor.debug")

let script_net_assert = getroottable()?["script_net_assert"] ?? logerr

let netAsserts = {}
let function script_net_assert_once(id, msg) {
  if (id in netAsserts)
    return println(msg)

  netAsserts[id] <- id
  return script_net_assert(msg)
}

return {
  script_net_assert_once
  netAsserts
}
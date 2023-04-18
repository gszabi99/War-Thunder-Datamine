//checked for plus_string
from "%scripts/dagui_library.nut" import *
#explicit-this
#no-root-fallback
let { send } = require("eventbus")
let { ndbWrite, ndbRead, ndbExists } = require("nestdb")

let function update(config) {
  local hasValueChanged = false
  foreach (name, value in config) {
    let key = ["EXT_WATCHED_STATE", name]
    hasValueChanged = hasValueChanged
      || !ndbExists(key) || (ndbRead(key) != value)
    ndbWrite(key, value)
  }
  send("extWatched.update", config)
  return hasValueChanged
}

return update
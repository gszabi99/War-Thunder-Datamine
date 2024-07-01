from "%scripts/dagui_library.nut" import *
let { eventbus_send } = require("eventbus")
let { ndbWrite, ndbRead, ndbExists } = require("nestdb")

function update(config) {
  local hasValueChanged = false
  foreach (name, value in config) {
    let key = ["EXT_WATCHED_STATE", name]
    hasValueChanged = hasValueChanged
      || !ndbExists(key) || (ndbRead(key) != value)
    ndbWrite(key, value)
  }
  eventbus_send("extWatched.update", config)
  return hasValueChanged
}

return update
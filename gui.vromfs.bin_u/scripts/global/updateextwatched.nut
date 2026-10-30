from "eventbus" import eventbus_send
from "nestdb" import ndbWrite, ndbRead, ndbExists
from "%sqStdLibs/helpers/u.nut" import isEqual

function update(config) {
  local hasValueChanged = false
  foreach (name, value in config) {
    let key = ["EXT_WATCHED_STATE", name]
    hasValueChanged = hasValueChanged
      || !ndbExists(key) || !isEqual(ndbRead(key), value)
    ndbWrite(key, value)
  }
  eventbus_send("extWatched.update", config)
  return hasValueChanged
}

return update
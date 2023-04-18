//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let regexp2 = require("regexp2")

let guidRe = regexp2(@"^\{?[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}\}?$")


let function isGuid(str) {
  return guidRe.match(str)
}

return {
  isGuid
}

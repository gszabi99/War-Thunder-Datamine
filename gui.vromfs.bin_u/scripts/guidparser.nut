import "regexp2" as regexp2
from "%scripts/dagui_library.nut" import *

let guidRe = regexp2(@"^\{?[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}\}?$")


function isGuid(str) {
  return guidRe.match(str)
}

return {
  isGuid
}

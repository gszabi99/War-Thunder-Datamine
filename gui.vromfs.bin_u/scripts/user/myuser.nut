from "%scripts/dagui_library.nut" import *

let userName = mkWatched(persist, "userName", "")
let userIdStr = mkWatched(persist, "userIdStr", "-1")
let userIdInt64 = Computed(@() userIdStr.value.tointeger())

return {
  userName
  userIdStr
  userIdInt64
}
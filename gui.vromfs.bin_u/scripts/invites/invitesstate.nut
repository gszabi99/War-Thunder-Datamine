from "%scripts/dagui_library.nut" import *

let invitesAmount = mkWatched(persist, "invitesAmount", 0)

return {
  invitesAmount
}
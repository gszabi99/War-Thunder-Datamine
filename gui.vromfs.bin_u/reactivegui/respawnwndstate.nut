from "%rGui/globals/ui_library.nut" import *
let extWatched = require("%rGui/globals/extWatched.nut")

return {
  isInRespawnWnd = extWatched("isInRespawnWnd", false)
  isInSpectatorMode = extWatched("isInRespawnSpectatorMode", false)
}
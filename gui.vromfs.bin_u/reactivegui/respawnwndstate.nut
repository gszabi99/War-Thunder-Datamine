import "%rGui/globals/extWatched.nut" as extWatched
from "%rGui/globals/ui_library.nut" import *

return freeze({
  isInRespawnWnd = extWatched("isInRespawnWnd", false)
  isInSpectatorMode = extWatched("isInRespawnSpectatorMode", false)
})
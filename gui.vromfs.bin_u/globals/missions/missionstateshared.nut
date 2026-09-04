from "mission" import get_game_type
from "%globalScripts/gameTypeConsts.nut" import *

function isModeWithTeams(gt = null) {
  if (gt == null)
    gt = get_game_type()
  return !(gt & (GT_FFA_DEATHMATCH | GT_FFA))
}

return freeze({
  isModeWithTeams
})
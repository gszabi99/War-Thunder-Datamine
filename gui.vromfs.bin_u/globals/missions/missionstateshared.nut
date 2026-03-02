let { get_game_type } = require("mission")

function isModeWithTeams(gt = null) {
  if (gt == null)
    gt = get_game_type()
  return !(gt & (GT_FFA_DEATHMATCH | GT_FFA))
}

return {
  isModeWithTeams
}
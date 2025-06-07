let sharedWatched = require("%globalScripts/sharedWatched.nut")


let controlledHeroEid = sharedWatched("controlledHeroEid", @() 0)

return {
  controlledHeroEid
}
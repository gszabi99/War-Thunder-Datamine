let sharedWatched = require("%globalScripts/sharedWatched.nut")


let currentGunEid = sharedWatched("currentGunEid", @() 0)

return {
  currentGunEid
}
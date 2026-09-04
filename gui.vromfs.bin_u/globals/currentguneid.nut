import "%globalScripts/sharedWatched.nut" as sharedWatched


let currentGunEid = sharedWatched("currentGunEid", @() 0)

return freeze({
  currentGunEid
})
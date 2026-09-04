import "%globalScripts/sharedWatched.nut" as sharedWatched

return freeze({
  artilleryReadyState = sharedWatched("artilleryReadyState", @() {})
})
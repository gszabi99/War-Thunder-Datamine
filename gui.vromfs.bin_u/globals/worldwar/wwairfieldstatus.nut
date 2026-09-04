import "%globalScripts/sharedWatched.nut" as sharedWatched

return freeze({
  hoveredAirfieldIndex = sharedWatched("hoveredAirfieldIndex", @() null)
})
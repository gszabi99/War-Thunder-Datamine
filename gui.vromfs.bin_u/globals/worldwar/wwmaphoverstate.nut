import "%globalScripts/sharedWatched.nut" as sharedWatched

let isMapHovered = sharedWatched("isMapHovered", @() false)

return freeze({
  isMapHovered
})
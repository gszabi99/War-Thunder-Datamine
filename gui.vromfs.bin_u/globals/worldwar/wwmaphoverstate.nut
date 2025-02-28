let sharedWatched = require("%globalScripts/sharedWatched.nut")
let isMapHovered = sharedWatched("isMapHovered", @() false)

return {
  isMapHovered
}
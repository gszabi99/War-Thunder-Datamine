let sharedWatched = require("%globalScripts/sharedWatched.nut")

let isAAComplexMenuActive = sharedWatched("isAAComplexMenuActive", @() false)

return {
  isAAComplexMenuActive
}
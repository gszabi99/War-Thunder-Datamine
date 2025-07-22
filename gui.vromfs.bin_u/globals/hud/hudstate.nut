let sharedWatched = require("%globalScripts/sharedWatched.nut")

let isAAComplexMenuActive = sharedWatched("isAAComplexMenuActive", @() false)
let isWheelMenuActive = sharedWatched("isWheelMenuActive", @() false)

return {
  isAAComplexMenuActive
  isWheelMenuActive
}
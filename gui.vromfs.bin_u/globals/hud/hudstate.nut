let sharedWatched = require("%globalScripts/sharedWatched.nut")

let isAAComplexMenuActive = sharedWatched("isAAComplexMenuActive", @() false)
let isWheelMenuActive = sharedWatched("isWheelMenuActive", @() false)
let savedRadarFilters = sharedWatched("savedRadarFilters", @() {})
let AAComplexRadarFiltersSaveSlotName = "AAComplex"


return {
  isAAComplexMenuActive
  isWheelMenuActive
  savedRadarFilters
  AAComplexRadarFiltersSaveSlotName
}
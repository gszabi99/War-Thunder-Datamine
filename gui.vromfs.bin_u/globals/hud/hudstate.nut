import "%globalScripts/sharedWatched.nut" as sharedWatched

let isAAComplexMenuActive = sharedWatched("isAAComplexMenuActive", @() false)
let isWheelMenuActive = sharedWatched("isWheelMenuActive", @() false)
let isCarrierMenuActive = sharedWatched("isCarrierMenuActive", @() false)
let savedRadarFilters = sharedWatched("savedRadarFilters", @() {})
let mpScoreBox = sharedWatched("mpScoreBox", @() null)
const AAComplexRadarFiltersSaveSlotName = "AAComplex"


return freeze({
  isAAComplexMenuActive
  isWheelMenuActive
  isCarrierMenuActive
  savedRadarFilters
  mpScoreBox
  AAComplexRadarFiltersSaveSlotName
})
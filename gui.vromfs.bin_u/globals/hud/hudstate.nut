import "%globalScripts/sharedWatched.nut" as sharedWatched

let isAAComplexMenuActive = sharedWatched("isAAComplexMenuActive", @() false)
let isWheelMenuActive = sharedWatched("isWheelMenuActive", @() false)
let savedRadarFilters = sharedWatched("savedRadarFilters", @() {})
const AAComplexRadarFiltersSaveSlotName = "AAComplex"


return {
  isAAComplexMenuActive
  isWheelMenuActive
  savedRadarFilters
  AAComplexRadarFiltersSaveSlotName
}
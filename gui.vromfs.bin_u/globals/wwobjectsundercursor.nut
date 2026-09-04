import "%globalScripts/sharedWatched.nut" as sharedWatched

return freeze({
  mapCellUnderCursor = sharedWatched("mapCellUnderCursor", @() {})
  armyUnderCursor = sharedWatched("armyUnderCursor", @() {})
  mapCoordsUnderCursor = sharedWatched("mapCoordsUnderCursor", @() {})
})
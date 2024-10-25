let sharedWatched = require("%globalScripts/sharedWatched.nut")

return {
  mapCellUnderCursor = sharedWatched("mapCellUnderCursor", @() {})
  armyUnderCursor = sharedWatched("armyUnderCursor", @() {})
  mapCoordsUnderCursor = sharedWatched("mapCoordsUnderCursor", @() {})
}
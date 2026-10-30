from "%appGlobals/dargScreenModel.nut" import mkScreenModel, mkUiWatched


let { screen, items, itemW, setField, setItem, reset } = mkScreenModel("axisSetup", @() {
  isOpen = false
  title = ""
  axisOptions = []
  axisIdx = 0
  autodetect = false
  rows = []
  selectedRowId = null
})


let axisPoints = mkUiWatched("axisPoints", @() [0.0, 0.0])

return freeze({
  axisSetup = screen
  axisSetupItems = items
  axisSetupItemW = itemW
  setAxisSetupField = setField
  setAxisSetupItem = setItem
  resetAxisSetup = reset
  axisPoints
})

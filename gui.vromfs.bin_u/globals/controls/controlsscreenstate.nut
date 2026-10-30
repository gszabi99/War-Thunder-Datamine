from "%appGlobals/dargScreenModel.nut" import mkScreenModel, mkUiWatched


let { screen, items, itemW, setField, setItem, reset } = mkScreenModel("controls", @() {
  backSceneName = ""
  groupTabs = []
  curGroupIdx = -1
  helpersFilter = []
  helpersFilterIdx = -1
  isHelpersFilterShown = true
  navItems = []
  curNavIdx = 0
  searchText = ""
  rows = []
  selectedRowId = null
})
let scrollOffsY = mkUiWatched("controlsScrollOffsY", @() 0)

function resetControlsScreen() {
  reset()
  scrollOffsY.set(0)
}

return freeze({
  controlsScreen = screen
  controlsItems = items
  controlsItemW = itemW
  controlsScrollOffsY = scrollOffsY
  setControlsScreenField = setField
  setControlsItem = setItem
  resetControlsScreen
})

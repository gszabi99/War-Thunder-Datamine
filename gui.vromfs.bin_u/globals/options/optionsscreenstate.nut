from "%appGlobals/dargScreenModel.nut" import mkScreenModel

const OPTIONS_HIDDEN_AT_START = ["web_ui_button", "assistant_map_qr_button", "btn_gpu_benchmark", "btn_reset_tab",
  "btn_restart", "btn_reset"]

let { screen, items, itemW, setField, setItem, reset } = mkScreenModel("options", @() {
  tabs = []
  curTab = -1
  inactiveTabs = {}
  navItems = []
  curNavIdx = 0
  rows = []
  columnsRatio = 0.5
  isInfoOnTheRight = false
  extraRows = null
  info = null
  searchText = ""
  backSceneName = ""
  
  sysopt = null
})

let getOptionsItem = @(id) items.get()?[id]

return freeze({
  OPTIONS_HIDDEN_AT_START
  optionsScreen = screen
  optionsItems = items
  optionsItemW = itemW
  getOptionsItem
  setOptionsItem = setItem
  setOptionsScreenField = setField
  resetOptionsScreen = reset
})

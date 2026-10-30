from "%appGlobals/dargScreenModel.nut" import mkScreenModel


const HIDDEN_BY_DEFAULT = ["language_selector", "loginbox_password_caps_indicator",
  "loginbox_code_remember_this_device", "loginbox_disable_ssl_cert", "sharding_block",
  "steam_login_action_button", "browser_bug_disclaimer"]

let { screen, items, itemW, setField, setItem, reset } = mkScreenModel("login", @() {
  style = "usual"
  isExistingAccountOpened = true
  isHelpShown = false
  focusId = null
  focusSeq = 0
  shardItems = []
  langs = []
  versionText = ""
  copyrightText = ""
  titleLogo = ""
})

let isShownItem = @(id, item) item?.shown ?? !HIDDEN_BY_DEFAULT.contains(id)

let focusLoginItem = @(id) screen.mutate(function(s) {
  s.focusId = id
  s.focusSeq++
})

return freeze({
  HIDDEN_BY_DEFAULT
  loginScreen = screen
  loginItemW = itemW
  getLoginValue = @(id, defVal) items.get()?[id]?.value ?? defVal
  isShownItem
  focusLoginItem
  setLoginItem = setItem
  setLoginScreenField = setField
  resetLoginScreen = reset
})

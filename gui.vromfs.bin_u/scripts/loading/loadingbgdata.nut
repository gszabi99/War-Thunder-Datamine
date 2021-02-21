/* Data in config (gui.blk/loading_bg)

loading_bg
{
  reserveBg:t='login_layer_c1' //layer loaded behind current to be visible while current images not full loaded

  //full layers list
  login_layer_a1:r = 2.0
  login_layer_b1:r = 2.0
  login_layer_c1:r = 2.0

  beforeLogin {  //ovverride chances before login
    default_chance:r=0  //default chance for all layers
    login_layer_r1:r = 2.0
  }

  tencent {  //override chances for tencent. applied after languages
    //default_chance:r=2.0
    login_layer_g1:r = 0
    login_layer_k1:r = 0

    beforeLogin {
      default_chance:r=0
      login_layer_q1:r = 2.0
    }
  }

  language {  //override chances by languages
    langsInclude  {
      lang:t="English"
      lang:t="Russian"
    }
    langsExclude {
      lang:t="English"
      lang:t="Russian"
    }
    //all languages if no langsInclude or langsExclude set

    platformInclude {
      platform:t="win32"
      platform:t="win64"
    }
    platformExclude {
      platform:t="win32"
      platform:t="win64"
    }
    //all platforms if no platformInclude or platformExclude set

    login_layer_g1:r = 0

    beforeLogin {
      default_chance:r=0
      login_layer_q1:r = 2.0
    }
  }
}
*/

local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")

local createBgData = @() {
  list = {}
  reserveBg = ""
}

local bgDataBeforeLogin = createBgData()
local bgDataAfterLogin = createBgData()

local inited = false
local bgUnlocks = null

local RESERVE_BG_KEY = "reserveBg"
local DEFAULT_VALUE_KEY = "default_chance"
local BLOCK_BEFORE_LOGIN_KEY = "beforeLogin"
local LOADING_BG_PATH = "loading_bg"

local function applyBlkToBgData(bgData, blk) {
  local list = bgData.list
  local defValue = blk?[DEFAULT_VALUE_KEY]
  if (defValue != null)
    foreach (key, value in list)
      list[key] = defValue

  local reserveBg = blk?[RESERVE_BG_KEY]
  if (::u.isString(reserveBg))
    bgData.reserveBg = reserveBg

  for (local i = 0; i < blk.paramCount(); i++) {
    local value = blk.getParamValue(i)
    if (::is_numeric(value))
      list[blk.getParamName(i)] <- value
  }

  // to not check name for each added param
  if (DEFAULT_VALUE_KEY in list)
    delete list[DEFAULT_VALUE_KEY]
}

local function applyBlkToAllBgData(blk) {
  applyBlkToBgData(bgDataAfterLogin, blk)
  applyBlkToBgData(bgDataBeforeLogin, blk)
  local beforeLoginBlk = blk?[BLOCK_BEFORE_LOGIN_KEY]
  if (::u.isDataBlock(beforeLoginBlk))
    applyBlkToBgData(bgDataBeforeLogin, beforeLoginBlk)
}

local function applyBlkByLang(langBlk, curLang) {
  local langsInclude = langBlk?.langsInclude
  local langsExclude = langBlk?.langsExclude
  if (::u.isDataBlock(langsInclude)
      && !::isInArray(curLang, langsInclude % "lang"))
    return
  if (::u.isDataBlock(langsExclude)
      && ::isInArray(curLang, langsExclude % "lang"))
    return

  local platformInclude = langBlk?.platformInclude
  local platformExclude = langBlk?.platformExclude
  if (::u.isDataBlock(platformInclude)
      && !::isInArray(::target_platform, platformInclude % "platform"))
    return
  if (::u.isDataBlock(platformExclude)
      && ::isInArray(::target_platform, platformExclude % "platform"))
    return

  ::dagor.assertf(!!(langsExclude || langsInclude || platformInclude || platformExclude),
    "AnimBG: Found block without language or platform permissions. it always override defaults.")

  applyBlkToAllBgData(langBlk)
}

local function validateBgData(bgData) {
  local list = bgData.list
  local keys = ::u.keys(list)
  foreach (key in keys) {
    local validValue = ::to_float_safe(list[key], 0)
    if (validValue > 0.0001)
      list[key] = validValue
    else
      delete list[key]
  }
}

local function initOnce() {
  if (inited)
    return
  inited = true

  bgDataAfterLogin.list.clear()
  bgDataBeforeLogin.list.clear()

  local blk = ::configs.GUI.get()
  local bgBlk = blk?[LOADING_BG_PATH]
  if (!bgBlk)
    return

  applyBlkToAllBgData(bgBlk)

  local curLang = ::g_language.getLanguageName()
  foreach (langBlk in bgBlk % "language")
    if (::u.isDataBlock(langBlk))
      applyBlkByLang(langBlk, curLang)

  local presetBlk = bgBlk?[::get_country_flags_preset()]
  if (::u.isDataBlock(presetBlk))
    applyBlkToAllBgData(presetBlk)

  validateBgData(bgDataAfterLogin)
  validateBgData(bgDataBeforeLogin)

  if (!bgUnlocks)
    bgUnlocks = ::buildTableFromBlk(bgBlk?.unlocks)
}

local function removeLoadingBgFromLists(name) {
  foreach (data in [bgDataAfterLogin, bgDataBeforeLogin]) {
    if (name in data.list)
      delete data.list[name]
    if (data.reserveBg == name)
      data.reserveBg = ""
  }
}

local isBgUnlockable = @(id) id in bgUnlocks
local isBgUnlocked = @(id) (id not in bgUnlocks) || ::is_unlocked_scripted(-1, bgUnlocks[id])

local function filterLoadingBgData(bgData) {
  bgData = clone bgData
  bgData.list = bgData.list.filter(::g_login.isProfileReceived()
    ? @(v, id) isBgUnlocked(id)
    : @(v, id) !isBgUnlockable(id))
  return bgData
}

local function getCurLoadingBgData() {
  initOnce()
  return filterLoadingBgData(::g_login.isLoggedIn() ? bgDataAfterLogin : bgDataBeforeLogin)
}

local function getLoadingBgIdByUnlockId(unlockId) {
  initOnce()
  return bgUnlocks.findindex(@(v) unlockId == v)
}

local isLoadingBgUnlock = @(unlockId) getLoadingBgIdByUnlockId(unlockId) != null
local getLoadingBgName = @(id) ::loc($"loading_bg/{id}")
local getLoadingBgTooltip = @(id) ::loc($"loading_bg/{id}/desc", "")

local reset = @() inited = false
local setLoadingBgPath = @(path) LOADING_BG_PATH = path

subscriptions.addListenersWithoutEnv({
  GameLocalizationChanged = @(p) reset()
})

return {
  getCurLoadingBgData
  getLoadingBgIdByUnlockId
  getLoadingBgName
  getLoadingBgTooltip
  setLoadingBgPath
  removeLoadingBgFromLists
  isLoadingBgUnlock
}
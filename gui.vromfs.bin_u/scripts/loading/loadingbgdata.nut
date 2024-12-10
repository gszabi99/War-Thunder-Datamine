from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { getCountryFlagsPresetName } = require("%scripts/options/countryFlagsPreset.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { isLoggedIn, isProfileReceived } = require("%scripts/login/loginStates.nut")

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

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { canDoUnlock, isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")

let createBgData = @() {
  list = {}
  reserveBg = ""
}

let bgDataBeforeLogin = createBgData()
let bgDataAfterLogin = createBgData()

local inited = false
local bgUnlocks = null

let RESERVE_BG_KEY = "reserveBg"
let DEFAULT_VALUE_KEY = "default_chance"
let BLOCK_BEFORE_LOGIN_KEY = "beforeLogin"
local LOADING_BG_PATH = "loading_bg"

function applyBlkToBgData(bgData, blk) {
  let list = bgData.list
  let defValue = blk?[DEFAULT_VALUE_KEY]
  if (defValue != null)
    foreach (key, _value in list)
      list[key] = defValue

  let reserveBg = blk?[RESERVE_BG_KEY]
  if (u.isString(reserveBg))
    bgData.reserveBg = reserveBg

  for (local i = 0; i < blk.paramCount(); i++) {
    let value = blk.getParamValue(i)
    if (is_numeric(value))
      list[blk.getParamName(i)] <- value
  }

  // to not check name for each added param
  if (DEFAULT_VALUE_KEY in list)
    list.$rawdelete(DEFAULT_VALUE_KEY)
}

function applyBlkToAllBgData(blk) {
  applyBlkToBgData(bgDataAfterLogin, blk)
  applyBlkToBgData(bgDataBeforeLogin, blk)
  let beforeLoginBlk = blk?[BLOCK_BEFORE_LOGIN_KEY]
  if (u.isDataBlock(beforeLoginBlk))
    applyBlkToBgData(bgDataBeforeLogin, beforeLoginBlk)
}

function applyBlkByLang(langBlk, curLang) {
  let langsInclude = langBlk?.langsInclude
  let langsExclude = langBlk?.langsExclude
  if (u.isDataBlock(langsInclude)
      && !isInArray(curLang, langsInclude % "lang"))
    return
  if (u.isDataBlock(langsExclude)
      && isInArray(curLang, langsExclude % "lang"))
    return

  let platformInclude = langBlk?.platformInclude
  let platformExclude = langBlk?.platformExclude
  if (u.isDataBlock(platformInclude)
      && !isInArray(platformId, platformInclude % "platform"))
    return
  if (u.isDataBlock(platformExclude)
      && isInArray(platformId, platformExclude % "platform"))
    return

  assert(!!(langsExclude || langsInclude || platformInclude || platformExclude),
    "AnimBG: Found block without language or platform permissions. it always override defaults.")

  applyBlkToAllBgData(langBlk)
}

function validateBgData(bgData) {
  let list = bgData.list
  let keys = u.keys(list)
  foreach (key in keys) {
    let validValue = to_float_safe(list[key], 0)
    if (validValue > 0.0001)
      list[key] = validValue
    else
      list.$rawdelete(key)
  }
}

function initOnce() {
  if (inited)
    return
  inited = true

  bgDataAfterLogin.list.clear()
  bgDataBeforeLogin.list.clear()

  let blk = GUI.get()
  let bgBlk = blk?[LOADING_BG_PATH]
  if (!bgBlk)
    return

  applyBlkToAllBgData(bgBlk)

  let curLang = getLanguageName()
  foreach (langBlk in bgBlk % "language")
    if (u.isDataBlock(langBlk))
      applyBlkByLang(langBlk, curLang)

  let presetBlk = bgBlk?[getCountryFlagsPresetName()]
  if (u.isDataBlock(presetBlk))
    applyBlkToAllBgData(presetBlk)

  validateBgData(bgDataAfterLogin)
  validateBgData(bgDataBeforeLogin)

  if (!bgUnlocks)
    bgUnlocks = u.isDataBlock(bgBlk?.unlocks) ? convertBlk(bgBlk.unlocks) : {}
}

function removeLoadingBgFromLists(name) {
  foreach (data in [bgDataAfterLogin, bgDataBeforeLogin]) {
    data.list?.$rawdelete(name)
    if (data.reserveBg == name)
      data.reserveBg = ""
  }
}

let isBgUnlockable = @(id) id in bgUnlocks
let isBgUnlocked = @(id) (id not in bgUnlocks) || isUnlockOpened(bgUnlocks[id])
let isBgUnlockableByUser = @(id) isBgUnlockable(id) && canDoUnlock(getUnlockById(bgUnlocks[id]))

function filterLoadingBgData(bgData) {
  bgData = clone bgData
  bgData.list = bgData.list.filter(isProfileReceived.get()
    ? @(_v, id) isBgUnlocked(id)
    : @(_v, id) !isBgUnlockable(id))
  return bgData
}

function getFilterBgList() {
  initOnce()
  let curBgData = isLoggedIn.get() ? bgDataAfterLogin : bgDataBeforeLogin
  return isProfileReceived.get()
    ? curBgData.list.keys().filter(@(id) isBgUnlocked(id) || isBgUnlockableByUser(id))
    : curBgData.list.keys().filter(@(id) !isBgUnlockable(id))
}

function getCurLoadingBgData() {
  initOnce()
  return filterLoadingBgData(isLoggedIn.get() ? bgDataAfterLogin : bgDataBeforeLogin)
}

function getLoadingBgIdByUnlockId(unlockId) {
  initOnce()
  return bgUnlocks.findindex(@(v) unlockId == v)
}

function getUnlockIdByLoadingBg(bgId) {
  initOnce()
  return bgUnlocks?[bgId]
}

let isLoadingBgUnlock = @(unlockId) getLoadingBgIdByUnlockId(unlockId) != null
let getLoadingBgName = @(id) loc($"loading_bg/{id}")
let getLoadingBgTooltip = @(id) loc($"loading_bg/{id}/desc", "")

let reset = @() inited = false
let setLoadingBgPath = @(path) LOADING_BG_PATH = path

subscriptions.addListenersWithoutEnv({
  GameLocalizationChanged = @(_p) reset()
})

return {
  getCurLoadingBgData
  getLoadingBgIdByUnlockId
  getLoadingBgName
  getLoadingBgTooltip
  setLoadingBgPath
  removeLoadingBgFromLists
  isLoadingBgUnlock
  createBgData
  getFilterBgList
  isBgUnlocked
  getUnlockIdByLoadingBg
}
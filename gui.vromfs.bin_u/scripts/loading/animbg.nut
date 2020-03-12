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

local fileCheck = require("scripts/clientState/fileCheck.nut")
local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")

const MODIFY_UNKNOWN = -1
const MODIFY_NO_FILE = -2

local createBgData = @() {
  list = {}
  reserveBg = ""
}

local bgDataBeforeLogin = createBgData()
local bgDataAfterLogin = createBgData()
local lastBg = ""

local getFullFileName = @(name) $"config/loadingbg/{name}.blk"
local getLastBgFileName = @() lastBg.len() ? getFullFileName(lastBg) : ""

local inited = false

local RESERVE_BG_KEY = "reserveBg"
local DEFAULT_VALUE_KEY = "default_chance"
local BLOCK_BEFORE_LOGIN_KEY = "beforeLogin"
local LOADING_BG_PATH = "loading_bg"

local isDebugMode = false
local debugLastModified = MODIFY_UNKNOWN
local loadErrorText = null

local function invalidateCache() {
  lastBg = ""
}

local function applyBlkToBgData(bgData, blk) {
  local list = bgData.list

  local defValue = blk?[DEFAULT_VALUE_KEY]
  if (defValue != null)
    foreach(key, value in list)
      list[key] = defValue

  local reserveBg = blk?[RESERVE_BG_KEY]
  if (::u.isString(reserveBg))
    bgData.reserveBg = reserveBg

  for (local i = 0; i < blk.paramCount(); i++)
  {
    local value = blk.getParamValue(i)
    if (::is_numeric(value))
      list[blk.getParamName(i)] <- value
  }

  //to not check name for each added param
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
  foreach(key in keys)
  {
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
  foreach(langBlk in bgBlk % "language")
    if (::u.isDataBlock(langBlk))
      applyBlkByLang(langBlk, curLang)

  local presetBlk = bgBlk?[::get_country_flags_preset()]
  if (::u.isDataBlock(presetBlk))
    applyBlkToAllBgData(presetBlk)

  validateBgData(bgDataAfterLogin)
  validateBgData(bgDataBeforeLogin)
}

local function removeFromBgLists(name) {
  foreach(data in [bgDataAfterLogin, bgDataBeforeLogin])
  {
    if (name in data.list)
      delete data.list[name]
    if (data.reserveBg == name)
      data.reserveBg = ""
  }
}

local function loadBgBlk(name) {
  loadErrorText = null
  local res = ::DataBlock()
  local fullName = getFullFileName(name)
  local isLoaded = res.load(fullName)
  if (isLoaded)
    return res

  local errText = ::dd_file_exist(fullName) ? "errors in file" : "not found file"
  loadErrorText = "Error: cant load login bg blk {0}: {1}".subst(::colorize("userlogColoredText", fullName), errText)

  if (isDebugMode)
    return res //no need to change bg in debugMode

  res = null
  removeFromBgLists(name)
  ::dagor.assertf(false, loadErrorText)
  return res
}

local getCurBgData = @() ::g_login.isLoggedIn() ? bgDataAfterLogin : bgDataBeforeLogin
local function load(animBgBlk = "", obj = null) {
  initOnce()

  if (!obj)
    obj = ::get_cur_gui_scene()["animated_bg_picture"]
  if (!::check_obj(obj))
    return

  local curBgData = getCurBgData()
  local curBgList = curBgData.list
  if (!curBgList.len())
    return

  if (animBgBlk!="")
    lastBg = animBgBlk
  else
    if (::g_login.isLoggedIn() || lastBg=="") //no change bg during first load
    {
      local sum = 0.0
      foreach(name, value in curBgList)
        sum += value
      sum = ::math.frnd() * sum
      foreach(name, value in curBgList)
      {
        lastBg = name
        sum -= value
        if (sum <= 0)
          break
      }
    }

  local bgBlk = loadBgBlk(lastBg)
  if (!bgBlk)
  {
    invalidateCache()
    load("", obj)
    return
  }

  if (!isDebugMode && !fileCheck.isAllBlkImagesPrefetched(bgBlk)
    && curBgData.reserveBg.len())
    bgBlk = loadBgBlk(curBgData.reserveBg) || bgBlk

  if (isDebugMode && loadErrorText) {
    local markup = "textAreaCentered { pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute'; text:t='{0}' }".subst(loadErrorText)
    obj.getScene().replaceContentFromText(obj, markup, markup.len(), this)
  } else
    obj.getScene().replaceContentFromDataBlock(obj, bgBlk, this)
  debugLastModified = MODIFY_UNKNOWN
}

local function reset() {
  inited = false
}

local function enableDebugUpdate() {
  SecondsUpdater(
    ::get_cur_gui_scene()["bg_picture_container"],
    function(tObj, params) {
      local fileName = getLastBgFileName()
      if (!fileName.len())
        return

      local modified = ::get_file_modify_time_sec(fileName)
      if (modified < 0)
        modified = ::dd_file_exist(fileName) ? MODIFY_UNKNOWN : MODIFY_NO_FILE

      if (debugLastModified == modified)
        return

      if (debugLastModified != MODIFY_UNKNOWN)
        load(lastBg)
      debugLastModified = modified
    },
    false)
}

//animBgBlk == null - swith debug mode off.
local function debugLoad(animBgBlk = "") {
  isDebugMode = animBgBlk != null
  if (!isDebugMode)
    return

  ::gui_start_loading()
  load(animBgBlk)
  enableDebugUpdate()
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(p) invalidateCache()
  GameLocalizationChanged = @(p) reset()
})

return {
  animBgLoad = load
  debugLoad = debugLoad
  changeLoadingBgPath = @(path) LOADING_BG_PATH = path
}
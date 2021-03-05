local fileCheck = require("scripts/clientState/fileCheck.nut")
local subscriptions = require("sqStdLibs/helpers/subscriptions.nut")
local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local { getCurLoadingBgData, removeLoadingBgFromLists } = require("scripts/loading/loadingBgData.nut")

const MODIFY_UNKNOWN = -1
const MODIFY_NO_FILE = -2

local lastBg = ""

local getFullFileName = @(name) $"config/loadingbg/{name}.blk"
local getLastBgFileName = @() lastBg.len() ? getFullFileName(lastBg) : ""

local isDebugMode = false
local debugLastModified = MODIFY_UNKNOWN
local loadErrorText = null

local function invalidateCache() {
  lastBg = ""
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
  removeLoadingBgFromLists(name)
  ::dagor.assertf(false, loadErrorText)
  return res
}

local function load(animBgBlk = "", obj = null) {
  if (!obj)
    obj = ::get_cur_gui_scene()["animated_bg_picture"]
  if (!::check_obj(obj))
    return

  local curBgData = getCurLoadingBgData()
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
})

return {
  animBgLoad = load
  debugLoad = debugLoad
}
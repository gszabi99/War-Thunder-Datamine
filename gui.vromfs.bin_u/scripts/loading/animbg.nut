from "%scripts/dagui_natives.nut" import get_file_modify_time_sec
from "%scripts/dagui_library.nut" import *

let { eventbus_send } = require("eventbus")
let { file_exists } = require("dagor.fs")
let { frnd } = require("dagor.random")
let DataBlock = require("DataBlock")
let fileCheck = require("%scripts/clientState/fileCheck.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { getCurLoadingBgData, removeLoadingBgFromLists } = require("%scripts/loading/loadingBgData.nut")
let { isLoadingScreenBanned } = require("%scripts/options/preloaderOptions.nut")
let { havePremium } = require("%scripts/user/premium.nut")

const MODIFY_UNKNOWN = -1
const MODIFY_NO_FILE = -2

local lastBg = ""

let getFullFileName = @(name) name.split(".").len() > 1 ? name : $"config/loadingbg/{name}.blk"
let getLastBgFileName = @() lastBg.len() ? getFullFileName(lastBg) : ""

local isDebugMode = false
local debugLastModified = MODIFY_UNKNOWN
local loadErrorText = null

function invalidateCache() {
  lastBg = ""
}

function loadBgBlk(name) {
  loadErrorText = null
  local res = DataBlock()
  let fullName = getFullFileName(name)
  let isLoaded = res.load(fullName)
  if (isLoaded)
    return res

  let errText = file_exists(fullName) ? "errors in file" : "not found file"
  loadErrorText = "Error: cant load login bg blk {0}: {1}".subst(colorize("userlogColoredText", fullName), errText)

  if (isDebugMode)
    return res //no need to change bg in debugMode

  res = null
  removeLoadingBgFromLists(name)
  assert(false, loadErrorText)
  return res
}

local function load(blkFilePath = "", obj = null, curBgData = null) {
  if (!obj)
    obj = get_cur_gui_scene()["animated_bg_picture"]
  if (!checkObj(obj))
    return

  curBgData = curBgData ?? getCurLoadingBgData()
  local curBgList = curBgData.list
  if (!curBgList.len())
    return

  if (blkFilePath != "")
    lastBg = blkFilePath
  else if (::g_login.isLoggedIn() || lastBg == "") { //no change bg during first load
      if (hasFeature("LoadingBackgroundFilter")
        && ::g_login.isProfileReceived() && havePremium.value) {
        let filteredCurBgList = curBgList.filter(@(_v, id) !isLoadingScreenBanned(id))
        if (filteredCurBgList.len() > 0)
          curBgList = filteredCurBgList
      }

      local sum = 0.0
      foreach (_name, value in curBgList)
        sum += value
      sum = frnd() * sum
      foreach (name, value in curBgList) {
        lastBg = name
        sum -= value
        if (sum <= 0)
          break
      }
    }

  local bgBlk = loadBgBlk(lastBg)
  if (!bgBlk) {
    invalidateCache()
    load("", obj)
    return
  }

  if (!isDebugMode && !fileCheck.isAllBlkImagesPrefetched(bgBlk)
    && curBgData.reserveBg.len())
    bgBlk = loadBgBlk(curBgData.reserveBg) || bgBlk

  if (isDebugMode && loadErrorText) {
    let markup = "textAreaCentered { pos:t='pw/2-w/2, ph/2-h/2'; position:t='absolute'; text:t='{0}' }".subst(loadErrorText)
    obj.getScene().replaceContentFromText(obj, markup, markup.len(), this)
  }
  else
    obj.getScene().replaceContentFromDataBlock(obj, bgBlk, this)
  debugLastModified = MODIFY_UNKNOWN
}

function enableDebugUpdate() {
  SecondsUpdater(
    get_cur_gui_scene()["bg_picture_container"],
    function(_tObj, _params) {
      let fileName = getLastBgFileName()
      if (!fileName.len())
        return

      local modified = get_file_modify_time_sec(fileName)
      if (modified < 0)
        modified = file_exists(fileName) ? MODIFY_UNKNOWN : MODIFY_NO_FILE

      if (debugLastModified == modified)
        return

      if (debugLastModified != MODIFY_UNKNOWN)
        load(lastBg)
      debugLastModified = modified
    },
    false)
}

//blkFilePath == null - swith debug mode off.
function debugLoad(blkFilePath = "") {
  isDebugMode = blkFilePath != null
  if (!isDebugMode)
    return

  eventbus_send("gui_start_loading", {})
  load(blkFilePath)
  enableDebugUpdate()
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
})

return {
  animBgLoad = load
  debugLoad = debugLoad
}
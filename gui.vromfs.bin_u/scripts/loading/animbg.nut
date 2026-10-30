import "%scripts/clientState/fileCheck.nut" as fileCheck
import "%sqStdLibs/helpers/subscriptions.nut" as subscriptions
import "DataBlock" as DataBlock
from "%scripts/loading/loadingBgData.nut" import getCurLoadingBgData, removeLoadingBgFromLists
from "%scripts/options/preloaderOptions.nut" import isLoadingScreenBanned
from "%scripts/user/premium.nut" import havePremium
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler
from "%appGlobals/login/loginState.nut" import hasFullLoginState, isProfileReceived
from "dagor.fs" import file_exists
from "dagor.random" import frnd
from "%appGlobals/loading/loadingBgChoice.nut" import pickLoadingBg, loadingBgBlkPath
from "%scripts/dagui_natives.nut" import get_file_modify_time_sec
from "dagor.workcycle" import deferOnce, resetTimeout
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_library.nut" import *

let SecondsUpdater = require("%scripts/sqDagui/timer/secondsUpdater.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

const MODIFY_UNKNOWN = -1
const MODIFY_NO_FILE = -2

local lastBg = ""
let shownBgImages = persist("shownBgImages", @() [])

let getLastBgFileName = @() lastBg.len() ? loadingBgBlkPath(lastBg) : ""

local isDebugMode = false
local debugLastModified = MODIFY_UNKNOWN
local loadErrorText = null

function invalidateCache() {
  lastBg = ""
}

function discardUnusedBgTextures() {
  get_cur_gui_scene().discardUnusedTextures(shownBgImages)
}

function releaseUnusedBgTextures() {
  discardUnusedBgTextures()
  resetTimeout(1.0, discardUnusedBgTextures)
}

function addShownBgImages(bgBlk) {
  foreach (img in fileCheck.getBlkImages(bgBlk))
    if (!shownBgImages.contains(img))
      shownBgImages.append(img)
}

function loadBgBlk(name) {
  loadErrorText = null
  local res = DataBlock()
  let fullName = loadingBgBlkPath(name)
  let isLoaded = res.load(fullName)
  if (isLoaded)
    return res

  let errText = file_exists(fullName) ? "errors in file" : "not found file"
  loadErrorText = "Error: cant load login bg blk {0}: {1}".subst(colorize("userlogColoredText", fullName), errText)

  if (isDebugMode)
    return res 

  res = null
  removeLoadingBgFromLists(name)
  assert(false, loadErrorText)
  return res
}

function load(blkFilePath = "", obj = null, curBgData = null) {
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
  else if (hasFullLoginState.get() || lastBg == "") { 
      if (hasFeature("LoadingBackgroundFilter")
        && isProfileReceived.get() && havePremium.get()) {
        let filteredCurBgList = curBgList.filter(@(_v, id) !isLoadingScreenBanned(id))
        if (filteredCurBgList.len() > 0)
          curBgList = filteredCurBgList
      }

      lastBg = pickLoadingBg(curBgList, frnd())
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
  else {
    addShownBgImages(bgBlk)
    obj.getScene().replaceContentFromDataBlock(obj, bgBlk, this)
    releaseUnusedBgTextures()
  }
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


function debugLoad(blkFilePath = "") {
  isDebugMode = blkFilePath != null
  if (!isDebugMode)
    return

  handlersManager.loadHandler(get_gui_handler("LoadingHandler"))
  load(blkFilePath)
  enableDebugUpdate()
}

subscriptions.addListenersWithoutEnv({
  SignOut = @(_p) invalidateCache()
  NewSceneLoaded = @(_p) deferOnce(releaseUnusedBgTextures)
})

eventbus_subscribe("onGuiFinishLoading", @(_) deferOnce(releaseUnusedBgTextures))

return freeze({
  animBgLoad = load
  debugLoad = debugLoad
  releaseUnusedBgTextures
})
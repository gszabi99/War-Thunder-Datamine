from "%scripts/dagui_library.nut" import *
from "%scripts/social/psConsts.nut" import ps4_activity_feed

let u = require("%sqStdLibs/helpers/u.nut")
let { checkPromoBlockUnlock, checkPromoBlockReqEntitlement,
  checkPromoBlockReqFeature, isPromoVisibleByAction
} = require("%scripts/promo/promo.nut")
let { split_by_chars } = require("string")
let { get_game_version_str } = require("app")
let time = require("%scripts/time.nut")
let promoConditions = require("%scripts/promo/promoConditions.nut")
let { isPollVoted } = require("%scripts/web/webpoll.nut")
let { startsWith } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { get_gui_regional_blk } = require("blkGetters")
let { userName, userIdStr } = require("%scripts/user/profileStates.nut")
let { isAvailableForCurLang, getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { isPartnerUnlockAvailable } = require("%scripts/user/partnerUnlocks.nut")
let { showUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")

enum POPUP_VIEW_TYPES {
  NEVER = "never"
  EVERY_SESSION = "every_session"
  EVERY_DAY = "every_day"
  ONCE = "once"
}
let passedPopups = persist("passedPopups", @() {})

let g_popup_msg = {

  passedPopups
  days = 0
}

function getTimeIntByString(stringDate, defaultValue = 0) {
  let t = stringDate ? time.getTimestampFromStringUtc(stringDate) : -1
  return t >= 0 ? t : defaultValue
}


g_popup_msg.ps4ActivityFeedFromPopup <- function ps4ActivityFeedFromPopup(blk) {
  if (blk?.ps4ActivityFeedType != "update")
    return null

  let ver = split_by_chars(get_game_version_str(), ".")
  let feed = {
    config = {
      locId = "major_update"
      subType = ps4_activity_feed.MAJOR_UPDATE
    }
    params = {
      blkParamName = "MAJOR_UPDATE"
      imgSuffix = "".concat("_", ver[0], "_", ver[1])
      forceLogo = true
      captions = { en = blk.name }
      condensedCaptions = { en = blk.name }
    }
  }

  foreach (name, val in blk) {
    if (startsWith(name, "name_")) {
      let lang = name.slice(5)
      feed.params.captions[lang] <- val
      feed.params.condensedCaptions[lang] <- val
    }
  }

  return feed
}

g_popup_msg.verifyPopupBlk <- function verifyPopupBlk(blk, hasModalObject, needDisplayCheck = true) {
  let popupId = blk.getBlockName()

  if (needDisplayCheck) {
    if (popupId in passedPopups)
      return null

    if (hasModalObject && !blk.getBool("showOverModalObject", false))
      return null

    if (!checkPromoBlockReqFeature(blk))
      return null

    if (!checkPromoBlockReqEntitlement(blk))
      return null

    if (!checkPromoBlockUnlock(blk))
      return null

    if (!isPartnerUnlockAvailable(blk?.partnerUnlock, blk?.partnerUnlockDurationMin))
      return null

    if (!isAvailableForCurLang(blk))
      return null

    if (blk?.pollId && isPollVoted(blk.pollId))
      return null

    if (!isPromoVisibleByAction(blk))
      return null

    let viewType = blk?.viewType ?? POPUP_VIEW_TYPES.NEVER
    let viewDay = loadLocalByAccount("".concat("popup/", (blk?.saveId ?? popupId)), 0)
    let canShow = (viewType == POPUP_VIEW_TYPES.EVERY_SESSION)
                    || (viewType == POPUP_VIEW_TYPES.ONCE && !viewDay)
                    || (viewType == POPUP_VIEW_TYPES.EVERY_DAY && viewDay < this.days)
    if (!canShow || !promoConditions.isVisibleByConditions(blk)) {
      passedPopups[popupId] <- true
      return null
    }

    let secs = get_charserver_time_sec()
    if (getTimeIntByString(blk?.startTime, 0) > secs)
      return null

    if (getTimeIntByString(blk?.endTime, 2114380800) < secs) {
      passedPopups[popupId] <- true
      return null
    }
  }

  let localizedTbl = { name = getPlayerName(userName.value), uid = userIdStr.value }
  let popupTable = {
    name = ""
    popupImage = ""
    ratioHeight = null
    forceExternalBrowser = false
    action = null
  }

  foreach (key in ["name", "desc", "link", "linkText", "actionText"]) {
    let keyPostfix = getCurCircuitOverride($"{key}ForPopupPostfix", "")
    let text = keyPostfix != "" ? (blk?[$"{key}{keyPostfix}"] ?? "") :  getLocTextFromConfig(blk, key, "")
    if (text != "")
      popupTable[key] <- text.subst(localizedTbl)
  }
  popupTable.popupImage = getLocTextFromConfig(blk, "image", "")
  popupTable.ratioHeight = blk?.imageRatio
  popupTable.forceExternalBrowser = blk?.forceExternalBrowser ?? false
  popupTable.action = blk?.action

  if (blk?.pollId != null)
    popupTable.pollId <- blk.pollId

  if (blk?.qrUrl != null)
    popupTable.qrUrl <- blk.qrUrl

  let ps4ActivityFeedData = this.ps4ActivityFeedFromPopup(blk)
  if (ps4ActivityFeedData)
    popupTable.ps4ActivityFeedData <- ps4ActivityFeedData

  return popupTable
}

g_popup_msg.showPopupWndIfNeed <- function showPopupWndIfNeed(hasModalObject) {
  this.days = time.getUtcDays()
  if (!get_gui_regional_blk())
    return false

  let popupsBlk = get_gui_regional_blk()?.popupItems
  if (!u.isDataBlock(popupsBlk))
    return false

  local result = false
  for (local i = 0; i < popupsBlk.blockCount(); i++) {
    let popupBlk = popupsBlk.getBlock(i)
    let popupId = popupBlk.getBlockName()
    let popupConfig = this.verifyPopupBlk(popupBlk, hasModalObject)
    if (popupConfig) {
      passedPopups[popupId] <- true
      popupConfig["type"] <- "regionalPromoPopup"
      showUnlockWnd(popupConfig)
      saveLocalByAccount("".concat("popup/", (popupBlk?.saveId ?? popupId)), this.days)
      result = true
    }
  }
  return result
}

g_popup_msg.showPopupDebug <- function showPopupDebug(dbgId) {
  let debugLog = dlog // warning disable: -forbidden-function
  let popupsBlk = get_gui_regional_blk()?.popupItems
  if (!u.isDataBlock(popupsBlk)) {
    debugLog("POPUP ERROR: No popupItems in gui_regional.blk") // warning disable: -forbidden-function
    return false
  }

  for (local i = 0; i < popupsBlk.blockCount(); i++) {
    let popupBlk = popupsBlk.getBlock(i)
    let popupId = popupBlk.getBlockName()
    if (popupId != dbgId)
      continue

    let popupConfig = this.verifyPopupBlk(popupBlk, false, false)
    showUnlockWnd(popupConfig)
    return true
  }
  debugLog($"POPUP ERROR: Not found {dbgId}") // warning disable: -forbidden-function
  return false
}

::g_popup_msg <- g_popup_msg
return { g_popup_msg }
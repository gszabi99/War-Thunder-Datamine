import "%scripts/time.nut" as time
import "%scripts/promo/promoConditions.nut" as promoConditions
import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/promo/promo.nut" import checkPromoBlockUnlock, checkPromoBlockReqEntitlement, checkPromoBlockReqFeature, isPromoVisibleByAction
from "%scripts/web/webpoll.nut" import isPollVoted
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/clientState/localProfileDeprecated.nut" import loadLocalByAccount, saveLocalByAccount
from "%scripts/user/profileStates.nut" import userName, userIdStr
from "%scripts/langUtils/language.nut" import isAvailableForCurLang, getLocTextFromConfig
from "%scripts/user/partnerUnlocks.nut" import isPartnerUnlockAvailable
from "%scripts/unlocks/showUnlockWnd.nut" import showUnlockWnd
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "chard" import get_charserver_time_sec
from "blkGetters" import get_gui_regional_blk
from "console" import register_command
from "%scripts/dagui_library.nut" import *

enum POPUP_VIEW_TYPES {
  NEVER = "never"
  EVERY_SESSION = "every_session"
  EVERY_DAY = "every_day"
  ONCE = "once"
}
let passedPopups = mkHardPersist("utils.popupMessages")("passedPopups", {})

function getTimeIntByString(stringDate, defaultValue = 0) {
  let t = stringDate ? time.getTimestampFromStringUtc(stringDate) : -1
  return t >= 0 ? t : defaultValue
}

function verifyPopupBlk(blk, days, hasModalObject, needDisplayCheck = true) {
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
                    || (viewType == POPUP_VIEW_TYPES.EVERY_DAY && viewDay < days)
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

  let localizedTbl = { name = getPlayerName(userName.get()), uid = userIdStr.get() }
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

  return popupTable
}

function showPopupWndIfNeed(hasModalObject) {
  if (!get_gui_regional_blk())
    return false

  let popupsBlk = get_gui_regional_blk()?.popupItems
  if (!u.isDataBlock(popupsBlk))
    return false

  let days = time.getUtcDays()
  local result = false
  for (local i = 0; i < popupsBlk.blockCount(); i++) {
    let popupBlk = popupsBlk.getBlock(i)
    let popupId = popupBlk.getBlockName()
    let popupConfig = verifyPopupBlk(popupBlk, days, hasModalObject)
    if (popupConfig) {
      passedPopups[popupId] <- true
      popupConfig["type"] <- "regionalPromoPopup"
      showUnlockWnd(popupConfig)
      saveLocalByAccount("".concat("popup/", (popupBlk?.saveId ?? popupId)), days)
      result = true
    }
  }
  return result
}

function showPopupDebug(dbgId) {
  let debugLog = dlog 
  let popupsBlk = get_gui_regional_blk()?.popupItems
  if (!u.isDataBlock(popupsBlk)) {
    debugLog("POPUP ERROR: No popupItems in gui_regional.blk") 
    return false
  }

  let days = time.getUtcDays()
  for (local i = 0; i < popupsBlk.blockCount(); i++) {
    let popupBlk = popupsBlk.getBlock(i)
    let popupId = popupBlk.getBlockName()
    if (popupId != dbgId)
      continue

    let popupConfig = verifyPopupBlk(popupBlk, days, false, false)
    showUnlockWnd(popupConfig)
    return true
  }
  debugLog($"POPUP ERROR: Not found {dbgId}") 
  return false
}

register_command(showPopupDebug, "debug.show_popup")

return freeze({
  showPopupWndIfNeed
})
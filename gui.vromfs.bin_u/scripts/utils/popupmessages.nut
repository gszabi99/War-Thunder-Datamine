from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { split_by_chars } = require("string")
let { get_game_version_str = @() ::get_game_version_str() //compatibility with 2.15.1.X
} = require("app")
let time = require("%scripts/time.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let promoConditions = require("%scripts/promo/promoConditions.nut")
let { isPollVoted } = require("%scripts/web/webpoll.nut")
let { PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")

enum POPUP_VIEW_TYPES {
  NEVER = "never"
  EVERY_SESSION = "every_session"
  EVERY_DAY = "every_day"
  ONCE = "once"
}

::g_popup_msg <- {
  [PERSISTENT_DATA_PARAMS] = ["passedPopups"]

  passedPopups = {}
  days = 0
}

let function getTimeIntByString(stringDate, defaultValue = 0) {
  let t = stringDate ? time.getTimestampFromStringUtc(stringDate) : -1
  return t >= 0 ? t : defaultValue
}


::g_popup_msg.ps4ActivityFeedFromPopup <- function ps4ActivityFeedFromPopup(blk)
{
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
      imgSuffix = "_" + ver[0] + "_" + ver[1]
      forceLogo = true
      captions = { en = blk.name }
      condensedCaptions = { en = blk.name }
    }
  }

  foreach(name, val in blk)
  {
    if (::g_string.startsWith(name, "name_"))
    {
      let lang = name.slice(5)
      feed.params.captions[lang] <- val
      feed.params.condensedCaptions[lang] <- val
    }
  }

  return feed
}

::g_popup_msg.verifyPopupBlk <- function verifyPopupBlk(blk, hasModalObject, needDisplayCheck = true)
{
  let popupId = blk.getBlockName()

  if (needDisplayCheck)
  {
    if (popupId in this.passedPopups)
      return null

    if (hasModalObject && !blk.getBool("showOverModalObject", false))
      return null

    if (!::g_promo.checkBlockReqFeature(blk))
      return null

    if (!::g_promo.checkBlockReqEntitlement(blk))
      return null

    if (!::g_promo.checkBlockUnlock(blk))
      return null

    if (!::g_partner_unlocks.isPartnerUnlockAvailable(blk?.partnerUnlock, blk?.partnerUnlockDurationMin))
      return null

    if (!::g_language.isAvailableForCurLang(blk))
      return null

    if (blk?.pollId && isPollVoted(blk.pollId))
      return null

    if (!::g_promo.isVisibleByAction(blk))
      return null

    let viewType = blk?.viewType ?? POPUP_VIEW_TYPES.NEVER
    let viewDay = ::loadLocalByAccount("popup/" + (blk?.saveId ?? popupId), 0)
    let canShow = (viewType == POPUP_VIEW_TYPES.EVERY_SESSION)
                    || (viewType == POPUP_VIEW_TYPES.ONCE && !viewDay)
                    || (viewType == POPUP_VIEW_TYPES.EVERY_DAY && viewDay < this.days)
    if (!canShow || !promoConditions.isVisibleByConditions(blk))
    {
      this.passedPopups[popupId] <- true
      return null
    }

    let secs = ::get_charserver_time_sec()
    if (getTimeIntByString(blk?.startTime, 0) > secs)
      return null

    if (getTimeIntByString(blk?.endTime, 2114380800) < secs)
    {
      this.passedPopups[popupId] <- true
      return null
    }
  }

  let localizedTbl = {name = platformModule.getPlayerName(::my_user_name), uid = ::my_user_id_str}
  let popupTable = {
    name = ""
    popupImage = ""
    ratioHeight = null
    forceExternalBrowser = false
    action = null
  }

  foreach (key in ["name", "desc", "link", "linkText", "actionText"])
  {
    let text = ::g_language.getLocTextFromConfig(blk, key, "")
    if (text != "")
      popupTable[key] <- text.subst(localizedTbl)
  }
  popupTable.popupImage = ::g_language.getLocTextFromConfig(blk, "image", "")
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

::g_popup_msg.showPopupWndIfNeed <- function showPopupWndIfNeed(hasModalObject)
{
  this.days = time.getUtcDays()
  if (!::get_gui_regional_blk())
    return false

  let popupsBlk = ::get_gui_regional_blk()?.popupItems
  if (!::u.isDataBlock(popupsBlk))
    return false

  local result = false
  for(local i = 0; i < popupsBlk.blockCount(); i++)
  {
    let popupBlk = popupsBlk.getBlock(i)
    let popupId = popupBlk.getBlockName()
    let popupConfig = this.verifyPopupBlk(popupBlk, hasModalObject)
    if (popupConfig)
    {
      this.passedPopups[popupId] <- true
      popupConfig["type"] <- "regionalPromoPopup"
      ::showUnlockWnd(popupConfig)
      ::saveLocalByAccount("popup/" + (popupBlk?.saveId ?? popupId), this.days)
      result = true
    }
  }
  return result
}

::g_popup_msg.showPopupDebug <- function showPopupDebug(dbgId)
{
  let debugLog = dlog // warning disable: -forbidden-function
  let popupsBlk = ::get_gui_regional_blk()?.popupItems
  if (!::u.isDataBlock(popupsBlk))
  {
    debugLog("POPUP ERROR: No popupItems in gui_regional.blk")
    return false
  }

  for (local i = 0; i < popupsBlk.blockCount(); i++)
  {
    let popupBlk = popupsBlk.getBlock(i)
    let popupId = popupBlk.getBlockName()
    if (popupId != dbgId)
      continue

    let popupConfig = this.verifyPopupBlk(popupBlk, false, false)
    ::showUnlockWnd(popupConfig)
    return true
  }
  debugLog($"POPUP ERROR: Not found {dbgId}")
  return false
}

::g_script_reloader.registerPersistentDataFromRoot("g_popup_msg")

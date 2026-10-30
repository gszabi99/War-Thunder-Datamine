import "%scripts/time.nut" as time
import "%scripts/viewUtils/showTitleLogo.nut" as showTitleLogo
import "%scripts/discounts/updateDiscountNotifications.nut" as updateDiscountNotifications
from "%scripts/gamercard/gamercardHelpers.nut" import getLastGamercardScene, addGamercardScene, updateGcInvites, updateGamercardsChatInfo, updateGcButton
from "%scripts/user/userInfoStats.nut" import getProfileInfo, getCurExpTable
from "%scripts/options/countryFlagsPreset.nut" import getCountryIcon
from "%scripts/langUtils/textFormat.nut" import decimalFormat
from "%scripts/clans/clanTextInfo.nut" import checkClanTagForDirtyWords
from "%scripts/money.nut" import Balance, Cost
from "%scripts/items/boosterEffect.nut" import haveActiveBonusesByEffectType, getCurrentBonusesText
from "%scripts/contacts/customNicknames.nut" import getCustomNick
from "%scripts/user/remapNick.nut" import getPlayerName
from "%scripts/userLog/userlogUtils.nut" import check_new_user_logs
from "%scripts/contacts/contactsInfo.nut" import getFriendsOnlineNum
from "%scripts/user/premium.nut" import getRemainingPremiumTime, havePremium
from "%scripts/queue/queueInfo/qiViewUtils.nut" import updateShortQueueInfo
from "%scripts/sqDagui/guiBhv/guiBhvValueConfig.nut" import stashBhvValueConfig
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/chat/chatStates.nut" import isChatEnabled, hasMenuChat
from "%scripts/items/itemsManager.nut" import isItemsManagerEnabled
from "%scripts/clans/clanCandidates.nut" import getUnseenCandidatesCount
from "%scripts/viewUtils/objectTextUpdate.nut" import setVersionText
from "%scripts/hud/serverMessages.nut" import serverMessageUpdateScene
from "%scripts/battlePass/unlocksRewardsState.nut" import hasBattlePass
from "%sqStdLibs/helpers/u.nut" import isEmpty
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "%sqstd/platform.nut" import is_gdk
from "%globalScripts/loc_helpers.nut" import locByVendor
from "string" import format
from "%scripts/dagui_natives.nut" import entitlement_expires_in
from "%scripts/dagui_library.nut" import *

let { boosterEffectType } = require("%scripts/items/boosterEffectTypes.nut")

let defaultFillGamercardObj = @(obj, val, _params) obj.setValue((val ?? "").tostring())

let fillGamercardObjByKey = {
  function frame(obj, val, _params) {
    let { frameImagePath, framesCount } = val
    let hasAvatarFrame = frameImagePath != null
    obj.show(hasAvatarFrame)
    if (!hasAvatarFrame)
      return

    obj["background-frames"] = framesCount
    obj["background-image"] = frameImagePath
  }

  country = @(obj, val, _params) obj["background-image"] = getCountryIcon(val)

  function rankProgress(obj, val, params) {
    let { cfg, isGamercard } = params
    let value = val?.tointeger() ?? 0
    let isProgressVisible = !isGamercard || value >= 0
    obj.show(isProgressVisible)
    if (!isProgressVisible)
      return

    obj.setValue(value != -1 ? value : 1000)
    let expTable = getCurExpTable(cfg)
    obj.tooltip = expTable
      ? nbsp.concat(decimalFormat(expTable.exp), "/", decimalFormat(expTable.rankExp))
      : "".concat(loc("ugm/total"), loc("ui/colon"), decimalFormat(cfg.exp))
  }

  function prestige(obj, val, params) {
    let { prefix, getObj } = params
    if (val == null)
      return

    obj["background-image"] = $"#ui/gameuiskin#prestige{val}"
    let titleObj = getObj($"{prefix}prestige_title")
    if (!(titleObj?.isValid() ?? false))
      return
    let prestigeTitle = val > 0 ? loc($"rank/prestige{val}") : ""
    titleObj.setValue(prestigeTitle)
  }

  function exp(obj, val, params) {
    let { cfg } = params
    let expTable = getCurExpTable(cfg)
    obj.setValue(expTable
      ? nbsp.concat(decimalFormat(expTable.exp), "/", decimalFormat(expTable.rankExp))
      : "")
    obj.tooltip = "".concat(loc("ugm/total"), loc("ui/colon"), decimalFormat(val))
  }

  function clanTag(obj, val, params) {
    let { prefix } = params
    let clanTagName = checkClanTagForDirtyWords(val?.tostring() ?? "")
    let btnText = obj.findObject($"{prefix}clanTag_name")
    if (btnText?.isValid() ?? false)
      btnText.setValue(clanTagName)
    else
      obj.setValue(clanTagName)
  }

  function gold(obj, val, _params) {
    let moneyInst = Cost(0, val)
    let valStr = moneyInst.toStringWithParams({ isGoldAlwaysShown = true })
    let tooltipText = "\n".concat(colorize("activeTextColor", valStr), loc("mainmenu/gold"))
    obj.getParent().tooltip = tooltipText
    obj.setValue(moneyInst.toStringWithParams({ isGoldAlwaysShown = true, needIcon = false }))
  }

  function balance(obj, val, _params) {
    let moneyInst = Cost(val)
    let valStr = moneyInst.toStringWithParams({ isWpAlwaysShown = true })
    let tooltipText = "\n".concat(colorize("activeTextColor", valStr),
      loc("mainmenu/warpoints"),
      getCurrentBonusesText(boosterEffectType.WP))
    let buttonObj = obj.getParent()
    buttonObj.tooltip = tooltipText
    buttonObj.showBonusCommon = haveActiveBonusesByEffectType(boosterEffectType.WP, false) ? "yes" : "no"
    buttonObj.showBonusPersonal = haveActiveBonusesByEffectType(boosterEffectType.WP, true) ? "yes" : "no"
    obj.setValue(moneyInst.toStringWithParams({ isWpAlwaysShown = true, needIcon = false }))
  }

  function free_exp(obj, val, _params) {
    let valStr = Balance(0, 0, val).toStringWithParams({ isFrpAlwaysShown = true })
    let tooltipText = "\n".concat(colorize("activeTextColor", valStr),
      loc("currency/freeResearchPoints/desc"),
      getCurrentBonusesText(boosterEffectType.RP))
    obj.tooltip = tooltipText
    obj.showBonusCommon = haveActiveBonusesByEffectType(boosterEffectType.RP, false) ? "yes" : "no"
    obj.showBonusPersonal = haveActiveBonusesByEffectType(boosterEffectType.RP, true) ? "yes" : "no"
  }

  function name(obj, val, params) {
    local valStr
    if (isEmpty(val))
      valStr = loc("mainmenu/pleaseSignIn")
    else {
      let { cfg } = params
      let customNick = getCustomNick(cfg)
      valStr = customNick == null ? getPlayerName(val)
        : $"{getPlayerName(val)}{loc("ui/parentheses/space", { text = customNick })}"
    }
    obj.setValue(valStr)
  }
}

function fillGamercard(cfg = null, prefix = "gc_", scene = null, save_scene = true) {
  if (!checkObj(scene)) {
    scene = getLastGamercardScene()
    if (!scene)
      return
  }
  let isGamercard = prefix == "gc_"
  let isShowGamercard = hasFullLoginState.get()
  let div = showObjById("gamercard_div", isShowGamercard, scene)
  let isValidGamercard = checkObj(div)
  if (isGamercard && !isValidGamercard)
    return

  if (isValidGamercard)
    showTitleLogo(div)

  if (scene && save_scene && isGamercard && isValidGamercard)
    addGamercardScene(scene)

  if (!isShowGamercard)
    return

  if (!cfg)
    cfg = getProfileInfo()

  let getObj = @(id) scene.findObject(id)
  let profileBtn = getObj($"{prefix}profile")
  if (profileBtn?.isValid())
    profileBtn.tooltip = locByVendor("mainmenu/btnProfile")
  let params = { cfg, isGamercard, prefix, getObj }
  foreach (name, val in cfg) {
    let obj = getObj($"{prefix}{name}")
    if (!(obj?.isValid() ?? false))
      continue

    let fillFunction = fillGamercardObjByKey?[name] ?? defaultFillGamercardObj
    fillFunction(obj, val, params)
  }

  if (!isGamercard)
    return

  
  let objBtn = getObj($"{prefix}userlog_btn")
  if (checkObj(objBtn)) {
    let newLogsCount = check_new_user_logs().len()
    let haveNew = newLogsCount > 0
    let tooltip = haveNew ?
      format(loc("userlog/new_messages"), newLogsCount) : loc("userlog/no_new_messages")
    updateGcButton(objBtn, haveNew, tooltip)
  }

  updateGamercardsChatInfo(prefix)

  let friendsOnline = getFriendsOnlineNum()
  let cObj = getObj($"{prefix}contacts")
  if (checkObj(cObj))
    cObj.tooltip = format(locByVendor("contacts/friends_online"), friendsOnline)

  let fObj = getObj($"{prefix}friends_online")
  if (checkObj(fObj))
    fObj.setValue(friendsOnline > 0 ? friendsOnline.tostring() : "")

  let totalText = []
  foreach (name in ["PremiumAccount", "RateWeek"]) {
    let expire = name == "PremiumAccount" ? getRemainingPremiumTime() : entitlement_expires_in(name)
    local text = loc("mainmenu/noPremium")
    local premPic = "#ui/gameuiskin#sub_premium_noactive.svg"
    if (expire > 0) {
      text = loc("ui/colon").concat(loc($"charServer/entitlement/{name}"), time.getExpireText(expire))
      totalText.append(text)
      premPic = "#ui/gameuiskin#sub_premiumaccount.svg"
    }
    let obj = getObj($"{prefix}{name}")
    if (obj && obj.isValid()) {
      let icoObj = obj.findObject("gc_prempic")
      if (checkObj(icoObj))
        icoObj["background-image"] = premPic
      obj.tooltip = text
    }
  }
  if (totalText.len() > 0) {
    let name = $"{prefix}subscriptions"
    let obj = getObj(name)
    if (obj && obj.isValid()) {
      obj.show(true)
      obj.tooltip = "\n".join(totalText)
    }
  }

  let queueTextObj = getObj("gc_queue_wait_text")
  updateShortQueueInfo(queueTextObj, queueTextObj, getObj("gc_queue_wait_icon"))

  let battlePassImgObj = getObj("gc_BattlePassProgressImg")
  if (battlePassImgObj?.isValid() ?? false)
    battlePassImgObj.setValue(stashBhvValueConfig([{
      watch = hasBattlePass
      updateFunc = @(obj, value) obj["background-saturate"] = value ? 1 : 0
  }]))

  let canSpendGold = hasFeature("SpendGold")
  let featureEnablePremiumPurchase = hasFeature("EnablePremiumPurchase")
  let is_in_menu = isInMenu.get()
  let skipNavigation = getObj("gamercard_div")?["gamercardSkipNavigation"] ?? "no"
  let showClanTag = (cfg?.clanTag ?? "") != ""

  let buttonsShowTable = {
    gc_clanTag = showClanTag
    gc_profile = true
    gc_contacts = true
    gc_chat_btn = hasMenuChat.get()
    gc_shop = is_in_menu && canSpendGold
    gc_eagles = canSpendGold
    gc_warpoints = true
    gc_PremiumAccount = hasFeature("showPremiumAccount")
      && ((canSpendGold && featureEnablePremiumPurchase) || havePremium.get())
    gc_BattlePassProgress = true
    gc_dropdown_premium_button = featureEnablePremiumPurchase
    gc_dropdown_shop_eagles_button = canSpendGold
    gc_free_exp = canSpendGold
    gc_items_shop_button = isItemsManagerEnabled() && isInMenu.get()
      && hasFeature("ItemsShop")
    gc_online_shop_button = hasFeature("OnlineShopPacks")
    gc_clanAlert = getUnseenCandidatesCount() > 0
    gc_invites_btn = !is_gdk || hasFeature("XboxCrossConsoleInteraction")
    gc_userlog_btn = true
    gc_manual_unlocks_unseen = is_in_menu
  }

  foreach (id, status in buttonsShowTable) {
    let bObj = getObj(id)
    if (checkObj(bObj)) {
      bObj.show(status)
      bObj.enable(status)
      bObj.inactive = status ? "no" : "yes"
      if (status)
        bObj["skip-navigation"] = skipNavigation
    }
  }

  let buttonsEnableTable = {
    gc_clanTag = showClanTag && is_in_menu
    gc_chat_btn = hasMenuChat.get() && isChatEnabled()
    gc_free_exp = canSpendGold && is_in_menu
    gc_warpoints = canSpendGold && is_in_menu
    gc_eagles = canSpendGold && is_in_menu
    gc_PremiumAccount = canSpendGold && featureEnablePremiumPurchase && is_in_menu
    gc_BattlePassProgress = canSpendGold && is_in_menu
  }

  foreach (id, status in buttonsEnableTable) {
    let pObj = getObj(id)
    if (checkObj(pObj)) {
      pObj.enable(status)
      pObj.inactive = status ? "no" : "yes"
    }
  }
  let squadWidgetObj = getObj("gamercard_squad_widget")
  if (squadWidgetObj?.isValid())
    squadWidgetObj["gamercardSkipNavigation"] = skipNavigation

  updateDiscountNotifications(scene)
  setVersionText(scene)
  serverMessageUpdateScene(scene)
  updateGcInvites(scene)
}

return freeze({
 fillGamercard
})
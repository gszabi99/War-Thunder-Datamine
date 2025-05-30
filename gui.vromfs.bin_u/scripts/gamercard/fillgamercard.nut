from "%scripts/dagui_natives.nut" import entitlement_expires_in
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let time = require("%scripts/time.nut")
let { getLastGamercardScene, addGamercardScene, updateGcInvites, updateGamercardsChatInfo,
  updateGcButton } = require("%scripts/gamercard/gamercardHelpers.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { getProfileInfo, getCurExpTable } = require("%scripts/user/userInfoStats.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")
let { checkClanTagForDirtyWords } = require("%scripts/clans/clanTextInfo.nut")
let { Balance, Cost } = require("%scripts/money.nut")
let { haveActiveBonusesByEffectType, getCurrentBonusesText
} = require("%scripts/items/boosterEffect.nut")
let { boosterEffectType } = require("%scripts/items/boosterEffectTypes.nut")
let { getCustomNick } = require("%scripts/contacts/customNicknames.nut")
let { getPlayerName } = require("%scripts/user/remapNick.nut")
let { check_new_user_logs } = require("%scripts/userLog/userlogUtils.nut")
let { getFriendsOnlineNum } = require("%scripts/contacts/contactsInfo.nut")
let { format } = require("string")
let { getRemainingPremiumTime, havePremium } = require("%scripts/user/premium.nut")
let { updateShortQueueInfo } = require("%scripts/queue/queueInfo/qiViewUtils.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { isChatEnabled, hasMenuChat } = require("%scripts/chat/chatStates.nut")
let { isItemsManagerEnabled } = require("%scripts/items/itemsManager.nut")
let { getUnseenCandidatesCount } = require("%scripts/clans/clanCandidates.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { serverMessageUpdateScene } = require("%scripts/hud/serverMessages.nut")
let updateDiscountNotifications = require("%scripts/discounts/updateDiscountNotifications.nut")
let { hasBattlePass } = require("%scripts/battlePass/unlocksRewardsState.nut")

function fillGamercard(cfg = null, prefix = "gc_", scene = null, save_scene = true) {
  if (!checkObj(scene)) {
    scene = getLastGamercardScene()
    if (!scene)
      return
  }
  let isGamercard = prefix == "gc_"
  let isShowGamercard = isLoggedIn.get()
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
  local showClanTag = false
  foreach (name, val in cfg) {
    let obj = getObj($"{prefix}{name}")
    if (checkObj(obj)) {
      if (name == "frame") {
        obj.show(val != "")
        if (val != "")
          obj["background-image"] = $"!ui/images/avatar_frames/{val}.avif"
      }
      if (name == "country")
        obj["background-image"] = getCountryIcon(val)
      else if (name == "rankProgress") {
        let value = val.tointeger()
        let isProgressVisible = !isGamercard || value >= 0
        if (isProgressVisible)
          obj.setValue(value != -1 ? value : 1000)
        obj.show(isProgressVisible)

        let expTable = getCurExpTable(cfg)
        obj.tooltip = expTable
          ? nbsp.concat(decimalFormat(expTable.exp), "/", decimalFormat(expTable.rankExp))
          : "".concat(loc("ugm/total"), loc("ui/colon"), decimalFormat(cfg.exp))
      }
      else if (name ==  "prestige") {
        if (val != null)
          obj["background-image"] = $"#ui/gameuiskin#prestige{val}"
        let titleObj = getObj($"{prefix}prestige_title")
        if (titleObj) {
          let prestigeTitle = (val ?? 0) > 0 ? loc($"rank/prestige{val}") : ""
          titleObj.setValue(prestigeTitle)
        }
      }
      else if (name == "exp") {
        let expTable = getCurExpTable(cfg)
        obj.setValue(expTable
          ? nbsp.concat(decimalFormat(expTable.exp), "/", decimalFormat(expTable.rankExp))
          : "")
        obj.tooltip = "".concat(loc("ugm/total"), loc("ui/colon"), decimalFormat(cfg.exp))
      }
      else if (name == "clanTag") {
        showClanTag = hasFeature("Clans") && val != ""
        let clanTagName = checkClanTagForDirtyWords(val.tostring())
        let btnText = obj.findObject($"{prefix}{name}_name")
        if (checkObj(btnText))
          btnText.setValue(clanTagName)
        else
          obj.setValue(clanTagName)
      }
      else if (name == "gold") {
        let moneyInst = Cost(0, val)
        let valStr = moneyInst.toStringWithParams({ isGoldAlwaysShown = true })

        let tooltipText = "\n".concat(colorize("activeTextColor", valStr), loc("mainmenu/gold"))
        obj.getParent().tooltip = tooltipText

        obj.setValue(moneyInst.toStringWithParams({ isGoldAlwaysShown = true, needIcon = false }))
      }
      else if (name == "balance") {
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
      else if (name == "free_exp") {
        let valStr = Balance(0, 0, val).toStringWithParams({ isFrpAlwaysShown = true })
        let tooltipText = "\n".concat(colorize("activeTextColor", valStr),
          loc("currency/freeResearchPoints/desc"),
          getCurrentBonusesText(boosterEffectType.RP))

        obj.tooltip = tooltipText
        obj.showBonusCommon = haveActiveBonusesByEffectType(boosterEffectType.RP, false) ? "yes" : "no"
        obj.showBonusPersonal = haveActiveBonusesByEffectType(boosterEffectType.RP, true) ? "yes" : "no"
      }
      else if (name == "name") {
        local valStr
        if (u.isEmpty(val))
          valStr = loc("mainmenu/pleaseSignIn")
        else {
          let customNick = getCustomNick(cfg)
          valStr = customNick == null ? getPlayerName(val)
            : $"{getPlayerName(val)}{loc("ui/parentheses/space", { text = customNick })}"
        }
        obj.setValue(valStr)
      }
      else
        obj.setValue((val ?? "").tostring())
    }
  }

  if (!isGamercard)
    return

  
  if (hasFeature("UserLog")) {
    let objBtn = getObj($"{prefix}userlog_btn")
    if (checkObj(objBtn)) {
      let newLogsCount = check_new_user_logs().len()
      let haveNew = newLogsCount > 0
      let tooltip = haveNew ?
        format(loc("userlog/new_messages"), newLogsCount) : loc("userlog/no_new_messages")
      updateGcButton(objBtn, haveNew, tooltip)
    }
  }

  updateGamercardsChatInfo(prefix)

  if (hasFeature("Friends")) {
    let friendsOnline = getFriendsOnlineNum()
    let cObj = getObj($"{prefix}contacts")
    if (checkObj(cObj))
      cObj.tooltip = format(loc("contacts/friends_online"), friendsOnline)

    let fObj = getObj($"{prefix}friends_online")
    if (checkObj(fObj))
      fObj.setValue(friendsOnline > 0 ? friendsOnline.tostring() : "")
  }

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
  let canHaveFriends = hasFeature("Friends")
  let is_in_menu = isInMenu.get()
  let skipNavigation = getObj("gamercard_div")?["gamercardSkipNavigation"] ?? "no"

  let buttonsShowTable = {
    gc_clanTag = showClanTag
    gc_profile = true
    gc_contacts = canHaveFriends
    gc_chat_btn = hasMenuChat.value
    gc_shop = is_in_menu && canSpendGold
    gc_eagles = canSpendGold
    gc_warpoints = hasFeature("WarpointsInMenu")
    gc_PremiumAccount = hasFeature("showPremiumAccount")
      && ((canSpendGold && featureEnablePremiumPurchase) || havePremium.get())
    gc_BattlePassProgress = true
    gc_dropdown_premium_button = featureEnablePremiumPurchase
    gc_dropdown_shop_eagles_button = canSpendGold
    gc_free_exp = hasFeature("SpendGold")
    gc_items_shop_button = isItemsManagerEnabled() && isInMenu.get()
      && hasFeature("ItemsShop")
    gc_online_shop_button = hasFeature("OnlineShopPacks")
    gc_clanAlert = hasFeature("Clans") && getUnseenCandidatesCount() > 0
    gc_invites_btn = !is_gdk || hasFeature("XboxCrossConsoleInteraction")
    gc_userlog_btn = hasFeature("UserLog")
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
    gc_contacts = canHaveFriends
    gc_chat_btn = hasMenuChat.value && isChatEnabled()
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

return {
 fillGamercard
}
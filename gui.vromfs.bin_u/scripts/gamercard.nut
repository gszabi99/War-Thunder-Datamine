//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let { money_type, Money, Balance } = require("%scripts/money.nut")
let { format } = require("string")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let time = require("%scripts/time.nut")
let platformModule = require("%scripts/clientState/platform.nut")
let { isChatEnabled, hasMenuChat } = require("%scripts/chat/chatStates.nut")
let showTitleLogo = require("%scripts/viewUtils/showTitleLogo.nut")
let { setVersionText } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { hasBattlePass } = require("%scripts/battlePass/unlocksRewardsState.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { boosterEffectType, haveActiveBonusesByEffectType } = require("%scripts/items/boosterEffect.nut")
let globalCallbacks = require("%sqDagui/globalCallbacks/globalCallbacks.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")

::fill_gamer_card <- function fill_gamer_card(cfg = null, prefix = "gc_", scene = null, save_scene = true) {
  if (!checkObj(scene)) {
    scene = ::getLastGamercardScene()
    if (!scene)
      return
  }
  let isGamercard = prefix == "gc_"
  let isShowGamercard = ::g_login.isLoggedIn()
  let div = showObjById("gamercard_div", isShowGamercard, scene)
  let isValidGamercard = checkObj(div)
  if (isGamercard && !isValidGamercard)
    return

  if (isValidGamercard)
    showTitleLogo(div)

  if (scene && save_scene && isGamercard && isValidGamercard)
    ::add_gamercard_scene(scene)

  if (!isShowGamercard)
    return

  if (!cfg)
    cfg = ::get_profile_info()

  let getObj = @(id) scene.findObject(id)
  local showClanTag = false
  foreach (name, val in cfg) {
    let obj = getObj($"{prefix}{name}")
    if (checkObj(obj))
      switch (name) {
        case "country":
          obj["background-image"] = ::get_country_icon(val)
          break
        case "rankProgress":
          let value = val.tointeger()
          if (value >= 0)
            obj.setValue(val.tointeger())
          obj.show(value >= 0)
          break
        case "prestige":
          if (val != null)
            obj["background-image"] = $"#ui/gameuiskin#prestige{val}"
          let titleObj = getObj($"{prefix}prestige_title")
          if (titleObj) {
            let prestigeTitle = (val > 0)
                                  ? loc($"rank/prestige{val}")
                                  : ""
            titleObj.setValue(prestigeTitle)
          }
          break
        case "exp":
          let expTable = ::get_cur_exp_table("", cfg)
          obj.setValue(expTable
            ? ::nbsp.concat(decimalFormat(expTable.exp), "/", decimalFormat(expTable.rankExp))
            : "")
          obj.tooltip = "".concat(loc("ugm/total"), loc("ui/colon"), decimalFormat(cfg.exp))
          break
        case "clanTag":
          let isVisible = hasFeature("Clans") && val != ""
          showClanTag = isVisible
          if (isVisible) {
            let clanTagName = ::checkClanTagForDirtyWords(val.tostring())
            let btnText = obj.findObject($"{prefix}{name}_name")
            if (checkObj(btnText))
              btnText.setValue(clanTagName)
            else
              obj.setValue(clanTagName)
          }
          break
        case "gold":
          let moneyInst = Money(money_type.none, 0, val)
          let valStr = moneyInst.toStringWithParams({ isGoldAlwaysShown = true })

          let tooltipText = "\n".concat(colorize("activeTextColor", valStr), loc("mainmenu/gold"))
          obj.getParent().tooltip = tooltipText

          obj.setValue(moneyInst.toStringWithParams({ isGoldAlwaysShown = true, needIcon = false }))
          break
        case "balance":
          let valStr = decimalFormat(val)
          let tooltipText = "\n".concat(::getWpPriceText(colorize("activeTextColor", valStr), true),
            loc("mainmenu/warpoints"),
            ::get_current_bonuses_text(boosterEffectType.WP))

          let buttonObj = obj.getParent()
          buttonObj.tooltip = tooltipText
          buttonObj.showBonusCommon = haveActiveBonusesByEffectType(boosterEffectType.WP, false) ? "yes" : "no"
          buttonObj.showBonusPersonal = haveActiveBonusesByEffectType(boosterEffectType.WP, true) ? "yes" : "no"

          obj.setValue(valStr)
          break
        case "free_exp":
          let valStr = Balance(0, 0, val).toStringWithParams({ isFrpAlwaysShown = true })
          let tooltipText = "\n".concat(colorize("activeTextColor", valStr),
            loc("currency/freeResearchPoints/desc"),
            ::get_current_bonuses_text(boosterEffectType.RP))

          obj.tooltip = tooltipText
          obj.showBonusCommon = haveActiveBonusesByEffectType(boosterEffectType.RP, false) ? "yes" : "no"
          obj.showBonusPersonal = haveActiveBonusesByEffectType(boosterEffectType.RP, true) ? "yes" : "no"
          break
        case "name":
          local valStr
          if (u.isEmpty(val))
            valStr = loc("mainmenu/pleaseSignIn")
          else
            valStr = platformModule.getPlayerName(val)
          obj.setValue(valStr)
          break
        default:
          obj.setValue((val ?? "").tostring())
      }
  }

  if (!isGamercard)
    return

  //checklogs
  if (hasFeature("UserLog")) {
    let objBtn = getObj($"{prefix}userlog_btn")
    if (checkObj(objBtn)) {
      let newLogsCount = ::check_new_user_logs().len()
      let haveNew = newLogsCount > 0
      let tooltip = haveNew ?
        format(loc("userlog/new_messages"), newLogsCount) : loc("userlog/no_new_messages")
      ::update_gc_button(objBtn, haveNew, tooltip)
    }
  }

  ::update_gamercards_chat_info(prefix)

  if (hasFeature("Friends")) {
    let friendsOnline = ::getFriendsOnlineNum()
    let cObj = getObj($"{prefix}contacts")
    if (checkObj(cObj))
      cObj.tooltip = format(loc("contacts/friends_online"), friendsOnline)

    let fObj = getObj($"{prefix}friends_online")
    if (checkObj(fObj))
      fObj.setValue(friendsOnline > 0 ? friendsOnline.tostring() : "")
  }

  let totalText = []
  let premAccName = ::shop_get_premium_account_ent_name()
  foreach (name in ["PremiumAccount", "RateWeek"]) {
    local entName = name
    if (entName == "PremiumAccount")
      entName = premAccName
    let expire = ::entitlement_expires_in(entName)
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
  ::g_qi_view_utils.updateShortQueueInfo(queueTextObj, queueTextObj, getObj("gc_queue_wait_icon"))

  let battlePassImgObj = getObj("gc_BattlePassProgressImg")
  if (battlePassImgObj?.isValid() ?? false)
    battlePassImgObj.setValue(stashBhvValueConfig([{
      watch = hasBattlePass
      updateFunc = @(obj, value) obj["background-saturate"] = value ? 1 : 0
  }]))

  let canSpendGold = hasFeature("SpendGold")
  let featureEnablePremiumPurchase = hasFeature("EnablePremiumPurchase")
  let canHaveFriends = hasFeature("Friends")
  let is_in_menu = ::isInMenu()
  let skipNavigation = getObj("gamercard_div")?["gamercardSkipNavigation"] ?? "no"

  let hasPremiumAccount = ::entitlement_expires_in(premAccName) > 0

  let buttonsShowTable = {
    gc_clanTag = showClanTag
    gc_profile = true
    gc_contacts = canHaveFriends
    gc_chat_btn = hasMenuChat.value
    gc_shop = is_in_menu && canSpendGold
    gc_eagles = canSpendGold
    gc_warpoints = hasFeature("WarpointsInMenu")
    gc_PremiumAccount = hasFeature("showPremiumAccount")
      && ((canSpendGold && featureEnablePremiumPurchase) || hasPremiumAccount)
    gc_BattlePassProgress = hasFeature("BattlePass")
    gc_dropdown_premium_button = featureEnablePremiumPurchase
    gc_dropdown_shop_eagles_button = canSpendGold
    gc_free_exp = hasFeature("SpendGold")
    gc_items_shop_button = ::ItemsManager.isEnabled() && ::isInMenu()
      && hasFeature("ItemsShop")
    gc_online_shop_button = hasFeature("OnlineShopPacks")
    gc_clanAlert = hasFeature("Clans") && ::g_clans.getUnseenCandidatesCount() > 0
    gc_invites_btn = !is_platform_xbox || hasFeature("XboxCrossConsoleInteraction")
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

  ::g_discount.updateDiscountNotifications(scene)
  setVersionText(scene)
  ::server_message_update_scene(scene)
  ::update_gc_invites(scene)
}

::update_gamercards <- function update_gamercards() {
  let info = ::get_profile_info()
  local needUpdateGamerCard = false
  for (local idx = ::last_gamercard_scenes.len() - 1; idx >= 0; idx--) {
    let s = ::last_gamercard_scenes[idx]
    if (!s || !s.isValid())
      ::last_gamercard_scenes.remove(idx)
    else if (s.isVisible()) {
      needUpdateGamerCard = true
      ::fill_gamer_card(info, "gc_", s, false)
    }
  }
  if (!needUpdateGamerCard)
    return

  ::checkNewNotificationUserlogs()
  broadcastEvent("UpdateGamercard")
}

::do_with_all_gamercards <- function do_with_all_gamercards(func) {
  foreach (scene in ::last_gamercard_scenes)
    if (checkObj(scene))
      func(scene)
}

::last_gamercard_scenes <- []
::add_gamercard_scene <- function add_gamercard_scene(scene) {
  for (local idx = ::last_gamercard_scenes.len() - 1; idx >= 0; idx--) {
    let s = ::last_gamercard_scenes[idx]
    if (!checkObj(s))
      ::last_gamercard_scenes.remove(idx)
    else if (s.isEqual(scene))
      return
  }
  ::last_gamercard_scenes.append(scene)
}

::set_last_gc_scene_if_exist <- function set_last_gc_scene_if_exist(scene) {
  foreach (idx, gcs in ::last_gamercard_scenes)
    if (checkObj(gcs) && scene.isEqual(gcs)
        && idx < ::last_gamercard_scenes.len() - 1) {
      ::last_gamercard_scenes.remove(idx)
      ::last_gamercard_scenes.append(scene)
      break
    }
}

::getLastGamercardScene <- function getLastGamercardScene() {
  if (::last_gamercard_scenes.len() > 0)
    for (local i = ::last_gamercard_scenes.len() - 1; i >= 0; i--)
      if (checkObj(::last_gamercard_scenes[i]))
        return ::last_gamercard_scenes[i]
      else
        ::last_gamercard_scenes.remove(i)
  return null
}

::update_gc_invites <- function update_gc_invites(scene) {
  let haveNew = ::g_invites.newInvitesAmount > 0
  ::update_gc_button(scene.findObject("gc_invites_btn"), haveNew)
}

::update_gc_button <- function update_gc_button(obj, isNew, tooltip = null) {
  if (!checkObj(obj))
    return

  if (tooltip)
    obj.tooltip = tooltip

  showObjectsByTable(obj, {
    icon    = !isNew
    iconNew = isNew
  })

  let objGlow = obj.findObject("iconGlow")
  if (checkObj(objGlow))
    objGlow.wink = isNew ? "yes" : "no"
}

::get_active_gc_popup_nest_obj <- function get_active_gc_popup_nest_obj() {
  let gcScene = ::getLastGamercardScene()
  let nestObj = gcScene ? gcScene.findObject("chatPopupNest") : null
  return checkObj(nestObj) ? nestObj : null
}

::update_clan_alert_icon <- function update_clan_alert_icon() {
  let needAlert = hasFeature("Clans") && ::g_clans.getUnseenCandidatesCount() > 0
  ::do_with_all_gamercards(function(scene) {
      showObjById("gc_clanAlert", needAlert, scene)
    })
}

::update_gamercards_chat_info <- function update_gamercards_chat_info(prefix = "gc_") {
  if (!::gchat_is_enabled() || !hasMenuChat.value)
    return

  let haveNew = ::g_chat.haveNewMessages()
  let tooltip = loc(haveNew ? "mainmenu/chat_new_messages" : "mainmenu/chat")

  let newMessagesCount = ::g_chat.getNewMessagesCount()
  let newMessagesText = newMessagesCount ? newMessagesCount.tostring() : ""

  ::do_with_all_gamercards(function(scene) {
    let objBtn = scene.findObject($"{prefix}chat_btn")
    if (!checkObj(objBtn))
      return

    ::update_gc_button(objBtn, haveNew, tooltip)
    let newCountChatObj = objBtn.findObject($"{prefix}new_chat_messages")
    newCountChatObj.setValue(newMessagesText)
  })
}

let function updateGamercardChatButton() {
  let canChat = ::gchat_is_enabled() && hasMenuChat.value
  ::do_with_all_gamercards(@(scene) showObjById("gc_chat_btn", canChat, scene))
}

hasMenuChat.subscribe(@(_) updateGamercardChatButton())

globalCallbacks.addTypes({
  onOpenGameModeSelect = {
    onCb = @(_obj, _params) broadcastEvent("OpenGameModeSelect")
  }
})

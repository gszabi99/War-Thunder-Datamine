from "%scripts/dagui_natives.nut" import wp_get_cost_gold
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { show_obj } = require("%sqDagui/daguiUtil.nut")
let DataBlock = require("DataBlock")
let { charSendBlk, get_charserver_time_sec } = require("chard")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { placePriceTextToButton, warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { format }  = require("string")
let { utf8ToUpper } = require("%sqstd/string.nut")
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitRoleIcon, getFullUnitRoleText, getUnitClassColor } = require("%scripts/unit/unitInfoRoles.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { buidPartialTimeStr } = require("%appGlobals/timeLoc.nut")
let { curPersonalOffer, cachePersonalOfferIfNeed, markSeenPersonalOffer,
  isSeenOffer, clearOfferCache
} = require("%scripts/user/personalOffersStates.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let prizesRewardWnd = require("%scripts/items/prizesRewardWnd.nut")
let { performPromoAction, togglePromoItem } = require("%scripts/promo/promo.nut")
let { getUnlockCost } = require("%scripts/unlocks/unlocksModule.nut")
let { convertBlk, copyParamsToTable } = require("%sqstd/datablock.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { getTypeByResourceType } = require("%scripts/customization/types.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { addTask } = require("%scripts/tasker.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { getWarpointsGoldCost, getEntitlementShortName, getEntitlementConfig, getEntitlementFullTimeText,
  getEntitlementLocParams
} = require("%scripts/onlineShop/entitlements.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { hasInWishlist } = require("%scripts/wishlist/wishlistManager.nut")
let { getPrizeActionButtonsView, getPrizeImageByConfig, getTrophyRewardText
} = require("%scripts/items/prizesView.nut")
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getTrophyRewardType, isRewardItem } = require("%scripts/items/trophyReward.nut")

function getEntitlementTimeForDesc(config) {
  let ent = getEntitlementConfig(config.entitlement)
  return ent == null ? "" : utf8ToUpper(getEntitlementFullTimeText(ent))
}

let premiumAccountDescriptionArr = [
  "charServer/entitlement/PremiumAccount/desc/string_2"
  "charServer/entitlement/PremiumAccount/desc/string_3"
  "charServer/entitlement/PremiumAccount/desc/string_4"
  "charServer/entitlement/PremiumAccount/desc/string_5"
]

let personalOfferWndStyles = {
  premium_account = {
    function fillOfferBody(obj, offerBlk) {
      let entitlementPrize = (offerBlk % "i").findvalue(@(v) "entitlement" in v)
      let paramTbl =  getEntitlementLocParams().map(@(v) colorize("userlogColoredText", v))
      let data = handyman.renderCached("%gui/profile/premiumOfferBody.tpl", {
        title = utf8ToUpper(loc("charServer/entitlement/PremiumAccount"))
        premiumTime = entitlementPrize != null ? getEntitlementTimeForDesc(entitlementPrize) : ""
        premiumDescription = "\n".join(premiumAccountDescriptionArr.map(@(v) loc(v, paramTbl)))
      })
      this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    }
    function updateHeader(headerObj) {
      headerObj["background-image"] = "!ui/images/premium/premium_account_image"
      let imgForParts = "!ui/images/premium/premium_account_header"
      let partLeftImgObj = headerObj.findObject("header_image_left")
      partLeftImgObj.width = "304@sf/@pf"
      partLeftImgObj["background-image"] = imgForParts
      partLeftImgObj["background-position"] = "0, 0, 620, 0"

      let partCenterImgObj = headerObj.findObject("header_image_center")
      partCenterImgObj["min-width"] = "158@sf/@pf"
      partCenterImgObj["background-image"] = imgForParts
      partCenterImgObj["background-position"] = "380, 0, 500, 0"

      let partRightImgObj = headerObj.findObject("header_image_right")
      partRightImgObj.width = "400@sf/@pf"
      partRightImgObj["background-image"] = imgForParts

      headerObj.findObject("limited_text")["margin-left"] = "130@sf/@pf"
      headerObj.findObject("personal_text")["margin-left"] = "130@sf/@pf"
      headerObj.findObject("time_expired_text")["margin-top"] = "40@sf/@pf - h"
      headerObj.findObject("time_expired_value")["margin-left"] = "pw - 165@sf/@pf - w/2"
    }
  }
}

let offerTypes = {
  unit = @(_c) loc("shop/section/premium")
  unlock = @(_c) loc("trophy/unlockables_names/achievement")
  gold = @(_c) loc("charServer/chapter/eagles")
  premium_in_hours = @(_c) loc("charServer/entitlement/PremiumAccount")
  item = @(_c) loc("item")
  entitlement = @(c) getEntitlementShortName(getEntitlementConfig(c.entitlement))
}

let descriptionByOfferType = {
  entitlement = getEntitlementTimeForDesc
}

let class PersonalOfferHandler (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/profile/personalOfferWnd.blk"

  offerName = ""
  timeExpired = -1
  offerBlk = null
  costGold = null
  groups = null

  function initScreen() {
    if (this.timeExpired > 0) {
      this.updateTimeLeftText()
      this.scene.findObject("update_timer").setUserData(this)
    }
    this.costGold = Cost(0, this.offerBlk.costGold)
    this.updateHeader()
    this.updateButtons()
    this.fillBody()
  }

  function updateHeader() {
    let { offerType = "" } = this.offerBlk
    personalOfferWndStyles?[offerType].updateHeader(this.scene.findObject("offer_image"))

    let maxTextWidthNoResize = to_pixels("290@sf/@pf")
    this.guiScene.applyPendingChanges(false)
    let personalTextSize = this.scene.findObject("personal_text").getSize()
    this.scene.findObject("header_image_center")["width"] = max(0, personalTextSize[0] - maxTextWidthNoResize)
  }

  getGroupTitle = @(offerType, config) offerTypes?[offerType](config) ?? loc($"trophy/unlockables_names/{offerType}", "")

  function prepareRewardsData() {
    this.groups = []
    let discount = this.offerBlk?.discountValue ?? 0
    foreach(config in (this.offerBlk % "i")) {
      local firstInBlock = false

      let localConfig = copyParamsToTable(config)
      let button = getPrizeActionButtonsView(localConfig, { shopDesc = true })
      local offerType = getTrophyRewardType(localConfig)
      offerType = offerType != "resourceType" ? offerType : localConfig.resourceType
      local group = this.groups.findvalue(@(value) value?.type == offerType)
      if(group == null) {
        group = {
          type = offerType
          title = this.getGroupTitle(offerType, localConfig)
          items = []
          units = []
          needSeparator =  this.groups.len() > 0
        }
        this.groups.append(group)
        firstInBlock = true
      }

      let count = localConfig?.count ?? 1
      localConfig.count <- count
      localConfig.hideCount <- true
      let itemData = {
        description = descriptionByOfferType?[offerType](localConfig)
          ?? getTrophyRewardText(localConfig, false, "#FFFFFF")
        count = count > 1 ? $"x{count}" : ""
        firstInBlock
      }

      if(offerType != "unit") {
        itemData.image <- getPrizeImageByConfig(localConfig, !isRewardItem(offerType), "", true)
        itemData.canPreview <- false
        if(button.len() > 0) {
          itemData.btnTooltip <- button[0].tooltip
          itemData.funcName <- button[0].funcName
          itemData.actionParamsMarkup <- button[0].actionParamsMarkup
          itemData.canPreview = true
        }
        group.items.append(itemData)
      }
      else {
        let unit = getAircraftByName(localConfig.unit)
        itemData.unitFullName <- getUnitName(unit, true)
        itemData.image <- getUnitTooltipImage(unit)
        itemData.tooltipId <- getTooltipType("UNIT").getTooltipId(localConfig.unit)
        itemData.inWishlist <- hasInWishlist(localConfig.unit)
        itemData.countryIco <- getUnitCountryIcon(unit, false)
        let fonticon = getUnitRoleIcon(unit)
        let typeText = getFullUnitRoleText(unit)
        itemData.unitType <- colorize(getUnitClassColor(unit), $"{typeText} {fonticon}")
        itemData.br <- format("%.1f", unit.getBattleRating(getCurrentGameModeEdiff()))
        itemData.unitRank <- "".concat(loc("shop/age"), loc("ui/colon"), get_roman_numeral(unit.rank))
        itemData.btnTooltip <- button[0].tooltip
        itemData.funcName <- button[0].funcName
        itemData.actionParamsMarkup <- button[0].actionParamsMarkup
        group.units.append(itemData)
      }
      itemData.cost <- this.getCost(offerType, localConfig)
      itemData.discountCost <- Cost().setGold(itemData.cost.gold).multiply(1 - 1.0 * discount / 100)
    }
  }

  function getCost(offerType, localConfig) {
    if ("costGold" in localConfig) 
      return Cost(0, localConfig.costGold)

    if(offerType == "unit") {
      let unit = getAircraftByName(localConfig.unit)
      return Cost().setGold(unit?.costGold ?? 0) 
    }
    if(offerType == "item") {
      let item = findItemById(localConfig.item)
      if(item != null)
        return item.getCost().multiply(localConfig.count)
      return Cost()
    }
    if (offerType == "unlock")
      return getUnlockCost(localConfig.unlock).multiply(localConfig.count)
    if ("resourceType" in localConfig) {
      let decType = getTypeByResourceType(localConfig.resourceType)
      let decorator = getDecorator(localConfig.resource, decType)
      return decType.getCost(decorator).multiply(localConfig.count)
    }
    if(offerType == "warpoints")
      return getWarpointsGoldCost(localConfig.warpoints).multiply(localConfig.count)
    return Cost()
  }

  function fillBody() {
    let { offerType = "" } = this.offerBlk
    let { fillOfferBody = null } = personalOfferWndStyles?[offerType]
    if (fillOfferBody != null) {
      fillOfferBody(this.scene.findObject("offer_markup"), this.offerBlk)
      return
    }
    this.updateRewards()
  }

  function updateRewards() {
    this.prepareRewardsData()
    let data = handyman.renderCached("%gui/profile/offerItem.tpl", { offers = this.groups })
    let nest = this.scene.findObject("offer_markup")
    this.guiScene.replaceContentFromText(nest, data, data.len(), this)
  }

  function updateButtons() {
    let { fullCostGold = 0 } = this.offerBlk
    placePriceTextToButton(this.scene, "btn_buy", loc("mainmenu/btnBuy"),
      this.costGold, 0, fullCostGold > 0 ? Cost(0, fullCostGold) : null,
      { textColor = "buttonFontColorPurchase", priceTextColor = "buttonFontColorPurchase" })
  }

  function updateTimeLeftText() {
    let timeLeftSec = this.timeExpired - get_charserver_time_sec()
    let timeExpiredObj = showObjById("time_expired_value", timeLeftSec > 0, this.scene)
    showObjById("time_expired_text", timeLeftSec > 0, this.scene)
    if (timeLeftSec <= 0)
      return

    let timeString = buidPartialTimeStr(timeLeftSec)
    if(getStringWidthPx(timeString, "fontMedium", this.guiScene) > to_pixels("110@sf/@pf"))
      timeExpiredObj["mediumFont"] = "no"
    timeExpiredObj.setValue(timeString)
  }

  function onBuyImpl() {
    let blk = DataBlock()
    blk.addStr("offer", this.offerName)
    let taskId = charSendBlk("cln_buy_personal_offer", blk)
    let cb = Callback(function() {
      clearOfferCache()
      this.goBack()
      prizesRewardWnd({ configsArray = (this.offerBlk % "i").map(@(v) convertBlk(v)) })
    }, this)
    addTask(taskId, { showProgressBox = true }, cb)
  }

  function onBuy() {
    let msgText = warningIfGold(
      loc("onlineShop/needMoneyQuestion", {
          purchase = loc("specialOffer"),
          cost = this.costGold.getTextAccordingToBalance()
        }),
        this.costGold)
    purchaseConfirmation("purchase_ask", msgText, Callback(function() {
      if (checkBalanceMsgBox(this.costGold))
        this.onBuyImpl()
    }, this))
  }

  function onTimer(_obj, _dt) {
    this.updateTimeLeftText()
  }

  function getHandlerRestoreData() {
    let data = {
      openData = {
        offerName = this.offerName
        timeExpired = this.timeExpired
        offerBlk = this.offerBlk
      }
      stateData = {
      }
    }
    return data
  }

  function onEventBeforeStartShowroom(_p) {
    markSeenPersonalOffer(this.offerName)
    handlersManager.requestHandlerRestore(this, gui_handlers.MainMenu)
  }

  function goBack() {
    markSeenPersonalOffer(this.offerName)
    base.goBack()
  }
}

let PersonalOfferPromoHandler = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/promo/promoPersonalOffer.blk"

  timeExpired = 0

  function initScreen() {
    this.scene.findObject("perform_action_personal_offer_mainmenu_button").setValue(
      stashBhvValueConfig({
        watch = curPersonalOffer
        updateFunc = Callback(@(_obj, offer) this.updateHandler(offer), this)
      }))
  }

  function updateTimeLeftText() {
    let timeLeftSec = this.timeExpired - get_charserver_time_sec()
    let timeExpiredObj = showObjById("time_expired_value", timeLeftSec > 0, this.scene)
    showObjById("time_expired_text", timeLeftSec > 0, this.scene)
    if (timeLeftSec <= 0)
      return

    let timeString = buidPartialTimeStr(timeLeftSec)
    timeExpiredObj.setValue(timeString)
  }

  function onTimer(_obj, _dt) {
    this.updateTimeLeftText()
  }

  function updateHandler(offer) {
    let isVisible = offer != null
    show_obj(this.scene, isVisible)
    this.scene.findObject("update_timer").setUserData(isVisible ? this : null)
    if (!isVisible)
      return

    this.timeExpired = offer.timeExpired
    this.updateTimeLeftText()
  }

  onToggleItem = @(obj) togglePromoItem(obj)

  function performAction(obj) { performPromoAction(this, obj) }
  function performActionCollapsed() {
    if (this.isValid())
      performPromoAction(this, this.scene.findObject("perform_action_personal_offer_mainmenu_button"))
  }
}

let openCurPersonalOfferWnd = @()
  handlersManager.loadHandler(PersonalOfferHandler, curPersonalOffer.get())

function checkShowPersonalOffers() {
  cachePersonalOfferIfNeed()
  if (curPersonalOffer.get() != null && !isSeenOffer(curPersonalOffer.get().offerName))
    openCurPersonalOfferWnd()
}

gui_handlers.PersonalOfferHandler <- PersonalOfferHandler
gui_handlers.PersonalOfferPromoHandler <- PersonalOfferPromoHandler

addPromoAction("personal_offer", @(_handler, _params, _obj) openCurPersonalOfferWnd())

let promoButtonId = "personal_offer_mainmenu_button"

addPromoButtonConfig({
  promoButtonId = promoButtonId
  buttonType = "imageButton"
  function updateFunctionInHandler() {
    let handlerWeak = handlersManager.loadHandler(PersonalOfferPromoHandler,
      { scene = this.scene.findObject(promoButtonId) })
    this.owner.registerSubHandler(handlerWeak)
  }
})

return {
  checkShowPersonalOffers
}
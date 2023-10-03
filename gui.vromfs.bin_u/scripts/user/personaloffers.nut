//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { show_obj } = require("%sqDagui/daguiUtil.nut")
let DataBlock = require("DataBlock")
let { charSendBlk, get_charserver_time_sec } = require("chard")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { format }  = require("string")
let { getUnitRoleIcon, getFullUnitRoleText } = require("%scripts/unit/unitInfoTexts.nut")
let { getStringWidthPx } = require("%scripts/viewUtils/daguiFonts.nut")
let { buidPartialTimeStr } = require("%appGlobals/timeLoc.nut")
let { curPersonalOffer, cachePersonalOfferIfNeed, markSeenPersonalOffer,
  isSeenOffer, clearOfferCache
} = require("%scripts/user/personalOffersStates.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { addPromoButtonConfig } = require("%scripts/promo/promoButtonsConfig.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let prizesRewardWnd = require("%scripts/items/prizesRewardWnd.nut")
let { performPromoAction } = require("%scripts/promo/promo.nut")
let { getUnlockCost } = require("%scripts/unlocks/unlocksModule.nut")
let { convertBlk, copyParamsToTable } = require("%sqstd/datablock.nut")
let { getUnitName, getUnitCountryIcon } = require("%scripts/unit/unitInfo.nut")
let { getTypeByResourceType } = require("%scripts/customization/types.nut")

let offerTypes = {
  unit = "shop/section/premium"
  unlock = "trophy/unlockables_names/achievement"
  gold = "charServer/chapter/eagles"
  premium_in_hours = "charServer/entitlement/PremiumAccount"
  item = "item"
}

let class PersonalOfferHandler extends gui_handlers.BaseGuiHandlerWT {
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
    this.updateDiscount()
    this.updateImages()
    this.updateButtons()
    this.prepareRewardsData()
    this.updateRewards()
    this.updateTotalAmount()
  }

  function updateDiscount() {
    let { discountValue = 0 } = this.offerBlk
    this.scene.findObject("exclusive_price_value_text").setValue(this.costGold.tostring())
    if (discountValue > 0)
      this.scene.findObject("discount_value_text").setValue($"{discountValue.tostring()}%")
  }

  function updateTotalAmount() {
    let { fullCostGold = 0 } = this.offerBlk
    if (fullCostGold > 0)
      this.scene.findObject("total_amount_value").setValue(Cost().setGold(fullCostGold).tostring())
  }

  function updateImages() {
    let maxTextWidthNoResize = to_pixels("290@sf/@pf")
    this.guiScene.applyPendingChanges(false)
    let personalTextSize = this.scene.findObject("personal_text").getSize()
    this.scene.findObject("header_image_center")["width"] = max(0, personalTextSize[0] - maxTextWidthNoResize)

    let exclusivePriceSize = this.scene.findObject("exclusive_price").getSize()
    let timeDiscountExpiredTextSize = this.scene.findObject("time_discount_expired_text").getSize()

    let maxSize = max(timeDiscountExpiredTextSize[0] - to_pixels("13@sf/@pf"), exclusivePriceSize[0])
    this.scene.findObject("discount_image_center")["width"] = max(0, maxSize - maxTextWidthNoResize)
  }

  getGroupTitle = @(offerType) loc(offerTypes?[offerType] ?? $"trophy/unlockables_names/{offerType}", "")

  function prepareRewardsData() {
    this.groups = []
    let discount = this.offerBlk?.discountValue ?? 0
    foreach(config in (this.offerBlk % "i")) {
      local firstInBlock = false

      let localConfig = copyParamsToTable(config)
      let button = ::PrizesView.getPrizeActionButtonsView(localConfig, { shopDesc = true })
      local offerType = ::trophyReward.getType(localConfig)
      offerType = offerType != "resourceType" ? offerType : localConfig.resourceType
      local group = this.groups.findvalue(@(value) value?.type == offerType)
      if(group == null) {
        group = {
          type = offerType
          title = this.getGroupTitle(offerType)
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
        description = ::trophyReward.getRewardText(localConfig, false, "#FFFFFF")
        count = count > 1 ? $"x{count}" : ""
        firstInBlock
      }

      if(offerType != "unit") {
        itemData.image <- ::trophyReward.getImageByConfig(localConfig, false, "", true)
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

        let fakeUnit = {
          isFakeUnit = true
          name = ""
          nameLoc = ""
          image = ::image_for_air(unit)
        }

        let unitPlate = ::build_aircraft_item(localConfig.unit, fakeUnit, {
            hasActions = false
            isLocalState = true
            showAsTrophyContent = true
            isReceivedPrizes = true
            status = "canBuy"
            unitRarity = "premium"
            isElite = true
            hasTalismanIcon = true
            tooltipId = ::g_tooltip.getIdUnit(localConfig.unit)
          })
        itemData.unitFullName <- getUnitName(unit, false)
        itemData.image <- unitPlate
        itemData.countryIco <- getUnitCountryIcon(unit, false)
        let fonticon = getUnitRoleIcon(unit)
        let typeText = getFullUnitRoleText(unit)
        itemData.unitType <- colorize(::getUnitClassColor(unit), $"{typeText} {fonticon}")
        itemData.br <- format("%.1f", unit.getBattleRating(::get_current_ediff()))
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
    if(offerType == "unit")
      return Cost().setGold(::wp_get_cost_gold(localConfig.unit))
    else if(offerType == "item") {
      let item = ::ItemsManager.findItemById(localConfig.item)
      if(item != null)
        return item.getCost().multiply(localConfig.count)
      return Cost()
    }
    else if(offerType == "unlock")
      return getUnlockCost(localConfig.unlock).multiply(localConfig.count)
    else
      return getTypeByResourceType(localConfig.resourceType)
        .getCost(localConfig.resource)
        .multiply(localConfig.count)
    return Cost()
  }

  function updateRewards() {
    let data = handyman.renderCached("%gui/profile/offerItem.tpl", { offers = this.groups })
    let nest = this.scene.findObject("offer_markup")
    this.guiScene.replaceContentFromText(nest, data, data.len(), this)
  }

  function updateButtons() {
    placePriceTextToButton(this.scene, "btn_buy", loc("mainmenu/btnBuy"), this.costGold)
  }

  function updateTimeLeftText() {
    let timeLeftSec = this.timeExpired - get_charserver_time_sec()
    let timeDiscountExpiredObj = this.showSceneBtn("time_discount_expired_text", timeLeftSec > 0)
    let timeExpiredObj = this.showSceneBtn("time_expired_value", timeLeftSec > 0)
    this.showSceneBtn("time_expired_text", timeLeftSec > 0)
    if (timeLeftSec <= 0)
      return

    let timeString = buidPartialTimeStr(timeLeftSec)
    timeDiscountExpiredObj.setValue(loc("specialOffer/TimeSec", {
      time = colorize("userlogColoredText", timeString)
    }))

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
    ::g_tasker.addTask(taskId, { showProgressBox = true }, cb)
  }

  function onBuy() {
    let msgText = ::warningIfGold(
      loc("onlineShop/needMoneyQuestion", {
          purchase = loc("specialOffer"),
          cost = this.costGold.getTextAccordingToBalance()
        }),
        this.costGold)
    this.msgBox("purchase_ask", msgText,
      [
        ["yes", function() {
          if (::check_balance_msgBox(this.costGold))
            this.onBuyImpl()
        }],
        ["no", @() null ]
      ], "yes", { cancel_fn = @() null }
    )
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

let PersonalOfferPromoHandler = class extends gui_handlers.BaseGuiHandlerWT {
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
    let timeExpiredObj = this.showSceneBtn("time_expired_value", timeLeftSec > 0)
    this.showSceneBtn("time_expired_text", timeLeftSec > 0)
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

  function performAction(obj) { performPromoAction(this, obj) }
}

let openCurPersonalOfferWnd = @()
  handlersManager.loadHandler(PersonalOfferHandler, curPersonalOffer.value)

let function checkShowPersonalOffers() {
  cachePersonalOfferIfNeed()
  if (curPersonalOffer.value != null && !isSeenOffer(curPersonalOffer.value.offerName))
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
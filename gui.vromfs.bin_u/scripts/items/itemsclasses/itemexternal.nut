from "%scripts/dagui_natives.nut" import char_send_blk, inventory_generate_key
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { get_time_msec } = require("dagor.time")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let DataBlock  = require("DataBlock")
let { ceil } = require("math")
let { format, split_by_chars } = require("string")
let inventoryClient = require("%scripts/inventory/inventoryClient.nut")
let { getItemGenerator, findItemGeneratorByReceptUid } = require("%scripts/items/itemGeneratorsManager.nut")
let { hasFakeRecipesInList, getRequirementsMarkup, tryUseRecipes, tryUseRecipeSeveralTime
} = require("%scripts/items/exchangeRecipes.nut")
let guidParser = require("%scripts/guidParser.nut")
let itemRarity = require("%scripts/items/itemRarity.nut")
let time = require("%scripts/time.nut")
let chooseAmountWnd = require("%scripts/wndLib/chooseAmountWnd.nut")
let recipesListWnd = require("%scripts/items/listPopupWnd/recipesListWnd.nut")
let itemTransfer = require("%scripts/items/itemsTransfer.nut")
let { getMarkingPresetsById, getCustomLocalizationPresets,
  getEffectOnOpenChestPresetById } = require("%scripts/items/workshop/workshop.nut")
let { getEnumValName } = require("%scripts/debugTools/dbgEnum.nut")
let { select_training_mission, get_meta_mission_info_by_name } = require("guiMission")
let { getDecorator, buildLiveDecoratorFromResource
} = require("%scripts/customization/decorCache.nut")
let { utf8ToLower, stripTags } = require("%sqstd/string.nut")
let { get_charserver_time_sec } = require("chard")
let { getTypeByResourceType } = require("%scripts/customization/types.nut")
let { addTask } = require("%scripts/tasker.nut")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { hasBuyAndOpenChestWndStyle } = require("%scripts/items/buyAndOpenChestWndStyles.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { currentCampaignMission, isCustomMissionFlight } = require("%scripts/missions/missionsStates.nut")
let { getMissionName } = require("%scripts/missions/missionsText.nut")
let { maxAllowedWarbondsBalance } = require("%scripts/warbonds/warbondsState.nut")
let { findItemById, findItemByUid, getInventoryItemById, refreshExtInventory,
  markInventoryUpdateDelayed, getInventoryItemByCraftedFrom
} = require("%scripts/items/itemsManager.nut")
let { getPrizesListView } = require("%scripts/items/prizesView.nut")
let { checkPackageAndAskDownload } = require("%scripts/clientState/contentPacks.nut")

let emptyBlk = DataBlock()

let defaultLocIdsList = {
  assemble                              = "item/assemble"
  disassemble                           = "item/disassemble"
  consumeSeveral                        = "item/consume/several"
  recipes                               = "item/recipes"
  modify                                = "item/modify"
  descReceipesListHeaderPrefix          = ""
  msgBoxCantUse                         = "msgBox/assembleItem/cant"
  msgBoxConfirm                         = ""
  msgBoxSeveralConfirm                  = ""
  msgBoxConfirmWhithItemName            = "msgBox/assembleItem/confirm"
  msgBoxConfirmWhithItemNameDisassemble = "msgBox/disassembleItem/confirmWhithItemName"
  craftCountdown                        = "items/craft_process/countdown"
  header                                = "item/create_header"
  craftingIconInAmmount                 = "icon/gear"
  craftResultIconInAmmount              = "icon/chest2"
  tryCreateRecipes                      = "item/try_create_recipes"
  createRecipes                         = "item/create_recipes"
  cancelTitle                           = ""
  reachedMaxAmount                      = "item/reached_max_amount"
  inventoryErrorPrefix                  = "inventoryError/"
  maxAmountIcon                         = "check_mark/green"
  reUseItemLocId                        = "item/consume/again"
  reUseItemSeveralLocId                 = "item/consume/several/again"
  openingRewardTitle                    = "mainmenu/itemConsumed/title"
  rewardTitle                           = "mainmenu/itemCreated/title"
  disassembledRewardTitle               = "mainmenu/itemDisassembled/title"
  cantConsumeYet                        = "item/cant_consume_yet"
}

let ItemExternal = class (BaseItem) {
  static defaultLocId = ""
  static name = "ItemExternal"
  static combinedNameLocId = null
  static descHeaderLocId = ""
  static linkActionLocId = "msgbox/btn_find_on_marketplace"
  static linkActionIcon = "#ui/gameuiskin#gc.svg"
  static userlogOpenLoc = "coupon_exchanged"
  static linkBigQueryKey = "marketplace_item"
  static isPreferMarkupDescInTooltip = true
  static isDescTextBeforeDescDiv = false
  static hasRecentItemConfirmMessageBox = false
  static descReceipesListHeaderPrefix = "item/requires/"
  static descReceipesListWithCurQuantities = true
  static expireCountdownColor = "badTextColor"
  static expireCountdownLocId = "items/expireDate"
  static craftColor = "goodTextColor"
  static craftFinishedLocId = "items/craft_process/finished"

  canBuy = true

  rarity = null
  expireTimestamp = -1

  itemDef = null
  metaBlk = null

  amountByUids = null 
  requirement = null

  aditionalConfirmationMsg = null
  locIdsList = null
  substitutionItemData = []
  allowToBuyAmount = -1

  isAllowWideSize = true

  canMultipleConsume = true

  constructor(itemDefDesc, itemDesc = null, _slotData = null) {
    base.constructor(emptyBlk)

    this.itemDef = itemDefDesc
    this.id = this.itemDef.itemdefid
    this.blkType = itemDefDesc?.tags.type ?? ""
    this.maxAmount = itemDefDesc?.tags.maxCount.tointeger() ?? -1
    this.requirement = itemDefDesc?.tags.showWithFeature
    this.allowToBuyAmount = itemDefDesc?.tags.allowToBuyAmount.tointeger() ?? -1
    this.forceShowRewardReceiving = itemDefDesc?.tags.forceShowRewardReceiving ?? false
    this.updateSubstitutionItemDataOnce()

    this.aditionalConfirmationMsg = {}
    let confirmationActions = itemDefDesc?.tags ? (itemDefDesc.tags % "confirmationAction") : []
    if (confirmationActions.len()) {
       let confirmationMsg = itemDefDesc.tags % "confirmationMsg"
       foreach (idx, action in confirmationActions)
         this.aditionalConfirmationMsg[action] <- confirmationMsg?[idx] ?? ""
    }
    this.rarity = itemRarity.get(this.itemDef?.item_quality, this.itemDef?.name_color)
    this.shouldAutoConsume = !!itemDefDesc?.tags.autoConsume || this.canOpenForGold()

    this.link = inventoryClient.getMarketplaceItemUrl(this.id, itemDesc?.itemid) ?? ""

    if (itemDesc) {
      this.isInventoryItem = true
      this.amount = 0
      this.uids = []
      this.amountByUids = {}
      if ("itemid" in itemDesc)
        this.addUid(itemDesc.itemid, itemDesc.quantity)
      if (itemDesc?.timestamp != null)
        this.lastChangeTimestamp = time.getTimestampFromIso8601(itemDesc.timestamp)
      this.tradeableTimestamp = this.getTradebleTimestamp(itemDesc)
      this.craftedFrom = itemDesc?.craftedFrom ?? ""
    }

    this.expireTimestamp = this.getExpireTimestamp(itemDefDesc, itemDesc)
    if (this.expireTimestamp != -1)
      this.expiredTimeSec = (get_time_msec() * 0.001) + (this.expireTimestamp - get_charserver_time_sec())

    let meta = getTblValue("meta", this.itemDef)
    if (meta && meta.len()) {
      this.metaBlk = DataBlock()
      if (!this.metaBlk.loadFromText(meta, meta.len())) {
        this.metaBlk = null
      }
    }

    this.canBuy = !this.isInventoryItem

    this.addResources()

    this.updateShopFilterMask()
  }

  function getTradebleTimestamp(itemDesc) {
    if (!hasFeature("Marketplace"))
      return 0
    let res = to_integer_safe(itemDesc?.tradable_after_timestamp ?? 0)
    return res > get_charserver_time_sec() ? res : 0
  }

  function updateShopFilterMask() {
    this.shopFilterMask = this.iType
  }

  function tryAddItem(itemDefDesc, itemDesc) {
    if (this.id != itemDefDesc.itemdefid
        || (this.itemDef?.tags.showItemIdInName ?? false)
        || this.expireTimestamp != this.getExpireTimestamp(itemDefDesc, itemDesc)
        || this.tradeableTimestamp != this.getTradebleTimestamp(itemDesc))
      return false
    this.addUid(itemDesc.itemid, itemDesc.quantity)
    if (itemDesc?.timestamp != null)
      this.lastChangeTimestamp = max(this.lastChangeTimestamp,
        time.getTimestampFromIso8601(itemDesc.timestamp))
    return true
  }

  function addUid(uid, count) {
    this.uids.append(uid)
    this.amountByUids[uid] <- count
    this.amount += count
  }

  onItemExpire     = @() refreshExtInventory()
  onTradeAllowed   = @() markInventoryUpdateDelayed()

  function getTimestampfromString(str) {
    if (str == "")
      return -1

    local res = to_integer_safe(str, -1, false)
    if (res < 0)
      res = time.getTimestampFromIso8601(str) 
    return res
  }

  function getExpireTimestamp(itemDefDesc, itemDesc) {
    let tShop = this.getTimestampfromString(itemDefDesc?.expireAt ?? "")
    let tInv  = this.getTimestampfromString(itemDesc?.expireAt ?? "")
    return (tShop != -1 && (tInv == -1 || tShop < tInv)) ? tShop : tInv
  }

  updateNameLoc = @(locName) !this.shouldAutoConsume && this.combinedNameLocId && !u.isEmpty(this.itemDef?.meta)
    ? loc(this.combinedNameLocId, { name = locName })
    : locName

  function getName(colored = true) {
    let item = this.getSubstitutionItem()
    if (item != null)
      return item.getName(colored)

    local res = ""
    if (this.isDisguised)
      res = loc("item/disguised")
    else {
      local locName = this.itemDef?.name ?? ""
      if (this.isInventoryItem && (this.itemDef?.tags.showItemIdInName ?? false))
        locName = "".concat(locName, nbsp, loc("ui/number_sign"), this.uids?[0] ?? "")
      res = this.updateNameLoc(locName)
    }

    if (colored)
      res = colorize(this.getRarityColor(), res)
    return res
  }

  function getDescription() {
    if (this.isDisguised)
      return ""

    let desc = [
      this.getResourceDesc()
    ]

    local tags = this.getTagsLoc()
    if (tags.len()) {
      tags = tags.map(@(txt) colorize("activeTextColor", txt))
      desc.append("".concat(loc("ugm/tags"), loc("ui/colon"), loc("ui/comma").join(tags, true)))
    }

    desc.append(this.getBaseDescription())

    return "\n\n".join(desc, true)
  }

  function getBaseDescription() {
    return !this.itemDef?.tags.hideDesc ? (this.itemDef?.description ?? "") : ""
  }

  function getIcon(_addItemName = true) {
    return this.isDisguised ? LayersIcon.getIconData("disguised_item")
      : LayersIcon.getCustomSizeIconData(this.itemDef.icon_url, "pw, ph")
  }

  function getBigIcon() {
    if (this.isDisguised)
      return LayersIcon.getIconData("disguised_item")

    let image = !u.isEmpty(this.itemDef.icon_url_large) ? this.itemDef.icon_url_large : this.itemDef.icon_url
    return LayersIcon.getCustomSizeIconData(image, "pw, ph")
  }

  getOpeningCaption = @() loc(this.getLocIdsList().openingRewardTitle)
  getCreationCaption = @() loc(this.getLocIdsList().rewardTitle)
  getDissasembledCaption = @() loc(this.getLocIdsList().disassembledRewardTitle)

  function isAllowSkipOpeningAnim() {
    return true
  }

  function isCanBuy() {
    let inventoryItemCost = inventoryClient.getItemCost(this.id)
    if (!this.canBuy || !this.checkPurchaseFeature() || inventoryItemCost.isZero() || this.isExpired())
      return false

    return inventoryItemCost.gold == 0 || hasFeature(this.itemDef?.tags.purchaseForGoldFeature ?? "PurchaseMarketItemsForGold")
  }

  function getCost(ignoreCanBuy = false) {
    if (this.isCanBuy() || ignoreCanBuy)
      return inventoryClient.getItemCost(this.id)
    return Cost()
  }

  getTransferText = @() this.transferAmount > 0
    ? loc("items/waitItemsInTransaction", { amount = colorize("activeTextColor", this.transferAmount) })
    : ""

  getDescTimers   = @() [
    this.makeDescTimerData({
      id = "craft_timer"
      getText = this.getCraftTimeText
      needTimer = this.hasCraftTimer
    }),
    this.makeDescTimerData({
      id = "expire_timer"
      getText = this.getCurExpireTimeText
      needTimer = this.hasExpireTimer
    }),
    this.makeDescTimerData({
      id = "marketable_timer"
      getText = this.getMarketablePropDesc
      needTimer = @() this.getNoTradeableTimeLeft() > 0
    })
  ]

  getDescHeaderLocId = @() !this.shouldAutoConsume ? this.descHeaderLocId : ""

  function getLongDescriptionMarkup(params = null) {
    params = params ?? {}
    params.receivedPrizes <- false

    if (this.isDisguised)
      return this.getDescRecipesMarkup(params)

    local content = []
    let headers = [
      { header = this.getTransferText() }
      { header = this.getMarketablePropDesc(), timerId = "marketable_timer" }
    ]

    if (this.hasCraftTimer())
      headers.append({ header = this.getCraftTimeText(), timerId = "craft_timer" })

    if (this.hasTimer())
      headers.append({ header = this.getCurExpireTimeText(), timerId = "expire_timer" })

    if (this.metaBlk) {
      headers.append({ header = colorize("grayOptionColor", loc(this.getDescHeaderLocId())) })
      content = [ this.metaBlk ]
      params.showAsTrophyContent <- true
      params.receivedPrizes <- false
      params.relatedItem <- this.id
    }

    params.header <- headers
    local recipes = []
    local resultContent = []
    if (this.needShowAsDisassemble() || (this.hasReachedMaxAmount() && this.isAltActionDisassemble())) {
      let recipe = this.getDisassembleRecipe()
      if (recipe) {
        recipes.append(recipe)
        resultContent = this.getDisassembleResultContent(recipe)
      }
    }
    else if (this.hasReachedMaxAmount())
      headers.append({ header = loc(this.getLocIdsList().reachedMaxAmount) })
    else
      recipes = this.getMyRecipes()
    return "".concat(getPrizesListView(content, params),
      getRequirementsMarkup(recipes, this, params),
      getPrizesListView(resultContent,
        { widthByParentParent = true,
          header = colorize("grayOptionColor", loc("mainmenu/you_will_receive")) },
        false)
    )
  }

  getTypeNameForMarketableDesc = @() utf8ToLower(this.getTypeName())

  function getMarketablePropDesc() {
    if (!hasFeature("Marketplace") || this.shouldAutoConsume || (this.itemDef?.tags.hideMarketablePropDesc ?? false))
      return ""

    let canSell = this.itemDef?.marketable
    let noTradeableSec = this.getNoTradeableTimeLeft()
    let locEnding = !canSell ? "no"
      : noTradeableSec > 0 ? "afterTime"
      : "yes"
    let text = loc($"item/marketable/{locEnding}",
      { name = this.getTypeNameForMarketableDesc()
        time = noTradeableSec > 0
          ? colorize("badTextColor",
          time.hoursToString(time.secondsToHours(noTradeableSec), false, true, true).replace(" ", nbsp))
          : ""
      })
    return  " ".concat(loc("currency/gc/sign/colored", ""),
      colorize(canSell ? "userlogColoredText" : "badTextColor", text))
  }

  function getResourceDesc() {
    if (!this.metaBlk || !this.metaBlk?.resource || !this.metaBlk?.resourceType)
      return ""
    let decoratorType = getTypeByResourceType(this.metaBlk.resourceType)
    let decorator = getDecorator(this.metaBlk.resource, decoratorType)
    if (!decorator)
      return ""
    return "\n".join([
      decorator.getTypeDesc()
      decorator.getVehicleDesc()
      decorator.getRestrictionsDesc()
    ], true)
  }

  function getDescRecipeListHeader(showAmount, totalAmount, isMultipleExtraItems, hasFakeRecipes = false, timeText = "") {
    if (showAmount < totalAmount)
      return loc(hasFakeRecipes ? this.getLocIdsList().tryCreateRecipes : this.getLocIdsList().createRecipes,
        {
          count = totalAmount
          countColored = colorize("activeTextColor", totalAmount)
          exampleCount = showAmount
          createTime = timeText.len() ? $"\n{timeText}\n" : ""
        })

    let isMultipleRecipes = showAmount > 1
    let headerSuffix = isMultipleRecipes && isMultipleExtraItems  ? "any_of_item_sets"
      : !isMultipleRecipes && isMultipleExtraItems ? "items_set"
      : isMultipleRecipes && !isMultipleExtraItems ? "any_of_items"
      : "item"

    return "".concat(timeText.len() ? $"{timeText}\n" : "",
      loc($"{this.getLocIdsList().descReceipesListHeaderPrefix}{headerSuffix}"))
  }

  isRare              = @() this.isDisguised ? base.isRare() : this.rarity.isRare
  getRarity           = @() this.isDisguised ? base.getRarity() : this.rarity.value
  getRarityColor      = @() this.isDisguised ? base.getRarityColor() : this.rarity.color
  getTagsLoc          = @() this.rarity.tag && !this.isDisguised ? [ this.rarity.tag ] : []

  canConsume          = @() false
  cantConsumeYet      = @() this.isInventoryItem && this.itemDef?.tags.cantConsumeYet
  canAssemble         = @() !this.isExpired() && this.getVisibleRecipes().len() > 0
  canConvertToWarbonds = @() this.isInventoryItem && !this.isExpired() && hasFeature("ItemConvertToWarbond") && this.amount > 0 && this.getWarbondRecipe() != null
  canDisassemble       = @() this.isInventoryItem && this.itemDef?.tags.canBeDisassembled
    && !this.isExpired() && this.getDisassembleRecipe() != null
  canBeModified           = @() this.isInventoryItem && this.itemDef?.tags.canBeModified != null
    && !this.isExpired() && this.getModifiedRecipe() != null
  getMaxRecipesToShow = @() 1

  hasMainActionDisassemble  = @() this.itemDef?.tags.canBeDisassembled == "mainAction"
  needShowAsDisassemble     = @() this.hasMainActionDisassemble() || (this.canDisassemble() && !this.canAssemble())

  function getMainActionData(isShort = false, params = {}) {
    let res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (this.amount && this.canConsume() && (params?.canConsume ?? true))
      return {
        btnName = loc("item/consume")
        isInactive = this.cantConsumeYet()
      }
    if (this.isCrafting())
      return {
        btnName = loc("item/craft_process/cancel")
      }
    if (this.hasCraftResult())
      return {
        btnName = loc("items/craft_process/finish")
      }
    if (this.hasMainActionDisassemble() && this.canDisassemble() && this.amount > 0)
      return {
        btnName = this.getDisassembleText()
        isDisassemble = true
      }
    if (this.canAssemble())
      return {
        btnName = this.getAssembleButtonText()
        isInactive = this.hasReachedMaxAmount()
      }
    if (this.canRunCustomMission())
      return {
        btnName = this.getCustomMissionButtonText()
        isRunCustomMission = true
      }

    return null
  }

  function doMainAction(cb, handler, params = null) {
    return this.buy(cb, handler, params)
      || this.consume(cb, params)
      || this.cancelCrafting(cb, params)
      || this.seeCraftResult(cb, handler, params)
      || (this.hasMainActionDisassemble() && this.disassemble(params))
      || this.assemble(cb, params)
      || this.runCustomMission()
  }

  isAltActionDisassemble = @() this.amount > 0 && (!this.canConsume() || !this.canAssemble())
    && !this.canConvertToWarbonds()
    && !this.hasMainActionDisassemble() && this.canDisassemble() && !this.isCrafting() && !this.hasCraftResult()

  getAltActionName   = @(params = null) (this.amount && this.canConsume() && this.getAllowToUseAmount() > 1
      && this.getRelatedRecipes().len() > 0) ? loc(this.getLocIdsList().consumeSeveral)
    : (params?.canConsume && this.amount && this.canConsume()) ? loc("item/consume")
    : (this.amount && this.canConsume() && this.canAssemble()) ? loc(this.getLocIdsList().assemble)
    : this.canConvertToWarbonds() ? loc("items/exchangeTo", { currency = this.getWarbondExchangeAmountText() })
    : (!this.hasMainActionDisassemble() && this.canDisassemble() && this.amount > 0 && !this.isCrafting() && !this.hasCraftResult())
      ? this.getDisassembleText()
    : (this.canBeModified() && this.amount > 0) ? this.getModifiedText()
    : (params?.canRunCustomMission ?? false) && this.canRunCustomMission() ? this.getCustomMissionButtonText()
    : ""
  doAltAction        = @(params = null) this.consumeSeveral(params)
    || (params?.canConsume && this.canConsume() && this.consume(null, params))
    || (this.canConsume() && this.assemble(null, params))
    || this.convertToWarbonds(params)
    || (!this.hasMainActionDisassemble() && this.disassemble(params))
    || this.modify(params)
    || ((params?.canRunCustomMission ?? false) && this.canRunCustomMission() && this.runCustomMission())

  function consume(cb, params) {
    if (!this.uids || !this.uids.len() || !this.metaBlk || !this.canConsume() || !(params?.canConsume ?? true))
      return false

    if (this.cantConsumeYet()) {
      scene_msg_box("cant_consume_yet", null, loc(this.getLocIdsList().cantConsumeYet), [["cancel"]], "cancel")
      return false
    }

    if (this.shouldAutoConsume || (params?.needConsumeImpl ?? false)) {
      this.consumeImpl(cb, params)
      return true
    }

    let text = "\n".concat(loc("recentItems/useItem", { itemName = colorize("activeTextColor", this.getName()) }),
      loc("msgBox/coupon_exchange"))
    let msgboxParams = {
      cancel_fn = @() null
      baseHandler = get_cur_base_gui_handler() 
      data_below_text = getPrizesListView([ this.metaBlk ],
        { showAsTrophyContent = true, receivedPrizes = false, widthByParentParent = true })
      data_below_buttons = hasFeature("Marketplace") && this.itemDef?.marketable
        ? format("textarea{overlayTextColor:t='warning'; text:t='%s'}", stripTags(loc("msgBox/coupon_will_be_spent")))
        : null
    }
    let item = this 
    scene_msg_box("coupon_exchange", null, text, [
      [ "yes", @() item.consumeImpl(cb, params) ],
      [ "no" ]
    ], "yes", msgboxParams)
    return true
  }

  function consumeImpl(cb = null, _params = null) {
    let uid = this.uids?[0]
    if (!uid)
      return

    let itemAmountByUid = this.amountByUids[uid] 
    let consumeAmount = this.shouldAutoConsume && this.canMultipleConsume
      ? itemAmountByUid
      : 1
    let blk = DataBlock()
    blk.setInt("itemId", uid.tointeger())
    blk.setInt("quantity", consumeAmount)
    let taskCallback = function() {
      let item = findItemByUid(uid)
      
      
      if (item && item.amountByUids[uid] == itemAmountByUid) {
        item.amountByUids[uid] -= consumeAmount
        item.amount -= consumeAmount
        if (item.amountByUids[uid] <= 0) {
          inventoryClient.removeItem(uid)
          if (item.uids?[0] == uid)
            item.uids.remove(0)
        }
      }
      if (cb)
        cb({ success = true })
    }
    let itemId = this.id
    let taskId = char_send_blk("cln_consume_inventory_item", blk)
    addTask(taskId, { showProgressBox = !this.shouldAutoConsume }, taskCallback,
      @() cb?({ success = false, itemId = itemId }))
  }

  function consumeSeveral(params = null) {
    if ((this.uids?.len() ?? 0) == 0 || !this.canConsume())
      return false

    let allowToUseAmount = this.getAllowToUseAmount()
    if (allowToUseAmount <= 1)
      return false

    let recipesList = this.getRelatedRecipes()
    if (recipesList.len() == 0)
      return false

    if (recipesList.len() == 1) {
      tryUseRecipeSeveralTime(recipesList[0], this, allowToUseAmount, params)
      return true
    }

    let item = this
    recipesListWnd.open({
      recipesList = recipesList
      headerText = this.getAssembleHeader()
      buttonText = this.getAssembleText()
      alignObj = params?.obj
      showTutorial = params?.showTutorial
      onAcceptCb = function(recipe) {
        tryUseRecipeSeveralTime(recipe, item, allowToUseAmount, params)
        return !recipe.isUsable
      }
    })
    return true
  }

  getAssembleHeader       = @() loc(this.getLocIdsList().headerRecipesList, { itemName = this.getName() })
  getAssembleText         = @() loc(this.getLocIdsList().assemble)
  getAssembleButtonText   = @() this.getVisibleRecipes().len() > 1 ? loc(this.getLocIdsList().recipes) : this.getAssembleText()
  getCantUseLocId         = @() this.getLocIdsList().msgBoxCantUse
  getConfirmMessageData   = @(recipe, quantity) this.getEmptyConfirmMessageData().__update({
    text = "".concat(loc(recipe.getConfirmMessageLocId(this.getLocIdsList()),
        { itemName = colorize("activeTextColor", quantity == 1 ? this.getName() : $"{this.getName()} {loc("ui/multiply")}{quantity})") }),
      recipe.hasCraftTime() ? $"\n{recipe.getCraftTimeText()}" : "")
    headerRecipeMarkup = recipe.getHeaderRecipeMarkupText()
    needRecipeMarkup = true
  })

  function assemble(_cb = null, params = null) {
    if (!this.canAssemble())
      return false

    let recipesList = params?.recipes ?? this.getVisibleRecipes()
    if (recipesList.len() == 1) {
      tryUseRecipes(recipesList, this, params)
      return true
    }

    let item = this
    recipesListWnd.open({
      recipesList = recipesList
      headerText = this.getAssembleHeader()
      buttonText = this.getAssembleText()
      alignObj = params?.obj
      showTutorial = params?.showTutorial
      onAcceptCb = function(recipe) {
        tryUseRecipes([recipe], item, params)
        return !recipe.isUsable
      }
    })
    return true
  }

  function getWarbondExchangeAmountText() {
    let recipe = this.getWarbondRecipe()
    if (this.amount <= 0 || !recipe)
      return ""
    let warbondItem = findItemById(recipe.generatorId)
    let warbond = warbondItem?.getWarbond()
    return $"{warbondItem?.getWarbondsAmount() ?? ""}{loc(warbond?.fontIcon ?? "currency/warbond/green")}"
  }

  getDisassembleText = @() loc(this.getLocIdsList().disassemble)
  function disassemble(_params = null) {
    if (!this.canDisassemble() || this.amount <= 0 || this.isCrafting() || this.hasCraftResult())
      return false

    let recipe = this.getDisassembleRecipe()
    if (this.amount <= 0 || !recipe)
      return false

    let content = this.getDisassembleResultContent(recipe)
    tryUseRecipes([ recipe ], this,
      { rewardListLocId = this.getItemsListLocId()
        bundleContent = content
      })
    return true
  }

  getModifiedText = @() loc(this.getLocIdsList().modify)
  function modify(params = null) {
    if (!this.canBeModified() || this.amount <= 0)
      return false

    let recipe = this.getModifiedRecipe()
    if (recipe == null)
      return false

    tryUseRecipes([ recipe ], this, params)
    return true
  }

  getDisassembleResultContent = function(recipe) {
    let gen = getItemGenerator(recipe.generatorId)
    let content = gen?.isPack ? gen.getContent() : []
    return gen?.isDelayedxchange?() && content.len() > 0
      ? findItemById(content[0].item)?.getContent?() ?? []
      : content
  }

  function convertToWarbonds(params = null) {
    if (!this.canConvertToWarbonds())
      return false
    let recipe = this.getWarbondRecipe()
    if (this.amount <= 0 || !recipe)
      return false

    let warbondItem = findItemById(recipe.generatorId)
    let warbond = warbondItem && warbondItem.getWarbond()
    if (!warbond) {
      showInfoMsgBox(loc("mainmenu/warbondsShop/notAvailable"))
      return true
    }

    let leftWbAmount = maxAllowedWarbondsBalance.get() - warbond.getBalance()
    if (leftWbAmount <= 0) {
      showInfoMsgBox(loc("items/cantExchangeToWarbondsMessage"))
      return true
    }

    local maxAmount = ceil(leftWbAmount.tofloat() / warbondItem.getWarbondsAmount()).tointeger()
    maxAmount = min(maxAmount, this.amount)
    if (maxAmount == 1 || !hasFeature("ItemConvertToWarbondMultiple")) {
      this.convertToWarbondsImpl(recipe, warbondItem, 1)
      return true
    }

    let item = this
    let icon = loc(warbond.fontIcon)
    chooseAmountWnd.open({
      parentObj = params?.obj
      align = params?.align ?? "bottom"
      minValue = 1
      maxValue = maxAmount
      curValue = maxAmount
      valueStep = 1

      headerText = loc("items/exchangeTo", { currency = icon })
      buttonText = loc("items/btnExchange")
      getValueText = @(value) "".concat(value, " x ", warbondItem.getWarbondsAmount(), icon,
        " = ", value * warbondItem.getWarbondsAmount(), icon)

      onAcceptCb = @(value) item.convertToWarbondsImpl(recipe, warbondItem, value)
      onCancelCb = null
    })
    return true
  }

  function convertToWarbondsImpl(recipe, warbondItem, convertAmount) {
    let msg = loc("items/exchangeMessage", {
      amount = convertAmount
      item = this.getName()
      currency = "".concat(convertAmount * warbondItem.getWarbondsAmount(),
        loc(warbondItem.getWarbond()?.fontIcon))
    })
    scene_msg_box("warbond_exchange", null, msg, [
      [ "yes", @() recipe.doExchange(warbondItem, convertAmount) ],
      [ "no" ]
    ], "yes", { cancel_fn = @() null })
  }

   function hasLink() {
    return !this.isDisguised && base.hasLink()
      && this.itemDef?.marketable && this.getNoTradeableTimeLeft() == 0
      && hasFeature("Marketplace")
  }

  function getMetaResource() {
    return this.metaBlk?.resource
  }

  function addResources(params = null) {
    if (!this.metaBlk?.resource || !this.metaBlk?.resourceType || !this.itemDef)
      return
    let resource = this.metaBlk.resource
    if (!guidParser.isGuid(resource))
      return

    buildLiveDecoratorFromResource(this.metaBlk.resource, this.metaBlk.resourceType, this.itemDef, params)
  }

  function getRelatedRecipes() {
    let res = []
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(this.id)) {
      let gen = getItemGenerator(genItemdefId)
      if (gen == null || findItemById(gen.id)?.iType == itemType.WARBONDS)
        continue
      res.extend(gen.getRecipesWithComponent(this.id))
    }
    return res
  }

  function getWarbondRecipe() {
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(this.id)) {
      let item = findItemById(genItemdefId)
      if (item?.iType != itemType.WARBONDS)
        continue
      let gen = getItemGenerator(genItemdefId)
      if (!gen)
        continue
      let recipes = gen.getRecipesWithComponent(this.id)
      if (recipes.len())
        return recipes[0]
    }
    return null
  }

  function getDisassembleRecipe() {
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(this.id)) {
      let gen = getItemGenerator(genItemdefId)
      if (!gen || !gen?.tags.isDisassemble)
        continue
      let recipes = gen.getRecipesWithComponent(this.id)
      if (recipes.len())
        return recipes[0]
    }
    return null
  }

  function getModifiedRecipe() {
    foreach (genItemdefId in inventoryClient.getChestGeneratorItemdefIds(this.id)) {
      let gen = getItemGenerator(genItemdefId)
      if (!gen?.tags.isModification)
        continue
      let recipes = gen.getRecipesWithComponent(this.id)
      if (recipes.len() > 0)
        return recipes[0]
    }
    return null
  }

  getMyRecipes = @() getItemGenerator(this.id)?.getRecipes() ?? []
  getGenerator = @() getItemGenerator(this.id)

  function getVisibleRecipes() {
    let gen = getItemGenerator(this.id)
    if (this.showAllowableRecipesOnly())
      return gen?.getUsableRecipes() ?? []
    return gen?.getRecipes() ?? []
  }

  getExpireTimeTextShort = @() colorize(this.expireCountdownColor, base.getExpireTimeTextShort())

  function getCurExpireTimeText() {
    if (this.expireTimestamp == -1)
      return ""
    if (this.expiredTimeSec <= 0)
      return colorize(this.expireCountdownColor, loc("items/expired"))
    return colorize(this.expireCountdownColor, loc(this.expireCountdownLocId, {
      datetime = time.buildDateTimeStr(this.expireTimestamp)
      timeleft = this.getExpireTimeTextShort()
    }))
  }

  function needShowActionButtonAlways(params) {
    let mainActionData = this.getMainActionData(true, params)
    if (mainActionData?.isInactive ?? false)
      return false

    if (this.canRunCustomMission())
      return true

    if (this.hasCraftResult())
      return true

    if (this.canAssemble())
      return !!this.getVisibleRecipes()?.findvalue(@(r) r.isUsable)

    if (mainActionData?.isDisassemble ?? false)
      return this.getDisassembleRecipe()?.isUsable ?? false

    return false
  }

  isGoldPurchaseInProgress = @() u.search(itemTransfer.getSendingList(), @(data) (data?.goldCost ?? 0) > 0) != null

  isMultiPurchaseAvailable = @() this.allowToBuyAmount > 1

  onCheckLegalRestrictions = @(cb, handler, params)
    hasBuyAndOpenChestWndStyle(this) && !params?.isFromChestWnd ? broadcastEvent("openChestWndOrTrophy", {chest = this})
      : (this.isMultiPurchaseAvailable() && params?.amount == null) ? this.showChooseAmountWnd(cb, handler, params)
      : this.showBuyConfirm(cb, handler, params)

  function showChooseAmountWnd(cb, handler, params) {
    let item = this
    chooseAmountWnd.open({
      parentObj = params?.obj
      minValue = 1
      maxValue = this.allowToBuyAmount
      headerText = loc("onlineShop/purchase", { purchase = this.getName() })
      buttonText = loc("msgbox/btn_purchase")
      getValueText = function(amount) {
        let cost = Cost() + item.getCost()
        let mult = cost.tostring()
        let product = cost.multiply(amount).getTextAccordingToBalance()
        return $"{amount} x {mult} = {product}"
      }
      onAcceptCb = @(amount) item.onAmountAccept(cb, handler, params.__merge({ amount }))
    })
  }

  function onAmountAccept(cb, handler, params) {
    let cost = (Cost() + this.getCost()).multiply(params.amount)
    if (checkBalanceMsgBox(cost))
      this.showBuyConfirm(cb, handler, params)
  }

  function _buy(cb = null, params = null) {
    if (!this.isCanBuy())
      return false

    if (this.isGoldPurchaseInProgress()) {
      addPopup(null, loc("items/msg/waitPreviousGoldTransaction"), null, null, null, "waitPrevGoldTrans")
      return true
    }
    let cost = this.getCost()
    let blk = DataBlock()
    blk.key = inventory_generate_key()
    blk.itemDefId = this.id
    blk.goldCost = cost.gold
    blk.wpCost = cost.wp
    if ("amount" in params)
      blk.amount = params.amount

    let item = this
    let onSuccess = function() {
      if (cb)
        cb({ success = true })
      broadcastEvent("showBuyAndOpenChestWndWhenReceive", item)
    }
    let onError = @(_errCode) cb ? cb({ success = false }) : null

    let taskId = char_send_blk("cln_inventory_purchase_item", blk)
    addTask(taskId, { showProgressBox = true }, onSuccess, onError)
    return true
  }

  onItemCraft     = @() refreshExtInventory()
  function getCraftingItem() {
    local recipes = []
    if (this.needShowAsDisassemble()) {
      let recipe = this.getDisassembleRecipe()
      if (recipe)
        recipes.append(recipe)
    }
    else {
      let gen = getItemGenerator(this.id)
      recipes = gen ? gen.getRecipes() : []
    }

    foreach (recipe in recipes) {
      let item = getInventoryItemById(recipe.generatorId)
      if (item)
        return item?.itemDef.type == "delayedexchange" ? item : null
    }

    return null
  }

  function getCraftTimeLeft() {
    let craftingItem = this.getCraftingItem()
    let craftTimeSec = craftingItem?.expiredTimeSec ?? 0
    if (craftTimeSec <= 0)
      return -1

    let curSeconds = get_time_msec() * 0.001
    let deltaSeconds = (craftTimeSec - curSeconds).tointeger()
    return max(0, deltaSeconds)
  }

  function getCraftTimeTextShort() {
    let deltaSeconds = this.getCraftTimeLeft()
    if (deltaSeconds == -1)
      return ""

    if (deltaSeconds == 0) {
      if (this.isInventoryItem)
        this.onItemCraft()
      return colorize(this.craftColor, loc(this.craftFinishedLocId))
    }
    return colorize(this.craftColor, "".concat(loc("icon/hourglass"), nbsp,
      time.hoursToString(time.secondsToHours(deltaSeconds), false, true, true).replace(" ", nbsp)))
  }

  function getCraftTimeText() {
    let craftingItem = this.getCraftingItem()
    let craftTime = craftingItem?.expireTimestamp ?? -1
    if (craftTime == -1)
      return ""

    return colorize(this.craftColor, loc(this.getLocIdsList().craftCountdown, {
      datetime = time.buildDateTimeStr(craftTime)
      timeleft = this.getCraftTimeTextShort()
    }))
  }

  isCraftResult = @() this.craftedFrom.indexof(";") != null
  getParentGen = @() this.isCraftResult() ? findItemGeneratorByReceptUid(this.craftedFrom) : null

  function getCraftResultItem() {
    local recipes = []
    if (this.needShowAsDisassemble()) {
      let recipe = this.getDisassembleRecipe()
      if (recipe)
        recipes.append(recipe)
    }
    else {
      let gen = getItemGenerator(this.id)
      recipes = gen ? gen.getRecipes() : []
    }

    foreach (recipe in recipes) {
      let item = getInventoryItemByCraftedFrom(recipe.uid)
      if (item)
        return item
    }

    return null
  }

  function seeCraftResult(cb, handler, params = {}) {
    let craftResult = this.getCraftResultItem()
    if (!craftResult)
      return false

    params.shouldSkipMsgBox <- true
    craftResult.doMainAction(cb, handler, params)
    return true
  }

  function getAdditionalTextInAmmount(needColorize = true, needOnlyIcon = false) {
    let locIds = this.getLocIdsList()
    let textIcon = this.isCrafting()
      ? locIds.craftingIconInAmmount
      : this.hasCraftResult()
        ? locIds.craftResultIconInAmmount
        : ""

    if (textIcon == "")
      return ""

    local text = loc(textIcon)
    if (!needOnlyIcon)
      text = " + 1{0}".subst(text)
    return needColorize ? colorize(this.craftColor, text) : text
  }

  function cancelCrafting(cb = null, params = {}) {
    let craftingItem = this.getCraftingItem()

    if (!craftingItem || craftingItem?.itemDef.type != "delayedexchange")
      return false

    
    if (craftingItem == this) {
      logerr("".concat($"Inventory: delayedexchange {this.id} instance has type ",
        getEnumValName("itemType", itemType, this.iType), " which does not implement cancelCrafting()"))
      return false
    }

    params.parentItem <- this
    params.isDisassemble <- this.needShowAsDisassemble()
    craftingItem.cancelCrafting(cb, params)
    return true
  }

  isHiddenItem = @() !this.isEnabled() || this.isCraftResult() || this.itemDef?.tags.devItem == true
  isEnabled = @() this.requirement == null || hasFeature(this.requirement)
  function getAdditionalConfirmMessage(actionName, delimiter = "\n") {
     let locKey = this.aditionalConfirmationMsg?[actionName]
     if (!locKey)
       return ""

     return "".concat(delimiter, loc($"confirmationMsg/{locKey}"))
  }

  getCustomMissionBlk = function() {
    let misName = this.itemDef?.tags.canRunCustomMission
    if (!misName)
      return null

    let misBlk = get_meta_mission_info_by_name(misName)
    if (!misBlk || (("reqFeature" in misBlk) && !hasFeature(misBlk.reqFeature)))
      return null

    return misBlk
  }

  hasCustomMission = @() this.getCustomMissionBlk() != null
  canRunCustomMission = @() this.amount > 0 && this.hasCustomMission()
  getCustomMissionButtonText = @() getMissionName(this.itemDef.tags.canRunCustomMission, this.getCustomMissionBlk())

  function runCustomMission() {
    if (!this.canRunCustomMission())
        return false

    let misBlk = get_meta_mission_info_by_name(this.itemDef.tags.canRunCustomMission)
    if (misBlk?.requiredPackage != null && !checkPackageAndAskDownload(misBlk.requiredPackage))
      return true

    broadcastEvent("BeforeStartCustomMission")
    isCustomMissionFlight.set(true)
    currentCampaignMission.set(this.itemDef.tags.canRunCustomMission)
    select_training_mission(misBlk)
    return true
  }

  function getViewData(params = {}) {
    let item = this.getSubstitutionItem()
    if (item != null)
      return this.getSubstitutionViewData(item.getViewData(params), params)

    let res = base.getViewData(params)
    if (res.layered_image == "")
      res.nameText <- this.getName()
    let markPresetName = this.itemDef?.tags.markingPreset
    if (!markPresetName)
      return res

    let preset = getMarkingPresetsById(markPresetName)
    if (!preset)
      return res

    if ("markIconLocId" in preset) {
      res.needMarkIcon <- true
      res.markIcon <- loc(preset.markIconLocId)
      res.markIconColor <- preset.color
    }
    else if ("markIcon" in preset) {
      res.needImageMarkIcon <- true
      res.markIcon <- preset.markIcon
      res.markIconColor <- preset.color
    }

    if (preset?.showBorder ?? false)
      res.rarityColor <- preset.color
    return res
  }

  function updateSubstitutionItemDataOnce() {
    let tag = this.itemDef.tags?.showAsAnotherItem
    if (tag == null)
      return

    this.substitutionItemData = []
    let tagData = split_by_chars(tag, "_")
    for (local i = tagData.len() - 1; i >= 0 ; i--) {
      let ids = split_by_chars(tagData[i], "-")
      if (ids.len() < 2)
        continue
      this.substitutionItemData.append(ids)
      inventoryClient.requestItemdefsByIds(ids)
    }
  }

  function getSubstitutionItem() {
    if (this.substitutionItemData?.len() == 0)
      return null
    for (local i = 0; i < this.substitutionItemData.len(); i++)
      if (getInventoryItemById(this.substitutionItemData[i][0].tointeger()))
        return findItemById(this.substitutionItemData[i][1].tointeger())

    return null
  }

  function getDescriptionUnderTitle() {
    let markPresetName = this.itemDef?.tags.markingPreset
    if (!markPresetName || this.isDisguised)
      return ""

    let data = getMarkingPresetsById(markPresetName)
    if (!data)
      return ""

    return colorize(data.color, loc(data.additionalDesc))
  }

  getLocIdsList = function() {
    if (this.locIdsList)
      return this.locIdsList

    this.locIdsList = this.getLocIdsListImpl()
    let localizationPreset = this.itemDef?.tags.customLocalizationPreset
    if (localizationPreset)
      this.locIdsList.__update(getCustomLocalizationPresets(localizationPreset))

    return this.locIdsList
  }

  getLocIdsListImpl = @() defaultLocIdsList.__merge({
    descReceipesListHeaderPrefix = "".concat(this.descReceipesListHeaderPrefix,
      this.needShowAsDisassemble() ? "disassemble/" : "")
    msgBoxCantUse                = this.needShowAsDisassemble()
      ? "msgBox/disassembleItem/cant"
      : "msgBox/assembleItem/cant"
    craftCountdown               = "".concat("items/craft_process/countdown",
      this.needShowAsDisassemble() ? "/disassemble" : "")
    headerRecipesList            = hasFakeRecipesInList(this.getVisibleRecipes())
      ? "item/create_header/findTrue"
      : "item/create_header"
    craftingIconInAmmount        = this.needShowAsDisassemble() ? "hud/iconRepair" : "icon/gear"
    reUseItemLocId               = this.canConsume() ? "item/consume/again"
      : this.hasMainActionDisassemble() && this.canDisassemble() ? "item/disassemble/again"
      : this.canAssemble() ? "item/assemble/again"
      : defaultLocIdsList.reUseItemLocId
  })

  hasUsableRecipe = @() this.getVisibleRecipes().findindex(@(r) r.isUsable) != null
  needOfferBuyAtExpiration = @() !this.isHiddenItem() && this.itemDef?.tags.offerToBuyAtExpiration
  isVisibleInWorkshopOnly = @() this.itemDef?.tags.showInWorkshopOnly ?? false
  getDescRecipesMarkup = @(params) getRequirementsMarkup(this.getMyRecipes(), this, params)
  getIconName = @() this.isDisguised ? this.getSmallIconName() : this.itemDef.icon_url
  hasUsableRecipeOrNotRecipes = function () {
    let recipes = this.getVisibleRecipes()
    if (recipes.len() == 0)
      return true

    return u.search(recipes, @(r) r.isUsable) != null
  }

  function getBoostEfficiency() {
    let substitutionItem = this.getSubstitutionItem()
    return substitutionItem != null
      ? substitutionItem.getBoostEfficiency()
      : this.itemDef?.tags.boostEfficiency.tointeger()
  }

  getEffectOnOpenChest = @() getEffectOnOpenChestPresetById(this.itemDef?.tags.effectOnOpenChest ?? "")
  canCraftOnlyInCraftTree = @() this.itemDef?.tags.canCraftOnlyInCraftTree ?? false
  showAllowableRecipesOnly = @() this.itemDef?.tags.showAllowableRecipesOnly ?? false
  canRecraftFromRewardWnd = @() this.itemDef?.tags.allowRecraftFromRewardWnd ?? false
  getQuality = @() this.itemDef?.tags.quality ?? "common"
  getExpireType = @() null
  showAlwaysAsEnabledAndUnlocked = @() this.itemDef?.tags.showAlwaysAsEnabledAndUnlocked ?? false
  showAsEmptyItem = @() (this.getSubstitutionItem() ?? this).itemDef?.tags.showAsEmptyItem
  showDescInRewardWndOnly = @() this.itemDef?.tags.showDescInRewardWndOnly ?? false
  getAllowToUseAmount = @() (this.itemDef?.tags.allowToUseAmount ?? 0).tointeger()

  function getCountriesWithBuyRestrict() {
    let countryDenyPurchase = this.itemDef?.tags.countryDenyPurchase ?? ""
    if (countryDenyPurchase == "")
      return []

    return countryDenyPurchase.split("_").map(@(c) c.toupper())
  }
}

return ItemExternal

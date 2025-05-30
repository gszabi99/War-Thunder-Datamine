from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { g_order_award_mode } = require("%scripts/items/orderAwardMode.nut")
let { orderUseResult } = require("%scripts/items/orderUseResult.nut")
let { g_difficulty } = require("%scripts/difficulty.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { convertBlk } = require("%sqstd/datablock.nut")
let { format } = require("string")
let time = require("%scripts/time.nut")
let { BaseItem } = require("%scripts/items/itemsClasses/itemsBase.nut")
let { orderTypes } = require("%scripts/items/orderType.nut")
let { getRoomEvent } = require("%scripts/matchingRooms/sessionLobbyInfo.nut")
let { registerItemClass } = require("%scripts/items/itemsTypeClasses.nut")
let { getOrderActivateInfoText, getTimesUsedOrderItem, isOrderItemActive, activateOrder,
  orderCanBeActivated, checkCurrentMission
} = require("%scripts/items/orders.nut")

let Order = class (BaseItem) {
  static iType = itemType.ORDER
  static name = "Order"
  static defaultLocId = "order"
  static defaultIconStyle = "default_order_debug"
  static typeIcon = "#ui/gameuiskin#item_type_orders.svg"
  helperCost = Cost()
  static colorScheme = {
    typeDescriptionColor = "commonTextColor"
    parameterValueColor = "activeTextColor"
    parameterLabelColor = "commonTextColor"

    
    objectiveDescriptionColor = "unlockActiveColor"

  }
  static includeInRecentItems = false

  canBuy = true
  allowBigPicture = false

  orderType = null

  
  onlyIssuerTeam = null
  timeTotal = null
  cooldown = null
  cooldownOtherTeam = null
  delayFromStart = null
  awardOnCancel = null
  awardWpByDifficulty = null
  awardXpByDifficulty = null
  awardGoldByDifficulty = null
  disabledDifficulties = null
  awardMode = null

  
  typeParams = null

  constructor(blk, invBlk = null, slotData = null) {
    base.constructor(blk, invBlk, slotData)
    this.isActivateBeforeExpired = blk?.isActivateBeforeExpired ?? true
    this.initMissionOrderParams(blk?.missionOrderParams)
  }

   function getName(_colored = true) {
    local name = this.getStatusOrderName()
    if (name.len() == 0)
      name = loc($"item/{this.defaultLocId}")
    else
      name = format("%s \"%s\"", loc("item/order"), name)
    if (this.locId != null)
      name = loc(this.locId, name)
    return name
  }

  function getStatusOrderName() {
    return loc($"item/{this.id}", "")
  }

  function getMainActionData(isShort = false, params = {}) {
    let res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (!this.isInventoryItem || !this.amount)
      return null

    let currentEvent = getRoomEvent()
    let diffCode = events.getEventDiffCode(currentEvent)
    let diff = g_difficulty.getDifficultyByDiffCode(diffCode)
    let checkDifficulty = !isInArray(diff, this.disabledDifficulties)
    if (!this.isActive() && orderCanBeActivated() && checkDifficulty)
      return {
        btnName = loc("item/activate")
      }

    return null
  }

  getActivateInfo    = @() getOrderActivateInfoText()

  function doMainAction(cb, handler, params = null) {
    let baseResult = base.doMainAction(cb, handler, params)
    if (baseResult || !this.isInventoryItem)
      return true
    if (this.isActive() || !orderCanBeActivated())
      return false
    activateOrder(this, cb)
  }

  function getAmount() {
    return this.amount - getTimesUsedOrderItem(this)
  }

  function isActive(...) {
    return isOrderItemActive(this)
  }

  function getIcon(_addItemName = true) {
    return LayersIcon.getIconData(this.iconStyle, this.defaultIcon, 1.0, this.defaultIconStyle)
  }

  function initMissionOrderParams(blk) {
    
    this.onlyIssuerTeam = getTblValue("onlyIssuerTeam", blk, false)
    this.timeTotal = getTblValue("timeTotal", blk, 0)
    this.cooldown = getTblValue("cooldown", blk, 0)
    this.cooldownOtherTeam = getTblValue("cooldownOtherTeam", blk, 0)
    this.delayFromStart = getTblValue("delayFromStart", blk, 0)
    this.awardOnCancel = getTblValue("awardOnCancel", blk, false)
    this.awardWpByDifficulty = this.parseP3byDifficulty(blk?.awardWp)
    this.awardXpByDifficulty = this.parseP3byDifficulty(blk?.awardXp)
    this.awardGoldByDifficulty = this.parseP3byDifficulty(blk?.awardGold)
    this.disabledDifficulties = []
    if (blk != null) {
      foreach (diffName in blk % "disabledDifficulty") {
        let difficulty = g_difficulty.getDifficultyByName(diffName)
        if (difficulty != g_difficulty.UNKNOWN)
          this.disabledDifficulties.append(difficulty)
      }
    }
    this.awardMode = g_order_award_mode.getAwardModeByOrderParams(blk)

    
    this.initMissionOrderMode(blk?.mode)
  }

  function initMissionOrderMode(blk) {
    this.orderType = orderTypes.getOrderTypeByName(blk?.type)
    this.typeParams = u.isDataBlock(blk) ? convertBlk(blk) : {}
  }

  



  function checkMission(missionName) {
    let missionRestriction = getTblValue("missionRestriction", this.typeParams, null)
    if (missionRestriction == null)
      return true 
    if (u.isTable(missionRestriction))
      return this.checkMissionRestriction(missionRestriction, missionName)
    if (!u.isArray(missionRestriction)) {
      assert(format("Invalid mission restriction config in item: %s", this.id))
      return true
    }
    foreach (restrictionElement in missionRestriction)
      if (!this.checkMissionRestriction(restrictionElement, missionName))
        return false
    return true
  }

  function checkMissionRestriction(restrictionElement, missionName) {
    if (restrictionElement?.type == "missionPostfix") {
      let missionPostfix = getTblValue("postfix", restrictionElement, null)
      if (missionPostfix == null)
        return true
      let stringIndex = missionName.len() - missionPostfix.len()
      return missionName.indexof(missionPostfix, stringIndex) != stringIndex
    }
    
    return true
  }

  
  function getDescription() {
    let textParts = []
    if (!checkCurrentMission(this)) {
      let warningText = orderUseResult.RESTRICTED_MISSION.createResultMessage(false)
      textParts.append($"{colorize("redMenuButtonColor", warningText)}\n")
    }
    textParts.append(this.getLongDescription())
    return "\n".join(textParts)
  }

  
  function getLongDescription() {
    let textParts = []

    let orderTypeDescription = this.orderType.getTypeDescription(this.colorScheme)
    if (orderTypeDescription.len() > 0)
      textParts.append(orderTypeDescription)

    let typeParamsDescription = this.orderType.getParametersDescription(this.typeParams, this.colorScheme)
    if (typeParamsDescription.len() > 0)
      textParts.append(typeParamsDescription)

    if (this.timeTotal > 0)
      textParts.append("".concat(loc("items/order/timeTotal"), loc("ui/colon"),
        colorize("activeTextColor", time.secondsToString(this.timeTotal, true, true))))

    let expireText = this.getCurExpireTimeText()
    if (expireText != "")
      textParts.append(expireText)

    if (textParts.len())
      textParts.append("")

    let awardModeLocParams = { awardUnit = this.orderType.getAwardUnitText() }
    textParts.append(loc($"items/order/awardMode/{this.awardMode.name}/header", awardModeLocParams))
    foreach (difficulty in g_difficulty.types) {
      if (isInArray(difficulty, this.disabledDifficulties)
        || difficulty == g_difficulty.UNKNOWN)
        continue
      let awardText = this.awardMode.getAwardTextByDifficulty(difficulty, this)
      if (awardText.len() > 0)
        textParts.append("".concat(loc($"options/{difficulty.name}"), loc("ui/colon"), awardText))
    }
    let awardModeDescriptionFooter = loc("".concat("items/order/awardMode/",
      this.awardMode.name, "/footer"), "", awardModeLocParams)
    if (awardModeDescriptionFooter.len() > 0)
      textParts.append(awardModeDescriptionFooter)

    textParts.append("")

    if (this.delayFromStart > 0)
      textParts.append("".concat(loc("items/order/delayFromStart"), loc("ui/colon"),
        colorize("activeTextColor", time.secondsToString(this.delayFromStart, true, true))))
    textParts.append(colorize("grayOptionColor",
      loc($"items/order/onlyIssuerTeam/{this.onlyIssuerTeam.tostring()}")))
    textParts.append(colorize("grayOptionColor",
      loc($"items/order/awardOnCancel/{this.awardOnCancel.tostring()}")))

    
    
    let disabledItems = this.disabledDifficulties.map(@(diff) loc($"options/{diff.name}"))
    disabledItems.append(loc("mainmenu/events"))
    textParts.append(colorize("grayOptionColor",
      "".concat(loc("items/order/disabledDifficulties"),
        loc("ui/colon"),  loc("ui/comma").join(disabledItems))))

    return "\n".join(textParts)
  }

  
  
  

  function parseP3byDifficulty(point) {
    return {
      [g_difficulty.ARCADE] = getTblValue("x", point, 0),
      [g_difficulty.REALISTIC] = getTblValue("y", point, 0),
      [g_difficulty.SIMULATOR] = getTblValue("z", point, 0)
    }
  }

  function getParameterDescription(paramName, paramValue) {
    return "".concat(loc($"items/order/{paramName}"), ": ", colorize("activeTextColor", paramValue))
  }
}

registerItemClass(Order)

local time = require("scripts/time.nut")


class ::items_classes.Order extends ::BaseItem
{
  static iType = itemType.ORDER
  static defaultLocId = "order"
  static defaultIconStyle = "default_order_debug"
  static typeIcon = "#ui/gameuiskin#item_type_orders"
  helperCost = Cost()
  static colorScheme = {
    typeDescriptionColor = "commonTextColor"
    parameterValueColor = "activeTextColor"
    parameterLabelColor = "commonTextColor"

    // Not used here.
    objectiveDescriptionColor = "unlockActiveColor"

  }
  static includeInRecentItems = false

  canBuy = true
  allowBigPicture = false

  /** @see ::g_order_type */
  orderType = null

  // These are common order item parameters.
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

  // This object hold parameters specific to type of order.
  typeParams = null

  constructor(blk, invBlk = null, slotData = null)
  {
    base.constructor(blk, invBlk, slotData)
    isActivateBeforeExpired = blk?.isActivateBeforeExpired ?? true
    initMissionOrderParams(blk?.missionOrderParams)
  }

  /* override */ function getName(colored = true)
  {
    local name = getStatusOrderName()
    if (name.len() == 0)
      name = ::loc("item/" + defaultLocId)
    else
      name = ::format("%s \"%s\"", ::loc("item/order"), name)
    if (locId != null)
      name = ::loc(locId, name)
    return name
  }

  function getStatusOrderName()
  {
    return ::loc("item/" + id, "")
  }

  function getMainActionData(isShort = false, params = {})
  {
    local res = base.getMainActionData(isShort, params)
    if (res)
      return res
    if (!isInventoryItem || !amount)
      return null

    local currentEvent = ::SessionLobby.getRoomEvent()
    local diffCode = ::events.getEventDiffCode(currentEvent)
    local diff = ::g_difficulty.getDifficultyByDiffCode(diffCode)
    local checkDifficulty = !::isInArray(diff, disabledDifficulties)
    if (!isActive() && ::g_orders.orderCanBeActivated() && checkDifficulty)
      return {
        btnName = ::loc("item/activate")
      }

    return null
  }

  getActivateInfo    = @() ::g_orders.getActivateInfoText()

  function doMainAction(cb, handler, params = null)
  {
    local baseResult = base.doMainAction(cb, handler, params)
    if (baseResult || !isInventoryItem)
      return true
    if (isActive() || !::g_orders.orderCanBeActivated())
      return false
    ::g_orders.activateOrder(this, cb)
  }

  function getAmount()
  {
    return amount - ::g_orders.getTimesUsedOrderItem(this)
  }

  function isActive(...)
  {
    return ::g_orders.isOrderItemActive(this)
  }

  function getIcon(addItemName = true)
  {
    return ::LayersIcon.getIconData(iconStyle, defaultIcon, 1.0, defaultIconStyle)
  }

  function initMissionOrderParams(blk)
  {
    // Common parameters.
    onlyIssuerTeam = ::getTblValue("onlyIssuerTeam", blk, false)
    timeTotal = ::getTblValue("timeTotal", blk, 0)
    cooldown = ::getTblValue("cooldown", blk, 0)
    cooldownOtherTeam = ::getTblValue("cooldownOtherTeam", blk, 0)
    delayFromStart = ::getTblValue("delayFromStart", blk, 0)
    awardOnCancel = ::getTblValue("awardOnCancel", blk, false)
    awardWpByDifficulty = parseP3byDifficulty(blk?.awardWp)
    awardXpByDifficulty = parseP3byDifficulty(blk?.awardXp)
    awardGoldByDifficulty = parseP3byDifficulty(blk?.awardGold)
    disabledDifficulties = []
    if (blk != null)
    {
      foreach (diffName in blk % "disabledDifficulty")
      {
        local difficulty = ::g_difficulty.getDifficultyByName(diffName)
        if (difficulty != ::g_difficulty.UNKNOWN)
          disabledDifficulties.append(difficulty)
      }
    }
    awardMode = ::g_order_award_mode.getAwardModeByOrderParams(blk)

    // Order type specific stuff.
    initMissionOrderMode(blk?.mode)
  }

  function initMissionOrderMode(blk)
  {
    orderType = ::g_order_type.getOrderTypeByName(blk?.type)
    typeParams = ::buildTableFromBlk(blk)
  }

  /**
   * Returns true if this item can be activated
   * in mission with specified name.
   */
  function checkMission(missionName)
  {
    local missionRestriction = ::getTblValue("missionRestriction", typeParams, null)
    if (missionRestriction == null)
      return true // No restrictions at all.
    if (::u.isTable(missionRestriction))
      return checkMissionRestriction(missionRestriction, missionName)
    if (!::u.isArray(missionRestriction))
    {
      ::dagor.assertf(::format("Invalid mission restriction config in item: %s", id))
      return true
    }
    foreach (restrictionElement in missionRestriction)
      if (!checkMissionRestriction(restrictionElement, missionName))
        return false
    return true
  }

  function checkMissionRestriction(restrictionElement, missionName)
  {
    switch (restrictionElement?.type)
    {
      case "missionPostfix":
        local missionPostfix = ::getTblValue("postfix", restrictionElement, null)
        if (missionPostfix == null)
          return true
        local stringIndex = missionName.len() - missionPostfix.len()
        return missionName.indexof(missionPostfix, stringIndex) != stringIndex

      // More restrictions types to come...
    }
    return true
  }

  /** Description for tooltip. */
  function getDescription()
  {
    local textParts = []
    if (!::g_orders.checkCurrentMission(this))
    {
      local warningText = ::g_order_use_result.RESTRICTED_MISSION.createResultMessage(false)
      textParts.append($"{::colorize("redMenuButtonColor", warningText)}\n")
    }
    textParts.append(getLongDescription())
    return "\n".join(textParts)
  }

  /** Description for shop. */
  function getLongDescription()
  {
    local textParts = []

    local orderTypeDescription = orderType.getTypeDescription(colorScheme)
    if (orderTypeDescription.len() > 0)
      textParts.append(orderTypeDescription)

    local typeParamsDescription = orderType.getParametersDescription(typeParams, colorScheme)
    if (typeParamsDescription.len() > 0)
      textParts.append(typeParamsDescription)

    if (timeTotal > 0)
      textParts.append("".concat(::loc("items/order/timeTotal"), ::loc("ui/colon"),
        ::colorize("activeTextColor", time.secondsToString(timeTotal, true, true))))

    local expireText = getCurExpireTimeText()
    if (expireText != "")
      textParts.append(expireText)

    if (textParts.len())
      textParts.append("")

    local awardModeLocParams = { awardUnit = orderType.getAwardUnitText() }
    textParts.append(::loc($"items/order/awardMode/{awardMode.name}/header", awardModeLocParams))
    foreach (difficulty in ::g_difficulty.types)
    {
      if (::isInArray(difficulty, disabledDifficulties)
        || difficulty == ::g_difficulty.UNKNOWN)
        continue
      local awardText = awardMode.getAwardTextByDifficulty(difficulty, this)
      if (awardText.len() > 0)
        textParts.append("".concat(::loc($"options/{difficulty.name}"), ::loc("ui/colon"), awardText))
    }
    local awardModeDescriptionFooter = ::loc("items/order/awardMode/"
      + awardMode.name + "/footer", "", awardModeLocParams)
    if (awardModeDescriptionFooter.len() > 0)
      textParts.append(awardModeDescriptionFooter)

    textParts.append("")

    if (delayFromStart > 0)
      textParts.append("".concat(::loc("items/order/delayFromStart"), ::loc("ui/colon"),
        ::colorize("activeTextColor", time.secondsToString(delayFromStart, true, true))))
    textParts.append(::colorize("grayOptionColor",
      ::loc($"items/order/onlyIssuerTeam/{onlyIssuerTeam.tostring()}")))
    textParts.append(::colorize("grayOptionColor",
      ::loc($"items/order/awardOnCancel/{awardOnCancel.tostring()}")))

    // e.g "Arcade Battles, Simulator Battles, Events"
    // Part "Events" is hardcoded.
    local disabledItems = u.map(disabledDifficulties, function (diff) {
      return ::loc("options/" + diff.name)
    })
    disabledItems.append(::loc("mainmenu/events"))
    textParts.append(::colorize("grayOptionColor",
      "".concat(::loc("items/order/disabledDifficulties"),
        ::loc("ui/colon"),  ::loc("ui/comma").join(disabledItems))))

    return "\n".join(textParts)
  }

  //
  // Helpers
  //

  function parseP3byDifficulty(point)
  {
    return {
      [::g_difficulty.ARCADE] = ::getTblValue("x", point, 0),
      [::g_difficulty.REALISTIC] = ::getTblValue("y", point, 0),
      [::g_difficulty.SIMULATOR] = ::getTblValue("z", point, 0)
    }
  }

  function getParameterDescription(paramName, paramValue)
  {
    return ::loc("items/order/" + paramName) + ": " + ::colorize("activeTextColor", paramValue)
  }
}

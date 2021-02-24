local guidParser = require("scripts/guidParser.nut")
local itemRarity = require("scripts/items/itemRarity.nut")
local contentPreview = require("scripts/customization/contentPreview.nut")
local skinLocations = require("scripts/customization/skinLocations.nut")
local stdMath = require("std/math.nut")

::Decorator <- class
{
  id = ""
  blk = null
  decoratorType = null
  unlockId = ""
  unlockBlk = null
  isLive = false
  couponItemdefId = null
  group = ""

  category = ""
  catIndex = 0

  limit = -1

  tex = ""
  aspect_ratio = 0

  countries = null
  units = null
  allowedUnitTypes = []

  tags = null
  rarity = null

  lockedByDLC = null

  cost = null
  forceShowInCustomization = null

  isToStringForDebug = true

  constructor(blkOrId, decType)
  {
    decoratorType = decType
    if (::u.isString(blkOrId))
      id = blkOrId
    else if (::u.isDataBlock(blkOrId))
    {
      blk = blkOrId
      id = blk.getBlockName()
    }

    unlockId = ::getTblValue("unlock", blk, "")
    unlockBlk = ::g_unlocks.getUnlockById(unlockId)
    limit = ::getTblValue("limit", blk, decoratorType.defaultLimitUsage)
    category = ::getTblValue("category", blk, "")
    group = ::getTblValue("group", blk, "")

    // Only decorators from live.warthunder.com has GUID in id.
    local slashPos = id.indexof("/")
    isLive = guidParser.isGuid(slashPos == null ? id : id.slice(slashPos + 1))

    cost = decoratorType.getCost(id)
    forceShowInCustomization = ::getTblValue("forceShowInCustomization", blk, false)

    tex = blk ? ::get_decal_tex(blk, 1) : id
    aspect_ratio = blk ? decoratorType.getRatio(blk) : 1

    if ("countries" in blk)
    {
      countries = []
      foreach (country, access in blk.countries)
        if (access == true)
          countries.append("country_" + country)
    }

    units = []
    if ("units" in blk)
      units = ::split(blk.units, "; ")

    allowedUnitTypes = blk?.unitType ? (blk % "unitType") : []

    if ("tags" in blk)
    {
      tags = {}
      foreach (tag, val in blk.tags)
        tags[tag] <- val
    }

    rarity  = itemRarity.get(blk?.item_quality, blk?.name_color)

    if (blk?.marketplaceItemdefId != null && ::ItemsManager.isMarketplaceEnabled())
    {
      couponItemdefId = blk.marketplaceItemdefId

      local couponItem = ::ItemsManager.findItemById(couponItemdefId)
      if (couponItem)
        updateFromItemdef(couponItem.itemDef)
    }

    if (!isUnlocked() && !isVisible() && ("showByEntitlement" in unlockBlk))
      lockedByDLC = ::has_entitlement(unlockBlk.showByEntitlement) ? null : unlockBlk.showByEntitlement
  }

  function getName()
  {
    local name = decoratorType.getLocName(id)
    return isRare() ? ::colorize(getRarityColor(), name) : name
  }

  function getDesc()
  {
    return decoratorType.getLocDesc(id)
  }

  function isUnlocked()
  {
    return decoratorType.isPlayerHaveDecorator(id)
  }

  function isVisible()
  {
    return decoratorType.isVisible(blk, this)
  }

  function isForceVisible()
  {
    return forceShowInCustomization
  }

  function getCost()
  {
    return cost
  }

  function canRecieve()
  {
    return unlockBlk != null || ! getCost().isZero() || getCouponItemdefId() != null
  }

  function isSuitableForUnit(unit)
  {
    return unit == null || (!isLockedByCountry(unit) && !isLockedByUnit(unit))
  }

  function isLockedByCountry(unit)
  {
    if (countries == null)
      return false

    return !::isInArray(::getUnitCountry(unit), countries)
  }

  function isLockedByUnit(unit)
  {
    if (decoratorType == ::g_decorator_type.SKINS)
      return unit?.name != ::g_unlocks.getPlaneBySkinId(id)

    if (::u.isEmpty(units))
      return false

    return !::isInArray(unit?.name, units)
  }

  function getUnitTypeLockIcon()
  {
    if (::u.isEmpty(units))
      return null

    return ::get_unit_type_font_icon(::get_es_unit_type(::getAircraftByName(units[0])))
  }

  function getTypeDesc()
  {
    return decoratorType.getTypeDesc(this)
  }

  function getRestrictionsDesc()
  {
    if (decoratorType == ::g_decorator_type.SKINS)
      return ""

    local important = []
    local common    = []

    if (!::u.isEmpty(units))
    {
      local visUnits = ::u.filter(units, @(u) ::getAircraftByName(u)?.isInShop)
      important.append(::loc("options/unit") + ::loc("ui/colon") +
        ::g_string.implode(::u.map(visUnits, @(u) ::getUnitName(u)), ::loc("ui/comma")))
    }

    if (countries)
    {
      local visCountries = ::u.filter(countries, @(c) ::isInArray(c, ::shopCountriesList))
      important.append(::loc("events/countres") + " " +
        ::g_string.implode(::u.map(visCountries, @(c) ::loc(c)), ::loc("ui/comma")))
    }

    if (limit != -1)
      common.append(::loc("mainmenu/decoratorLimit", { limit = limit }))

    return ::colorize("warningTextColor", ::g_string.implode(important, "\n")) +
      (important.len() ? "\n" : "") + ::g_string.implode(common, "\n")
  }

  function getLocationDesc()
  {
    if (decoratorType != ::g_decorator_type.SKINS)
      return ""

    local mask = skinLocations.getSkinLocationsMaskBySkinId(id, false)
    local locations = mask ? skinLocations.getLocationsLoc(mask) : []
    if (!locations.len())
      return ""

    return ::loc("camouflage/for_environment_conditions") +
      ::loc("ui/colon") + ::g_string.implode(locations.map(@(l) ::colorize("activeTextColor", l)), ", ")
  }

  function getTagsDesc()
  {
    local tagsLoc = getTagsLoc()
    if (!tagsLoc.len())
      return ""

    tagsLoc = ::u.map(tagsLoc, @(txt) ::colorize("activeTextColor", txt))
    return ::loc("ugm/tags") + ::loc("ui/colon") + ::g_string.implode(tagsLoc, ::loc("ui/comma"))
  }

  function getUnlockDesc()
  {
    if (!unlockBlk)
      return ""

    local config = ::build_conditions_config(unlockBlk)

    local showStages = (config?.stages ?? []).len() > 1
    if (!showStages && config.maxVal < 0)
      return ""

    local descData = []

    local isComplete = ::UnlockConditions.isBitModeType(config.type)
                         ? stdMath.number_of_set_bits(config.curVal) >= stdMath.number_of_set_bits(config.maxVal)
                         : config.curVal >= config.maxVal

    if (showStages && !isComplete)
      descData.append(::loc("challenge/stage", {
                           stage = ::colorize("unlockActiveColor", config.curStage + 1)
                           totalStages = ::colorize("unlockActiveColor", config.stages.len())
                         }))

    local curVal = config.curVal < config.maxVal ? config.curVal : null
    descData.append(::UnlockConditions.getConditionsText(config.conditions, curVal, config.maxVal))

    return ::g_string.implode(descData, "\n")
  }

  function getCostText()
  {
    if (isUnlocked())
      return ""

    if (cost.isZero())
      return ""

    return ::loc("ugm/price")
           + ::loc("ui/colon")
           + cost.getTextAccordingToBalance()
           + "\n"
           + ::loc("shop/object/can_be_purchased")
  }

  function getRevenueShareDesc()
  {
    if (unlockBlk?.isRevenueShare != true)
      return ""

    return ::colorize("advertTextColor", ::loc("content/revenue_share"))
  }

  function getSmallIcon()
  {
    return decoratorType.getSmallIcon(this)
  }

  function canBuyUnlock(unit)
  {
    return isSuitableForUnit(unit) && !isUnlocked() && !getCost().isZero() && ::has_feature("SpendGold")
  }

  function canGetFromCoupon(unit)
  {
    return isSuitableForUnit(unit) && !isUnlocked()
      && (::ItemsManager.getInventoryItemById(getCouponItemdefId())?.canConsume() ?? false)
  }

  function canBuyCouponOnMarketplace(unit)
  {
    return isSuitableForUnit(unit) && !isUnlocked()
      && (::ItemsManager.findItemById(getCouponItemdefId())?.hasLink() ?? false)
  }

  function canUse(unit)
  {
    return isAvailable(unit) && !isOutOfLimit(unit)
  }

  function isAvailable(unit)
  {
    return isSuitableForUnit(unit) && isUnlocked()
  }

  function getCountOfUsingDecorator(unit)
  {
    if (decoratorType != ::g_decorator_type.ATTACHABLES || !isUnlocked())
      return 0

    local numUse = 0
    for (local i = 0; i < decoratorType.getAvailableSlots(unit); i++)
      if (id == decoratorType.getDecoratorNameInSlot(i) || (group != "" && group == decoratorType.getDecoratorGroupInSlot(i)))
        numUse++

    return numUse
  }

  function isOutOfLimit(unit)
  {
    if (limit < 0)
      return false

    if (limit == 0)
      return true

    return limit <= getCountOfUsingDecorator(unit)
  }

  function isRare()
  {
    return rarity.isRare
  }

  function getRarity()
  {
    return rarity.value
  }

  function getRarityColor()
  {
    return  rarity.color
  }

  function getTagsLoc()
  {
    local res = rarity.tag ? [ rarity.tag ] : []
    local tagsVisibleBlk = ::configs.GUI.get()?.decorator_tags_visible
    if (tagsVisibleBlk && tags)
      foreach (tagBlk in tagsVisibleBlk % "i")
        if (tags?[tagBlk.tag])
          res.append(::loc("content/tag/" + tagBlk.tag))
    return res
  }

  function updateFromItemdef(itemDef)
  {
    rarity = itemRarity.get(itemDef?.item_quality, itemDef?.name_color)
    tags = itemDef?.tags
  }

  function setCouponItemdefId(itemdefId)
  {
    couponItemdefId = itemdefId
  }

  function getCouponItemdefId()
  {
    return couponItemdefId
  }

  function _tostring()
  {
    return format("Decorator(%s, %s%s)", ::toString(id), decoratorType.name,
      unlockId == "" ? "" : (", unlock=" + unlockId))
  }

  function getLocParamsDesc()
  {
    return decoratorType.getLocParamsDesc(this)
  }

  function canPreview()
  {
    return isLive ? decoratorType.canPreviewLiveDecorator() : true
  }

  function doPreview()
  {
    if (canPreview())
      contentPreview.showResource(id, decoratorType.resourceType)
  }

  function isAllowedByUnitTypes(unitType)
  {
    return (allowedUnitTypes.len() == 0 || allowedUnitTypes.indexof(unitType) != null)
  }
}

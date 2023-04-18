//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format, split_by_chars } = require("string")
let guidParser = require("%scripts/guidParser.nut")
let itemRarity = require("%scripts/items/itemRarity.nut")
let contentPreview = require("%scripts/customization/contentPreview.nut")
let skinLocations = require("%scripts/customization/skinLocations.nut")
let { isMarketplaceEnabled } = require("%scripts/items/itemsMarketplace.nut")
let { copyParamsToTable, eachParam } = require("%sqstd/datablock.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { processUnitTypeArray } = require("%scripts/unit/unitClassType.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

::Decorator <- class {
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
  maxSurfaceAngle = 180

  isToStringForDebug = true

  constructor(blkOrId, decType) {
    this.decoratorType = decType
    if (::u.isString(blkOrId))
      this.id = blkOrId
    else if (::u.isDataBlock(blkOrId)) {
      this.blk = blkOrId
      this.id = this.blk.getBlockName()
    }

    this.unlockId = getTblValue("unlock", this.blk, "")
    this.unlockBlk = getUnlockById(this.unlockId)
    this.limit = getTblValue("limit", this.blk, this.decoratorType.defaultLimitUsage)
    this.category = getTblValue("category", this.blk, "")
    this.group = getTblValue("group", this.blk, "")

    // Only decorators from live.warthunder.com has GUID in id.
    let slashPos = this.id.indexof("/")
    this.isLive = guidParser.isGuid(slashPos == null ? this.id : this.id.slice(slashPos + 1))

    this.cost = this.decoratorType.getCost(this.id)
    this.maxSurfaceAngle = this.blk?.maxSurfaceAngle ?? 180

    this.tex = this.blk ? ::get_decal_tex(this.blk, 1) : this.id
    this.aspect_ratio = this.blk ? this.decoratorType.getRatio(this.blk) : 1

    if ("countries" in this.blk) {
      this.countries = []
      eachParam(this.blk.countries, function(access, country) {
        if (access == true)
          this.countries.append($"country_{country}")
      }, this)
    }

    this.units = []
    if ("units" in this.blk)
      this.units = split_by_chars(this.blk.units, "; ")

    this.allowedUnitTypes = this.blk?.unitType ? (this.blk % "unitType") : []

    if ("tags" in this.blk)
      this.tags = copyParamsToTable(this.blk.tags)

    this.rarity  = itemRarity.get(this.blk?.item_quality, this.blk?.name_color)

    if (this.blk?.marketplaceItemdefId != null && isMarketplaceEnabled()) {
      this.couponItemdefId = this.blk.marketplaceItemdefId

      let couponItem = ::ItemsManager.findItemById(this.couponItemdefId)
      if (couponItem)
        this.updateFromItemdef(couponItem.itemDef)
    }

    if (!this.isUnlocked() && !this.isVisible() && ("showByEntitlement" in this.unlockBlk))
      this.lockedByDLC = ::has_entitlement(this.unlockBlk.showByEntitlement) ? null : this.unlockBlk.showByEntitlement
  }

  function getName() {
    let name = this.decoratorType.getLocName(this.id)
    return this.isRare() ? colorize(this.getRarityColor(), name) : name
  }

  function getDesc() {
    return this.decoratorType.getLocDesc(this.id)
  }

  function isUnlocked() {
    return this.decoratorType.isPlayerHaveDecorator(this.id)
  }

  function isVisible() {
    return this.decoratorType.isVisible(this.blk, this)
  }

  function getCost() {
    return this.cost
  }

  function canRecieve() {
    return this.unlockBlk != null || ! this.getCost().isZero() || this.getCouponItemdefId() != null
  }

  function isSuitableForUnit(unit) {
    return unit == null
      || (!this.isLockedByCountry(unit) && !this.isLockedByUnit(unit) && this.isAllowedByUnitTypes(unit.unitType.tag))
  }

  function isLockedByCountry(unit) {
    if (this.countries == null)
      return false

    return !isInArray(::getUnitCountry(unit), this.countries)
  }

  function isLockedByUnit(unit) {
    if (this.decoratorType == ::g_decorator_type.SKINS)
      return unit?.name != ::g_unlocks.getPlaneBySkinId(this.id)

    if (::u.isEmpty(this.units))
      return false

    return !isInArray(unit?.name, this.units)
  }

  function getUnitTypeLockIcon() {
    if (::u.isEmpty(this.units))
      return null

    return ::get_unit_type_font_icon(::get_es_unit_type(::getAircraftByName(this.units[0])))
  }

  function getTypeDesc() {
    return this.decoratorType.getTypeDesc(this)
  }

  function getRestrictionsDesc() {
    if (this.decoratorType == ::g_decorator_type.SKINS)
      return ""

    let important = []
    let common    = []

    if (!::u.isEmpty(this.units)) {
      let visUnits = ::u.filter(this.units, @(u) ::getAircraftByName(u)?.isInShop)
      important.append(loc("options/unit") + loc("ui/colon") +
        ::g_string.implode(::u.map(visUnits, @(u) ::getUnitName(u)), loc("ui/comma")))
    }

    if (this.countries) {
      let visCountries = ::u.filter(this.countries, @(c) isInArray(c, shopCountriesList))
      important.append(loc("events/countres") + " " +
        ::g_string.implode(::u.map(visCountries, @(c) loc(c)), loc("ui/comma")))
    }

    if (this.limit != -1)
      common.append(loc("mainmenu/decoratorLimit", { limit = this.limit }))

    return colorize("warningTextColor", ::g_string.implode(important, "\n")) +
      (important.len() ? "\n" : "") + ::g_string.implode(common, "\n")
  }

  function getLocationDesc() {
    if (!this.decoratorType.hasLocations(this.id))
      return ""

    let mask = skinLocations.getSkinLocationsMaskBySkinId(this.id, false)
    let locations = mask ? skinLocations.getLocationsLoc(mask) : []
    if (!locations.len())
      return ""

    return loc("camouflage/for_environment_conditions") +
      loc("ui/colon") + ::g_string.implode(locations.map(@(l) colorize("activeTextColor", l)), ", ")
  }

  function getTagsDesc() {
    local tagsLoc = this.getTagsLoc()
    if (!tagsLoc.len())
      return ""

    tagsLoc = ::u.map(tagsLoc, @(txt) colorize("activeTextColor", txt))
    return loc("ugm/tags") + loc("ui/colon") + ::g_string.implode(tagsLoc, loc("ui/comma"))
  }

  function getCostText() {
    if (this.isUnlocked())
      return ""

    if (this.cost.isZero())
      return ""

    return loc("ugm/price")
           + loc("ui/colon")
           + this.cost.getTextAccordingToBalance()
           + "\n"
           + loc("shop/object/can_be_purchased")
  }

  function getSmallIcon() {
    return this.decoratorType.getSmallIcon(this)
  }

  function canBuyUnlock(unit) {
    return this.isSuitableForUnit(unit) && !this.isUnlocked() && !this.getCost().isZero() && hasFeature("SpendGold")
  }

  function canGetFromCoupon(unit) {
    return this.isSuitableForUnit(unit) && !this.isUnlocked()
      && (::ItemsManager.getInventoryItemById(this.getCouponItemdefId())?.canConsume() ?? false)
  }

  function canBuyCouponOnMarketplace(unit) {
    return this.isSuitableForUnit(unit) && !this.isUnlocked()
      && (::ItemsManager.findItemById(this.getCouponItemdefId())?.hasLink() ?? false)
  }

  function canUse(unit) {
    return this.isAvailable(unit) && !this.isOutOfLimit(unit)
  }

  function isAvailable(unit) {
    return this.isSuitableForUnit(unit) && this.isUnlocked()
  }

  function getCountOfUsingDecorator(unit) {
    if (this.decoratorType != ::g_decorator_type.ATTACHABLES || !this.isUnlocked())
      return 0

    local numUse = 0
    for (local i = 0; i < this.decoratorType.getAvailableSlots(unit); i++)
      if (this.id == this.decoratorType.getDecoratorNameInSlot(i) || (this.group != "" && this.group == this.decoratorType.getDecoratorGroupInSlot(i)))
        numUse++

    return numUse
  }

  function isOutOfLimit(unit) {
    if (this.limit < 0)
      return false

    if (this.limit == 0)
      return true

    return this.limit <= this.getCountOfUsingDecorator(unit)
  }

  function isRare() {
    return this.rarity.isRare
  }

  function getRarity() {
    return this.rarity.value
  }

  function getRarityColor() {
    return  this.rarity.color
  }

  function getTagsLoc() {
    let res = this.rarity.tag ? [ this.rarity.tag ] : []
    let tagsVisibleBlk = GUI.get()?.decorator_tags_visible
    if (tagsVisibleBlk && this.tags)
      foreach (tagBlk in tagsVisibleBlk % "i")
        if (this.tags?[tagBlk.tag])
          res.append(loc("content/tag/" + tagBlk.tag))
    return res
  }

  function updateFromItemdef(itemDef) {
    this.rarity = itemRarity.get(itemDef?.item_quality, itemDef?.name_color)
    this.tags = itemDef?.tags
  }

  function setCouponItemdefId(itemdefId) {
    this.couponItemdefId = itemdefId
  }

  function getCouponItemdefId() {
    return this.couponItemdefId
  }

  function _tostring() {
    return format("Decorator(%s, %s%s)", toString(this.id), this.decoratorType.name,
      this.unlockId == "" ? "" : (", unlock=" + this.unlockId))
  }

  function getLocParamsDesc() {
    return this.decoratorType.getLocParamsDesc(this)
  }

  function canPreview() {
    return this.isLive ? this.decoratorType.canPreviewLiveDecorator() : true
  }

  function doPreview() {
    if (this.canPreview())
      contentPreview.showResource(this.id, this.decoratorType.resourceType)
  }

  function isAllowedByUnitTypes(unitType) {
    return (this.allowedUnitTypes.len() == 0 || this.allowedUnitTypes.indexof(unitType) != null)
  }

  function getLocAllowedUnitTypes() {
    if (this.blk == null)
      return ""

    let processedUnitTypes = processUnitTypeArray(this.blk % "unitType")
    if (processedUnitTypes.len() == 0)
      return ""

    return colorize("activeTextColor", loc("ui/comma").join(
      processedUnitTypes.map(@(unitType) loc($"mainmenu/type_{unitType}"))))
  }

  function getVehicleDesc() {
    let locUnitTypes = this.getLocAllowedUnitTypes()
    if (locUnitTypes == "")
      return ""
    return $"{loc("mainmenu/btnUnits")}{loc("ui/colon")}{locUnitTypes}"
  }
}

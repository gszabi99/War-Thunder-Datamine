import "%scripts/guidParser.nut" as guidParser
import "%scripts/items/itemRarity.nut" as itemRarity
import "%scripts/customization/skinLocations.nut" as skinLocations
import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/items/itemsMarketplaceStatus.nut" import isMarketplaceEnabled
from "%scripts/unit/unitClassType.nut" import processUnitTypeArray
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById
from "%scripts/customization/skinUtils.nut" import getPlaneBySkinId
from "%scripts/unit/unitInfo.nut" import getUnitName, getUnitCountry
from "%scripts/unit/unitParams.nut" import getEsUnitType
from "%scripts/customization/decoratorBaseType.nut" import getTypeByUnlockedItemType
from "%scripts/customization/decoratorViewType.nut" import getViewTypeByUnlockedItemType
from "%scripts/items/itemsManagerModule.nut" import findItemById
from "%scripts/items/itemsManagerGetters.nut" import getInventoryItemById
from "%scripts/countries/countriesCustomization.nut" import getCountryOverride
from "%scripts/inventory/inventoryItemdefs.nut" import getItemdefTagsTable, getSharedItemdefTags
from "string" import format, split_by_chars
from "%sqstd/datablock.nut" import copyParamsToTable, eachParam
from "unitCustomization" import get_decal_tex
from "dagor.localize" import doesLocTextExist
from "%scripts/dagui_natives.nut" import has_entitlement
from "%scripts/dagui_library.nut" import *

let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { decoratorTypes } = require("%scripts/customization/decoratorBaseType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")

let emptyArray = freeze([])




local doPreviewImpl = @(_id, _resourceType) null
function setDecoratorPreviewer(fn) { doPreviewImpl = fn }

function getUnlockIdByBlk(blk) { return blk?.unlock ?? blk?.unlockId ?? "" }

function getCouponItemdefIdByBlk(blk) {
  let marketplaceItemdefId = blk?.marketplaceItemdefId
  return marketplaceItemdefId != null && isMarketplaceEnabled() ? marketplaceItemdefId : null
}

function getAllowedUnitTypesByBlk(blk) {
  let allowedUnitTypes = blk != null ? (blk % "unitType") : emptyArray
  return allowedUnitTypes.len() > 0 ? allowedUnitTypes : emptyArray
}

let Decorator = class {
  id = ""
  blk = null
  decoratorType = null
  decoratorViewType = null
  unlockId = ""
  unlockBlk = null
  isLive = null
  couponItemdefId = null
  group = ""

  category = ""

  limit = -1

  tex = null
  aspect_ratio = 0

  countries = null
  units = null
  allowedUnitTypes = []

  tags = null
  rarity = null

  cost = null
  maxSurfaceAngle = 180

  isToStringForDebug = true

  constructor(blkOrId, decType) {
    this.decoratorType = getTypeByUnlockedItemType(decType.unlockedItemType)
    this.decoratorViewType = getViewTypeByUnlockedItemType(decType.unlockedItemType)
    if (u.isString(blkOrId))
      this.id = blkOrId
    else if (u.isDataBlock(blkOrId)) {
      this.blk = blkOrId
      this.id = this.blk.getBlockName()
    }
    this.unlockId = getUnlockIdByBlk(this.blk)
    this.unlockBlk = getUnlockById(this.unlockId)
    this.limit = this.blk?.limit ?? this.decoratorType.defaultLimitUsage
    this.category = this.blk?.category ?? ""
    this.group = this.blk?.group ?? ""

    this.maxSurfaceAngle = this.blk?.maxSurfaceAngle ?? 180

    this.aspect_ratio = this.blk ? this.decoratorViewType.getRatio(this.blk) : 1

    let countriesBlk = this.blk?.countries
    if (countriesBlk != null) {
      let resCountries = []
      eachParam(countriesBlk, function(access, country) {
        if (access == true)
          resCountries.append($"country_{country}")
      })
      this.countries = resCountries
    }

    let unitsStr = this.blk?.units
    this.units = unitsStr == null ? emptyArray
      : split_by_chars(unitsStr, "; ")

    this.allowedUnitTypes = getAllowedUnitTypesByBlk(this.blk)

    let tagsBlk = this.blk?.tags
    if (tagsBlk != null)
      this.tags = copyParamsToTable(tagsBlk)

    this.rarity  = itemRarity.get(this.blk?.item_quality, this.blk?.name_color)

    this.couponItemdefId = getCouponItemdefIdByBlk(this.blk)
    if (this.couponItemdefId != null) {
      let couponItem = findItemById(this.couponItemdefId)
      if (couponItem)
        this.updateFromItemdef(couponItem.itemDef)
    }
  }

  function getLocalizedName() {
    return this.decoratorViewType.getLocName(this.id)
  }

  function getName() {
    let name = this.decoratorViewType.getLocName(this.id)
    return this.isRare() ? colorize(this.getRarityColor(), name) : name
  }

  function getDesc() {
    return this.decoratorViewType.getLocDesc(this.id)
  }

  function isUnlocked() {
    return this.decoratorType.isPlayerHaveDecorator(this.id)
  }

  function isVisible() {
    return this.decoratorType.isVisible(this.blk, this)
  }

  function getCost() {
    if (this.cost == null)
      this.cost = this.decoratorType.getCost(this)
    return this.cost
  }

  function canReceive() {
    return this.unlockBlk != null || ! this.getCost().isZero() || this.getCouponItemdefId() != null
  }

  function isSuitableForUnit(unit) {
    return unit == null
      || (!this.isLockedByCountry(unit) && !this.isLockedByUnit(unit) && this.isAllowedByUnitTypes(unit.unitType.tag))
  }

  function isLockedByCountry(unit) {
    if (this.countries == null)
      return false

    return !isInArray(getUnitCountry(unit), this.countries)
  }

  function isLockedByUnit(unit) {
    if (this.decoratorType == decoratorTypes.SKINS)
      return unit?.name != getPlaneBySkinId(this.id)

    if (u.isEmpty(this.units))
      return false

    return !isInArray(unit?.name, this.units)
  }

  function getUnitTypeLockIcon() {
    if (u.isEmpty(this.units))
      return null

    return unitTypes.getByEsUnitType(getEsUnitType(getAircraftByName(this.units[0]))).fontIcon
  }

  function getTypeDesc() {
    return this.decoratorViewType.getTypeDesc(this)
  }

  function getRestrictionsDesc() {
    if (this.decoratorType == decoratorTypes.SKINS)
      return ""

    let important = []
    let common    = []

    if (!u.isEmpty(this.units)) {
      let visUnits = this.units.filter(@(unit) getAircraftByName(unit)?.isInShop)
      important.append("".concat(loc("options/unit"), loc("ui/colon"),
        loc("ui/comma").join(visUnits.map(@(unit) getUnitName(unit)), true)))
    }

    if (this.countries) {
      let visCountries = this.countries.filter(@(c) isInArray(c, shopCountriesList))
      important.append(" ".concat(loc("events/countres"),
        loc("ui/comma").join(visCountries.map(@(c) loc(getCountryOverride(c))), true)))
    }

    if (this.limit != -1)
      common.append(loc("mainmenu/decoratorLimit", { limit = this.limit }))

    return "".concat(colorize("warningTextColor", "\n".join(important, true)),
      important.len() ? "\n" : "",
      "\n".join(common, true))
  }

  function getLocationDesc() {
    if (!this.decoratorType.hasLocations(this.id))
      return ""

    let mask = skinLocations.getSkinLocationsMaskBySkinId(this.id, false)
    let locations = mask ? skinLocations.getLocationsLoc(mask) : []
    if (!locations.len())
      return ""

    return "".concat(loc("camouflage/for_environment_conditions"),
      loc("ui/colon"),
      ", ".join(locations.map(@(l) colorize("activeTextColor", l)), true))
  }

  function getTagsDesc() {
    local tagsLoc = this.getTagsLoc()
    if (!tagsLoc.len())
      return ""

    tagsLoc = tagsLoc.map(@(txt) colorize("activeTextColor", txt))
    return "".concat(loc("ugm/tags"),
      loc("ui/colon"),
      loc("ui/comma").join(tagsLoc, true))
  }

  function getCostText() {
    if (this.isUnlocked())
      return ""

    let decorCost = this.getCost()
    if (decorCost.isZero())
      return ""

    return "".concat(loc("ugm/price"), loc("ui/colon"), decorCost.getTextAccordingToBalance(),
      "\n", loc("shop/object/can_be_purchased"))
  }

  function getSmallIcon() {
    return this.decoratorViewType.getSmallIcon(this)
  }

  function canBuyUnlock(unit) {
    return this.isSuitableForUnit(unit) && !this.isUnlocked() && !this.getCost().isZero() && hasFeature("SpendGold")
  }

  function canGetFromCoupon(unit) {
    return this.isSuitableForUnit(unit) && !this.isUnlocked()
      && (getInventoryItemById(this.getCouponItemdefId())?.canConsume() ?? false)
  }

  function canBuyCouponOnMarketplace(unit) {
    return this.isSuitableForUnit(unit) && !this.isUnlocked()
      && (findItemById(this.getCouponItemdefId())?.hasLink() ?? false)
  }

  function canUse(unit) {
    return this.isAvailable(unit) && !this.isOutOfLimit(unit)
  }

  function isAvailable(unit) {
    return this.isSuitableForUnit(unit) && this.isUnlocked()
  }

  function getCountOfUsingDecorator(unit) {
    if (this.decoratorType != decoratorTypes.ATTACHABLES || !this.isUnlocked())
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
          res.append(loc($"content/tag/{tagBlk.tag}"))
    return res
  }

  function getTypeDisclaimerText() {
    let { authenticity = "" } = this.tags
    if (authenticity == "")
      return ""
    let disclaimerLocKey = $"content/tag/{authenticity}/disclaimer"
    return doesLocTextExist(disclaimerLocKey) ? loc(disclaimerLocKey) : ""
  }

  function updateFromItemdef(itemDef) {
    this.rarity = itemRarity.get(itemDef?.item_quality, itemDef?.name_color)
    
    this.tags = this.getIsLive() ? getItemdefTagsTable(itemDef, { usergenerated = true })
      : getSharedItemdefTags(itemDef)
  }

  function setCouponItemdefId(itemdefId) {
    this.couponItemdefId = itemdefId
  }

  function getCouponItemdefId() {
    return this.couponItemdefId
  }

  function _tostring() {
    return format("Decorator(%s, %s%s)", toString(this.id), this.decoratorType.name,
      this.unlockId == "" ? "" : ($", unlock={this.unlockId}"))
  }

  function getLocParamsDesc() {
    return this.decoratorViewType.getLocParamsDesc(this)
  }

  function getIsLive() {
    if (this.isLive != null)
      return this.isLive

    
    let slashPos = this.id.indexof("/")
    this.isLive = guidParser.isGuid(slashPos == null ? this.id : this.id.slice(slashPos + 1))
    return this.isLive
  }

  function canPreview() {
    return this.getIsLive() ? this.decoratorType.canPreviewLiveDecorator() : true
  }

  function doPreview() {
    if (this.canPreview())
      doPreviewImpl(this.id, this.decoratorType.resourceType)
  }

  function isAllowedByUnitTypes(unitType) {
    return ((this.allowedUnitTypes.len() == 0
      && ((this.decoratorType != decoratorTypes.DECALS) || (unitType != unitTypes.HUMAN.tag)))
      || this.allowedUnitTypes.indexof(unitType) != null)
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

  function getLockedByDLC() {
    local res = ""
    let showByEntitlement = this.unlockBlk?.showByEntitlement
    if (showByEntitlement != null && !this.isUnlocked() && !this.isVisible())
      res = has_entitlement(showByEntitlement) ? "" : showByEntitlement

    return res
  }

  function getTex() {
    if (this.tex == null)
      this.tex = this.blk ? get_decal_tex(this.blk, 1) : this.id
    return this.tex
  }
}

let DecoratorProbe = class(Decorator) {
  blkIdx = -1
  canReceiveByBlkIdx = null

  constructor(blk, decType, blkIdx, canReceiveByBlkIdx) {
    this.decoratorType = getTypeByUnlockedItemType(decType.unlockedItemType)
    this.blk = blk
    this.id = blk.getBlockName()
    this.blkIdx = blkIdx
    this.canReceiveByBlkIdx = canReceiveByBlkIdx
  }

  function canReceive() {
    let known = this.canReceiveByBlkIdx[this.blkIdx]
    if (known != null)
      return known
    this.unlockBlk = getUnlockById(getUnlockIdByBlk(this.blk))
    this.couponItemdefId = getCouponItemdefIdByBlk(this.blk)
    let res = base.canReceive()
    this.canReceiveByBlkIdx[this.blkIdx] = res
    return res
  }

  function isAllowedByUnitTypes(unitType) {
    this.allowedUnitTypes = getAllowedUnitTypesByBlk(this.blk)
    return base.isAllowedByUnitTypes(unitType)
  }
}

return freeze({
  Decorator
  DecoratorProbe
  setDecoratorPreviewer
})
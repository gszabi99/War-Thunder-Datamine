from "%scripts/dagui_library.nut" import *
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getCountryFlagImg } = require("%scripts/options/countryFlagsPreset.nut")
let { getUnitCountry } = require("%scripts/unit/unitInfo.nut")

function getDecorLockStatusText(decorator, unit) {
  if (!decorator || decorator.canUse(unit))
    return null

  if (decorator.isLockedByCountry(unit))
    return "country"

  if (decorator.isLockedByUnit(unit) || !decorator.isAllowedByUnitTypes(unit.unitType.tag))
    return "achievement"

  if (decorator.lockedByDLC)
    return "noDLC"

  if (!decorator.isUnlocked() && !decorator.canBuyUnlock(unit) && !decorator.canBuyCouponOnMarketplace(unit))
    return "achievement"

  return null
}

function getDecorButtonView(decorator, unit, params = null) {
  let isTrophyContent = params?.showAsTrophyContent ?? false
  let isUnlocked = decorator.canUse(unit)
  let lockCountryImg = getCountryFlagImg($"decal_locked_{getUnitCountry(unit)}")
  let unitLocked = decorator.getUnitTypeLockIcon()
  let cost = decorator.canBuyUnlock(unit) ? decorator.getCost().getTextAccordingToBalance()
    : decorator.canBuyCouponOnMarketplace(unit) ? colorize("warningTextColor", loc("currency/gc/sign"))
    : null
  let statusLock = !isTrophyContent ? getDecorLockStatusText(decorator, unit)
    : (isUnlocked || cost != null) ? null
    : "achievement"
  let leftAmount = decorator.limit - decorator.getCountOfUsingDecorator(unit)

  return {
    id = $"decal_{decorator.id}"
    onClick = params?.onClick
    onDblClick = params?.onDblClick
    highlighted = params?.needHighlight ?? false
    ratio = clamp(decorator.decoratorType.getRatio(decorator), 0.5, 2)
    unlocked = isUnlocked
    image = decorator.decoratorType.getImage(decorator)
    tooltipId = getTooltipType("DECORATION").getTooltipId(decorator.id, decorator.decoratorType.unlockedItemType, params)
    rarityColor = decorator.isRare() ? decorator.getRarityColor() : null
    leftBottomButtonCb = params?.onCollectionBtnClick
    leftBottomButtonImg = "#ui/gameuiskin#collection.svg"
    leftBottomButtonTooltip = "#collection/go_to_collection"
    leftBottomButtonHolderId = decorator.id
    limit = decorator.limit
    isMax = leftAmount <= 0
    showLimit = !isTrophyContent && decorator.limit > 0 && !statusLock && !cost && !unitLocked
    cost
    statusLock
    unitLocked
    leftAmount
    lockCountryImg
    unseenIcon = params?.unseenIcon
  }
}

return {
  getDecorLockStatusText
  getDecorButtonView
}
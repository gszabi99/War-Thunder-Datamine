//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem
from "%scripts/items/itemsConsts.nut" import itemType

let { Cost } = require("%scripts/money.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")
let modUpgradeElem = require("%scripts/weaponry/elems/modUpgradeElem.nut")
let { getByCurBundle, canResearchItem, getItemUnlockCost, getBundleCurItem, isCanBeDisabled, isModInResearch,
  getDiscountPath, getItemStatusTbl, getItemUpgradesStatus
} = require("%scripts/weaponry/itemInfo.nut")
let { isBullets, isFakeBullet, getBulletsSetData, getModifIconItem, isBulletsWithoutTracer
} = require("%scripts/weaponry/bulletsInfo.nut")
let { getBulletsIconView } = require("%scripts/weaponry/bulletsVisual.nut")
let { getModItemName, getFullItemCostText } = require("weaponryDescription.nut")
let { MODIFICATION, WEAPON, SPARE, PRIMARY_WEAPON } = require("%scripts/weaponry/weaponryTooltips.nut")
let { debug_dump_stack } = require("dagor.debug")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { isInFlight } = require("gameplayBinding")
let { canGoToNightBattleOnUnit, needShowUnseenNightBattlesForUnit
} = require("%scripts/events/nightBattlesStates.nut")
let { needShowUnseenModTutorialForUnitMod, hasAvailableModTutorial } = require("%scripts/missions/modificationTutorial.nut")
let { getCurMissionRules } = require("%scripts/misCustomRules/missionCustomState.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { getInventoryList } = require("%scripts/items/itemsManager.nut")

dagui_propid_add_name_id("_iconBulletName")

let bulletsLocIdByCaliber = [
  "air_target", "air_targets", "all_tracers", "antibomber", "antitank", "apit", "apt",
  "armor_target", "armor_targets", "fighter", "ground_targets", "mix", "night", "stealth",
  "tracer", "tracers", "turret_ap", "turret_ap_he", "turret_ap_t", "turret_api", "turret_apit",
  "turret_apt", "turret_he", "turret_het", "universal"
]

function getLocIdPrefixByCaliber(name) {
  foreach(id in bulletsLocIdByCaliber)
    if (name.endswith(id))
      return id
  return name
}

let getBulletBeltShortName = @(id) (id == "" || id.endswith("_default")) ? loc("modification/default_bullets")
  : loc($"{getLocIdPrefixByCaliber(id)}/name/short")

function getBulletsCountText(curVal, maxVal, unallocated, guns) {
  local restText = ""
  if (unallocated && curVal < maxVal)
    restText = colorize("userlogColoredText", format(" %s", loc("ui/parentheses",
      { text = format("+%d", guns * min(unallocated, maxVal - curVal)) })))
  let valColor = (!curVal || maxVal == 0) ? "badTextColor"
    : (curVal == maxVal) ? "goodTextColor"
    : "activeTextColor"
  let valText = colorize(valColor, guns * curVal)
  return format("%s/%s%s", valText, (guns * maxVal).tostring(), restText)
}

function getPairSliderBulletsCountText(curVal, maxVal, valueMultiplier) {
  let valText = colorize("activeTextColor", valueMultiplier * curVal)
  return $"{valText}/{(valueMultiplier * (maxVal - curVal)).tostring()}"
}

function getFixedBulletsCountText(curVal, valueMultiplier) {
  return colorize("activeTextColor", valueMultiplier * curVal)
}

function getStatusIcon(unit, item) {
  if (needShowUnseenNightBattlesForUnit(unit, item.name) || needShowUnseenModTutorialForUnitMod(unit, item))
    return "#ui/gameuiskin#new_icon.svg"
  let misRules = getCurMissionRules()
  if (item.type == weaponsItem.weapon
    && isInFlight()
    && misRules.isWorldWar
    && misRules.needCheckWeaponsAllowed(unit)
    && misRules.isUnitWeaponAllowed(unit, item))
    return "#ui/gameuiskin#ww_icon.svg"

  return ""
}

function getItemImage(unit, item) {
  if (!isBullets(item)) {
    let self = callee()
    if (item.type == weaponsItem.bundle)
      return getByCurBundle(unit, item, self)

    if ("image" in item && item.image != "")
      return item.image
    if (item.type == weaponsItem.primaryWeapon && ("weaponMod" in item) && item.weaponMod)
      return self(unit, item.weaponMod)
  }
  return ""
}

function getBulletImageConfig(unit, item) {
  let bIcoItem = isBullets(item) ? item : getModifIconItem(unit, item)
  if (bIcoItem == null)
    return null

  let bulletsSet = getBulletsSetData(unit, bIcoItem.name)
  if (!unit?.isTank() && bulletsSet == null) {
    let unitName = unit.name // warning disable: -declared-never-used
    let bulletsSetName = item.name // warning disable: -declared-never-used
    debug_dump_stack()
    logerr("No bullets in bullets set")
  }
  return { iconBulletName = bIcoItem.name, bulletImg = getBulletsIconView(bulletsSet) }
}

let getTooltipId = @(unitName, mod, params)
  mod.type == weaponsItem.weapon ? WEAPON.getTooltipId(unitName, mod.name, params)
    : mod.type == weaponsItem.spare ? SPARE.getTooltipId(unitName)
    : mod.type == weaponsItem.primaryWeapon ? PRIMARY_WEAPON.getTooltipId(unitName, mod.name, params)
    : MODIFICATION.getTooltipId(unitName, mod.name, params)


function getBonusTierViewParams(item, params = {}) {
  return item.__update({  // -unwanted-modification
    itemWidth = params?.itemWidth ?? 1
    posX = params?.posX ?? 0
    posY = params?.posY ?? 0
  })
}

function getWeaponItemViewParams(id, unit, item, params = {}) {
  let res = {
    id                        = id
    itemWidth                 = params?.itemWidth ?? 1
    posX                      = params?.posX ?? 0
    posY                      = params?.posY ?? 0
    hideStatus                = item?.hideStatus ?? params?.hideStatus ?? false
    needSliderButtons         = params?.needSliderButtons ?? false
    wideItemWithSlider        = params?.wideItemWithSlider ?? false
    modUpgradeIcon            = hasFeature("ItemModUpgrade") ?
      modUpgradeElem.createMarkup("mod_upgrade_icon") : null
    collapsable               = params?.collapsable ? "yes" : "no"
    modUpgradeIconValue       = null
    bulletImg                 = null
    additionalWeaponryIcon    = null
    additionalWeaponrName     = null
    tiers                     = null
    shortcutIcon              = params?.shortcutIcon
    isSelected                = params?.selected
    isShowStatusImg           = true
    hideStatusRadio           = false
    isShowDiscount            = true
    hideProgressBlock         = false
    hideOldResearchProgress   = false
    hideBulletsChoiceBlock    = true
    hideVisualHasMenu         = false
    hideWarningIcon           = false
    isShowPrice               = true
    isBundle                  = false
    modUpgradeStatus          = ""
    nameText                  = ""
    nameTextWithPrice         = ""
    tooltipId                 = ""
    iconBulletName            = ""
    itemImg                   = ""
    discountText              = ""
    discountTooltip           = ""
    researchProgress          = ""
    progressType              = ""
    progressPaused            = ""
    oldResearchProgress       = ""
    priceText                 = ""
    optEquipped               = ""
    optStatus                 = ""
    amountText                = ""
    amountTextColor           = ""
    bulletsCountText          = ""
    decBulletsLimit           = ""
    incBulletsLimit           = ""
    sliderMax                 = ""
    sliderValue               = ""
    sliderGroupIdx            = ""
    invSliderMax              = ""
    invSliderValue            = ""
    sliderProgressType        = "new"
    statusIconImg             = ""
    actionBtnCanShow          = ""
    actionBtnText             = ""
    altBtnCanShow             = ""
    altBtnCommonCanShow       = ""
    hasUnseenAltBtn           = false
    altBtnTooltip             = ""
    altBtnBuyText             = ""
    itemTextColor             = ""
    isTooltipByHold           = params?.isTooltipByHold ?? showConsoleButtons.value
    actionHoldDummyCanShow    = "yes"
    canShowGoToModTutorialBtn = ""
    hasUnseenTutorial         = false
  }
  let isOwn = ::isUnitUsable(unit)
  local visualItem = item
  res.isBundle = item.type == weaponsItem.bundle
  if (res.isBundle) {
    visualItem = getBundleCurItem(unit, item) || visualItem
    if (!("type" in visualItem))
      visualItem.type <- weaponsItem.bundle
  }
  let bulletsManager = params?.selectBulletsByManager
  let bulGroup = bulletsManager?.canChangeBulletsCount() ?
    bulletsManager.getBulletGroupBySelectedMod(visualItem) : null
  let isPairBulletsGroup = bulGroup?.isPairBulletsGroup() ?? false
  if (isPairBulletsGroup) {
    let bulletName = getBulletsSetData(unit, visualItem.name)?.bullets[0]
    if (bulletName != null)
      res.nameText = loc($"{bulletName}/name/short")
  }
  if (res.nameText == "")
    res.nameText = visualItem?.customNameText ?? getModItemName(unit, visualItem, params?.limitedName ?? true)
  if (isBulletsWithoutTracer(unit, visualItem))
    res.nameText = $"{loc("weapon/noTracer/icon")}{res.nameText}"
  let isForceHidePlayerInfo = params?.isForceHidePlayerInfo ?? false
  let bulletImageConfig = getBulletImageConfig(unit, visualItem)
  if (bulletImageConfig != null)
    res.__update(bulletImageConfig)
  res.itemImg = getItemImage(unit, visualItem)
  let statusTbl = getItemStatusTbl(unit, visualItem)
  let canBeDisabled = isCanBeDisabled(item)
  let isSwitcher = (visualItem.type == weaponsItem.weapon) ||
    (visualItem.type == weaponsItem.primaryWeapon) ||
    isBullets(visualItem)
  let discount = ::getDiscountByPath(
    getDiscountPath(unit, visualItem, statusTbl.discountType))
  let itemCostText = getFullItemCostText(unit, item)
  local priceText = statusTbl.showPrice && (params?.canShowPrice ?? true) ? itemCostText : ""
  let flushExp = params?.flushExp ?? 0
  let canShowResearch = params?.canShowResearch ?? true
  let canResearch = canResearchItem(unit, visualItem, false)
  let itemReqExp = visualItem?.reqExp ?? 0
  let isModResearching = canShowResearch &&
                               canResearch &&
                               statusTbl.modExp >= 0 &&
                               statusTbl.modExp < itemReqExp &&
                               !statusTbl.amount
  let isInResearch = isModInResearch(unit, visualItem)
  let isResearchInProgress = isModResearching && isInResearch
  let isResearchPaused = isModResearching && statusTbl.modExp > 0 && !isInResearch
  local showStatus = false
  res.optEquipped = isForceHidePlayerInfo || statusTbl.equipped ? "yes" : "no"
  if (params?.canShowStatusImage ?? true)
    if (visualItem.type == weaponsItem.weapon || isBullets(visualItem))
      showStatus = true
    else if (visualItem.type == weaponsItem.modification ||
      visualItem.type == weaponsItem.expendables)
        showStatus = (canBeDisabled && statusTbl.amount)
          || (statusTbl.showPrice && !statusTbl.unlocked)
  res.isShowStatusImg = showStatus && (! statusTbl.unlocked || ! isSwitcher)
  res.hideStatusRadio = !showStatus || !statusTbl.unlocked ||
    !isSwitcher || isFakeBullet(visualItem.name)
  res.hideStatus = isResearchInProgress || res.hideStatus
  res.isShowDiscount = discount > 1
  let isScoreCost = isInFlight() && getCurMissionRules().isScoreRespawnEnabled
  let haveDiscount = discount > 0 && statusTbl.canShowDiscount && itemCostText != ""
  if (haveDiscount && !isScoreCost) {
    if (res.isShowDiscount) {
      res.discountText = "".concat("-", discount, "%")
      res.discountTooltip = format(
        loc("".concat("discount/", statusTbl.discountType, "/tooltip")), discount.tostring())
    }
    if (priceText != "")
      priceText = $"<color=@goodTextColor>{priceText}</color>"
  }
  res.nameTextWithPrice = res.nameText
  let spawnScoreCost = getFullItemCostText(unit, item, true)
  if (statusTbl.showPrice && (params?.canShowPrice ?? true) && spawnScoreCost != "")
    res.nameTextWithPrice = "".concat(res.nameTextWithPrice, loc("ui/parentheses/space", { text = spawnScoreCost }))
  let showProgress = isResearchInProgress || isResearchPaused
  local isNestedFreeModNearUnlocked = false
  if ((itemReqExp == 0) && (visualItem?.reqModification ?? []).len() > 0) { // isNestedFreeMod
    let parentMod = getModificationByName(unit, visualItem.reqModification[0])
    isNestedFreeModNearUnlocked = canResearchItem(unit, parentMod) // NearUnlocked
  }
  res.isShowPrice = (!showProgress && (statusTbl.showPrice || canResearch)) || isNestedFreeModNearUnlocked
  res.hideProgressBlock = !showProgress
  if (showProgress) {
    let diffExp = params?.diffExp ?? 0
    let paused = isResearchPaused ? "yes" : "no"
    res.researchProgress = (itemReqExp ? statusTbl.modExp.tofloat() / itemReqExp : 1) * 1000
    res.progressType = diffExp ? "new" : ""
    res.progressPaused = paused
    let oldExp = max(0, statusTbl.modExp - diffExp)
    res.hideOldResearchProgress = oldExp == 0
    res.oldResearchProgress = (itemReqExp ? oldExp.tofloat() / itemReqExp : 1) * 1000
  }
  else {
    if (statusTbl.showPrice)
      res.priceText = priceText
    else if ((canResearch && !isResearchInProgress && !isResearchPaused) || isNestedFreeModNearUnlocked) {
      let showExp = itemReqExp - statusTbl.modExp
      local rpText = Cost().setRp(showExp).toStringWithParams({ isRpAlwaysShown = isNestedFreeModNearUnlocked })
      if (flushExp > 0 && flushExp >= showExp)
        rpText = colorize("goodTextColor", rpText)
      res.priceText = rpText
    }
  }
  local optStatus = "locked"
  if (params?.visualDisabled ?? false)
    optStatus = "disabled"
  else if (statusTbl.amount)
    optStatus = "owned"
  else if (params?.showButtons && statusTbl.canBuyForWP)
    optStatus = "canBuyForWP"
  else if (isForceHidePlayerInfo || statusTbl.unlocked)
    optStatus = "unlocked"
  else if (isInResearch && visualItem.type == weaponsItem.modification)
    optStatus = canShowResearch ? "research" : "researchable"
  else if (canResearchItem(unit, visualItem))
    optStatus = "researchable"
  res.optStatus = optStatus
  if (!isForceHidePlayerInfo) {
    res.amountText = ::getAmountAndMaxAmountText(statusTbl.amount,
      statusTbl.maxAmount, statusTbl.showMaxAmount)
    res.amountTextColor = statusTbl.amount < statusTbl.amountWarningValue ? "weaponWarning" : ""
  }
  res.hideWarningIcon = isForceHidePlayerInfo || !statusTbl.unlocked || !statusTbl.showMaxAmount ||
    statusTbl.amount >= statusTbl.amountWarningValue
  res.itemTextColor = res.isShowStatusImg ?
    "badTextColor" : res.hideWarningIcon ?
      "commonTextColor" : "warningTextColor"
  let hideBullets = bulGroup == null || bulGroup.gunInfo.isBulletBelt
  res.hideBulletsChoiceBlock = hideBullets
  local pairModName = null
  if (!hideBullets) {
    let guns = bulGroup.guns
    let { cartridge } = bulGroup.gunInfo
    let maxVal = bulGroup.maxBulletsCount
    let curVal = bulGroup.bulletsCount
    let unallocated = bulletsManager.getUnallocatedBulletCount(bulGroup)
    let canChangePairBulletsCount = bulGroup.canChangePairBulletsCount()
    res.bulletsCountText = !isPairBulletsGroup ? getBulletsCountText(curVal, maxVal, unallocated, guns)
      : canChangePairBulletsCount ? getPairSliderBulletsCountText(curVal, maxVal, guns * cartridge)
      : getFixedBulletsCountText(curVal, guns * cartridge)
    res.needSliderButtons = res.needSliderButtons
      && (!isPairBulletsGroup || canChangePairBulletsCount)
    if (res.needSliderButtons) {
      res.decBulletsLimit = curVal != 0 ? "no" : "yes"
      res.incBulletsLimit = curVal == maxVal
        || (!isPairBulletsGroup && unallocated == 0) ? "yes" : "no"
    }
    res.sliderMax = maxVal.tostring()
    res.sliderValue = curVal
    res.sliderGroupIdx = bulGroup.groupIndex
    res.invSliderMax = maxVal.tostring()
    res.invSliderValue = curVal
    let linkedBulGroup = !isPairBulletsGroup || !canChangePairBulletsCount ? null
      : bulletsManager.getLinkedBulletsGroup(bulGroup)
    if (linkedBulGroup != null) {
      res.sliderProgressType = "doubleProgress"
      let pairVisualItem = linkedBulGroup.getSelBullet()
      pairModName = pairVisualItem.name
      let pairStatusTbl = getItemStatusTbl(unit, pairVisualItem)
      let amountText = ::getAmountAndMaxAmountText(pairStatusTbl.amount,
        pairStatusTbl.maxAmount, pairStatusTbl.showMaxAmount)
      let amountTextColor = pairStatusTbl.amount < pairStatusTbl.amountWarningValue
        ? "weaponWarning" : ""
      let bulletName = getBulletsSetData(unit, pairVisualItem.name)?.bullets[0]
      if (bulletName != null)
        res.additionalWeaponrName = loc($"{bulletName}/name/short")
      let additionalBulletImageConfig = getBulletImageConfig(unit, pairVisualItem)
      if (additionalBulletImageConfig != null)
        res.additionalWeaponryIcon = additionalBulletImageConfig.__update({
          itemImg = ""
          hideWarningIcon = true
          amountText
          amountTextColor
        })
    }
  }
  res.tooltipId = params?.tooltipId ?? getTooltipId(unit.name, visualItem, params.__merge({
    hasPlayerInfo = (params?.hasPlayerInfo ?? true) && !isForceHidePlayerInfo
    pairModName
  }))
  res.hideVisualHasMenu = !res.isBundle && !params?.hasMenu
  res.modUpgradeStatus = getItemUpgradesStatus(unit, visualItem)
  res.statusIconImg = getStatusIcon(unit, item)
  if (params?.showButtons) {
    local btnText = ""
    if (res.isBundle)
      btnText = loc("mainmenu/btnAirGroupOpen")
    else if (isOwn && statusTbl.unlocked) {
      if (!statusTbl.amount || (visualItem.type == weaponsItem.spare && statusTbl.canBuyMore))
        btnText = loc("mainmenu/btnBuy")
      else if (isSwitcher && !statusTbl.equipped)
        btnText = loc("mainmenu/btnSelect")
      else if (visualItem.type == weaponsItem.modification || visualItem.type == weaponsItem.expendables)
        btnText = statusTbl.equipped ?
          (canBeDisabled ? loc("mod/disable") : "") : loc("mod/enable")
    }
    else if (canResearchItem(unit, visualItem) ||
      (canResearchItem(unit, visualItem, false) &&
      (flushExp > 0 || !canShowResearch)))
      btnText = loc("mainmenu/btnResearch")
    btnText = params?.actionBtnText ?? btnText
    res.actionBtnCanShow = btnText == "" ? "no" : "yes"
    res.actionBtnText = btnText
    local altBtnText = ""
    local altBtnTooltip = ""
    if (statusTbl.goldUnlockable && !((params?.researchMode ?? false) && flushExp > 0))
      altBtnText = getItemUnlockCost(unit, item).tostring()
    if (altBtnText != "")
      altBtnText = loc("mainmenu/btnBuy") + loc("ui/parentheses/space", { text = altBtnText })
    else if (visualItem.type == weaponsItem.spare && isOwn) {
      if (getInventoryList(itemType.UNIVERSAL_SPARE).len() && statusTbl.canBuyMore) {
        altBtnText = loc("items/universalSpare/activate", { icon = loc("icon/universalSpare") })
        altBtnTooltip = loc("items/universalSpare/activate/tooltip")
      }
    }
    else if (statusTbl.amount && statusTbl.maxAmount > 1 && statusTbl.amount < statusTbl.maxAmount
      && !res.isBundle)
        altBtnText = loc("mainmenu/btnBuy")
    else if (visualItem.type == weaponsItem.modification && isOwn) {
      if (statusTbl.curUpgrade < statusTbl.maxUpgrade
          && getInventoryList(itemType.MOD_UPGRADE).len())
        altBtnText = loc("mainmenu/btnUpgrade")
      else if (statusTbl.unlocked && canGoToNightBattleOnUnit(unit, visualItem.name)) {
        altBtnText = loc("night_battles")
        res.altBtnCommonCanShow = "yes"
        res.hasUnseenAltBtn = needShowUnseenNightBattlesForUnit(unit, visualItem.name)
      }
    }
    res.canShowGoToModTutorialBtn = hasAvailableModTutorial(unit, item) ? "yes" : "no"
    res.hasUnseenTutorial = needShowUnseenModTutorialForUnitMod(unit, item)

    res.altBtnCanShow = (altBtnText == "" || res.altBtnCommonCanShow == "yes") ? "no" : "yes"
    res.altBtnTooltip = altBtnTooltip
    res.altBtnBuyText = altBtnText

    res.actionHoldDummyCanShow = (btnText == "" && res.canShowGoToModTutorialBtn == "no")
      ? "yes"
      : "no"
  }

  return res
}

function updateModItem(unit, item, itemObj, showButtons, handler, params = {}) {
  let id = itemObj?.id ?? ""
  let viewParams = getWeaponItemViewParams(id, unit, item,
    params.__merge({ showButtons = showButtons }))
  let { isTooltipByHold, tooltipId, actionBtnCanShow, actionHoldDummyCanShow } = viewParams
  // For single-line textareas, enforce non-breaking text to prevent line wrapping,
  // ensuring maximum visibility of the displayed text.
  let isSingleLine = !viewParams.hideBulletsChoiceBlock
  itemObj.findObject("name").setValue(isSingleLine
    ? ::stringReplace(viewParams.nameText, " ", nbsp)
    : viewParams.nameText)
  if (isTooltipByHold)
    itemObj.tooltipId = tooltipId
  let tooltipObj = itemObj.findObject(isTooltipByHold ? "centralBlock" : $"tooltip_{id}")
  if (checkObj(tooltipObj))
    tooltipObj.tooltipId = tooltipId

  if (viewParams.iconBulletName != "") {
    let divObj = itemObj.findObject("bullets")
    if (checkObj(divObj)) {
      divObj._iconBulletName = viewParams.iconBulletName
      let data = handyman.renderCached(("%gui/weaponry/bullets.tpl"), viewParams.bulletImg)
      itemObj.getScene().replaceContentFromText(divObj, data, data.len(), handler)
    }
  }

  let imgObj = itemObj.findObject("image")
  imgObj["background-image"] = viewParams.iconBulletName != "" ? "" : viewParams.itemImg

  showObjById("status_image", viewParams.isShowStatusImg, itemObj)
  showObjById("status_radio", !viewParams.hideStatusRadio, itemObj)
  showObjById("modItem_statusBlock", !viewParams.hideStatus, itemObj)
  showObjById("modItem_discount", viewParams.isShowDiscount, itemObj)

  if (viewParams.isShowDiscount) {
    let dObj = itemObj.findObject("discount")
    if (checkObj(dObj)) {
      dObj.setValue(viewParams.discountText)
      dObj.tooltip = viewParams.discountTooltip
    }
  }

  let priceObj = itemObj.findObject("price")
  if (checkObj(priceObj)) {
    priceObj.setValue(viewParams.priceText)
    priceObj.show(viewParams.isShowPrice)
  }

  let progressBlock = itemObj.findObject("mod_research_block")
  if (checkObj(progressBlock)) {
    progressBlock.show(!viewParams.hideProgressBlock)
    if (!viewParams.hideProgressBlock) {
      let progressObj = progressBlock.findObject("mod_research_progress")
      progressObj.setValue(viewParams.researchProgress)
      progressObj.type = viewParams.progressType
      progressObj.paused = viewParams.progressPaused

      let progressObjOld = progressBlock.findObject("mod_research_progress_old")
      progressObjOld.show(!viewParams.hideOldResearchProgress)
      progressObjOld.setValue(viewParams.oldResearchProgress)
      progressObjOld.paused = viewParams.progressPaused
    }
  }

  itemObj.equipped = viewParams.optEquipped
  itemObj.status = viewParams.optStatus
  let iconObj = itemObj.findObject("icon")
  if (checkObj(iconObj)) {
    iconObj.equipped = viewParams.optEquipped
    iconObj.status = viewParams.optStatus
  }

  let amountObject = itemObj.findObject("amount")
  if (checkObj(amountObject)) {
    amountObject.setValue(viewParams.amountText)
    amountObject.overlayTextColor = viewParams.amountTextColor
  }

  showObjById("warning_icon", !viewParams.hideWarningIcon, itemObj)

  if (!viewParams.hideBulletsChoiceBlock) {
    let holderObj = showObjById("bullets_amount_choice_block", true, itemObj)
    let textObj = holderObj.findObject("bulletsCountText")
    if (checkObj(textObj))
      textObj.setValue(viewParams.bulletsCountText)
    let { needSliderButtons } = viewParams
    if (needSliderButtons) {
      let btnDec = holderObj.findObject("buttonDec")
      if (checkObj(btnDec))
        btnDec.bulletsLimit = viewParams.decBulletsLimit

      let btnIncr = holderObj.findObject("buttonInc")
      if (checkObj(btnIncr))
        btnIncr.bulletsLimit = viewParams.incBulletsLimit
    }

    showObjById("slider_button", needSliderButtons, holderObj)
    let slidObj = holderObj.findObject("bulletsSlider")
    if (checkObj(slidObj)) {
      slidObj.max = viewParams.sliderMax
      slidObj.type = viewParams.sliderProgressType
      slidObj.setValue(viewParams.sliderValue)
    }
    let invSlidObj = holderObj.findObject("invisBulletsSlider")
    if (checkObj(invSlidObj)) {
      invSlidObj.groupIdx = viewParams.sliderGroupIdx
      invSlidObj.max = viewParams.invSliderMax
      if (invSlidObj.getValue() != viewParams.invSliderValue)
        invSlidObj.setValue(viewParams.invSliderValue)
    }
  }

  showObjById("modItem_visualHasMenu", !viewParams.hideVisualHasMenu, itemObj)

  let upgradesObj = itemObj.findObject("upgrade_img")
  if (checkObj(upgradesObj))
    upgradesObj.upgradeStatus = viewParams.modUpgradeStatus

  let statusIcon = itemObj.findObject("status_icon")
  if (checkObj(statusIcon))
    statusIcon["background-image"] = viewParams.statusIconImg

  modUpgradeElem.setValueToObj(itemObj.findObject("mod_upgrade_icon"), unit.name, item.name)

  if (isTooltipByHold) {
    let dummyBtn = itemObj.findObject("actionHoldDummy")
    if (dummyBtn?.isValid())
      dummyBtn.canShow = actionHoldDummyCanShow
  }

  if (!showButtons)
    return

  let actionBtn = itemObj.findObject("actionBtn")
  actionBtn.canShow = actionBtnCanShow
  actionBtn.setValue(viewParams.actionBtnText)

  let { altBtnCanShow, altBtnCommonCanShow, altBtnTooltip, altBtnBuyText, canShowGoToModTutorialBtn, hasUnseenTutorial
  } = viewParams
  let altBtn = itemObj.findObject("altActionBtn")
  altBtn.canShow = altBtnCanShow
  if (altBtnCanShow == "yes") {
    if (altBtnTooltip != "")
      altBtn.tooltip = altBtnTooltip

    let textObj = altBtn.findObject("altBtnBuyText")
    if (checkObj(textObj))
      textObj.setValue(altBtnBuyText)
  }

  let altBtnCommon = itemObj.findObject("altActionBtnCommon")
  altBtnCommon.canShow = altBtnCommonCanShow
  if (altBtnCommonCanShow == "yes") {
    if (altBtnTooltip != "")
      altBtnCommon.tooltip = altBtnTooltip
    altBtnCommon.findObject("altActionBtnCommon_text").setValue(altBtnBuyText)
  }

  let goToModTutorBtn = itemObj.findObject("goToModTutorial")
  goToModTutorBtn.canShow = canShowGoToModTutorialBtn
  if (canShowGoToModTutorialBtn == "yes")
    goToModTutorBtn.btnName = actionBtnCanShow == "no" ? "A"
      : altBtnCanShow == "no" && altBtnCommonCanShow == "no" ? "X"
      : "RT"
  itemObj.findObject("goToModTutorial_new_icon").show(hasUnseenTutorial)
}

function getSkinModView(id, unit, item, pos) {
  let { decor, canDo, progress } = item
  return {
    id
    itemImg                = decor.decoratorType.getImage(decor)
    nameText               = "#skins"
    isTooltipByHold        = showConsoleButtons.value
    tooltipId              = getTooltipType("UNLOCK_SHORT").getTooltipId(decor.unlockBlk.id)
    optStatus              = canDo ? "research" : "owned"
    hideProgressBlock      = !canDo
    researchProgress       = progress
    hideBulletsChoiceBlock = true
    hideStatus             = true
    hideVisualHasMenu      = true
    hideWarningIcon        = true
    actionBtnCanShow       = decor.canPreview() ? "yes" : "no"
    actionBtnText          = unit.isUsable()
      ? loc("mainmenu/btnShowroom")
      : loc("mainmenu/btnPreview")
  }.__update(pos)
}

function createModItemLayout(id, unit, item, iType, params = {}) {
  if (!("type" in item))
    item.type <- iType

  let { isBonusTier = false, isFakeMod = false } = item
  if (isBonusTier || isFakeMod)
    return handyman.renderCached("%gui/weaponry/bonusTierItem.tpl", getBonusTierViewParams(item, params))

  if (item.type == weaponsItem.skin)
    return handyman.renderCached("%gui/weaponry/weaponItem.tpl", getSkinModView(id, unit, item, params))

  return handyman.renderCached("%gui/weaponry/weaponItem.tpl", getWeaponItemViewParams(id, unit, item, params))
}

function createModItem(id, unit, item, iType, holderObj, handler, params = {}) {
  let data = createModItemLayout(id, unit, item, iType, params)
  holderObj.getScene().appendWithBlk(holderObj, data, handler)
  return holderObj.findObject(id)
}

local function createModBundle(id, unit, itemsList, itemsType, holderObj, handler, params = {}) {
  if (itemsList.len() == 0)
    return null

  let guiScene = holderObj.getScene()
  let { maxItemsInColumn = 5, createItemLayoutFunc = createModItemLayout } = params
  let bundleItem = {
      name = id
      type = weaponsItem.bundle
      hideStatus = true
      itemsType = itemsType
      subType = params?.subType ?? 0
      itemsList = itemsList
    }
  if (itemsType == weaponsItem.bullets)
    itemsType = weaponsItem.modification

  if (itemsList.len() == 1) {
    itemsList[0].hideStatus <- true //!!FIX ME: Remove modify data
    let { itemLayout } = createItemLayoutFunc.call(handler, id, unit, itemsList[0], itemsType, params)
    guiScene.appendWithBlk(holderObj, itemLayout, handler)
    return itemsList[0]
  }

  let { itemLayout, itemId } = createItemLayoutFunc.call(handler, id, unit, bundleItem, bundleItem.type, params)
  guiScene.appendWithBlk(holderObj, itemLayout, handler)
  let bundleObj = holderObj.findObject(itemId)
  bundleObj["class"] = "dropDown"

  let hoverObj = guiScene.createElementByObject(bundleObj, "%gui/weaponry/weaponBundleTop.blk", "hoverSize", handler)

  let cols = ((itemsList.len() - 1) / maxItemsInColumn + 1).tointeger()
  let rows = ((itemsList.len() - 1) / cols + 1).tointeger()
  let itemsObj = hoverObj.findObject("items_field")
  local itemsData = ""
  foreach (idx, item in itemsList)
    itemsData = "\n".concat(itemsData, createItemLayoutFunc.call(handler, $"{id}_{idx}", unit, item,
      itemsType, { posX = (idx / rows).tointeger(), posY = idx % rows }).itemLayout)
  if (itemsData != "")
    this.guiScene.appendWithBlk(itemsObj, itemsData, this)

  itemsObj.width = cols + "@modCellWidth"
  itemsObj.height = rows + "@modCellHeight"

  hoverObj.width = cols + "@modCellWidth"
  let rootSize = guiScene.getRoot().getSize()
  let rightSide = bundleObj.getPosRC()[0] < 0.7 * rootSize[0] //better to use width const here, but need const calculator from dagui for that
  if (rightSide)
    hoverObj.pos = "0.5pw-0.5@modCellWidth, ph"
  else
    hoverObj.pos = "0.5pw+0.5@modCellWidth-w, ph"

  let cellObj = params?.cellSizeObj || bundleObj
  let cellSize = cellObj.getSize()
  let extraHeight = to_pixels("2@modBundlePopupBgPadH + 1@modBundlePopupAdditionalBtnsHeight")
  hoverObj["height-end"] = (cellSize[1] * rows + extraHeight).tointeger().tostring()
  return bundleItem
}

function updateItemBulletsSlider(itemObj, bulletsManager, bulGroup) {
  let show = bulGroup != null && bulletsManager != null && bulletsManager.canChangeBulletsCount()
  let holderObj = showObjById("bullets_amount_choice_block", show, itemObj)
  if (!show || !holderObj)
    return

  let guns = bulGroup.guns
  let { cartridge = 1 } = bulGroup.gunInfo
  let maxVal = bulGroup.maxBulletsCount
  let curVal = bulGroup.bulletsCount
  let unallocated = bulletsManager.getUnallocatedBulletCount(bulGroup)
  let isPairBulletsGroup = bulGroup.isPairBulletsGroup()
  let canChangePairBulletsCount = bulGroup.canChangePairBulletsCount()

  let textObj = holderObj.findObject("bulletsCountText")
  if (checkObj(textObj))
    textObj.setValue(!isPairBulletsGroup ? getBulletsCountText(curVal, maxVal, unallocated, guns)
      : canChangePairBulletsCount ? getPairSliderBulletsCountText(curVal, maxVal, guns * cartridge)
      : getFixedBulletsCountText(curVal, guns * cartridge))

  let btnDec = holderObj.findObject("buttonDec")
  if (checkObj(btnDec))
    btnDec.bulletsLimit = curVal != 0 ? "no" : "yes"

  let btnIncr = holderObj.findObject("buttonInc")
  if (checkObj(btnIncr))
    btnIncr.bulletsLimit = curVal == maxVal
      || (!isPairBulletsGroup && unallocated == 0) ? "yes" : "no"

  let slidObj = holderObj.findObject("bulletsSlider")
  if (checkObj(slidObj)) {
    slidObj.max = maxVal.tostring()
    slidObj.setValue(curVal)
  }
  let invSlidObj = holderObj.findObject("invisBulletsSlider")
  if (checkObj(invSlidObj)) {
    invSlidObj.groupIdx = bulGroup.groupIndex
    invSlidObj.max = maxVal.tostring()
    if (invSlidObj.getValue() != curVal)
      invSlidObj.setValue(curVal)
  }
}

return {
  getWeaponItemViewParams         = getWeaponItemViewParams
  updateModItem                   = updateModItem
  createModItemLayout             = createModItemLayout
  createModItem                   = createModItem
  createModBundle                 = createModBundle
  updateItemBulletsSlider         = updateItemBulletsSlider
  getBulletBeltShortName
}

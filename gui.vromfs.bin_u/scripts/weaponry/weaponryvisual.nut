//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let modUpgradeElem = require("%scripts/weaponry/elems/modUpgradeElem.nut")
let { getByCurBundle, canResearchItem, getItemUnlockCost, getBundleCurItem, isCanBeDisabled, isModInResearch,
  getDiscountPath, getItemStatusTbl, getItemUpgradesStatus
} = require("%scripts/weaponry/itemInfo.nut")
let { isBullets, isFakeBullet, getBulletsSetData, getModifIconItem } = require("%scripts/weaponry/bulletsInfo.nut")
let { getBulletsIconView } = require("%scripts/weaponry/bulletsVisual.nut")
let { weaponItemTplPath } = require("%scripts/weaponry/getWeaponItemTplPath.nut")
let { getModItemName, getFullItemCostText } = require("weaponryDescription.nut")
let { MODIFICATION, WEAPON, SPARE, PRIMARY_WEAPON } = require("%scripts/weaponry/weaponryTooltips.nut")

::dagui_propid.add_name_id("_iconBulletName")

let function getBulletsCountText(curVal, maxVal, unallocated, guns) {
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

let function getStatusIcon(unit, item) {
  let misRules = ::g_mis_custom_state.getCurMissionRules()
  if (item.type == weaponsItem.weapon
    && ::is_in_flight()
    && misRules.isWorldWar
    && misRules.needCheckWeaponsAllowed(unit)
    && misRules.isUnitWeaponAllowed(unit, item))
    return "#ui/gameuiskin#ww_icon.svg"

  return ""
}

let function getItemImage(unit, item) {
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

let getTooltipId = @(unitName, mod, params)
  mod.type == weaponsItem.weapon ? WEAPON.getTooltipId(unitName, mod.name, params)
    : mod.type == weaponsItem.spare ? SPARE.getTooltipId(unitName)
    : mod.type == weaponsItem.primaryWeapon ? PRIMARY_WEAPON.getTooltipId(unitName, mod.name, params)
    : MODIFICATION.getTooltipId(unitName, mod.name, params)

let function getWeaponItemViewParams(id, unit, item, params = {}) {
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
    statusIconImg             = ""
    actionBtnCanShow          = ""
    actionBtnText             = ""
    altBtnCanShow             = ""
    altBtnTooltip             = ""
    altBtnBuyText             = ""
    itemTextColor             = ""
    isTooltipByHold           = params?.isTooltipByHold ?? ::show_console_buttons
    actionHoldDummyCanShow    = "yes"
  }

  let isOwn = ::isUnitUsable(unit)
  local visualItem = item
  res.isBundle = item.type == weaponsItem.bundle
  if (res.isBundle) {
    visualItem = getBundleCurItem(unit, item) || visualItem
    if (!("type" in visualItem))
      visualItem.type <- weaponsItem.bundle
  }
  res.nameText = visualItem?.customNameText ?? getModItemName(unit, visualItem, params?.limitedName ?? true)
  let isForceHidePlayerInfo = params?.isForceHidePlayerInfo ?? false
  res.tooltipId = params?.tooltipId ?? getTooltipId(unit.name, visualItem, params.__merge({
    hasPlayerInfo = (params?.hasPlayerInfo ?? true) && !isForceHidePlayerInfo
  }))
  let bIcoItem = isBullets(visualItem) ? visualItem : getModifIconItem(unit, visualItem)
  if (bIcoItem) {
    let bulletsSet = getBulletsSetData(unit, bIcoItem.name)
    assert(unit?.isTank() || bulletsSet != null,
          $"No bullets in bullets set {visualItem.name} for {unit.name}")

    res.iconBulletName = bIcoItem.name
    res.bulletImg = getBulletsIconView(bulletsSet)
  }
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
  let isScoreCost = ::is_in_flight()
    && ::g_mis_custom_state.getCurMissionRules().isScoreRespawnEnabled
  let haveDiscount = discount > 0 && statusTbl.canShowDiscount && itemCostText != ""
  if (haveDiscount && !isScoreCost) {
    if (res.isShowDiscount) {
      res.discountText = "".concat("-", discount, "%")
      res.discountTooltip = format(
        loc("".concat("discount/", statusTbl.discountType, "/tooltip")), discount.tostring())
    }
    if (priceText != "")
      priceText = "<color=@goodTextColor>" + priceText + "</color>"
  }
  res.nameTextWithPrice = res.nameText
  let spawnScoreCost = getFullItemCostText(unit, item, true)
  if (statusTbl.showPrice && (params?.canShowPrice ?? true) && spawnScoreCost != "")
    res.nameTextWithPrice = "".concat(res.nameTextWithPrice, loc("ui/parentheses/space", { text = spawnScoreCost }))
  let showProgress = isResearchInProgress || isResearchPaused
  res.isShowPrice = !showProgress && (statusTbl.showPrice || canResearch)
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
    else if (canResearch && !isResearchInProgress && !isResearchPaused) {
      let showExp = itemReqExp - statusTbl.modExp
      local rpText = ::Cost().setRp(showExp).tostring()
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
  let bulletsManager = params?.selectBulletsByManager
  let bulGroup = bulletsManager?.canChangeBulletsCount() ?
    bulletsManager.getBulletGroupBySelectedMod(visualItem) : null
  res.hideBulletsChoiceBlock = bulGroup == null
  if (!res.hideBulletsChoiceBlock) {
    let guns = bulGroup.guns
    let maxVal = bulGroup.maxBulletsCount
    let curVal = bulGroup.bulletsCount
    let unallocated = bulletsManager.getUnallocatedBulletCount(bulGroup)
    res.bulletsCountText = getBulletsCountText(curVal, maxVal, unallocated, guns)
    if (res.needSliderButtons) {
      res.decBulletsLimit = curVal != 0 ? "no" : "yes"
      res.incBulletsLimit = (curVal != maxVal && unallocated != 0) ? "no" : "yes"
    }
    res.sliderMax = maxVal.tostring()
    res.sliderValue = curVal
    res.sliderGroupIdx = bulGroup.groupIndex
    res.invSliderMax = maxVal.tostring()
    res.invSliderValue = curVal
  }
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
      else if (visualItem.type == weaponsItem.modification)
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
    res.actionHoldDummyCanShow = btnText == "" ? "yes" : "no"
    local altBtnText = ""
    local altBtnTooltip = ""
    if (statusTbl.goldUnlockable && !((params?.researchMode ?? false) && flushExp > 0))
      altBtnText = getItemUnlockCost(unit, item).tostring()
    if (altBtnText != "")
      altBtnText = loc("mainmenu/btnBuy") + loc("ui/parentheses/space", { text = altBtnText })
    else if (visualItem.type == weaponsItem.spare && isOwn) {
      if (::ItemsManager.getInventoryList(itemType.UNIVERSAL_SPARE).len() && statusTbl.canBuyMore) {
        altBtnText = loc("items/universalSpare/activate", { icon = loc("icon/universalSpare") })
        altBtnTooltip = loc("items/universalSpare/activate/tooltip")
      }
    }
    else if (statusTbl.amount && statusTbl.maxAmount > 1 && statusTbl.amount < statusTbl.maxAmount
      && !res.isBundle)
        altBtnText = loc("mainmenu/btnBuy")
    else if (visualItem.type == weaponsItem.modification
      && isOwn
      && statusTbl.curUpgrade < statusTbl.maxUpgrade
      && ::ItemsManager.getInventoryList(itemType.MOD_UPGRADE).len())
        altBtnText = loc("mainmenu/btnUpgrade")
    res.altBtnCanShow = (altBtnText == "") ? "no" : "yes"
    res.altBtnTooltip = altBtnTooltip
    res.altBtnBuyText = altBtnText
  }

  return res
}

let function updateModItem(unit, item, itemObj, showButtons, handler, params = {}) {
  let id = itemObj?.id ?? ""
  let viewParams = getWeaponItemViewParams(id, unit, item,
    params.__merge({ showButtons = showButtons }))
  let { isTooltipByHold, tooltipId, actionBtnCanShow, actionHoldDummyCanShow } = viewParams

  itemObj.findObject("name").setValue(viewParams.nameText)

  if (isTooltipByHold)
    itemObj.tooltipId = tooltipId
  let tooltipObj = itemObj.findObject(isTooltipByHold ? "centralBlock" : $"tooltip_{id}")
  if (checkObj(tooltipObj))
    tooltipObj.tooltipId = tooltipId

  if (viewParams.iconBulletName != "") {
    let divObj = itemObj.findObject("bullets")
    if (checkObj(divObj)) {
      divObj._iconBulletName = viewParams.iconBulletName
      let data = ::handyman.renderCached(("%gui/weaponry/bullets.tpl"), viewParams.bulletImg)
      itemObj.getScene().replaceContentFromText(divObj, data, data.len(), handler)
    }
  }

  let imgObj = itemObj.findObject("image")
  imgObj["background-image"] = viewParams.iconBulletName != "" ? "" : viewParams.itemImg

  ::showBtn("status_image", viewParams.isShowStatusImg, itemObj)
  ::showBtn("status_radio", !viewParams.hideStatusRadio, itemObj)
  ::showBtn("modItem_statusBlock", !viewParams.hideStatus, itemObj)
  ::showBtn("modItem_discount", viewParams.isShowDiscount, itemObj)

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

  ::showBtn("warning_icon", !viewParams.hideWarningIcon, itemObj)

  if (!viewParams.hideBulletsChoiceBlock) {
    let holderObj = ::showBtn("bullets_amount_choice_block", true, itemObj)
    let textObj = holderObj.findObject("bulletsCountText")
    if (checkObj(textObj))
      textObj.setValue(viewParams.bulletsCountText)
    if (viewParams.needSliderButtons) {
      let btnDec = holderObj.findObject("buttonDec")
      if (checkObj(btnDec))
        btnDec.bulletsLimit = viewParams.decBulletsLimit

      let btnIncr = holderObj.findObject("buttonInc")
      if (checkObj(btnIncr))
        btnIncr.bulletsLimit = viewParams.incBulletsLimit
    }

    let slidObj = holderObj.findObject("bulletsSlider")
    if (checkObj(slidObj)) {
      slidObj.max = viewParams.sliderMax
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

  ::showBtn("modItem_visualHasMenu", !viewParams.hideVisualHasMenu, itemObj)

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

  let altBtn = itemObj.findObject("altActionBtn")
  altBtn.canShow = viewParams.altBtnCanShow
  if (viewParams.altBtnTooltip != "")
    altBtn.tooltip = viewParams.altBtnTooltip
  let textObj = altBtn.findObject("altBtnBuyText")
  if (checkObj(textObj))
    textObj.setValue(viewParams.altBtnBuyText)
}

let function createModItemLayout(id, unit, item, iType, params = {}) {
  if (!("type" in item))
    item.type <- iType

  return ::handyman.renderCached(weaponItemTplPath.value, getWeaponItemViewParams(id, unit, item, params))
}

let function createModItem(id, unit, item, iType, holderObj, handler, params = {}) {
  let data = createModItemLayout(id, unit, item, iType, params)
  holderObj.getScene().appendWithBlk(holderObj, data, handler)
  return holderObj.findObject(id)
}

local function createModBundle(id, unit, itemsList, itemsType, holderObj, handler, params = {}) {
  if (itemsList.len() == 0)
    return null

  let maxItemsInColumn = params?.maxItemsInColumn ?? 5
  let createItemFunc = params?.createItemFunc ?? createModItem
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
    createItemFunc.call(handler, id, unit, itemsList[0], itemsType, holderObj, handler, params)
    return itemsList[0]
  }

  let bundleObj = createItemFunc.call(handler, id, unit, bundleItem, bundleItem.type, holderObj, handler, params)
  bundleObj["class"] = "dropDown"

  let guiScene = holderObj.getScene()
  let hoverObj = guiScene.createElementByObject(bundleObj, "%gui/weaponry/weaponBundleTop.blk", "hoverSize", handler)

  let cols = ((itemsList.len() - 1) / maxItemsInColumn + 1).tointeger()
  let rows = ((itemsList.len() - 1) / cols + 1).tointeger()
  let itemsObj = hoverObj.findObject("items_field")
  foreach (idx, item in itemsList)
    createItemFunc.call(handler, id + "_" + idx, unit, item, itemsType, itemsObj, handler, { posX = (idx / rows).tointeger(), posY = idx % rows })
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

let function updateItemBulletsSlider(itemObj, bulletsManager, bulGroup) {
  let show = bulGroup != null && bulletsManager != null && bulletsManager.canChangeBulletsCount()
  let holderObj = ::showBtn("bullets_amount_choice_block", show, itemObj)
  if (!show || !holderObj)
    return

  let guns = bulGroup.guns
  let maxVal = bulGroup.maxBulletsCount
  let curVal = bulGroup.bulletsCount
  let unallocated = bulletsManager.getUnallocatedBulletCount(bulGroup)

  let textObj = holderObj.findObject("bulletsCountText")
  if (checkObj(textObj))
    textObj.setValue(getBulletsCountText(curVal, maxVal, unallocated, guns))

  let btnDec = holderObj.findObject("buttonDec")
  if (checkObj(btnDec))
    btnDec.bulletsLimit = curVal != 0 ? "no" : "yes"

  let btnIncr = holderObj.findObject("buttonInc")
  if (checkObj(btnIncr))
    btnIncr.bulletsLimit = (curVal != maxVal && unallocated != 0) ? "no" : "yes"

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
}

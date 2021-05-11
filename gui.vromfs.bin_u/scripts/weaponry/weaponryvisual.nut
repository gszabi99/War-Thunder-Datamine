local modUpgradeElem = require("scripts/weaponry/elems/modUpgradeElem.nut")
local { getByCurBundle, canResearchItem, getItemUnlockCost, getBundleCurItem, isCanBeDisabled, isModInResearch,
  getDiscountPath, getItemStatusTbl, getItemUpgradesStatus
} = require("scripts/weaponry/itemInfo.nut")
local { isBullets, isFakeBullet, getBulletsSetData, getBulletsIconItem, getBulletsIconView
} = require("scripts/weaponry/bulletsInfo.nut")
local { weaponItemTplPath } = require("scripts/weaponry/getWeaponItemTplPath.nut")
local { getModItemName, getFullItemCostText } = require("weaponryDescription.nut")
local { MODIFICATION, WEAPON, SPARE, PRIMARY_WEAPON } = require("scripts/weaponry/weaponryTooltips.nut")

::dagui_propid.add_name_id("_iconBulletName")

local function getBulletsCountText(curVal, maxVal, unallocated, guns)
{
  local restText = ""
  if (unallocated && curVal < maxVal)
    restText = ::colorize("userlogColoredText", ::format(" %s", ::loc("ui/parentheses",
      { text = ::format("+%d", guns * ::min(unallocated, maxVal - curVal)) })))
  local valColor = (!curVal || maxVal == 0) ? "badTextColor"
    : (curVal == maxVal) ? "goodTextColor"
    : "activeTextColor"
  local valText = ::colorize(valColor, guns * curVal)
  return ::format("%s/%s%s", valText, (guns * maxVal).tostring(), restText)
}

local function getStatusIcon(unit, item)
{
  local misRules = ::g_mis_custom_state.getCurMissionRules()
  if (item.type==weaponsItem.weapon
    && ::is_in_flight()
    && misRules.isWorldWar
    && misRules.needCheckWeaponsAllowed(unit)
    && misRules.isUnitWeaponAllowed(unit, item))
    return "#ui/gameuiskin#ww_icon.svg"

  return ""
}

local function getItemImage(unit, item){return null}
getItemImage = function(unit, item)
{
  if (!isBullets(item))
  {
    if (item.type == weaponsItem.bundle)
      return getByCurBundle(unit, item, getItemImage)

    if("image" in item && item.image != "")
      return item.image
    if (item.type == weaponsItem.primaryWeapon && ("weaponMod" in item) && item.weaponMod)
      return getItemImage(unit, item.weaponMod)
  }
  return ""
}

local getTooltipId = @(unitName, mod, params)
  mod.type == weaponsItem.weapon ? WEAPON.getTooltipId(unitName, mod.name, params)
    : mod.type == weaponsItem.spare ? SPARE.getTooltipId(unitName)
    : mod.type == weaponsItem.primaryWeapon ? PRIMARY_WEAPON.getTooltipId(unitName, mod.name)
    : MODIFICATION.getTooltipId(unitName, mod.name)

local function getWeaponItemViewParams(id, unit, item, params = {})
{
  local res = {
    id                        = id
    itemWidth                 = params?.itemWidth ?? 1
    posX                      = params?.posX ?? 0
    posY                      = params?.posY ?? 0
    hideStatus                = item?.hideStatus ?? params?.hideStatus ?? false
    needSliderButtons         = params?.needSliderButtons ?? false
    wideItemWithSlider        = params?.wideItemWithSlider ?? false
    modUpgradeIcon            = ::has_feature("ItemModUpgrade") ?
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
  }

  local isOwn = ::isUnitUsable(unit)
  local visualItem = item
  res.isBundle = item.type == weaponsItem.bundle
  if (res.isBundle)
  {
    visualItem = getBundleCurItem(unit, item) || visualItem
    if (!("type" in visualItem))
      visualItem.type <- weaponsItem.bundle
  }
  res.nameText = getModItemName(unit, visualItem, params?.limitedName ?? true)
  res.tooltipId = params?.tooltipId ?? getTooltipId(unit.name, visualItem, params)
  local isForceHidePlayerInfo = params?.isForceHidePlayerInfo ?? false
  local bIcoItem = getBulletsIconItem(unit, visualItem)
  if (bIcoItem)
  {
    local bulletsSet = getBulletsSetData(unit, bIcoItem.name)
    ::dagor.assertf(unit?.isTank() || bulletsSet!=null,
          $"No bullets in bullets set {visualItem.name} for {unit.name}")

    res.iconBulletName = bIcoItem.name
    res.bulletImg = getBulletsIconView(bulletsSet)
  }
  res.itemImg = getItemImage(unit, visualItem)
  local statusTbl = getItemStatusTbl(unit, visualItem)
  local canBeDisabled = isCanBeDisabled(item)
  local isSwitcher = (visualItem.type == weaponsItem.weapon) ||
    (visualItem.type == weaponsItem.primaryWeapon) ||
    isBullets(visualItem)
  local discount = ::getDiscountByPath(
    getDiscountPath(unit, visualItem, statusTbl.discountType))
  local itemCostText = getFullItemCostText(unit, item)
  local priceText = statusTbl.showPrice && (params?.canShowPrice ?? true) ? itemCostText : ""
  local flushExp = params?.flushExp ?? 0
  local canShowResearch = params?.canShowResearch ?? true
  local canResearch = canResearchItem(unit, visualItem, false)
  local itemReqExp = visualItem?.reqExp ?? 0
  local isModResearching = canShowResearch &&
                               canResearch &&
                               statusTbl.modExp >= 0 &&
                               statusTbl.modExp < itemReqExp &&
                               !statusTbl.amount
  local isInResearch = isModInResearch(unit, visualItem)
  local isResearchInProgress = isModResearching && isInResearch
  local isResearchPaused = isModResearching && statusTbl.modExp > 0 && !isInResearch
  local showStatus = false
  res.optEquipped = isForceHidePlayerInfo || statusTbl.equipped ? "yes" : "no"
  if (params?.canShowStatusImage ?? true)
    if (visualItem.type == weaponsItem.weapon || isBullets(visualItem))
      showStatus = true
    else if (visualItem.type == weaponsItem.modification ||
      visualItem.type == weaponsItem.expendables)
        showStatus = canBeDisabled && statusTbl.amount
  res.isShowStatusImg = showStatus && (! statusTbl.unlocked || ! isSwitcher)
  res.hideStatusRadio = !showStatus || !statusTbl.unlocked ||
    !isSwitcher || isFakeBullet(visualItem.name)
  res.hideStatus = isResearchInProgress || res.hideStatus
  res.isShowDiscount = discount > 1
  local isScoreCost = ::is_in_flight()
    && ::g_mis_custom_state.getCurMissionRules().isScoreRespawnEnabled
  local haveDiscount = discount > 0 && statusTbl.canShowDiscount && itemCostText != ""
  if (haveDiscount && !isScoreCost)
  {
    if (res.isShowDiscount)
    {
      res.discountText = "".concat("-", discount, "%")
      res.discountTooltip = ::format(
        ::loc("".concat("discount/", statusTbl.discountType, "/tooltip")), discount.tostring())
    }
    if (priceText != "")
      priceText = "<color=@goodTextColor>" + priceText +"</color>"
  }
  res.nameTextWithPrice = res.nameText
  local spawnScoreCost = getFullItemCostText(unit, item, true)
  if (statusTbl.showPrice && (params?.canShowPrice ?? true) && spawnScoreCost != "")
    res.nameTextWithPrice = "".concat(res.nameTextWithPrice, ::loc("ui/parentheses/space", {text = spawnScoreCost}))
  local showProgress = isResearchInProgress || isResearchPaused
  res.isShowPrice = !showProgress && (statusTbl.showPrice || canResearch)
  res.hideProgressBlock = !showProgress
  if (showProgress)
  {
    local diffExp = params?.diffExp ?? 0
    local paused = isResearchPaused? "yes" : "no"
    res.researchProgress = (itemReqExp ? statusTbl.modExp.tofloat() / itemReqExp : 1) * 1000
    res.progressType = diffExp ? "new" : ""
    res.progressPaused = paused
    local oldExp = max(0, statusTbl.modExp - diffExp)
    res.hideOldResearchProgress = oldExp == 0
    res.oldResearchProgress = (itemReqExp ? oldExp.tofloat() / itemReqExp : 1) * 1000
  }
  else
  {
    if (statusTbl.showPrice)
      res.priceText = priceText
    else if (canResearch && !isResearchInProgress && !isResearchPaused)
    {
      local showExp = itemReqExp - statusTbl.modExp
      local rpText = ::Cost().setRp(showExp).tostring()
      if (flushExp > 0 && flushExp > showExp)
        rpText = ::colorize("goodTextColor", rpText)
      res.priceText = rpText
    }
  }
  local optStatus = "locked"
  if (params?.visualDisabled ?? false)
    optStatus = "disabled"
  else if (statusTbl.amount)
    optStatus = "owned"
  else if (isForceHidePlayerInfo || statusTbl.unlocked)
    optStatus = "unlocked"
  else if (isInResearch && visualItem.type == weaponsItem.modification)
    optStatus = canShowResearch ? "research" : "researchable"
  else if (canResearchItem(unit, visualItem))
    optStatus = "researchable"
  res.optStatus = optStatus
  if (!isForceHidePlayerInfo)
  {
    res.amountText = ::getAmountAndMaxAmountText(statusTbl.amount,
      statusTbl.maxAmount, statusTbl.showMaxAmount)
    res.amountTextColor = statusTbl.amount < statusTbl.amountWarningValue ? "weaponWarning" : ""
  }
  res.hideWarningIcon = isForceHidePlayerInfo || !statusTbl.unlocked || !statusTbl.showMaxAmount ||
    statusTbl.amount >= statusTbl.amountWarningValue
  res.itemTextColor = res.isShowStatusImg ?
    "badTextColor" : res.hideWarningIcon ?
      "commonTextColor" : "warningTextColor"
  local bulletsManager = params?.selectBulletsByManager
  local bulGroup = bulletsManager?.canChangeBulletsCount() ?
    bulletsManager.getBulletGroupBySelectedMod(visualItem) : null
  res.hideBulletsChoiceBlock = bulGroup == null
  if(!res.hideBulletsChoiceBlock)
  {
    local guns = bulGroup.guns
    local maxVal = bulGroup.maxBulletsCount
    local curVal = bulGroup.bulletsCount
    local unallocated = bulletsManager.getUnallocatedBulletCount(bulGroup)
    res.bulletsCountText = getBulletsCountText(curVal, maxVal, unallocated, guns)
    if(res.needSliderButtons)
    {
      res.decBulletsLimit = curVal != 0? "no" : "yes"
      res.incBulletsLimit = (curVal != maxVal && unallocated != 0)? "no" : "yes"
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
  if (params?.showButtons)
  {
    local btnText = ""
    if (res.isBundle)
      btnText = ::loc("mainmenu/btnAirGroupOpen")
    else if (isOwn && statusTbl.unlocked)
    {
      if (!statusTbl.amount || (visualItem.type == weaponsItem.spare && statusTbl.canBuyMore))
        btnText = ::loc("mainmenu/btnBuy")
      else if (isSwitcher && !statusTbl.equipped)
        btnText = ::loc("mainmenu/btnSelect")
      else if (visualItem.type == weaponsItem.modification)
        btnText = statusTbl.equipped ?
          (canBeDisabled ? ::loc("mod/disable") : "") : ::loc("mod/enable")
    }
    else if (canResearchItem(unit, visualItem) ||
      (canResearchItem(unit, visualItem, false) &&
      (flushExp > 0 || !canShowResearch)))
      btnText = ::loc("mainmenu/btnResearch")
    btnText = params?.actionBtnText ?? btnText
    res.actionBtnCanShow = btnText == "" ? "no" : "yes"
    res.actionBtnText = btnText
    local altBtnText = ""
    local altBtnTooltip = ""
    if (statusTbl.goldUnlockable && !((params?.researchMode ?? false) && flushExp > 0))
      altBtnText = getItemUnlockCost(unit, item).tostring()
    if (altBtnText != "")
      altBtnText = ::loc("mainmenu/btnBuy") + ::loc("ui/parentheses/space", {text = altBtnText})
    else if (visualItem.type == weaponsItem.spare && isOwn)
    {
      if (::ItemsManager.getInventoryList(itemType.UNIVERSAL_SPARE).len() && statusTbl.canBuyMore)
      {
        altBtnText = ::loc("items/universalSpare/activate", { icon = ::loc("icon/universalSpare") })
        altBtnTooltip = ::loc("items/universalSpare/activate/tooltip")
      }
    }
    else if (statusTbl.amount && statusTbl.maxAmount > 1 && statusTbl.amount < statusTbl.maxAmount
      && !res.isBundle)
        altBtnText = ::loc("mainmenu/btnBuy")
    else if (visualItem.type == weaponsItem.modification
      && isOwn
      && statusTbl.curUpgrade < statusTbl.maxUpgrade
      && ::ItemsManager.getInventoryList(itemType.MOD_UPGRADE).len())
        altBtnText = ::loc("mainmenu/btnUpgrade")
    res.altBtnCanShow = (altBtnText == "") ? "no" : "yes"
    res.altBtnTooltip = altBtnTooltip
    res.altBtnBuyText = altBtnText
  }

  return res
}

local function updateModItem(unit, item, itemObj, showButtons, handler, params = {})
{
  local id = itemObj?.id ?? ""
  local viewParams = getWeaponItemViewParams(id, unit, item,
    params.__merge({showButtons = showButtons}))
  local { isTooltipByHold, tooltipId, actionBtnCanShow } = viewParams

  itemObj.findObject("name").setValue(viewParams.nameText)

  if (isTooltipByHold)
    itemObj.tooltipId = tooltipId
  local tooltipObj = itemObj.findObject(isTooltipByHold ? "centralBlock" : $"tooltip_{id}")
  if (::check_obj(tooltipObj))
    tooltipObj.tooltipId = tooltipId

  if (viewParams.iconBulletName != "")
  {
    local divObj = itemObj.findObject("bullets")
    if (::check_obj(divObj))
    {
      divObj._iconBulletName = viewParams.iconBulletName
      local data = ::handyman.renderCached(("gui/weaponry/bullets"), viewParams.bulletImg)
      itemObj.getScene().replaceContentFromText(divObj, data, data.len(), handler)
    }
  }

  local imgObj = itemObj.findObject("image")
  imgObj["background-image"] = viewParams.iconBulletName != "" ? "" : viewParams.itemImg

  ::showBtn("status_image", viewParams.isShowStatusImg, itemObj)
  ::showBtn("status_radio", !viewParams.hideStatusRadio, itemObj)
  ::showBtn("modItem_statusBlock", !viewParams.hideStatus, itemObj)
  ::showBtn("modItem_discount", viewParams.isShowDiscount, itemObj)

  if (viewParams.isShowDiscount)
  {
    local dObj = itemObj.findObject("discount")
    if(::check_obj(dObj))
    {
      dObj.setValue(viewParams.discountText)
      dObj.tooltip = viewParams.discountTooltip
    }
  }

  local priceObj = itemObj.findObject("price")
  if (::check_obj(priceObj))
  {
    priceObj.setValue(viewParams.priceText)
    priceObj.show(viewParams.isShowPrice)
  }

  local progressBlock = itemObj.findObject("mod_research_block")
  if (::check_obj(progressBlock))
  {
    progressBlock.show(!viewParams.hideProgressBlock)
    if (!viewParams.hideProgressBlock)
    {
      local progressObj = progressBlock.findObject("mod_research_progress")
      progressObj.setValue(viewParams.researchProgress)
      progressObj.type = viewParams.progressType
      progressObj.paused = viewParams.progressPaused

      local progressObjOld = progressBlock.findObject("mod_research_progress_old")
      progressObjOld.show(!viewParams.hideOldResearchProgress)
      progressObjOld.setValue(viewParams.oldResearchProgress)
      progressObjOld.paused = viewParams.progressPaused
    }
  }

  itemObj.equipped = viewParams.optEquipped
  itemObj.status = viewParams.optStatus
  local iconObj = itemObj.findObject("icon")
  if (::check_obj(iconObj))
  {
    iconObj.equipped = viewParams.optEquipped
    iconObj.status = viewParams.optStatus
  }

  local amountObject = itemObj.findObject("amount")
  if (::check_obj(amountObject))
  {
    amountObject.setValue(viewParams.amountText)
    amountObject.overlayTextColor = viewParams.amountTextColor
  }

  ::showBtn("warning_icon", !viewParams.hideWarningIcon, itemObj)

  if(!viewParams.hideBulletsChoiceBlock)
  {
    local holderObj = ::showBtn("bullets_amount_choice_block", true, itemObj)
    local textObj = holderObj.findObject("bulletsCountText")
    if (::check_obj(textObj))
      textObj.setValue(viewParams.bulletsCountText)
    if(viewParams.needSliderButtons)
    {
      local btnDec = holderObj.findObject("buttonDec")
      if (::check_obj(btnDec))
        btnDec.bulletsLimit = viewParams.decBulletsLimit

      local btnIncr = holderObj.findObject("buttonInc")
      if (::check_obj(btnIncr))
        btnIncr.bulletsLimit = viewParams.incBulletsLimit
    }

    local slidObj = holderObj.findObject("bulletsSlider")
    if (::check_obj(slidObj))
    {
      slidObj.max = viewParams.sliderMax
      slidObj.setValue(viewParams.sliderValue)
    }
    local invSlidObj = holderObj.findObject("invisBulletsSlider")
    if (::check_obj(invSlidObj))
    {
      invSlidObj.groupIdx = viewParams.sliderGroupIdx
      invSlidObj.max = viewParams.invSliderMax
      if (invSlidObj.getValue() != viewParams.invSliderValue)
        invSlidObj.setValue(viewParams.invSliderValue)
    }
  }

  ::showBtn("modItem_visualHasMenu", !viewParams.hideVisualHasMenu, itemObj)

  local upgradesObj = itemObj.findObject("upgrade_img")
  if (::check_obj(upgradesObj))
    upgradesObj.upgradeStatus = viewParams.modUpgradeStatus

  local statusIcon = itemObj.findObject("status_icon")
  if (::check_obj(statusIcon))
    statusIcon["background-image"] = viewParams.statusIconImg

  modUpgradeElem.setValueToObj(itemObj.findObject("mod_upgrade_icon"), unit.name, item.name)

  if (isTooltipByHold) {
    local dummyBtn = itemObj.findObject("actionHoldDummy")
    if (dummyBtn?.isValid())
      dummyBtn.canShow = showButtons && actionBtnCanShow == "yes" ? "no" : "yes"
  }

  if (!showButtons)
    return

  local actionBtn = itemObj.findObject("actionBtn")
  actionBtn.canShow = actionBtnCanShow
  actionBtn.setValue(viewParams.actionBtnText)

  local altBtn = itemObj.findObject("altActionBtn")
  altBtn.canShow = viewParams.altBtnCanShow
  if (viewParams.altBtnTooltip != "")
    altBtn.tooltip = viewParams.altBtnTooltip
  local textObj = altBtn.findObject("altBtnBuyText")
  if (::check_obj(textObj))
    textObj.setValue(viewParams.altBtnBuyText)
}

local function createModItemLayout(id, unit, item, iType, params = {})
{
  if (!("type" in item))
    item.type <- iType

  return ::handyman.renderCached(weaponItemTplPath.value, getWeaponItemViewParams(id, unit, item, params))
}

local function createModItem(id, unit, item, iType, holderObj, handler, params = {})
{
  local data = createModItemLayout(id, unit, item, iType, params)
  holderObj.getScene().appendWithBlk(holderObj, data, handler)
  return holderObj.findObject(id)
}

local function createModBundle(id, unit, itemsList, itemsType, holderObj, handler, params = {})
{
  if (itemsList.len()==0)
    return null

  local maxItemsInColumn = params?.maxItemsInColumn ?? 5
  local createItemFunc = params?.createItemFunc ?? createModItem
  local bundleItem = {
      name = id
      type = weaponsItem.bundle
      hideStatus = true
      itemsType = itemsType
      subType = params?.subType ?? 0
      itemsList = itemsList
    }
  if (itemsType==weaponsItem.bullets)
    itemsType = weaponsItem.modification

  if (itemsList.len()==1)
  {
    itemsList[0].hideStatus <- true //!!FIX ME: Remove modify data
    createItemFunc.call(handler, id, unit, itemsList[0], itemsType, holderObj, handler, params)
    return itemsList[0]
  }

  local bundleObj = createItemFunc.call(handler, id, unit, bundleItem, bundleItem.type, holderObj, handler, params)
  bundleObj["class"] = "dropDown"

  local guiScene = holderObj.getScene()
  local hoverObj = guiScene.createElementByObject(bundleObj, "gui/weaponry/weaponBundleTop.blk", "hoverSize", handler)

  local cols = ((itemsList.len()-1)/maxItemsInColumn + 1).tointeger()
  local rows = ((itemsList.len()-1)/cols + 1).tointeger()
  local itemsObj = hoverObj.findObject("items_field")
  foreach(idx, item in itemsList)
    createItemFunc.call(handler, id + "_" + idx, unit, item, itemsType, itemsObj, handler, { posX = (idx/rows).tointeger(), posY = idx%rows })
  itemsObj.width = cols + "@modCellWidth"
  itemsObj.height = rows + "@modCellHeight"

  hoverObj.width = cols + "@modCellWidth"
  local rootSize = guiScene.getRoot().getSize()
  local rightSide = bundleObj.getPosRC()[0] < 0.7 * rootSize[0] //better to use width const here, but need const calculator from dagui for that
  if (rightSide)
    hoverObj.pos = "0.5pw-0.5@modCellWidth, ph"
  else
    hoverObj.pos = "0.5pw+0.5@modCellWidth-w, ph"

  local cellObj = params?.cellSizeObj || bundleObj
  local cellSize = cellObj.getSize()
  local extraHeight = ::to_pixels("2@modBundlePopupBgPadH + 1@modBundlePopupAdditionalBtnsHeight")
  hoverObj["height-end"] = (cellSize[1] * rows + extraHeight).tointeger().tostring()
  return bundleItem
}

local function updateItemBulletsSlider(itemObj, bulletsManager, bulGroup)
{
  local show = bulGroup != null && bulletsManager != null && bulletsManager.canChangeBulletsCount()
  local holderObj = ::showBtn("bullets_amount_choice_block", show, itemObj)
  if (!show || !holderObj)
    return

  local guns = bulGroup.guns
  local maxVal = bulGroup.maxBulletsCount
  local curVal = bulGroup.bulletsCount
  local unallocated = bulletsManager.getUnallocatedBulletCount(bulGroup)

  local textObj = holderObj.findObject("bulletsCountText")
  if (::check_obj(textObj))
    textObj.setValue(getBulletsCountText(curVal, maxVal, unallocated, guns))

  local btnDec = holderObj.findObject("buttonDec")
  if (::checkObj(btnDec))
    btnDec.bulletsLimit = curVal != 0? "no" : "yes"

  local btnIncr = holderObj.findObject("buttonInc")
  if (::checkObj(btnIncr))
    btnIncr.bulletsLimit = (curVal != maxVal && unallocated != 0)? "no" : "yes"

  local slidObj = holderObj.findObject("bulletsSlider")
  if (::checkObj(slidObj))
  {
    slidObj.max = maxVal.tostring()
    slidObj.setValue(curVal)
  }
  local invSlidObj = holderObj.findObject("invisBulletsSlider")
  if (::checkObj(invSlidObj))
  {
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

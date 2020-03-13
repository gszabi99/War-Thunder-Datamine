local weaponryEffects = ::require("scripts/weaponry/weaponryEffects.nut")
local modUpgradeElem = ::require("scripts/weaponry/elems/modUpgradeElem.nut")
local stdMath = require("std/math.nut")
local { isFakeBullet,
        getBulletIcons,
        initBulletIcons,
        getBulletsSetData,
        getBulletGroupIndex,
        getModificationInfo,
        getModificationName,
        getBulletsSearchName,
        getBulletsFeaturesImg,
        isBulletsGroupActiveByMod,
        getModificationBulletsEffect,
        getModificationBulletsGroup } = require("scripts/weaponry/bulletsInfo.nut")
local { AMMO,
        getAmmoAmount,
        getAmmoMaxAmount,
        getAmmoWarningMinimum } = require("scripts/weaponry/ammoInfo.nut")
local { WEAPON_TYPE,
        getLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local { getWeaponInfoText,
        getWeaponNameText,
        getWeaponItemViewParams } = require("scripts/weaponry/weaponryVisual.nut")

/*
  weaponVisual API

    createItem(id, item, type, holderObj, handler, params)  - creates base visual item, but not update it.
               params <- { posX, posY }
    createBundle(itemsList, itemsType, subType, holderObj, handler)  - creates items bundle
                 params <- { posX, posY, createItemFunc, maxItemsInColumn, subType }
*/

::dagui_propid.add_name_id("_iconBulletName")

::weaponVisual <- {
  function addBonusToObj(handler, obj, value, tooltipLocName="", isDiscount=true, bType = "old")
  {
    if (!::checkObj(obj) || value < 2) return

    local guiScene = obj.getScene()
    local text = ""
    local id = ""
    local tooltip = ""
    text = isDiscount? "-" + value + "%" : "x" + stdMath.roundToDigits(value, 2)
    if(tooltipLocName != "")
    {
      local prefix = isDiscount? "discount/" : "bonus/"
      id = isDiscount? "discount" : "bonus"
      tooltip = ::format(::loc(prefix + tooltipLocName + "/tooltip"), value.tostring())
    }
    local discountData = ::format("discount{id:t='%s'; type:t='%s'; tooltip:t='%s'; text:t='%s';}",
      id, bType, tooltip, text)

    guiScene.appendWithBlk(obj, discountData, handler)
  }
}

weaponVisual.createItemLayout <- function createItemLayout(id, unit, item, iType, params = {})
{
  if (!("type" in item))
    item.type <- iType

  return ::handyman.renderCached("gui/weaponry/weaponItem", getWeaponItemViewParams(id, unit, item, params))
}

weaponVisual.createItem <- function createItem(id, unit, item, iType, holderObj, handler, params = {})
{
  local data = createItemLayout(id, unit, item, iType, params)
  holderObj.getScene().appendWithBlk(holderObj, data, handler)
  return holderObj.findObject(id)
}

weaponVisual.createBundle <- function createBundle(id, unit, itemsList, itemsType, holderObj, handler, params = {})
{
  if (itemsList.len()==0)
    return null

  local maxItemsInColumn = ::getTblValue("maxItemsInColumn", params, 5)
  local createItemFunc = ::getTblValue("createItemFunc", params, createItem)
  local bundleItem = {
      name = id
      type = weaponsItem.bundle
      hideStatus = true
      itemsType = itemsType
      subType = ::getTblValue("subType", params, 0)
      itemsList = itemsList
    }
  if (itemsType==weaponsItem.bullets)
    itemsType = weaponsItem.modification

  if (itemsList.len()==1)
  {
    itemsList[0].hideStatus <- true
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

  local cellObj = ::getTblValue("cellSizeObj", params) || bundleObj
  local cellSize = cellObj.getSize()
  hoverObj["height-end"] = (cellSize[1].tofloat() * (rows + 0.4)).tointeger().tostring()
  return bundleItem
}

weaponVisual.updateItem <- function updateItem(air, item, itemObj, showButtons, handler, params = {})
{
  local guiScene = itemObj.getScene()
  local isOwn = ::isUnitUsable(air)
  local visualItem = item
  local isBundle = item.type == weaponsItem.bundle
  if (isBundle)
    visualItem = getBundleCurItem(air, item) || visualItem

  local limitedName = ::getTblValue("limitedName", params, true)
  itemObj.findObject("name").setValue(getItemName(air, visualItem, limitedName))

  local isForceHidePlayerInfo = params?.isForceHidePlayerInfo ?? false
  if (::getTblValue("useGenericTooltip", params))
    updateGenericTooltipId(itemObj, air, item, { hasPlayerInfo = !isForceHidePlayerInfo })

  local bIcoItem = getBulletsIconItem(air, visualItem)
  if (bIcoItem)
  {
    local divObj = itemObj.findObject("bullets")
    if (divObj?._iconBulletName != bIcoItem.name)
    {
      divObj._iconBulletName = bIcoItem.name
      local bulletsSet = getBulletsSetData(air, bIcoItem.name)
      dagor.assertf(isTank(air) || bulletsSet!=null, "No bullets in bullets set " + visualItem.name + " for " + air.name)
      local iconData = getBulletsIconData(bulletsSet)
      guiScene.replaceContentFromText(divObj, iconData, iconData.len(), handler)
    }
  }

  local imgObj = itemObj.findObject("image")
  imgObj["background-image"] = bIcoItem? "" : getItemImage(air, visualItem)

  local statusTbl = getItemStatusTbl(air, visualItem)
  local canBeDisabled = isCanBeDisabled(item)
  local isSwitcher = isItemSwitcher(visualItem)
  local discount = ::getDiscountByPath(getDiscountPath(air, visualItem, statusTbl.discountType))
  local itemCostText = getFullItemCostText(air, item)
  local priceText = statusTbl.showPrice && ::getTblValue("canShowPrice", params, true) ? itemCostText : ""
  local flushExp = ::getTblValue("flushExp", params, 0)
  local canShowResearch = ::getTblValue("canShowResearch", params, true)
  local canResearch = canResearchItem(air, visualItem, false)
  local itemReqExp = ::getTblValue("reqExp", visualItem, 0)
  local isModResearching = canShowResearch &&
                               canResearch &&
                               statusTbl.modExp >= 0 &&
                               statusTbl.modExp < itemReqExp &&
                               !statusTbl.amount

  local isResearchInProgress = isModResearching && isModInResearch(air, visualItem)
  local isResearchPaused = isModResearching && statusTbl.modExp > 0 && !isModInResearch(air, visualItem)

  local showStatus = false
  if (::getTblValue("canShowStatusImage", params, true))
    if (visualItem.type == weaponsItem.weapon || isBullets(visualItem))
      showStatus = true
    else if (visualItem.type == weaponsItem.modification || visualItem.type == weaponsItem.expendables)
      showStatus = canBeDisabled && statusTbl.amount

  local statusObj = itemObj.findObject("status_image")
  if(statusObj)
    statusObj.show(showStatus && (! statusTbl.unlocked || ! isSwitcher))

  local statusRadioObj = itemObj.findObject("status_radio")
  if(statusRadioObj)
    statusRadioObj.show(showStatus && statusTbl.unlocked &&
      isSwitcher && !isFakeBullet(visualItem.name))

  local blockObj = itemObj.findObject("modItem_statusBlock")
  if (blockObj)
    blockObj.show(!isResearchInProgress)
  local dObj = itemObj.findObject("discount")
  if(::checkObj(dObj))
    guiScene.destroyElement(dObj)

  local haveDiscount = discount > 0 && statusTbl.canShowDiscount && itemCostText != ""
  if (haveDiscount)
  {
    local discountObj = itemObj.findObject("modItem_discount")
    if (discountObj)
      addBonusToObj(handler, discountObj, discount, statusTbl.discountType, true, "weaponryItem")
    if (priceText != "")
      priceText = "<color=@goodTextColor>" + priceText +"</color>"
  }

  local showProgress = isResearchInProgress || isResearchPaused

  local priceObj = itemObj.findObject("price")
  if (priceObj)
    priceObj.show(!showProgress && (statusTbl.showPrice || canResearch))

  local progressBlock = itemObj.findObject("mod_research_block")
  if (progressBlock)
    progressBlock.show(showProgress)
  if (showProgress && progressBlock)
  {
    local diffExp = ::getTblValue("diffExp", params, 0)
    local progressObj = progressBlock.findObject("mod_research_progress")

    progressObj.setValue((itemReqExp ? statusTbl.modExp.tofloat() / itemReqExp : 1) * 1000)
    progressObj.type = diffExp? "new" : ""
    progressObj.paused = isResearchPaused? "yes" : "no"

    local oldExp = max(0, statusTbl.modExp - diffExp)
    local progressObjOld = progressBlock.findObject("mod_research_progress_old")
    progressObjOld.show(oldExp > 0)
    progressObjOld.setValue((itemReqExp ? oldExp.tofloat() / itemReqExp : 1) * 1000)
    progressObjOld.paused = isResearchPaused? "yes" : "no"
  }
  else
  {
    if (priceObj && statusTbl.showPrice)
      priceObj.setValue(priceText)
    else if (priceObj && canResearch && !isResearchInProgress && !isResearchPaused)
    {
      local showExp = itemReqExp - statusTbl.modExp
      local rpText = ::Cost().setRp(showExp).tostring()
      if (flushExp > 0 && flushExp > showExp)
        rpText = "<color=@goodTextColor>" + rpText + "</color>"
      priceObj.setValue(rpText)
    }
  }

  local iconObj = itemObj.findObject("icon")
  local optEquipped = isForceHidePlayerInfo || statusTbl.equipped ? "yes" : "no"
  local optStatus = "locked"
  if (::getTblValue("visualDisabled", params, false))
    optStatus = "disabled"
  else if (statusTbl.amount)
    optStatus = "owned"
  else if (isForceHidePlayerInfo || statusTbl.unlocked)
    optStatus = "unlocked"
  else if (isModInResearch(air, visualItem) && visualItem.type == weaponsItem.modification)
    optStatus = canShowResearch? "research" : "researchable"
  else if (canResearchItem(air, visualItem))
    optStatus = "researchable"

  itemObj.equipped = optEquipped
  itemObj.status = optStatus
  iconObj.equipped = optEquipped
  iconObj.status = optStatus

  if (!isForceHidePlayerInfo)
  {
    local amountText = getAmountAndMaxAmountText(statusTbl.amount, statusTbl.maxAmount, statusTbl.showMaxAmount);
    local amountObject = itemObj.findObject("amount");
    amountObject.setValue(amountText)
    amountObject.overlayTextColor = statusTbl.amount < statusTbl.amountWarningValue ? "weaponWarning" : "";
  }

  local isWarningIconVisible = !isForceHidePlayerInfo
                            && statusTbl.unlocked
                            && statusTbl.showMaxAmount
                            && statusTbl.amount < statusTbl.amountWarningValue
  itemObj.findObject("warning_icon").show(isWarningIconVisible)

  updateItemBulletsSliderByItem(itemObj, ::getTblValue("selectBulletsByManager", params), visualItem)

  local showMenuIcon = isBundle || ::getTblValue("hasMenu", params)
  local visualHasMenuObj = itemObj.findObject("modItem_visualHasMenu")
  if (visualHasMenuObj)
    visualHasMenuObj.show(showMenuIcon)

  local upgradesObj = itemObj.findObject("upgrade_img")
  if (upgradesObj)
    upgradesObj.upgradeStatus = getItemUpgradesStatus(air, visualItem)

  local statusIcon = itemObj.findObject("status_icon")
  if (::checkObj(statusIcon))
    statusIcon["background-image"] = getStatusIcon(air, item)

  modUpgradeElem.setValueToObj(itemObj.findObject("mod_upgrade_icon"), air.name, visualItem.name)

  if (!showButtons)
    return

  //updateButtons
  local btnText = ""
  local showBtnOnlySelected = false
  if (isBundle)
  {
    showBtnOnlySelected = true
    btnText = ::loc("mainmenu/btnAirGroupOpen")
  }
  else if (isOwn && statusTbl.unlocked)
  {
    if (!statusTbl.amount || (visualItem.type == weaponsItem.spare && statusTbl.canBuyMore))
      btnText = ::loc("mainmenu/btnBuy")
    else if (isSwitcher && !statusTbl.equipped)
      btnText = ::loc("mainmenu/btnSelect")
    else if (visualItem.type == weaponsItem.modification)
      btnText = statusTbl.equipped ? (canBeDisabled ? ::loc("mod/disable") : "") : ::loc("mod/enable")
  }
  else if (canResearchItem(air, visualItem) || (canResearchItem(air, visualItem, false) && (flushExp > 0 || !canShowResearch)))
    btnText = ::loc("mainmenu/btnResearch")

  local actionBtn = itemObj.findObject("actionBtn")
  actionBtn.canShow = btnText == "" ? "no" : !showBtnOnlySelected? "yes"
                      : (isBundle) ? "console" : "selected"
  actionBtn.setValue(btnText)

  //alternative action button
  local altBtn = itemObj.findObject("altActionBtn")
  local altBtnText = ""
  local altBtnTooltip = ""
  if (statusTbl.goldUnlockable && !(::getTblValue("researchMode", params, false) && flushExp > 0))
    altBtnText = getItemUnlockCost(air, item).tostring()
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
  else if (statusTbl.amount && statusTbl.maxAmount > 1
            && statusTbl.amount < statusTbl.maxAmount
            && !isBundle)
    altBtnText = ::loc("mainmenu/btnBuy")
  else if (visualItem.type == weaponsItem.modification
      && isOwn
      && statusTbl.curUpgrade < statusTbl.maxUpgrade
      && ::ItemsManager.getInventoryList(itemType.MOD_UPGRADE).len())
    altBtnText = ::loc("mainmenu/btnUpgrade")

  altBtn.canShow = (altBtnText == "") ? "no" : "yes"
  if (altBtnTooltip != "")
    altBtn.tooltip = altBtnTooltip
  local textObj = altBtn.findObject("altBtnBuyText")
  if (::checkObj(textObj))
    textObj.setValue(altBtnText)
}

weaponVisual.getItemStatusTbl <- function getItemStatusTbl(air, item)
{
  local isOwn = ::isUnitUsable(air)
  local res = {
    amount = getItemAmount(air, item)
    maxAmount = 0
    amountWarningValue = 0
    modExp = 0
    showMaxAmount = false
    canBuyMore = false
    equipped = false
    goldUnlockable = false
    unlocked = false
    showPrice = true
    discountType = ""
    canShowDiscount = true
    curUpgrade = 0
    maxUpgrade = 0
  }

  if (item.type == weaponsItem.weapon)
  {
    res.maxAmount = getAmmoMaxAmount(air, item.name, AMMO.WEAPON)
    res.amount = getAmmoAmount(air, item.name, AMMO.WEAPON)
    res.showMaxAmount = res.maxAmount > 1
    res.amountWarningValue = getAmmoWarningMinimum(AMMO.WEAPON, air, res.maxAmount)
    res.canBuyMore = res.amount < res.maxAmount
    res.equipped = res.amount && getLastWeapon(air.name) == item.name
    res.unlocked = ::is_weapon_enabled(air, item) || (isOwn && ::is_weapon_unlocked(air, item) )
    res.discountType = "weapons"
  }
  else if (item.type == weaponsItem.primaryWeapon)
  {
    res.equipped = ::get_last_primary_weapon(air) == item.name
    if (item.name == "") //default
      res.unlocked = isOwn
    else
    {
      res.maxAmount = ::wp_get_modification_max_count(air.name, item.name)
      res.equipped = res.amount && ::shop_is_modification_enabled(air.name, item.name)
      res.unlocked = res.amount || ::canBuyMod(air, item)
      res.showPrice = false//amount < maxAmount
    }
  }
  else if (item.type == weaponsItem.modification || item.type == weaponsItem.expendables)
  {
    local groupDef = ("isDefaultForGroup" in item)? item.isDefaultForGroup : -1
    if (groupDef >= 0) //default bullets, always bought.
    {
      res.unlocked = isOwn
      local currBullet = ::get_last_bullets(air.name, groupDef);
      res.equipped = !currBullet || currBullet == "" || currBullet == item.name
      res.showPrice = false
    }
    else
    {
      res.unlocked = res.amount || ::canBuyMod(air, item)
      res.maxAmount = ::wp_get_modification_max_count(air.name, item.name)
      res.amountWarningValue = getAmmoWarningMinimum(AMMO.MODIFICATION, air, res.maxAmount)
      res.canBuyMore = res.amount < res.maxAmount
      res.modExp = ::shop_get_module_exp(air.name, item.name)
      res.discountType = "mods"
      if (!isBullets(item))
      {
        res.equipped = res.amount && ::shop_is_modification_enabled(air.name, item.name)
        res.goldUnlockable = !res.unlocked && ::has_feature("SpendGold") && canBeResearched(air, item, false)
        if (item.type == weaponsItem.expendables)
          res.showPrice = !res.amount || ::canBuyMod(air, item)
        else
        {
          res.canShowDiscount = res.canBuyMore
          res.showPrice = !res.amount && ::canBuyMod(air, item)
        }

        if (isOwn && res.amount && ::is_mod_upgradeable(item.name))
        {
          res.curUpgrade = ::get_modification_level(air.name, item.name)
          res.maxUpgrade = 1 //only 1 upgrade level planned to be used atm.
                             //so no point to add complex logic about max upgrade detection right now.
        }
      }
      else
      {
        res.equipped = false
        res.showMaxAmount = res.maxAmount > 1
        local id = getBulletGroupIndex(air.name, item.name)
        if (id >= 0)
        {
          local currBullet = ::get_last_bullets(air.name, id);
          res.equipped = res.amount && (currBullet == item.name)
        }
      }
    }
  }
  else if (item.type == weaponsItem.spare)
  {
    res.equipped = res.amount > 0
    res.maxAmount = ::max_spare_amount
    res.showMaxAmount = false
    res.canBuyMore = res.amount < res.maxAmount
    res.unlocked = isOwn
    res.discountType = "spare"
  }
  return res
}

weaponVisual.isItemSwitcher <- function isItemSwitcher(item)
{
  return (item.type == weaponsItem.weapon) || (item.type == weaponsItem.primaryWeapon) || isBullets(item)
}

weaponVisual.updateGenericTooltipId <- function updateGenericTooltipId(itemObj, unit, item, params = null)
{
  local tooltipObj = itemObj.findObject("tooltip_" + (itemObj?.id??""))
  if (!tooltipObj)
    return

  local tooltipId = ""
  if (item.type == weaponsItem.modification)
    tooltipId = ::g_tooltip_type.MODIFICATION.getTooltipId(unit.name, item.name)
  else if (item.type == weaponsItem.weapon)
    tooltipId = ::g_tooltip_type.WEAPON.getTooltipId(unit.name, item.name, params)
  else if (item.type == weaponsItem.spare)
    tooltipId = ::g_tooltip_type.SPARE.getTooltipId(unit.name)
  tooltipObj.tooltipId = tooltipId
}

weaponVisual.updateItemBulletsSliderByItem <- function updateItemBulletsSliderByItem(itemObj, bulletsManager, item)
{
  local bulGroup = null
  if (bulletsManager != null && bulletsManager.canChangeBulletsCount())
    bulGroup = bulletsManager.getBulletGroupBySelectedMod(item)
  updateItemBulletsSlider(itemObj, bulletsManager, bulGroup)
}

weaponVisual.updateItemBulletsSlider <- function updateItemBulletsSlider(itemObj, bulletsManager, bulGroup)
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
  if (::checkObj(textObj))
  {
    local restText = ""
    if (unallocated && curVal < maxVal)
      restText = ::colorize("userlogColoredText",
        ::loc("ui/parentheses", { text = "+" + min(unallocated * guns,maxVal - curVal ) }))
    local valColor = "activeTextColor"
    if (!curVal || maxVal == 0)
      valColor = "badTextColor"
    else if (curVal == maxVal)
      valColor = "goodTextColor"

    local valText = ::colorize(valColor, curVal*guns)
    local text = ::format("%s/%s %s", valText, (maxVal*guns).tostring(), restText)
    textObj.setValue(text)
  }

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

weaponVisual.getBundleCurItem <- function getBundleCurItem(air, bundle)
{
  if (!("itemsType" in bundle))
    return null

  if (bundle.itemsType == weaponsItem.weapon)
  {
    local curWeapon = getLastWeapon(air.name)
    foreach(item in bundle.itemsList)
      if (curWeapon == item.name)
        return item
    return bundle.itemsList[0]
  }
  else if (bundle.itemsType == weaponsItem.bullets)
  {
    local curName = ::get_last_bullets(air.name, ::getTblValue("subType", bundle, 0))
    local def = null
    foreach(item in bundle.itemsList)
      if (curName == item.name)
        return item
      else if (("isDefaultForGroup" in item)
               || (!def && curName == "" && !::wp_get_modification_cost(air.name, item.name)))
        def = item
    return def
  }
  else if (bundle.itemsType == weaponsItem.primaryWeapon)
  {
    local curPrimaryWeaponName = ::get_last_primary_weapon(air)
    foreach (item in bundle.itemsList)
      if(item.name == curPrimaryWeaponName)
        return item
  }
  return null
}

weaponVisual.getByCurBundle <- function getByCurBundle(air, bundle, func, defValue = "")
{
  local cur = getBundleCurItem(air, bundle)
  return cur? func(air, cur) : defValue
}

weaponVisual.isBullets <- function isBullets(item)
{
  return (("isDefaultForGroup" in item) && (item.isDefaultForGroup >= 0))
    || (item.type == weaponsItem.modification && getModificationBulletsGroup(item.name) != "")
}

weaponVisual.getBulletsIconItem <- function getBulletsIconItem(air, item)
{
  if (isBullets(item))
    return item

  if (item.type == weaponsItem.modification)
  {
    updateRelationModificationList(air, item.name)
    if ("relationModification" in item && item.relationModification.len() == 1)
      return ::getModificationByName(air, item.relationModification[0])
  }
  return null
}

weaponVisual.getItemName <- function getItemName(air, item, limitedName = true)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getLocName(air, item, limitedName)
}

weaponVisual.getItemImage <- function getItemImage(air, item)
{
  if (!isBullets(item))
  {
    if (item.type==weaponsItem.bundle)
      return getByCurBundle(air, item, getItemImage)

    if("image" in item && item.image != "")
      return item.image
    if (item.type==weaponsItem.primaryWeapon && ("weaponMod" in item) && item.weaponMod)
      return getItemImage(air, item.weaponMod)
  }
  return ""
}

weaponVisual.getBulletsIconData <- function getBulletsIconData(bulletsSet)
{
  if (!bulletsSet)
    return ""
  local blk = ::handyman.renderCached(("gui/weaponry/bullets"), getBulletsIconView(bulletsSet))
  return blk
}

/**
 * @param tooltipId If not null, tooltip block
 * will be added with specified tooltip id.
 */
weaponVisual.getBulletsIconView <- function getBulletsIconView(bulletsSet, tooltipId = null, tooltipDelayed = false)
{
  local view = {}
  if (!bulletsSet || !("bullets" in bulletsSet))
    return view

  initBulletIcons()
  local bulletIcons = getBulletIcons()
  view.bullets <- (@(bulletsSet, tooltipId, tooltipDelayed) function () {
      local res = []

      local length = bulletsSet.bullets.len()
      local isBelt = "isBulletBelt" in bulletsSet ? bulletsSet.isBulletBelt : true
      local maxAmountInView = 4
      if (bulletsSet.catridge)
        maxAmountInView = ::min(bulletsSet.catridge, maxAmountInView)
      local count = isBelt ? length * max(1,::floor(maxAmountInView / length)) : 1
      local totalWidth = 100.0
      local itemWidth = isBelt ? totalWidth / 5 : totalWidth
      local itemHeight = totalWidth
      local space = totalWidth - itemWidth * count
      local separator = (space > 0) ? (space / (count + 1)) : (count == 1 ? space : (space / (count - 1)))
      local start = (space > 0) ? separator : 0.0

      for (local i = 0; i < count; i++)
      {
        local imgId = bulletsSet.bullets[i % length]
        if (bulletsSet?.customIconsMap[imgId] != null)
          imgId = bulletsSet.customIconsMap[imgId]
        if (imgId.indexof("@") != null)
          imgId = imgId.slice(0, imgId.indexof("@"))
        local defaultImgId = ::isCaliberCannon(1000 * (bulletsSet?.caliber ?? 0.0)) ? "default_shell" : "default_ball"

        local item = {
          image           = "#ui/gameuiskin#" + bulletIcons[ (imgId in bulletIcons) ? imgId : defaultImgId ]
          posx            = (start + (itemWidth + separator) * i) + "%pw"
          sizex           = itemWidth + "%pw"
          sizey           = itemHeight + "%pw"
          useTooltip      = tooltipId != null
          tooltipId       = tooltipId
          tooltipDelayed  = tooltipId != null && tooltipDelayed
        }
        res.append(item)
      }

      return res
    })(bulletsSet, tooltipId, tooltipDelayed)

  local bIconParam = getTblValue("bIconParam", bulletsSet)
  if (bIconParam)
  {
    local addIco = []
    foreach(item in getBulletsFeaturesImg())
    {
      local idx = ::getTblValue(item.id, bIconParam, -1)
      if (idx in item.values)
        addIco.append({ img = item.values[idx] })
    }
    if (addIco.len())
      view.addIco <- addIco
  }
  return view
}

weaponVisual.getItemAmount <- function getItemAmount(air, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getAmount(air, item)
}

weaponVisual.getItemCost <- function getItemCost(air, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getCost(air, item)
}

//include spawn score cost
weaponVisual.getFullItemCostText <- function getFullItemCostText(unit, item)
{
  local res = ""
  local wType = ::g_weaponry_types.getUpgradeTypeByItem(item)
  local misRules = ::g_mis_custom_state.getCurMissionRules()

  if (!::is_in_flight() || misRules.isWarpointsRespawnEnabled)
    res = wType.getCost(unit, item).tostring()

  if (::is_in_flight() && misRules.isScoreRespawnEnabled)
  {
    local scoreCostText = wType.getScoreCostText(unit, item)
    if (scoreCostText.len())
      res += (res.len() ? ", " : "") + scoreCostText
  }
  return res
}

weaponVisual.getItemUnlockCost <- function getItemUnlockCost(air, item)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getUnlockCost(air, item)
}

weaponVisual.isCanBeDisabled <- function isCanBeDisabled(item)
{
  return (item.type == weaponsItem.modification || item.type == weaponsItem.expendables) &&
         (!("deactivationIsAllowed" in item) || item.deactivationIsAllowed) &&
         !isBullets(item)
}

weaponVisual.isResearchableItem <- function isResearchableItem(item)
{
  return item.type == weaponsItem.modification
}

weaponVisual.canResearchItem <- function canResearchItem(air, item, checkCurrent = true)
{
  return item.type == weaponsItem.modification &&
         canBeResearched(air, item, checkCurrent)
}

weaponVisual.canBeResearched <- function canBeResearched(air, item, checkCurrent = true)
{
  if (isResearchableItem(item))
    return ::canResearchMod(air, item, checkCurrent)
  return false
}

weaponVisual.isModInResearch <- function isModInResearch(air, item)
{
  if (item.name == "" || !("type" in item) || item.type != weaponsItem.modification)
    return false

  local status = ::shop_get_module_research_status(air.name, item.name)
  return status == ::ES_ITEM_STATUS_IN_RESEARCH
}

weaponVisual.getItemUpgradesStatus <- function getItemUpgradesStatus(unit, item)
{
  if (item.type == weaponsItem.primaryWeapon)
  {
    local countData = countWeaponsUpgrade(unit, item)
    return !countData?[1] ? ""
      : countData[0] >= countData[1] ? "full"
      : "part"
  }
  if (item.type == weaponsItem.modification)
  {
    local curPrimWeaponName = ::get_last_primary_weapon(unit)
    local weapMod = ::getModificationByName(unit, curPrimWeaponName)
    local upgradesList = getItemUpgradesList(weapMod || unit) //default weapon upgrades stored in unit
    if (upgradesList)
      foreach(list in upgradesList)
        if (::isInArray(item.name, list))
          return "mod"
  }
  return ""
}

weaponVisual.getItemUpgradesList <- function getItemUpgradesList(item)
{
  if ("weaponUpgrades" in item)
    return item.weaponUpgrades
  else if ("weaponMod" in item && item.weaponMod != null && "weaponUpgrades" in item.weaponMod)
    return item.weaponMod.weaponUpgrades
  return null
}

weaponVisual.countWeaponsUpgrade <- function countWeaponsUpgrade(air, item)
{
  local upgradesTotal = 0
  local upgraded = 0
  local upgrades = getItemUpgradesList(item)

  if (!upgrades)
    return null

  foreach (i, modsArray in upgrades)
  {
    if (modsArray.len() == 0)
      continue

    upgradesTotal++

    foreach(modName in modsArray)
      if (::shop_is_modification_enabled(air.name, modName))
      {
        upgraded++
        break
      }
  }
  return [upgraded, upgradesTotal]
}

weaponVisual.getRepairCostCoef <- function getRepairCostCoef(item)
{
  local modeName = ::get_current_shop_difficulty().getEgdName(true)
  return item?["repairCostCoef" + modeName] ?? item?.repairCostCoef ?? 0
}

weaponVisual.getReqModsText <- function getReqModsText(air, item)
{
  local reqText = ""
  foreach(rp in ["reqWeapon", "reqModification"])
      if (rp in item)
        foreach (req in item[rp])
          if (rp == "reqWeapon" && !::shop_is_weapon_purchased(air.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getWeaponNameText(air.name, false, req, ", ")
          else
          if (rp == "reqModification" && !::shop_is_modification_purchased(air.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getModificationName(air, req)
  return reqText
}

weaponVisual.getItemDescTbl <- function getItemDescTbl(air, item, params = null, effect = null, updateEffectFunc = null)
{
  local res = { name = "", desc = "", delayed = false }
  local needShowWWSecondaryWeapons = item.type==weaponsItem.weapon && ::is_in_flight() &&
    ::g_mis_custom_state.getCurMissionRules().isWorldWar

  if (item.type==weaponsItem.bundle)
    return ::weaponVisual.getByCurBundle(air, item,
      function(air, item) {
        return getItemDescTbl(air, item, params, effect, updateEffectFunc)
      }, res)

  local name = "<color=@activeTextColor>" + getItemName(air, item, false) + "</color>"
  local desc = ""
  local addDesc = ""
  local reqText = ""
  local curTier = "tier" in item? item.tier : 1
  local statusTbl = getItemStatusTbl(air, item)
  local currentPrice = statusTbl.showPrice? getFullItemCostText(air, item) : ""

  local hasPlayerInfo = params?.hasPlayerInfo ?? true
  if (hasPlayerInfo
    && !::weaponVisual.isTierAvailable(air, curTier) && curTier > 1
    && !needShowWWSecondaryWeapons)
  {
    local reqMods = ::getNextTierModsCount(air, curTier - 1)
    if(reqMods > 0)
      reqText = ::loc("weaponry/unlockModTierReq",
                      { tier = ::roman_numerals[curTier], amount = reqMods.tostring() })
    else
      reqText = ::loc("weaponry/unlockTier/reqPrevTiers")
    reqText = "<color=@badTextColor>" + reqText + "</color>"
    res.reqText <- reqText

    if(!(params?.canDisplayInfo ?? true))
    {
      res.delayed = true
      return res
    }
  }

  if (item.type==weaponsItem.weapon)
  {
    name = ""
    desc = getWeaponInfoText(air, { isPrimary = false, weaponPreset = item.name,
      detail = INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })

    if(item.rocket || item.bomb)
    {
      buildPiercingData(air.name,
        ::calculate_tank_bullet_parameters(air.name, item.name, true, true), res)
    }

    if (effect)
      addDesc = weaponryEffects.getDesc(air, effect)
    if (!effect && updateEffectFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(air.name, item.name, false, this, updateEffectFunc, null) ?? true
  }
  else if (item.type==weaponsItem.primaryWeapon)
  {
    name = ""
    desc = getWeaponInfoText(air, { isPrimary = true, weaponPreset = item.name,
      detail = INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })
    local upgradesList = getItemUpgradesList(item)
    if(upgradesList)
    {
      local upgradesCount = countWeaponsUpgrade(air, item)
      if (upgradesCount?[1])
        addDesc = "\n" + ::loc("weaponry/weaponsUpgradeInstalled",
                               { current = upgradesCount[0], total = upgradesCount[1] })
      foreach(arr in upgradesList)
        foreach(upgrade in arr)
        {
          if(upgrade == null)
            continue
          addDesc += "\n" + (::shop_is_modification_enabled(air.name, upgrade) ? "<color=@goodTextColor>" : "<color=@commonTextColor>") + getModificationName(air, upgrade) + "</color>"
        }
    }
  }
  else if (item.type==weaponsItem.modification || item.type==weaponsItem.expendables)
  {
    if (effect)
    {
      desc = getModificationInfo(air, item.name).desc;
      addDesc = weaponryEffects.getDesc(air, effect);
    }
    else
    {
      local info = getModificationInfo(air, item.name, false, false, this, updateEffectFunc)
      desc = info.desc
      res.delayed = info.delayed
    }

    addBulletsParamToDesc(res, air, item)
  }
  else if (item.type==weaponsItem.spare)
    desc = ::loc("spare/"+item.name + "/desc")

  if (hasPlayerInfo && statusTbl.unlocked && currentPrice != "")
  {
    local amountText = ::getAmountAndMaxAmountText(statusTbl.amount, statusTbl.maxAmount, statusTbl.showMaxAmount)
    if (amountText != "")
    {
      local color = statusTbl.amount < statusTbl.amountWarningValue ? "badTextColor" : ""
      res.amountText <- ::colorize(color, ::loc("options/count") + ::loc("ui/colon") + amountText)

      if (::is_in_flight() && item.type==weaponsItem.weapon)
      {
        local respLeft = ::g_mis_custom_state.getCurMissionRules().getUnitWeaponRespawnsLeft(air, item)
        if (respLeft >= 0)
          res.amountText += ::loc("ui/colon") + ::loc("respawn/leftRespawns", { num = respLeft })
      }
    }
    if (statusTbl.showMaxAmount && statusTbl.amount < statusTbl.amountWarningValue)
      res.warningText <- ::loc("weapons/restock_advice")
  }
  else if (params?.isInHudActionBar)
  {
    local modData = ::u.search(::get_action_bar_items(),
      @(itemData) itemData?.modificationName == item.name)
    if (modData)
      res.amountText <- ::ActionBar.getModAmountText(modData, true)
  }

  if (statusTbl.discountType != "")
  {
    local discount = getDiscountByPath(getDiscountPath(air, item, statusTbl.discountType))
    if (discount > 0 && statusTbl.showPrice)
    {
      local cost = "cost" in item? item.cost : 0
      local costGold = "costGold" in item? item.costGold : 0
      local priceText = ::Cost(cost, costGold).getUncoloredText()
      if (priceText != "")
        res.noDiscountPrice <- "<color=@oldPrice>" + priceText + "</color>"
      if (currentPrice != "")
        currentPrice = "<color=@goodTextColor>" + currentPrice + "</color>"
    }
  }

  local repairCostCoef = getRepairCostCoef(item)
  if (repairCostCoef)
  {
    local avgRepairMul = ::get_warpoints_blk()?.avgRepairMul ?? 1.0
    local egdCode = ::get_current_shop_difficulty().egdCode
    local rCost = ::wp_get_repair_cost_by_mode(air.name, egdCode, false)
    local avgCost = (rCost * repairCostCoef * avgRepairMul).tointeger()
    if (avgCost)
      addDesc += "\n" + ::loc("shop/avg_repair_cost") + ::nbsp
        + (avgCost > 0? "+" : "")
        + ::Cost(avgCost).toStringWithParams({isWpAlwaysShown = true, isColored = false})
  }

  if (hasPlayerInfo)
  {
    if (!statusTbl.amount && !needShowWWSecondaryWeapons)
    {
      local reqMods = getReqModsText(air, item)
      if(reqMods != "")
        reqText += (reqText==""? "" : "\n") + reqMods
    }
    if (isBullets(item) && !isBulletsGroupActiveByMod(air, item))
      reqText += ((reqText=="")?"":"\n") + ::loc("msg/weaponSelectRequired")
    reqText = reqText!=""? ("<color=@badTextColor>" + reqText + "</color>") : ""

    if (needShowWWSecondaryWeapons)
      reqText = getReqTextWorldWarArmy(air, item)
  }
  res.reqText <- reqText

  if (currentPrice != "")
    res.currentPrice <- currentPrice
  res.name = name
  res.desc = desc
  res.addDesc <- addDesc
  return res
}

weaponVisual.addBulletsParamToDesc <- function addBulletsParamToDesc(descTbl, unit, item)
{
  if (!unit.unitType.canUseSeveralBulletsForGun && !::has_feature("BulletParamsForAirs"))
    return
  local bIcoItem = getBulletsIconItem(unit, item)
  if (!bIcoItem)
    return

  local modName = bIcoItem.name
  local bulletsSet = getBulletsSetData(unit, modName)
  if (!bulletsSet)
    return

  local bIconParam = getTblValue("bIconParam", bulletsSet)
  if (bIconParam)
  {
    descTbl.bulletActions <- []
    local setClone = clone bulletsSet
    foreach(p in ["armor", "damage"])
    {
      local value = ::getTblValue(p, bIconParam, -1)
      if (value < 0)
        continue

      setClone.bIconParam = { [p] = value }
      descTbl.bulletActions.append({
        text = ::loc("bulletAction/" + p)
        visual = getBulletsIconData(setClone)
      })
    }
  }
  else
    descTbl.bulletActions <- [{ visual = getBulletsIconData(bulletsSet) }]

  local searchName = getBulletsSearchName(unit, modName)
  local useDefaultBullet = searchName!=modName;
  local bullet_parameters = ::calculate_tank_bullet_parameters(unit.name,
    useDefaultBullet && "weaponBlkName" in bulletsSet ? bulletsSet.weaponBlkName : getModificationBulletsEffect(searchName),
    useDefaultBullet, false);

  buildPiercingData(unit, bullet_parameters, descTbl, bulletsSet, true)
}

weaponVisual.buildPiercingData <- function buildPiercingData(unit, bullet_parameters, descTbl, bulletsSet = null, needAdditionalInfo = false)
{
  local param = { armorPiercing = array(0, null) , armorPiercingDist = array(0, null)}
  local needAddParams = bullet_parameters.len() == 1

  local isSmokeShell = bulletsSet?.weaponType == WEAPON_TYPE.GUN && bulletsSet?.bullets?[0] == "smoke_tank"
  local isSmokeGenerator = isSmokeShell || bulletsSet?.weaponType == WEAPON_TYPE.SMOKE_SCREEN
  local isCountermeasure = isSmokeGenerator || bulletsSet?.weaponType == WEAPON_TYPE.FLARES

  if (isCountermeasure)
  {
    local whitelistParams = [ "bulletType" ]
    if (isSmokeShell)
      whitelistParams.append("mass", "speed", "weaponBlkPath")
    local filteredBulletParameters = []
    foreach (_params in bullet_parameters)
    {
      local params = _params ? {} : null
      if (_params)
      {
        foreach (key in whitelistParams)
          if (key in _params)
            params[key] <- _params[key]

        params.armorPiercing     <- []
        params.armorPiercingDist <- []
      }
      filteredBulletParameters.append(params)
    }
    bullet_parameters = filteredBulletParameters
  }

  foreach (bullet_params in bullet_parameters)
  {
    if (!bullet_params)
      continue

    if (bullet_params?.bulletType != "aam")
    {
      if (param.armorPiercingDist.len() < bullet_params.armorPiercingDist.len())
      {
        param.armorPiercing.resize(bullet_params.armorPiercingDist.len());
        param.armorPiercingDist = bullet_params.armorPiercingDist;
      }
      foreach(ind, d in param.armorPiercingDist)
      {
        for (local i = 0; i < bullet_params.armorPiercingDist.len(); i++)
        {
          local armor = null;
          local idist = bullet_params.armorPiercingDist[i].tointeger()
          if (typeof(bullet_params.armorPiercing[i]) != "table")
            continue

          if (d == idist || (d < idist && !i))
            armor = ::u.map(bullet_params.armorPiercing[i], @(f) stdMath.round(f).tointeger())
          else if (d < idist && i)
          {
            local prevDist = bullet_params.armorPiercingDist[i-1].tointeger()
            if (d > prevDist)
              armor = ::u.tablesCombine(bullet_params.armorPiercing[i-1], bullet_params.armorPiercing[i],
                        (@(d, prevDist, idist) function(prev, next) {
                          return (prev + (next - prev) * (d - prevDist.tointeger()) / (idist - prevDist)).tointeger()
                        })(d, prevDist, idist), 0)
          }
          if (armor == null)
            continue

          param.armorPiercing[ind] = (!param.armorPiercing[ind]) ? armor
                                    : ::u.tablesCombine(param.armorPiercing[ind], armor, ::max)
        }
      }
    }

    if (!needAddParams)
      continue

    foreach(p in ["mass", "speed", "fuseDelayDist", "explodeTreshold", "operatedDist", "endSpeed", "maxSpeed", "rangeBand0", "rangeBand1"])
      param[p] <- ::getTblValue(p, bullet_params, 0)

    foreach(p in ["reloadTimes", "autoAiming", "weaponBlkPath"])
    {
      if(p in bullet_params)
        param[p] <- bullet_params[p]
    }

    if(bulletsSet)
    {
      foreach(p in ["caliber", "explosiveType", "explosiveMass",
        "proximityFuseArmDistance", "proximityFuseRadius" ])
      if (p in bulletsSet)
        param[p] <- bulletsSet[p]

      if (isSmokeGenerator)
        foreach(p in ["smokeShellRad", "smokeActivateTime", "smokeTime"])
          if (p in bulletsSet)
            param[p] <- bulletsSet[p]
    }

    param.bulletType <- ::getTblValue("bulletType", bullet_params, "")
  }

  descTbl.bulletParams <- []
  local p = []
  local addProp = function(arr, text, value)
  {
    arr.append({
      text = text
      value = value
    })
  }
  if (needAdditionalInfo && "mass" in param)
  {
    if (param.caliber > 0)
      addProp(p, ::loc("bullet_properties/caliber"),
                stdMath.round_by_value(param.caliber, ::isCaliberCannon(param.caliber) ? 1 : 0.01) + " " + ::loc("measureUnits/mm"))
    if (param.mass > 0)
      addProp(p, ::loc("bullet_properties/mass"),
                ::g_measure_type.getTypeByName("kg", true).getMeasureUnitsText(param.mass))
    if (param.speed > 0)
      addProp(p, ::loc("bullet_properties/speed"),
                 ::format("%.0f %s", param.speed, ::loc("measureUnits/metersPerSecond_climbSpeed")))

    local maxSpeed = (param?.maxSpeed || param?.endSpeed) ?? 0
    if (maxSpeed)
      addProp(p, ::loc("rocket/maxSpeed"), ::g_measure_type.SPEED_PER_SEC.getMeasureUnitsText(maxSpeed))

    if ("autoAiming" in param)
    {
      local aimingTypeLocId = "guidanceSystemType/" + (param.autoAiming ? "semiAuto" : "handAim")
      addProp(p, ::loc("guidanceSystemType/header"), ::loc(aimingTypeLocId))
    }

    local operatedDist = ::getTblValue("operatedDist", param, 0)
    if (operatedDist)
      addProp(p, ::loc("firingRange"), ::g_measure_type.DISTANCE.getMeasureUnitsText(operatedDist))

    local explosiveType = ::getTblValue("explosiveType", param)
    if (explosiveType)
      addProp(p, ::loc("bullet_properties/explosiveType"), ::loc("explosiveType/" + explosiveType))
    local explosiveMass = ::getTblValue("explosiveMass", param)
    if (explosiveMass)
      addProp(p, ::loc("bullet_properties/explosiveMass"),
        ::g_dmg_model.getMeasuredExplosionText(explosiveMass))

    if (explosiveType && explosiveMass)
    {
      local tntEqText = ::g_dmg_model.getTntEquivalentText(explosiveType, explosiveMass)
      if (tntEqText.len())
        addProp(p, ::loc("bullet_properties/explosiveMassInTNTEquivalent"), tntEqText)
    }

    local fuseDelayDist = stdMath.roundToDigits(param.fuseDelayDist, 2)
    if (fuseDelayDist)
      addProp(p, ::loc("bullet_properties/fuseDelayDist"),
                 fuseDelayDist + " " + ::loc("measureUnits/meters_alt"))
    local explodeTreshold = stdMath.roundToDigits(param.explodeTreshold, 2)
    if (explodeTreshold)
      addProp(p, ::loc("bullet_properties/explodeTreshold"),
                 explodeTreshold + " " + ::loc("measureUnits/mm"))
    local rangeBand0 = ::getTblValue("rangeBand0", param)
    if (rangeBand0)
      addProp(p, ::loc("missile/seekerRange/rearAspect"), ::g_measure_type.DISTANCE.getMeasureUnitsText(rangeBand0))
    local rangeBand1 = ::getTblValue("rangeBand1", param)
    if (rangeBand1)
      addProp(p, ::loc("missile/seekerRange/allAspect"), ::g_measure_type.DISTANCE.getMeasureUnitsText(rangeBand1))

    local proximityFuseArmDistance = stdMath.round(param?.proximityFuseArmDistance ?? 0)
    if (proximityFuseArmDistance)
      addProp(p, ::loc("torpedo/armingDistance"),
        proximityFuseArmDistance + " " + ::loc("measureUnits/meters_alt"))
    local proximityFuseRadius = stdMath.round(param?.proximityFuseRadius ?? 0)
    if (proximityFuseRadius)
      addProp(p, ::loc("bullet_properties/proximityFuze/triggerRadius"),
        proximityFuseRadius + " " + ::loc("measureUnits/meters_alt"))

    local ricochetData = !isCountermeasure && ::g_dmg_model.getRicochetData(param.bulletType)
    if (ricochetData)
      foreach(item in ricochetData.angleProbabilityMap)
        addProp(p, ::loc("bullet_properties/angleByProbability",
                         { probability = stdMath.roundToDigits(100.0 * item.probability, 2) }),
                   stdMath.roundToDigits(item.angle, 2) + ::loc("measureUnits/deg"))

    if ("reloadTimes" in param)
    {
      local currentDiffficulty = ::is_in_flight() ? ::get_mission_difficulty_int()
        : ::get_current_shop_difficulty().diffCode
      local reloadTime = param.reloadTimes[currentDiffficulty]
      if(reloadTime > 0)
        addProp(p, ::colorize("badTextColor", ::loc("bullet_properties/cooldown")),
                   ::colorize("badTextColor", stdMath.roundToDigits(reloadTime, 2) + " " + ::loc("measureUnits/seconds")))
    }

    if ("smokeShellRad" in param)
      addProp(p, ::loc("bullet_properties/smokeShellRad"),
                 stdMath.roundToDigits(param.smokeShellRad, 2) + " " + ::loc("measureUnits/meters_alt"))

    if ("smokeActivateTime" in param)
      addProp(p, ::loc("bullet_properties/smokeActivateTime"),
                 stdMath.roundToDigits(param.smokeActivateTime, 2) + " " + ::loc("measureUnits/seconds"))

    if ("smokeTime" in param)
      addProp(p, ::loc("bullet_properties/smokeTime"),
                 stdMath.roundToDigits(param.smokeTime, 2) + " " + ::loc("measureUnits/seconds"))

    local bTypeDesc = ::loc(param.bulletType, "")
    if (bTypeDesc != "")
      descTbl.bulletsDesc <- bTypeDesc
  }
  descTbl.bulletParams.append({ props = p })

  local bulletName = ""
  if("weaponBlkPath" in param)
    bulletName = ::loc("weapons/{0}".subst(::get_weapon_name_by_blk_path(param.weaponBlkPath)))

  local apData = getArmorPiercingViewData(param.armorPiercing, param.armorPiercingDist)
  if (apData)
  {
    local header = ::loc("bullet_properties/armorPiercing")
      + (::u.isEmpty(bulletName) ? "" : ( ": " + bulletName))
      + "\n" + ::format("(%s / %s)", ::loc("distance"), ::loc("bullet_properties/hitAngle"))
    descTbl.bulletParams.append({ props = apData, header = header })
  }
}

weaponVisual.getArmorPiercingViewData <- function getArmorPiercingViewData(armorPiercing, dist)
{
  local res = null
  if (armorPiercing.len() <= 0)
    return res

  local angles = null
  foreach(ind, armorTbl in armorPiercing)
  {
    if (armorTbl == null)
      continue
    if (!angles)
    {
      res = []
      angles = ::u.keys(armorTbl)
      angles.sort(@(a,b) a <=> b)
      local headRow = {
        text = ""
        values = ::u.map(angles, function(v) { return { value = v + ::loc("measureUnits/deg") } })
      }
      res.append(headRow)
    }

    local row = {
      text = dist[ind] + ::loc("measureUnits/meters_alt")
      values = []
    }
    foreach(angle in angles)
      row.values.append({ value = ::getTblValue(angle, armorTbl, 0) + ::loc("measureUnits/mm") })
    res.append(row)
  }
  return res
}

weaponVisual.updateModType <- function updateModType(unit, mod)
{
  if ("type" in mod)
    return

  local name = mod.name
  local primaryWeaponsNames = ::getPrimaryWeaponsList(unit)
  foreach(modName in primaryWeaponsNames)
    if (modName == name)
    {
      mod.type <- weaponsItem.primaryWeapon
      return
    }

  mod.type <- weaponsItem.modification
  return
}

weaponVisual.updateSpareType <- function updateSpareType(spare)
{
  if (!("type" in spare))
    spare.type <- weaponsItem.spare
}

weaponVisual.updateWeaponTooltip <- function updateWeaponTooltip(obj, air, item, handler, params={}, effect=null)
{
  local descTbl = getItemDescTbl(air, item, params, effect,
    function(effect, ...) {
      if (::checkObj(obj) && obj.isVisible())
        ::weaponVisual.updateWeaponTooltip(obj, air, item, handler, params, effect)
    })

  local curExp = ::shop_get_module_exp(air.name, item.name)
  local is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && ::isModResearched(air, item))
  local is_researching = isModInResearch(air, item)
  local is_paused = canBeResearched(air, item, true) && curExp > 0

  if (is_researching || is_paused || !is_researched)
  {
    if ((("reqExp" in item) && item.reqExp > curExp) || is_paused)
    {
      local expText = ""
      if (is_researching || is_paused)
        expText = ::loc("currency/researchPoints/name") + ::loc("ui/colon") +
          ::colorize("activeTextColor",
            ::Cost().setRp(curExp).toStringWithParams({isRpAlwaysShown = true}) +
            ::loc("ui/slash") + ::Cost().setRp(item.reqExp).tostring())
      else
        expText = ::loc("shop/required_rp") + " " + "<color=@activeTextColor>" +
          ::Cost().setRp(item.reqExp).tostring() + "</color>"

      local diffExp = ::Cost().setRp(::getTblValue("diffExp", params, 0)).tostring()
      if (diffExp.len())
        expText += " (+" + diffExp + ")"
      descTbl.expText <- expText
    }
  }
  else if (params?.hasPlayerInfo ?? true)
    descTbl.showPrice <- ("currentPrice" in descTbl) || ("noDiscountPrice" in descTbl)

  local data = ::handyman.renderCached(("gui/weaponry/weaponTooltip"), descTbl)
  obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
}

weaponVisual.isTierAvailable <- function isTierAvailable(air, tierNum)
{
  local isAvailable = ::is_tier_available(air.name, tierNum)

  if (!isAvailable && tierNum > 1) //make force check
  {
    local reqMods = air.needBuyToOpenNextInTier[tierNum-2]
    foreach(mod in air.modifications)
      if(mod.tier == (tierNum-1) &&
         ::isModResearched(air, mod) &&
         getModificationBulletsGroup(mod.name) == "" &&
         !::wp_get_modification_cost_gold(air.name, mod.name)
        )
        reqMods--

    isAvailable = reqMods <= 0
  }

  return isAvailable
}

weaponVisual.getReqTextWorldWarArmy <- function getReqTextWorldWarArmy(unit, item)
{
  local text = ""
  local misRules = ::g_mis_custom_state.getCurMissionRules()
  if (!misRules.needCheckWeaponsAllowed(unit))
    return text

  local isEnabledByMission = misRules.isUnitWeaponAllowed(unit, item)
  local isEnabledForUnit = ::is_weapon_enabled(unit, item)
  if (!isEnabledByMission)
    text = "<color=@badTextColor>" + ::loc("worldwar/weaponry/inArmyIsDisabled") + "</color>"
  else if (isEnabledByMission && !isEnabledForUnit)
    text = "<color=@badTextColor>" + ::loc("worldwar/weaponry/inArmyIsEnabled/weaponRequired") + "</color>"
  else if (isEnabledByMission && isEnabledForUnit)
    text = "<color=@goodTextColor>" + ::loc("worldwar/weaponry/inArmyIsEnabled") + "</color>"

  return text
}

weaponVisual.getStatusIcon <- function getStatusIcon(unit, item)
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

weaponVisual.getDiscountPath <- function getDiscountPath(air, item, discountType)
{
  local discountPath = ["aircrafts", air.name, item.name]
  if (item.type != weaponsItem.spare)
    discountPath.insert(2, discountType)

  return discountPath
}

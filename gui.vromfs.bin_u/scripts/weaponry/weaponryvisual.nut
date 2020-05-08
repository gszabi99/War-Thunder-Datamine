local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local modUpgradeElem = ::require("scripts/weaponry/elems/modUpgradeElem.nut")
local { countMeasure } = require("scripts/options/optionsMeasureUnits.nut")
local { canResearchItem,
        getItemUnlockCost,
        getBundleCurItem,
        isCanBeDisabled,
        isModInResearch,
        getItemStatusTbl,
        getDiscountPath,
        getItemUpgradesStatus } = require("scripts/weaponry/itemInfo.nut")
local { isBullets,
        isFakeBullet,
        getBulletsSetData,
        getBulletsIconItem,
        getBulletsIconView,
        getModificationBulletsGroup } = require("scripts/weaponry/bulletsInfo.nut")
local { WEAPON_TYPE,
        TRIGGER_TYPE,
        WEAPON_TEXT_PARAMS,
        getLastWeapon,
        getUnitWeaponry,
        addWeaponsFromBlk,
        getWeaponExtendedInfo } = require("scripts/weaponry/weaponryInfo.nut")

local function getTextNoWeapons(unit, isPrimary)
{
  return isPrimary ? ::loc("weapon/noPrimaryWeapon") : (unit.isAir() || unit.isHelicopter()) ?
    ::loc("weapon/noSecondaryWeapon") : ::loc("weapon/noAdditionalWeapon")
}

local function getWeaponInfoText(air, p = WEAPON_TEXT_PARAMS)
{
  local text = ""
  air = typeof(air) == "string" ? ::getAircraftByName(air) : air
  if (!air)
    return text

  local weapons = getUnitWeaponry(air, p)
  if (weapons == null)
    return text

  p = WEAPON_TEXT_PARAMS.__merge(p)
  local unitType = ::get_es_unit_type(air)
  if (::u.isEmpty(weapons) && p.needTextWhenNoWeapons)
    text += getTextNoWeapons(air, p.isPrimary)
  local consumableWeapons = [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM, WEAPON_TYPE.ROCKETS,
    WEAPON_TYPE.TORPEDOES, WEAPON_TYPE.BOMBS, WEAPON_TYPE.SMOKE, WEAPON_TYPE.FLARES ]
  local stackableWeapons = [WEAPON_TYPE.TURRETS]
  foreach (index, weaponType in WEAPON_TYPE)
  {
    if (!(weaponType in weapons))
      continue

    local triggers = weapons[weaponType]
    triggers.sort(@(a, b) b.caliber <=> a.caliber)

    if (::isInArray(weaponType, stackableWeapons))
    {  //merge stackable in one
      for(local i=0; i<triggers.len(); i++)
      {
        triggers[i][weaponType] <- 1
        local sameIdx = -1
        for(local j=0; j<i; j++)
          if (triggers[i].len() == triggers[j].len())
          {
            local same = true
            foreach(wName, w in triggers[j])
              if (!(wName in triggers[i]) ||
                  ((typeof(w) == "table") && triggers[i][wName].num!=w.num))
              {
                same = false
                break
              }
            if (same)
            {
              sameIdx = j
              break
            }
          }
        if (sameIdx>=0)
        {
          triggers[sameIdx][weaponType]++
          foreach(wName, w in triggers[i])
            if (typeof(w) == "table")
              triggers[sameIdx][wName].ammo += w.ammo
          triggers.remove(i)
          i--
        }
      }
    }

    local isShortDesc = p.detail <= INFO_DETAIL.SHORT //for weapons SHORT == LIMITED_11
    local weapTypeCount = 0; //for shortDesc only
    foreach (trigger in triggers)
    {
      local tText = ""
      foreach (weaponName, weapon in trigger)
        if (typeof(weapon) == "table")
        {
          if (tText != "" && weapTypeCount==0)
            tText += p.newLine

          if (::isInArray(weaponType, consumableWeapons))
          {
            if (isShortDesc)
            {
              tText += ::loc($"weapons/{weaponName}/short")
              if (weapon.ammo > 1)
                tText += " " + ::format(::loc("weapons/counter/right/short"), weapon.ammo)
            }
            else
            {
              tText += ::loc($"weapons/{weaponName}") + ::format(::loc("weapons/counter"), weapon.ammo)
              if (weaponType == "torpedoes" && p.isPrimary != null &&
                  ::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])) // torpedoes drop for air only
              {
                if (weapon.dropSpeedRange)
                {
                  local speedKmph = countMeasure(0, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
                  local speedMps  = countMeasure(3, [weapon.dropSpeedRange.x, weapon.dropSpeedRange.y])
                  tText += "\n"+::format( ::loc("weapons/drop_speed_range"),
                    "{0} {1}".subst(speedKmph, ::loc("ui/parentheses", { text = speedMps })) )
                }
                if (weapon.dropHeightRange)
                  tText += "\n"+::format(::loc("weapons/drop_height_range"),
                    countMeasure(1, [weapon.dropHeightRange.x, weapon.dropHeightRange.y]))
              }
              if (p.detail >= INFO_DETAIL.EXTENDED && unitType != ::ES_UNIT_TYPE_TANK)
                tText += getWeaponExtendedInfo(weapon, weaponType, air, p.ediff, p.newLine + ::nbsp + ::nbsp + ::nbsp + ::nbsp)
            }
          }
          else
          {
            if (isShortDesc)
              weapTypeCount += (TRIGGER_TYPE.TURRETS in trigger)? 0 : weapon.num
            else
            {
              tText += ::loc($"weapons/{weaponName}")
              if (weapon.num > 1)
                tText += ::format(::loc("weapons/counter"), weapon.num)

              if (weapon.ammo > 0)
                tText += " (" + ::loc("shop/ammo") + ::loc("ui/colon") + weapon.ammo + ")"

              if (!air.unitType.canUseSeveralBulletsForGun)
              {
                local rTime = ::get_reload_time_by_caliber(weapon.caliber, p.ediff)
                if (rTime)
                {
                  if (p.isLocalState)
                  {
                    local difficulty = ::get_difficulty_by_ediff(p.ediff ?? ::get_current_ediff())
                    local key = ::isCaliberCannon(weapon.caliber) ? "cannonReloadSpeedK" : "gunReloadSpeedK"
                    local speedK = air.modificators?[difficulty.crewSkillName]?[key] ?? 1.0
                    if (speedK)
                      rTime = stdMath.round_by_value(rTime / speedK, 1.0).tointeger()
                  }
                  tText += " " + ::loc("bullet_properties/cooldown") + " " + time.secondsToString(rTime, true, true)
                }
              }
            }
          }
        }

      if (isShortDesc)
        weapTypeCount += (TRIGGER_TYPE.TURRETS in trigger)? trigger[TRIGGER_TYPE.TURRETS] : 0
      else
      {
        if (TRIGGER_TYPE.TURRETS in trigger) // && !air.unitType.canUseSeveralBulletsForGun)
        {
          if(trigger[TRIGGER_TYPE.TURRETS] > 1)
            tText = ::format(::loc("weapons/turret_number"), trigger[TRIGGER_TYPE.TURRETS]) + tText
          else
            tText = ::g_string.utf8ToUpper(::loc("weapons_types/turrets"), 1) + ::loc("ui/colon") + tText
        }
      }

      if (tText!="")
        text += ((text!="")? p.newLine : "") + tText
    }
    if (weapTypeCount>0)
    {
      if (text!="") text += p.newLine
      if (isShortDesc)
        text += ::loc("weapons_types/" + weaponType) + ::nbsp + ::format(::loc("weapons/counter/right/short"), weapTypeCount)
      else
        text += ::loc("weapons_types/" + weaponType) + ::format(::loc("weapons/counter"), weapTypeCount)
    }
  }

  if (text=="" && p.needTextWhenNoWeapons)
    text = getTextNoWeapons(air, p.isPrimary)

  return text
}

local function getWeaponNameText(air, isPrimary = null, weaponPreset=-1, newLine=", ")
{
  return getWeaponInfoText(air,
    { isPrimary = isPrimary, weaponPreset = weaponPreset, newLine = newLine, detail = INFO_DETAIL.SHORT })
}


local function getWeaponXrayDescText(weaponBlk, unit, ediff)
{
  local weaponsBlk = ::DataBlock()
  weaponsBlk["Weapon"] = weaponBlk
  local weaponTypes = addWeaponsFromBlk({}, weaponsBlk, unit)
  foreach (weaponType, weaponTypeList in weaponTypes)
    foreach (weapons in weaponTypeList)
      foreach (weapon in weapons)
        if (::u.isTable(weapon))
          return getWeaponExtendedInfo(weapon, weaponType, unit, ediff, "\n")
  return ""
}


local function getWeaponDescTextByTriggerGroup(triggerGroup, unit, ediff)
{
  local unitBlk = ::get_full_unit_blk(unit.name)
  local primaryWeapon = ::get_last_primary_weapon(unit)
  local secondaryWeapon = getLastWeapon(unit.name)

  local primaryBlk = ::getCommonWeaponsBlk(unitBlk, primaryWeapon)
  local weaponTypes = {}
  if (primaryBlk)
    weaponTypes = addWeaponsFromBlk(weaponTypes, primaryBlk, unit)
  if (unitBlk?.weapon_presets)
    foreach (wp in (unitBlk.weapon_presets % "preset"))
      if (wp.name == secondaryWeapon)
      {
        local wpBlk = ::DataBlock(wp.blk)
        if (wpBlk)
          weaponTypes = addWeaponsFromBlk(weaponTypes, wpBlk, unit)
        break
      }

  if (weaponTypes?[triggerGroup])
    foreach (weapons in weaponTypes[triggerGroup])
      foreach (weaponName, weapon in weapons)
        if (::u.isTable(weapon))
          return "".concat(
            ::loc($"weapons/{weaponName}"),
            ::format(::loc("weapons/counter"), weapon.ammo),
            getWeaponExtendedInfo(weapon, triggerGroup, unit, ediff, "\n{0}{0}{0}{0}".subst(::nbsp))
          )
  return ""
}

// return short desc of air.weapons[weaponPresetNo], like M\C\B\T
local function getWeaponShortType(air, weaponPresetNo=0)
{
  if (typeof(air) == "string")
    air = ::getAircraftByName(air)

  if (!air)
    return ""

  local textArr = []
  if (air.weapons[weaponPresetNo].frontGun)
    textArr.append(::loc("weapons_types/short/guns"))
  if (air.weapons[weaponPresetNo].cannon)
    textArr.append(::loc("weapons_types/short/cannons"))
  if (air.weapons[weaponPresetNo].bomb)
    textArr.append(::loc("weapons_types/short/bombs"))
  if (air.weapons[weaponPresetNo].rocket)
    textArr.append(::loc("weapons_types/short/rockets"))
  if (air.weapons[weaponPresetNo].torpedo)
    textArr.append(::loc("weapons_types/short/torpedoes"))

  return ::loc("weapons_types/short/separator").join(textArr)
}

local function getWeaponShortTypeFromWpName(wpName, air = null)
{
  if (!wpName || typeof(wpName) != "string")
    return ""

  if (typeof(air) == "string")
    air = ::getAircraftByName(air)

  if (!air)
    return ""

  for (local i = 0; i < air.weapons.len(); ++i)
  {
    if (wpName == air.weapons[i].name)
      return getWeaponShortType(air, i)
  }

  return ""
}

local function getDefaultBulletName(unit)
{
  if (!("modifications" in unit))
    return ""

  local ignoreGroups = [null, ""]
  for (local modifNo = 0; modifNo < unit.modifications.len(); modifNo++)
  {
    local modif = unit.modifications[modifNo]
    local modifName = modif.name;

    local groupName = getModificationBulletsGroup(modifName);
    if (::isInArray(groupName, ignoreGroups))
      continue

    local bData = getBulletsSetData(unit, modifName)
    if (!bData || bData?.useDefaultBullet)
      return groupName + "_default"

    ignoreGroups.append(groupName)
  }
  return ""
}

local function getBulletsListHeader(unit, bulletsList)
{
  local locId = ""
  if (bulletsList.weaponType == WEAPON_TYPE.ROCKETS)
    locId = "modification/_rockets"
  else if (::isInArray(bulletsList.weaponType, [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM ]))
    locId = "modification/_missiles"
  else if (bulletsList.weaponType == WEAPON_TYPE.FLARES)
    locId = "modification/_flares"
  else if (bulletsList.weaponType == WEAPON_TYPE.SMOKE)
    locId = "modification/_smoke_screen"
  else if (bulletsList.weaponType == WEAPON_TYPE.GUNS)
  {
    if (unit.unitType.canUseSeveralBulletsForGun)
      locId = ::isCaliberCannon(bulletsList.caliber)? "modification/_tank_gun_pack" : "modification/_tank_minigun_pack"
    else
      locId = bulletsList.isTurretBelt ? "modification/_turret_belt_pack/short" : "modification/_belt_pack/short"
  }
  return ::format(::loc(locId), bulletsList.caliber.tostring())
}

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

local function getWeaponItemViewParams(id, unit, item, params = {})
{
  local res = {
    id                        = id
    itemWidth                 = params?.itemWidth ?? 1
    posX                      = params?.posX ?? 0
    posY                      = params?.posY ?? 0
    hideStatus                = item?.hideStatus ?? false
    useGenericTooltip         = params?.useGenericTooltip ?? false
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
    genericTooltipId          = ""
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
  res.nameText = ::weaponVisual.getItemName(unit, visualItem, params?.limitedName ?? true)
  local isForceHidePlayerInfo = params?.isForceHidePlayerInfo ?? false
  if (res.useGenericTooltip)
  {
    local genericTooltipId = ""
    if (item.type == weaponsItem.modification)
      genericTooltipId = ::g_tooltip_type.MODIFICATION.getTooltipId(unit.name, item.name)
    else if (item.type == weaponsItem.weapon)
      genericTooltipId = ::g_tooltip_type.WEAPON.getTooltipId(unit.name, item.name, params)
    else if (item.type == weaponsItem.spare)
      genericTooltipId = ::g_tooltip_type.SPARE.getTooltipId(unit.name)

    res.genericTooltipId = genericTooltipId
  }
  local bIcoItem = getBulletsIconItem(unit, visualItem)
  if (bIcoItem)
  {
    local bulletsSet = getBulletsSetData(unit, bIcoItem.name)
    dagor.assertf(isTank(unit) || bulletsSet!=null,
          $"No bullets in bullets set {visualItem.name} for {unit.name}")

    res.iconBulletName = bIcoItem.name
    res.bulletImg = getBulletsIconView(bulletsSet)
  }
  res.itemImg = ::weaponVisual.getItemImage(unit, visualItem)
  local statusTbl = getItemStatusTbl(unit, visualItem)
  local canBeDisabled = isCanBeDisabled(item)
  local isSwitcher = (visualItem.type == weaponsItem.weapon) ||
    (visualItem.type == weaponsItem.primaryWeapon) ||
    isBullets(visualItem)
  local discount = ::getDiscountByPath(
    getDiscountPath(unit, visualItem, statusTbl.discountType))
  local itemCostText = ::weaponVisual.getFullItemCostText(unit, item)
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
  local haveDiscount = discount > 0 && statusTbl.canShowDiscount && itemCostText != ""
  if (haveDiscount)
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
  res.statusIconImg = ::weaponVisual.getStatusIcon(unit, item)
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
    res.actionBtnCanShow = btnText == "" ? "no"
      : !res.isBundle || params?.isMenuBtn ? "yes" : "console"
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

local function updateModItem(air, item, itemObj, showButtons, handler, params = {})
{
  local id = itemObj?.id ?? ""
  local viewParams = getWeaponItemViewParams(id, air, item,
    params.__merge({showButtons = showButtons}))

  itemObj.findObject("name").setValue(viewParams.nameText)

  if (viewParams.useGenericTooltip)
  {
    local tooltipObj = itemObj.findObject($"tooltip_{id}")
    if (::check_obj(tooltipObj))
      tooltipObj.tooltipId = viewParams.genericTooltipId
  }

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

  modUpgradeElem.setValueToObj(itemObj.findObject("mod_upgrade_icon"), air.name, item.name)

  if (!showButtons)
    return

  local actionBtn = itemObj.findObject("actionBtn")
  actionBtn.canShow = viewParams.actionBtnCanShow
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

return ::handyman.renderCached("gui/weaponry/weaponItem", getWeaponItemViewParams(id, unit, item, params))
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
  local needDropDown = params?.needDropDown
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
    itemsList[0].hideStatus <- true
    createItemFunc.call(handler, id, unit, itemsList[0], itemsType, holderObj, handler, params)
    return itemsList[0]
  }

  local bundleObj = createItemFunc.call(handler, id, unit, bundleItem, bundleItem.type, holderObj, handler, params)
  if(needDropDown)
    bundleObj["class"] = "dropDown"

  local guiScene = holderObj.getScene()
  local hoverObj = guiScene.createElementByObject(bundleObj, "gui/weaponry/weaponBundleTop.blk",
    needDropDown ? "hoverSize" : "weaponBundle", handler)

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
  hoverObj["height-end"] = (cellSize[1].tofloat() * (rows + 0.4)).tointeger().tostring()
  return bundleItem
}

return {
  getWeaponInfoText               = getWeaponInfoText
  getWeaponNameText               = getWeaponNameText
  getWeaponXrayDescText           = getWeaponXrayDescText
  getWeaponDescTextByTriggerGroup = getWeaponDescTextByTriggerGroup
  getWeaponShortTypeFromWpName    = getWeaponShortTypeFromWpName
  getDefaultBulletName            = getDefaultBulletName
  getBulletsListHeader            = getBulletsListHeader
  getBulletsCountText             = getBulletsCountText
  getWeaponItemViewParams         = getWeaponItemViewParams
  updateModItem                   = updateModItem
  createModItemLayout             = createModItemLayout
  createModItem                   = createModItem
  createModBundle                 = createModBundle
}

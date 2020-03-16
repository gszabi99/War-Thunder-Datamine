local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local modUpgradeElem = ::require("scripts/weaponry/elems/modUpgradeElem.nut")
local { countMeasure } = require("scripts/options/optionsMeasureUnits.nut")
local { isFakeBullet,
        getBulletsSetData,
        getModificationBulletsGroup } = require("scripts/weaponry/bulletsInfo.nut")
local { WEAPON_TEXT_PARAMS,
        WEAPON_TYPE,
        getLastWeapon,
        getPresetsWeaponry,
        addWeaponsFromBlk,
        getWeaponExtendedInfo } = require("scripts/weaponry/weaponryInfo.nut")

local function getWeaponInfoText(air, p = WEAPON_TEXT_PARAMS)
{
  local text = ""
  air = typeof(air) == "string" ? ::getAircraftByName(air) : air
  if (!air)
    return text

  local weapons = getPresetsWeaponry(air, p)
  if (weapons == null)
    return text

  p = WEAPON_TEXT_PARAMS.__merge(p)
  local unitType = ::get_es_unit_type(air)
  if (::u.isEmpty(weapons) && p.needTextWhenNoWeapons)
      text += ::loc("weapon/noPrimaryWeapon")
  local weaponTypeList = [ "cannons", "guns", "aam", "agm", "rockets", "turrets", "torpedoes",
    "bombs", "smoke", "flares" ]
  local consumableWeapons = [ "aam", "agm", "rockets", "torpedoes", "bombs", "smoke", "flares" ]
  local stackableWeapons = ["turrets"]
  foreach (index, weaponType in weaponTypeList)
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
              weapTypeCount += ("turrets" in trigger)? 0 : weapon.num
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
        weapTypeCount += ("turrets" in trigger)? trigger.turrets : 0
      else
      {
        if ("turrets" in trigger) // && !air.unitType.canUseSeveralBulletsForGun)
        {
          if(trigger.turrets > 1)
            tText = ::format(::loc("weapons/turret_number"), trigger.turrets) + tText
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
    if (p.isPrimary)
      text = ::loc("weapon/noPrimaryWeapon")
    else
      text = (air.isAir() || air.isHelicopter()) ? ::loc("weapon/noSecondaryWeapon")
        : ::loc("weapon/noAdditionalWeapon")

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
  if (bulletsList.weaponType == WEAPON_TYPE.ROCKET)
    locId = "modification/_rockets"
  else if (::isInArray(bulletsList.weaponType, [ WEAPON_TYPE.AAM, WEAPON_TYPE.AGM ]))
    locId = "modification/_missiles"
  else if (bulletsList.weaponType == WEAPON_TYPE.FLARES)
    locId = "modification/_flares"
  else if (bulletsList.weaponType == WEAPON_TYPE.SMOKE_SCREEN)
    locId = "modification/_smoke_screen"
  else if (bulletsList.weaponType == WEAPON_TYPE.GUN)
  {
    if (unit.unitType.canUseSeveralBulletsForGun)
      locId = ::isCaliberCannon(bulletsList.caliber)? "modification/_tank_gun_pack" : "modification/_tank_minigun_pack"
    else
      locId = bulletsList.isTurretBelt ? "modification/_turret_belt_pack/short" : "modification/_belt_pack/short"
  }
  return ::format(::loc(locId), bulletsList.caliber.tostring())
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
  }

  local isOwn = ::isUnitUsable(unit)
  local visualItem = item
  local isBundle = item.type == weaponsItem.bundle
  if (isBundle)
  {
    visualItem = ::weaponVisual.getBundleCurItem(unit, item) || visualItem
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
  local bIcoItem = ::weaponVisual.getBulletsIconItem(unit, visualItem)
  if (bIcoItem)
  {
    local bulletsSet = getBulletsSetData(unit, bIcoItem.name)
    dagor.assertf(isTank(unit) || bulletsSet!=null, "No bullets in bullets set " + visualItem.name + " for " + unit.name)

    res.iconBulletName = bIcoItem.name
    res.bulletImg = ::weaponVisual.getBulletsIconView(bulletsSet)
  }
  res.itemImg = ::weaponVisual.getItemImage(unit, visualItem)
  local statusTbl = ::weaponVisual.getItemStatusTbl(unit, visualItem)
  local canBeDisabled = ::weaponVisual.isCanBeDisabled(item)
  local isSwitcher = ::weaponVisual.isItemSwitcher(visualItem)
  local discount = ::getDiscountByPath(
    ::weaponVisual.getDiscountPath(unit, visualItem, statusTbl.discountType))
  local itemCostText = ::weaponVisual.getFullItemCostText(unit, item)
  local priceText = statusTbl.showPrice && (params?.canShowPrice ?? true) ? itemCostText : ""
  local flushExp = params?.flushExp ?? 0
  local canShowResearch = params?.canShowResearch ?? true
  local canResearch = ::weaponVisual.canResearchItem(unit, visualItem, false)
  local itemReqExp = visualItem?.reqExp ?? 0
  local isModResearching = canShowResearch &&
                               canResearch &&
                               statusTbl.modExp >= 0 &&
                               statusTbl.modExp < itemReqExp &&
                               !statusTbl.amount
  local isModInResearch = ::weaponVisual.isModInResearch(unit, visualItem)
  local isResearchInProgress = isModResearching && isModInResearch
  local isResearchPaused = isModResearching && statusTbl.modExp > 0 && !isModInResearch
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
    if (!res.hideDiscount)
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
  else if (isModInResearch && visualItem.type == weaponsItem.modification)
    optStatus = canShowResearch ? "research" : "researchable"
  else if (::weaponVisual.canResearchItem(unit, visualItem))
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
    res.bulletsCountText = ::format("%s/%s %s", valText, (maxVal*guns).tostring(), restText)
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
  res.hideVisualHasMenu = !isBundle && !params?.hasMenu
  res.modUpgradeStatus = ::weaponVisual.getItemUpgradesStatus(unit, visualItem)
  res.statusIconImg = ::weaponVisual.getStatusIcon(unit, item)
  if (params?.showButtons)
  {
    local btnText = ""
    if (isBundle)
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
    else if (::weaponVisual.canResearchItem(unit, visualItem) ||
      (::weaponVisual.canResearchItem(unit, visualItem, false) &&
      (flushExp > 0 || !canShowResearch)))
      btnText = ::loc("mainmenu/btnResearch")
    res.actionBtnCanShow = btnText == "" ? "no"
      : !isBundle ? "yes" : "console"
    res.actionBtnText = btnText
    local altBtnText = ""
    local altBtnTooltip = ""
    if (statusTbl.goldUnlockable && !((params?.researchMode ?? false) && flushExp > 0))
      altBtnText = ::weaponVisual.getItemUnlockCost(unit, item).tostring()
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
      && !isBundle)
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

return {
  getWeaponInfoText               = getWeaponInfoText
  getWeaponNameText               = getWeaponNameText
  getWeaponXrayDescText           = getWeaponXrayDescText
  getWeaponDescTextByTriggerGroup = getWeaponDescTextByTriggerGroup
  getWeaponShortTypeFromWpName    = getWeaponShortTypeFromWpName
  getDefaultBulletName            = getDefaultBulletName
  getBulletsListHeader            = getBulletsListHeader
  getWeaponItemViewParams         = getWeaponItemViewParams
}

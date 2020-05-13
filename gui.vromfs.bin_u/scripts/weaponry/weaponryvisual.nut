local time = require("scripts/time.nut")
local stdMath = require("std/math.nut")
local weaponryEffects = require("scripts/weaponry/weaponryEffects.nut")
local modUpgradeElem = require("scripts/weaponry/elems/modUpgradeElem.nut")
local { countMeasure } = require("scripts/options/optionsMeasureUnits.nut")
local { getByCurBundle,
        canResearchItem,
        canBeResearched,
        getItemUnlockCost,
        getBundleCurItem,
        isCanBeDisabled,
        isModInResearch,
        getDiscountPath,
        getItemStatusTbl,
        getRepairCostCoef,
        isResearchableItem,
        countWeaponsUpgrade,
        getItemUpgradesList,
        getItemUpgradesStatus } = require("scripts/weaponry/itemInfo.nut")
local { isBullets,
        isFakeBullet,
        buildPiercingData,
        getBulletsSetData,
        getBulletsIconItem,
        getBulletsIconView,
        getModificationInfo,
        getModificationName,
        addBulletsParamToDesc,
        isWeaponTierAvailable,
        isBulletsGroupActiveByMod,
        getModificationBulletsGroup } = require("scripts/weaponry/bulletsInfo.nut")
local { WEAPON_TYPE,
        TRIGGER_TYPE,
        WEAPON_TEXT_PARAMS,
        getLastWeapon,
        getUnitWeaponry,
        addWeaponsFromBlk,
        getWeaponExtendedInfo } = require("scripts/weaponry/weaponryInfo.nut")

::dagui_propid.add_name_id("_iconBulletName")

local function getTextNoWeapons(unit, isPrimary)
{
  return isPrimary ? ::loc("weapon/noPrimaryWeapon") : (unit.isAir() || unit.isHelicopter()) ?
    ::loc("weapon/noSecondaryWeapon") : ::loc("weapon/noAdditionalWeapon")
}

local function getWeaponInfoText(unit, p = WEAPON_TEXT_PARAMS)
{
  local text = ""
  unit = typeof(unit) == "string" ? ::getAircraftByName(unit) : unit
  if (!unit)
    return text

  local weapons = getUnitWeaponry(unit, p)
  if (weapons == null)
    return text

  p = WEAPON_TEXT_PARAMS.__merge(p)
  local unitType = ::get_es_unit_type(unit)
  if (::u.isEmpty(weapons) && p.needTextWhenNoWeapons)
    text += getTextNoWeapons(unit, p.isPrimary)
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
                  ::isInArray(unitType, [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_HELICOPTER])) // torpedoes drop for unit only
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
                tText += getWeaponExtendedInfo(weapon, weaponType, unit, p.ediff, p.newLine + ::nbsp + ::nbsp + ::nbsp + ::nbsp)
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

              if (!unit.unitType.canUseSeveralBulletsForGun)
              {
                local rTime = ::get_reload_time_by_caliber(weapon.caliber, p.ediff)
                if (rTime)
                {
                  if (p.isLocalState)
                  {
                    local difficulty = ::get_difficulty_by_ediff(p.ediff ?? ::get_current_ediff())
                    local key = ::isCaliberCannon(weapon.caliber) ? "cannonReloadSpeedK" : "gunReloadSpeedK"
                    local speedK = unit.modificators?[difficulty.crewSkillName]?[key] ?? 1.0
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
        if (TRIGGER_TYPE.TURRETS in trigger) // && !unit.unitType.canUseSeveralBulletsForGun)
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
    text = getTextNoWeapons(unit, p.isPrimary)

  return text
}

local function getWeaponNameText(unit, isPrimary = null, weaponPreset=-1, newLine=", ")
{
  return getWeaponInfoText(unit,
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

// return short desc of unit.weapons[weaponPresetNo], like M\C\B\T
local function getWeaponShortType(unit, weaponPresetNo=0)
{
  if (typeof(unit) == "string")
    unit = ::getAircraftByName(unit)

  if (!unit)
    return ""

  local textArr = []
  if (unit.weapons[weaponPresetNo].frontGun)
    textArr.append(::loc("weapons_types/short/guns"))
  if (unit.weapons[weaponPresetNo].cannon)
    textArr.append(::loc("weapons_types/short/cannons"))
  if (unit.weapons[weaponPresetNo].bomb)
    textArr.append(::loc("weapons_types/short/bombs"))
  if (unit.weapons[weaponPresetNo].rocket)
    textArr.append(::loc("weapons_types/short/rockets"))
  if (unit.weapons[weaponPresetNo].torpedo)
    textArr.append(::loc("weapons_types/short/torpedoes"))

  return ::loc("weapons_types/short/separator").join(textArr)
}

local function getWeaponShortTypeFromWpName(wpName, unit = null)
{
  if (!wpName || typeof(wpName) != "string")
    return ""

  if (typeof(unit) == "string")
    unit = ::getAircraftByName(unit)

  if (!unit)
    return ""

  for (local i = 0; i < unit.weapons.len(); ++i)
  {
    if (wpName == unit.weapons[i].name)
      return getWeaponShortType(unit, i)
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

local function getModItemName(unit, item, limitedName = true)
{
  return ::g_weaponry_types.getUpgradeTypeByItem(item).getLocName(unit, item, limitedName)
}

//include spawn score cost
local function getFullItemCostText(unit, item)
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
  res.nameText = getModItemName(unit, visualItem, params?.limitedName ?? true)
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

local function updateModItem(unit, item, itemObj, showButtons, handler, params = {})
{
  local id = itemObj?.id ?? ""
  local viewParams = getWeaponItemViewParams(id, unit, item,
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

  modUpgradeElem.setValueToObj(itemObj.findObject("mod_upgrade_icon"), unit.name, item.name)

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
  local extraHeight = ::to_pixels("2@modBundlePopupBgPadH + 1@modBundlePopupAdditionalBtnsHeight")
  hoverObj["height-end"] = (cellSize[1] * rows + extraHeight).tointeger().tostring()
  return bundleItem
}

local function getReqModsText(unit, item)
{
  local reqText = ""
  foreach(rp in ["reqWeapon", "reqModification"])
      if (rp in item)
        foreach (req in item[rp])
          if (rp == "reqWeapon" && !::shop_is_weapon_purchased(unit.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getWeaponNameText(unit.name, false, req, ", ")
          else
          if (rp == "reqModification" && !::shop_is_modification_purchased(unit.name, req))
            reqText += ((reqText=="")?"":"\n") + ::loc(rp) + ::loc("ui/colon") + getModificationName(unit, req)
  return reqText
}

local function getReqTextWorldWarArmy(unit, item)
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

local function getItemDescTbl(unit, item, params = null, effect = null, updateEffectFunc = null){return null}
getItemDescTbl = function(unit, item, params = null, effect = null, updateEffectFunc = null)
{
  local res = { name = "", desc = "", delayed = false }
  local needShowWWSecondaryWeapons = item.type==weaponsItem.weapon && ::is_in_flight() &&
    ::g_mis_custom_state.getCurMissionRules().isWorldWar

  if (item.type==weaponsItem.bundle)
    return getByCurBundle(unit, item,
      function(unit, item) {
        return getItemDescTbl(unit, item, params, effect, updateEffectFunc)
      }, res)

  local name = "<color=@activeTextColor>" + getModItemName(unit, item, false) + "</color>"
  local desc = ""
  local addDesc = ""
  local reqText = ""
  local curTier = "tier" in item? item.tier : 1
  local statusTbl = getItemStatusTbl(unit, item)
  local currentPrice = statusTbl.showPrice ? getFullItemCostText(unit, item) : ""

  local hasPlayerInfo = params?.hasPlayerInfo ?? true
  if (hasPlayerInfo
    && !isWeaponTierAvailable(unit, curTier) && curTier > 1
    && !needShowWWSecondaryWeapons)
  {
    local reqMods = ::getNextTierModsCount(unit, curTier - 1)
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
    desc = getWeaponInfoText(unit, { isPrimary = false, weaponPreset = item.name,
      detail = INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })

    if(item.rocket || item.bomb)
    {
      buildPiercingData(unit.name,
        ::calculate_tank_bullet_parameters(unit.name, item.name, true, true), res)
    }

    if (effect)
      addDesc = weaponryEffects.getDesc(unit, effect)
    if (!effect && updateEffectFunc)
      res.delayed = ::calculate_mod_or_weapon_effect(unit.name, item.name, false, this,
        updateEffectFunc, null) ?? true
  }
  else if (item.type==weaponsItem.primaryWeapon)
  {
    name = ""
    desc = getWeaponInfoText(unit, { isPrimary = true, weaponPreset = item.name,
      detail = INFO_DETAIL.EXTENDED, weaponsFilterFunc = params?.weaponsFilterFunc })
    local upgradesList = getItemUpgradesList(item)
    if(upgradesList)
    {
      local upgradesCount = countWeaponsUpgrade(unit, item)
      if (upgradesCount?[1])
        addDesc = "\n" + ::loc("weaponry/weaponsUpgradeInstalled",
                               { current = upgradesCount[0], total = upgradesCount[1] })
      foreach(arr in upgradesList)
        foreach(upgrade in arr)
        {
          if(upgrade == null)
            continue
          addDesc += "\n" + (::shop_is_modification_enabled(unit.name, upgrade) ?"<color=@goodTextColor>" : "<color=@commonTextColor>") + getModificationName(unit, upgrade) + "</color>"
        }
    }
  }
  else if (item.type==weaponsItem.modification || item.type==weaponsItem.expendables)
  {
    if (effect)
    {
      desc = getModificationInfo(unit, item.name).desc;
      addDesc = weaponryEffects.getDesc(unit, effect);
    }
    else
    {
      local info = getModificationInfo(unit, item.name, false, false, this, updateEffectFunc)
      desc = info.desc
      res.delayed = info.delayed
    }

    addBulletsParamToDesc(res, unit, item)
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
        local respLeft = ::g_mis_custom_state.getCurMissionRules().getUnitWeaponRespawnsLeft(unit, item)
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
    local discount = ::getDiscountByPath(getDiscountPath(unit, item, statusTbl.discountType))
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
    local rCost = ::wp_get_repair_cost_by_mode(unit.name, egdCode, false)
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
      local reqMods = getReqModsText(unit, item)
      if(reqMods != "")
        reqText += (reqText==""? "" : "\n") + reqMods
    }
    if (isBullets(item) && !isBulletsGroupActiveByMod(unit, item))
      reqText += ((reqText=="")?"":"\n") + ::loc("msg/weaponSelectRequired")
    reqText = reqText!=""? ("<color=@badTextColor>" + reqText + "</color>") : ""

    if (needShowWWSecondaryWeapons)
      reqText = getReqTextWorldWarArmy(unit, item)
  }
  res.reqText <- reqText

  if (currentPrice != "")
    res.currentPrice <- currentPrice
  res.name = name
  res.desc = desc
  res.addDesc <- addDesc
  return res
}

local function updateWeaponTooltip(obj, unit, item, handler, params={}, effect=null){}
updateWeaponTooltip = function(obj, unit, item, handler, params={}, effect=null)
{
  local descTbl = getItemDescTbl(unit, item, params, effect,
    function(effect, ...) {
      if (::checkObj(obj) && obj.isVisible())
        updateWeaponTooltip(obj, unit, item, handler, params, effect)
    })

  local curExp = ::shop_get_module_exp(unit.name, item.name)
  local is_researched = !isResearchableItem(item) || ((item.name.len() > 0) && ::isModResearched(unit, item))
  local is_researching = isModInResearch(unit, item)
  local is_paused = canBeResearched(unit, item, true) && curExp > 0

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

local function updateSpareType(spare)
{
  if (!("type" in spare))
    spare.type <- weaponsItem.spare
}

local function updateModType(unit, mod)
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

return {
  getWeaponInfoText               = getWeaponInfoText
  getWeaponNameText               = getWeaponNameText
  getWeaponXrayDescText           = getWeaponXrayDescText
  getWeaponDescTextByTriggerGroup = getWeaponDescTextByTriggerGroup
  getWeaponShortTypeFromWpName    = getWeaponShortTypeFromWpName
  getDefaultBulletName            = getDefaultBulletName
  getBulletsListHeader            = getBulletsListHeader
  getBulletsCountText             = getBulletsCountText
  getModItemName                  = getModItemName
  getWeaponItemViewParams         = getWeaponItemViewParams
  updateModItem                   = updateModItem
  createModItemLayout             = createModItemLayout
  createModItem                   = createModItem
  createModBundle                 = createModBundle
  getReqModsText                  = getReqModsText
  getItemDescTbl                  = getItemDescTbl
  updateWeaponTooltip             = updateWeaponTooltip
  updateItemBulletsSlider         = updateItemBulletsSlider
  updateSpareType                 = updateSpareType
  updateModType                   = updateModType
}

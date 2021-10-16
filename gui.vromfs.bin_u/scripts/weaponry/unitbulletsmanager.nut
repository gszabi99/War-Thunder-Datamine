local stdMath = require("std/math.nut")
local { AMMO, getAmmoWarningMinimum } = require("scripts/weaponry/ammoInfo.nut")
local { getLinkedGunIdx, getOverrideBullets } = require("scripts/weaponry/weaponryInfo.nut")
local { getBulletsSetData,
        getOptionsBulletsList,
        getBulletsGroupCount,
        getActiveBulletsGroupInt,
        getBulletsInfoForPrimaryGuns } = require("scripts/weaponry/bulletsInfo.nut")
local { getGuiOptionsMode } = ::require_native("guiOptions")

global enum bulletsAmountState {
  READY
  HAS_UNALLOCATED
  LOW_AMOUNT
}

::UnitBulletsManager <- class
{
  unit = null  //setUnit to change
  bulGroups = null //bulletsGroups
  gunsInfo = null //bulletsInfo for primary guns (guns, total, catridge, groupIndex) //getBulletsInfoForPrimaryGuns
  groupsActiveMask = 0

  checkPurchased = true
  isForcedAvailable = false
  isBulletDataLoading = false

  constructor(_unit, params = {})
  {
    gunsInfo = []
    checkPurchased = getGuiOptionsMode() != ::OPTIONS_MODE_TRAINING
    isForcedAvailable = params?.isForcedAvailable ?? false

    setUnit(_unit)
    ::subscribe_handler(this, ::g_listener_priority.CONFIG_VALIDATION)
  }

  function getUnit()
  {
    return unit
  }

  function setUnit(_unit)
  {
    if (typeof(_unit) == "string")
      _unit = ::getAircraftByName(_unit)
    if (unit == _unit)
      return

    unit = _unit
    bulGroups = null
  }

  function getBulletsGroups()
  {
    checkInitBullets()
    return bulGroups
  }

  function getBulletGroupByIndex(groupIdx)
  {
    return ::getTblValue(groupIdx, getBulletsGroups())
  }

  function getBulletGroupBySelectedMod(mod)
  {
    foreach(group in getBulletsGroups())
      if (mod.name == group.selectedName)
        return group
    return null
  }

  function getGunTypesCount()
  {
    return gunsInfo.len() || 1
  }

  getGroupGunInfo = @(linkedIdx, isUniformNoBelts, maxToRespawn) isUniformNoBelts
    ? gunsInfo?[linkedIdx].__update({total = maxToRespawn}) : gunsInfo?[linkedIdx]

  function getUnallocatedBulletCount(bulGroup)
  {
    return ::getTblValue("unallocated", bulGroup.gunInfo, 0)
  }

  //return isChanged
  function changeBulletsCount(bulGroup, newCount)
  {
    local count = bulGroup.bulletsCount
    if (count == newCount)
      return false

    local unallocated = getUnallocatedBulletCount(bulGroup)
    local maxCount = ::min(unallocated + count, bulGroup.maxBulletsCount)
    newCount = ::clamp(newCount, 0, maxCount)

    if (count == newCount)
      return false

    bulGroup.setBulletsCount(newCount)
    if (bulGroup.gunInfo)
      bulGroup.gunInfo.unallocated <- unallocated + count - newCount
    ::broadcastEvent("BulletsCountChanged", { unit = unit })
    return true
  }

  //will send broadcast event with full list of changed bullets groups
  function changeBulletsValueByIdx(bulGroup, valueIdx)
  {
    return changeBulletsValue(bulGroup, bulGroup.getBulletNameByIdx(valueIdx))
  }

  _bulletsSetValueRecursion = false
  function changeBulletsValue(bulGroup, bulletName)
  {
    if (!bulletName || bulletName == bulGroup.selectedName)
      return

    if (_bulletsSetValueRecursion)
    {
      ::script_net_assert_once("bullets set value recursion",
                                format("Bullets Manager: set bullet recursion detected!! (unit = %s)\nbullet groups =\n%s",
                                  unit.name, ::toString(bulGroups)
                                )
                              )
      return
    }
    _bulletsSetValueRecursion = true

    local changedGroups = [bulGroup]
    local gunIdx = bulGroup.getGunIdx()
    foreach(gIdx, group in bulGroups)
    {
      if (!group.active
          || group.groupIndex == bulGroup.groupIndex
          || group.getGunIdx() != gunIdx
          || group.selectedName != bulletName)
        continue

      local prevBullet = bulGroup.selectedName
      group.setBullet(prevBullet)
      changedGroups.append(group)
      break
    }

    bulGroup.setBullet(bulletName)
    validateBulletsCount()
    ::broadcastEvent("BulletsGroupsChanged", { unit = unit, changedGroups = changedGroups })

    _bulletsSetValueRecursion = false
  }

  function checkBulletsCountReady()
  {
    local res = {
      status = bulletsAmountState.READY
      unallocated = 0
      required = 0
    }
    if (!gunsInfo.len())
      return res

    foreach(gInfo in gunsInfo)
    {
      local unallocated = gInfo.unallocated
      if (unallocated <= 0)
        continue
      if (gInfo?.forcedMaxBulletsInRespawn ?? false) // Player can't change counts.
        continue

      local status = bulletsAmountState.READY
      local totalBullets = gInfo.total
      local minBullets = ::clamp((0.2 * totalBullets).tointeger(), 1, getAmmoWarningMinimum(AMMO.MODIFICATION, unit, totalBullets))
      if (totalBullets - unallocated >= minBullets)
        status = bulletsAmountState.HAS_UNALLOCATED
      else
        status = bulletsAmountState.LOW_AMOUNT

      if (status <= res.status)
        continue

      res.status = status
      res.unallocated = unallocated * gInfo.guns
      if (status == bulletsAmountState.LOW_AMOUNT)
        res.required = ::min(minBullets, totalBullets) * gInfo.guns
    }
    return res
  }

  function checkChosenBulletsCount(needWarnUnallocated = false, applyFunc = null)
  {
    if (getOverrideBullets(unit))
      return true
    local readyCounts = checkBulletsCountReady()
    if (readyCounts.status == bulletsAmountState.READY
        || (readyCounts.status == bulletsAmountState.HAS_UNALLOCATED
          && (!needWarnUnallocated || ::get_gui_option(::USEROPT_SKIP_LEFT_BULLETS_WARNING))))
      return true

    local msg = ""
    if (readyCounts.status == bulletsAmountState.HAS_UNALLOCATED)
      msg = ::format(::loc("multiplayer/someBulletsLeft"), ::colorize("activeTextColor", readyCounts.unallocated.tostring()))
    else
      msg = ::format(::loc("multiplayer/notEnoughBullets"), ::colorize("activeTextColor", readyCounts.required.tostring()))

    ::gui_start_modal_wnd(::gui_handlers.WeaponWarningHandler,
      {
        parentHandler = this
        message = msg
        list = ""
        showCheckBoxBullets = false
        ableToStartAndSkip = readyCounts.status != bulletsAmountState.LOW_AMOUNT
        skipOption = ::USEROPT_SKIP_LEFT_BULLETS_WARNING
        onStartPressed = applyFunc
      })

    return false
  }

  function canChangeBulletsCount()
  {
    return gunsInfo.len() > 0
  }

  function canChangeBulletsActivity()
  {
    return !unit.unitType.canUseSeveralBulletsForGun
  }

  function getActiveBulGroupsAmount()
  {
    //do not count fake bullets
    return stdMath.number_of_set_bits(groupsActiveMask & ((1 << unit.unitType.bulletSetsQuantity) - 1))
  }

  function openChooseBulletsWnd(groupIdx, itemParams = null, alignObj = null, align = "bottom")
  {
    local bulGroup = ::getTblValue(groupIdx, getBulletsGroups())
    if (!unit || !bulGroup)
      return

    local list = []
    local modsList = bulGroup.getBulletsModsList()
    local curName = bulGroup.selectedName

    local otherSelList = []
    foreach(gIdx, group in getBulletsGroups())
      if (group.active && gIdx != groupIdx && group.gunInfo == bulGroup.gunInfo)
        otherSelList.append(group.selectedName)

    foreach(idx, mod in modsList)
    {
      if (checkPurchased
          && !("isDefaultForGroup" in mod)
          && !::shop_is_modification_purchased(unit.name, mod.name))
        continue

      list.append({
        weaponryItem = mod
        selected = curName == mod.name
        visualDisabled = ::isInArray(mod.name, otherSelList)
      })
    }

    ::gui_start_weaponry_select_modal({
      unit = unit
      list = list
      weaponItemParams = itemParams
      alignObj = alignObj
      align = align
      onChangeValueCb = ::Callback((@(bulGroup) function(mod) {
        changeBulletsValue(bulGroup, mod.name)
      })(bulGroup), this)
    })
  }

//**************************************************************************************
//******************************* PRIVATE ***********************************************
//**************************************************************************************

  function checkInitBullets()
  {
    if (bulGroups)
      return

    loadBulletsData()
    forcedBulletsCount()
    validateBullets()
    validateBulletsCount()
  }

  function loadBulletsData()
  {
    if (isBulletDataLoading)
      return

    isBulletDataLoading = true
    loadGunInfo()
    loadBulGroups()
    isBulletDataLoading = false
  }

  function loadGunInfo()
  {
    gunsInfo = []
    if (!unit)
      return

    gunsInfo = getBulletsInfoForPrimaryGuns(unit).map(@(gInfo, idx) gInfo.__merge({
      gunIdx = idx
      unallocated = gInfo.total
      notInitedCount = 0
    }))
  }

  function loadBulGroups()
  {
    bulGroups = []
    groupsActiveMask = unit ? getActiveBulletsGroupInt(unit, checkPurchased) : 0//!!FIX ME: better to detect actives in manager too.
    if (!unit)
      return

    // Preparatory work of Bullet Groups creation
    local bulletDataByGroup = {}
    local bullGroupsCountersByGun = {}
    local bulletsTotal = unit.unitType.canUseSeveralBulletsForGun
      ? unit.unitType.bulletSetsQuantity : getBulletsGroupCount(unit)

    for (local groupIndex = 0; groupIndex < bulletsTotal; groupIndex++)
    {
      local linkedIdx = getLinkedGunIdx(groupIndex, getGunTypesCount(),
        unit.unitType.bulletSetsQuantity)
      local bullets = getOptionsBulletsList(unit, groupIndex, false, isForcedAvailable)
      local selectedName = bullets.values?[bullets.value] ?? ""
      local bulletsSet = getBulletsSetData(unit, selectedName)
      local maxToRespawn = bulletsSet?.maxToRespawn ?? 0
      //!!FIX ME: Needs to have a bit more reliable way to determine bullets type like by TRIGGER_TYPE for example
      local currBulletType = bulletsSet?.isBulletBelt ? "belt" : bulletsSet?.bullets[0].split("_")[0]
      bulletDataByGroup[groupIndex] <- {
        linkedIdx = linkedIdx
        maxToRespawn = maxToRespawn
      }

      if (!bullGroupsCountersByGun?[linkedIdx])
        bullGroupsCountersByGun[linkedIdx] <- {
          limitedGroupCount = 0
          groupCount = 0
          beltsCount = 0
          isUniform = true
          bulletType = currBulletType// Helper value to define isUniform
        }

      local currCounters = bullGroupsCountersByGun[linkedIdx]
      currCounters.limitedGroupCount += maxToRespawn > 0 ? 1 : 0
      currCounters.beltsCount += bulletsSet?.isBulletBelt ? 1 : 0
      currCounters.groupCount++
      currCounters.isUniform = currBulletType == currCounters.bulletType
    }

    // Check and create Bullet Group Data
    // User can chose the bullet set where maxToRespawn defined for all gun bullets simultaneously.
    // There is needs to current logic be changed when all gun bullets are the same type but not belt.
    // It means that maxToRespawn currently limits count for each bullet in gun,
    // so for mentioned case total count looks like summ of all maxToRespawn,
    // that actually is true for belts only.
    foreach (groupIndex, data in bulletDataByGroup)
    {
      local currCounters = bullGroupsCountersByGun[data.linkedIdx]
      local isUniformNoBelts = (currCounters.isUniform && currCounters.beltsCount == 0
        && currCounters.limitedGroupCount == currCounters.groupCount)
      bulGroups.append(::BulletGroup(unit, groupIndex,
        getGroupGunInfo(data.linkedIdx, isUniformNoBelts, data.maxToRespawn), {
          isActive = stdMath.is_bit_set(groupsActiveMask, groupIndex)
          canChangeActivity = canChangeBulletsActivity()
          isForcedAvailable = isForcedAvailable
          maxToRespawn = data.maxToRespawn
        }))
    }
  }

  function forcedBulletsCount()
  {
    if (!gunsInfo.len())
      return

    local forceBulletGroupByGun = {}
    foreach(bulGroup in bulGroups)
      if (bulGroup.active && bulGroup.gunInfo.forcedMaxBulletsInRespawn)
      {
        local gIdx = bulGroup.getGunIdx()
        if (!forceBulletGroupByGun?[gIdx])
          forceBulletGroupByGun[gIdx] <- []

        forceBulletGroupByGun[gIdx].append(bulGroup)
      }

    foreach(idx, gunBullets in forceBulletGroupByGun)
    {
      local countBullet = gunBullets.len()

      foreach(bulGroup in gunBullets)
        bulGroup.setBulletsCount(bulGroup.gunInfo.total / countBullet)
    }
  }

  function validateBullets()
  {
    if (!gunsInfo.len())
      return

    local selectedList = gunsInfo.map(@(v) [])

    foreach(gIdx, bulGroup in bulGroups)
    {
      if (!bulGroup.active)
        continue
      local list = ::getTblValue(bulGroup.getGunIdx(), selectedList)
      if (!list)
        continue

      //check for duplicate bullets
      if (!bulGroup.setBulletNotFromList(list))
      {
        bulGroup.active = false
        groupsActiveMask = stdMath.change_bit(groupsActiveMask, gIdx, 0)
        continue
      }

      local curBulletName = bulGroup.selectedName
      list.append(curBulletName)
    }
  }

  function validateBulletsCount()
  {
    if (!gunsInfo.len())
      return

    foreach(gInfo in gunsInfo)
    {
      gInfo.unallocated = gInfo.total
      gInfo.notInitedCount = 0
    }

    //update unallocated bullets, collect not inited
    local haveNotInited = false
    foreach(gIdx, bulGroup in bulGroups)
    {
      local gInfo = bulGroup.gunInfo
      if (!bulGroup.active || !gInfo)
        continue

      if (bulGroup.bulletsCount < 0)
      {
        gInfo.notInitedCount++
        haveNotInited = true
        continue
      }

      if (gInfo.unallocated < bulGroup.bulletsCount)
      {
        bulGroup.setBulletsCount(gInfo.unallocated)
        gInfo.unallocated = 0
      } else
        gInfo.unallocated -= bulGroup.bulletsCount
    }

    if (!haveNotInited)
      return

    //init all active not inited bullets
    foreach(gIdx, bulGroup in bulGroups)
    {
      if (!bulGroup.active || bulGroup.bulletsCount >= 0)
        continue
      local gInfo = bulGroup.gunInfo
      if (!gInfo || !gInfo.notInitedCount)
      {
        ::dagor.assertf(false, "UnitBulletsManager Error: Incorrect not inited bullets count or gun not exist for unit " + unit.name)
        continue
      }

      //no point to check unallocated amount left after init. this will happen only once, and all bullets atthat moment will be filled up.
      local newCount = ::min(gInfo.unallocated / gInfo.notInitedCount, bulGroup.maxBulletsCount)
      bulGroup.setBulletsCount(newCount)
      gInfo.unallocated -= newCount
      gInfo.notInitedCount--
    }
  }

  function updateGroupsActiveMask()
  {
    if (!canChangeBulletsActivity())
      return

    groupsActiveMask = getActiveBulletsGroupInt(unit)
    foreach(gIdx, bulGroup in bulGroups)
      bulGroup.active = stdMath.is_bit_set(groupsActiveMask, gIdx)
  }

  function onEventUnitWeaponChanged(p)
  {
    if (unit && unit.name == ::getTblValue("unitName", p))
      updateGroupsActiveMask()
  }

  function onEventUnitBulletsChanged(p)
  {
    if (!unit || unit.name != p.unit?.name)
      return

    loadBulletsData()// Need to reload data because of maxToRespawn in bullet group might be recalculated
    if (p.groupIdx in bulGroups)
      changeBulletsValue(bulGroups[p.groupIdx], p.bulletName)
  }
}

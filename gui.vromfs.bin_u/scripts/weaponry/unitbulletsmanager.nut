local stdMath = require("std/math.nut")
local { AMMO, getAmmoWarningMinimum } = require("scripts/weaponry/ammoInfo.nut")
local { getLinkedGunIdx, getOverrideBullets } = require("scripts/weaponry/weaponryInfo.nut")
local { getBulletsGroupCount,
        getActiveBulletsGroupInt,
        getBulletsInfoForPrimaryGuns } = require("scripts/weaponry/bulletsInfo.nut")

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

  constructor(_unit)
  {
    gunsInfo = []
    checkPurchased = ::get_gui_options_mode() != ::OPTIONS_MODE_TRAINING

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

  function getBulletsGroups(isForcedAvailable = false)
  {
    checkInitBullets(isForcedAvailable)
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

  function getGroupGunInfo(groupIdx)
  {
    local linkedIdx = getLinkedGunIdx(groupIdx, getGunTypesCount(), unit.unitType.bulletSetsQuantity)
    return ::getTblValue(linkedIdx, gunsInfo, null)
  }

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

  function checkInitBullets(isForcedAvailable = false)
  {
    if (bulGroups)
      return

    loadGunInfo()
    loadBulGroups(isForcedAvailable)
    forcedBulletsCount()
    validateBullets()
    validateBulletsCount()
  }

  function loadGunInfo()
  {
    if (!unit)
    {
      gunsInfo = []
      return
    }

    gunsInfo = getBulletsInfoForPrimaryGuns(unit)
    foreach(idx, gInfo in gunsInfo)
    {
      gInfo.gunIdx <- idx
      gInfo.unallocated <- gInfo.total
      gInfo.notInitedCount <- 0
    }
  }

  function loadBulGroups(isForcedAvailable = false)
  {
    bulGroups = []
    if (!unit)
    {
      groupsActiveMask = 0
      return
    }

    groupsActiveMask = getActiveBulletsGroupInt(unit, checkPurchased) //!!FIX ME: better to detect actives in manager too.

    local canChangeActivity = canChangeBulletsActivity()
    local bulletsTotal = unit.unitType.canUseSeveralBulletsForGun ? unit.unitType.bulletSetsQuantity : getBulletsGroupCount(unit)
    for (local groupIndex = 0; groupIndex < bulletsTotal; groupIndex++)
    {
      bulGroups.append(::BulletGroup(unit, groupIndex, getGroupGunInfo(groupIndex), {
        isActive = stdMath.is_bit_set(groupsActiveMask, groupIndex)
        canChangeActivity = canChangeActivity
        isForcedAvailable = isForcedAvailable
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
    if (unit && unit.name == p.unit?.name && p.groupIdx in bulGroups)
      changeBulletsValue(bulGroups[p.groupIdx], p.bulletName)
  }
}

//-file:plus-string
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { format } = require("string")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { get_gui_option, getGuiOptionsMode } = require("guiOptions")
let stdMath = require("%sqstd/math.nut")
let { AMMO, getAmmoWarningMinimum } = require("%scripts/weaponry/ammoInfo.nut")
let { getLinkedGunIdx, getOverrideBullets } = require("%scripts/weaponry/weaponryInfo.nut")
let { getBulletsSetData,
        getOptionsBulletsList,
        getBulletsGroupCount,
        getActiveBulletsGroupInt,
        getBulletsInfoForPrimaryGuns,
        getAmmoStowageConstraintsByTrigger,
        getBulletsSetMaxAmmoWithConstraints } = require("%scripts/weaponry/bulletsInfo.nut")
let { OPTIONS_MODE_TRAINING, USEROPT_SKIP_LEFT_BULLETS_WARNING, USEROPT_MODIFICATIONS
} = require("%scripts/options/optionsExtNames.nut")
let { shopIsModificationPurchased } = require("chardResearch")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { guiStartWeaponrySelectModal } = require("%scripts/weaponry/weaponrySelectModal.nut")

enum bulletsAmountState {
  READY
  HAS_UNALLOCATED
  LOW_AMOUNT
}

::UnitBulletsManager <- class {
  unit = null  //setUnit to change
  bulGroups = null //bulletsGroups
  gunsInfo = null //bulletsInfo for primary guns (guns, total, cartridge, groupIndex) //getBulletsInfoForPrimaryGuns
  groupsActiveMask = 0

  checkPurchased = true
  isForcedAvailable = false
  isBulletDataLoading = false

  constructor(v_unit, params = {}) {
    this.gunsInfo = []
    this.isForcedAvailable = params?.isForcedAvailable ?? false

    this.setUnit(v_unit)
    subscribe_handler(this, g_listener_priority.CONFIG_VALIDATION)
  }

  function getUnit() {
    return this.unit
  }

  function setUnit(v_unit, forceUpdate = false) {
    if (type(v_unit) == "string")
      v_unit = getAircraftByName(v_unit)
    if (this.unit == v_unit && !forceUpdate)
      return

    this.unit = v_unit
    this.bulGroups = null
    this.checkPurchased = getGuiOptionsMode() != OPTIONS_MODE_TRAINING
      || get_gui_option(USEROPT_MODIFICATIONS)
  }

  function getBulletsGroups() {
    this.checkInitBullets()
    return this.bulGroups
  }

  function getBulletGroupByIndex(groupIdx) {
    return getTblValue(groupIdx, this.getBulletsGroups())
  }

  function getBulletGroupBySelectedMod(mod) {
    foreach (group in this.getBulletsGroups())
      if (mod.name == group.selectedName)
        return group
    return null
  }

  function getGunTypesCount() {
    return this.gunsInfo.len() || 1
  }

  getGroupGunInfo = @(linkedIdx, isUniformNoBelts, maxToRespawn) isUniformNoBelts
    ? this.gunsInfo?[linkedIdx].__update({ total = maxToRespawn }) : this.gunsInfo?[linkedIdx]

  function getUnallocatedBulletCount(bulGroup) {
    return getTblValue("unallocated", bulGroup.gunInfo, 0)
  }

  //return isChanged
  function changeBulletsCount(bulGroup, newCount) {
    let count = bulGroup.bulletsCount
    if (count == newCount)
      return false

    let isPairBulletsGroup = bulGroup.isPairBulletsGroup()
    local unallocated = this.getUnallocatedBulletCount(bulGroup)
    let maxCount = isPairBulletsGroup ? bulGroup.maxBulletsCount
      : min(unallocated + count, bulGroup.maxBulletsCount)
    newCount = isPairBulletsGroup && !bulGroup.canChangePairBulletsCount()
      ? maxCount
      : clamp(newCount, 0, maxCount)

    if (count == newCount)
      return false

    bulGroup.setBulletsCount(newCount)
    let { gunInfo }= bulGroup
    if (gunInfo) {
      unallocated = unallocated + count - newCount
      if (isPairBulletsGroup && unallocated != 0) {
        let linkedBulGroup = this.getLinkedBulletsGroup(bulGroup)
        if (linkedBulGroup != null && linkedBulGroup) {
          let linkedCount = linkedBulGroup.bulletsCount
          let newLinkedCount = clamp(linkedCount + unallocated, 0, maxCount)
          unallocated = unallocated + linkedCount - newLinkedCount
          linkedBulGroup.setBulletsCount(newLinkedCount)
        }
      }
      bulGroup.gunInfo.unallocated <- unallocated
    }
    broadcastEvent("BulletsCountChanged", { unit = this.unit })
    return true
  }

  //will send broadcast event with full list of changed bullets groups
  function changeBulletsValueByIdx(bulGroup, valueIdx) {
    return this.changeBulletsValue(bulGroup, bulGroup.getBulletNameByIdx(valueIdx))
  }

  _bulletsSetValueRecursion = false
  function changeBulletsValue(bulGroup, bulletName) {
    if (!bulletName || bulletName == bulGroup.selectedName)
      return

    if (this._bulletsSetValueRecursion) {
      script_net_assert_once("bullets set value recursion",
                                format("Bullets Manager: set bullet recursion detected!! (unit = %s)\nbullet groups =\n%s",
                                  this.unit.name, toString(this.bulGroups)
                                )
                              )
      return
    }
    this._bulletsSetValueRecursion = true

    let changedGroups = [bulGroup]
    let gunIdx = bulGroup.getGunIdx()
    foreach (_gIdx, group in this.bulGroups) {
      if (!group.active
          || group.groupIndex == bulGroup.groupIndex
          || group.getGunIdx() != gunIdx
          || group.selectedName != bulletName)
        continue

      let prevBullet = bulGroup.selectedName
      group.setBullet(prevBullet)
      changedGroups.append(group)
      break
    }

    bulGroup.setBullet(bulletName)
    this.validateBulletsCount()
    broadcastEvent("BulletsGroupsChanged", { unit = this.unit, changedGroups = changedGroups })

    this._bulletsSetValueRecursion = false
  }

  function checkBulletsCountReady() {
    let res = {
      status = bulletsAmountState.READY
      unallocated = 0
      required = 0
    }
    if (!this.gunsInfo.len())
      return res

    foreach (gInfo in this.gunsInfo) {
      let unallocated = gInfo.unallocated
      if (unallocated <= 0)
        continue
      if (gInfo?.forcedMaxBulletsInRespawn ?? false) // Player can't change counts.
        continue
      if (gInfo?.isBulletBelt ?? true)
        continue

      local status = bulletsAmountState.READY
      let totalBullets = gInfo.total
      let minBullets = clamp((0.2 * totalBullets).tointeger(), 1, getAmmoWarningMinimum(AMMO.MODIFICATION, this.unit, totalBullets))
      if (totalBullets - unallocated >= minBullets)
        status = bulletsAmountState.HAS_UNALLOCATED
      else
        status = bulletsAmountState.LOW_AMOUNT

      if (status <= res.status)
        continue

      res.status = status
      res.unallocated = unallocated * gInfo.guns
      if (status == bulletsAmountState.LOW_AMOUNT)
        res.required = min(minBullets, totalBullets) * gInfo.guns
    }
    return res
  }

  function checkChosenBulletsCount(needWarnUnallocated = false, applyFunc = null) {
    if (getOverrideBullets(this.unit))
      return true
    let readyCounts = this.checkBulletsCountReady()
    if (readyCounts.status == bulletsAmountState.READY
        || (readyCounts.status == bulletsAmountState.HAS_UNALLOCATED
          && (!needWarnUnallocated || get_gui_option(USEROPT_SKIP_LEFT_BULLETS_WARNING))))
      return true

    local msg = ""
    if (readyCounts.status == bulletsAmountState.HAS_UNALLOCATED)
      msg = format(loc("multiplayer/someBulletsLeft"), colorize("activeTextColor", readyCounts.unallocated.tostring()))
    else
      msg = format(loc("multiplayer/notEnoughBullets"), colorize("activeTextColor", readyCounts.required.tostring()))

    loadHandler(gui_handlers.WeaponWarningHandler,
      {
        parentHandler = this
        message = msg
        list = ""
        showCheckBoxBullets = false
        ableToStartAndSkip = readyCounts.status != bulletsAmountState.LOW_AMOUNT
        skipOption = USEROPT_SKIP_LEFT_BULLETS_WARNING
        onStartPressed = applyFunc
      })

    return false
  }

  function canChangeBulletsCount() {
    return this.gunsInfo.len() > 0
  }

  function canChangeBulletsActivity() {
    return !this.unit.unitType.canUseSeveralBulletsForGun
  }

  function getActiveBulGroupsAmount() {
    //do not count fake bullets
    return stdMath.number_of_set_bits(this.groupsActiveMask & ((1 << this.unit.unitType.bulletSetsQuantity) - 1))
  }

  function openChooseBulletsWnd(groupIdx, itemParams = null, alignObj = null, align = "bottom") {
    let bulGroup = getTblValue(groupIdx, this.getBulletsGroups())
    if (!this.unit || !bulGroup)
      return

    let list = []
    let modsList = bulGroup.getBulletsModsList()
    let curName = bulGroup.selectedName

    let otherSelList = []
    foreach (gIdx, group in this.getBulletsGroups())
      if (group.active && gIdx != groupIdx && group.gunInfo == bulGroup.gunInfo)
        otherSelList.append(group.selectedName)

    foreach (_idx, mod in modsList) {
      if (this.checkPurchased
          && !("isDefaultForGroup" in mod)
          && !shopIsModificationPurchased(this.unit.name, mod.name))
        continue

      list.append({
        weaponryItem = mod
        selected = curName == mod.name
        visualDisabled = isInArray(mod.name, otherSelList)
      })
    }

    guiStartWeaponrySelectModal({
      unit = this.unit
      list = list
      weaponItemParams = itemParams
      alignObj = alignObj
      align = align
      onChangeValueCb = Callback(@(mod) this.changeBulletsValue(bulGroup, mod.name), this)
    })
  }

//**************************************************************************************
//******************************* PRIVATE ***********************************************
//**************************************************************************************

  function checkInitBullets() {
    if (this.bulGroups)
      return

    this.loadBulletsData()
    this.forcedBulletsCount()
    this.validateBullets()
    this.validateBulletsCount()
  }

  function loadBulletsData() {
    if (this.isBulletDataLoading)
      return

    this.isBulletDataLoading = true
    this.loadGunInfo()
    this.loadBulGroups()
    this.isBulletDataLoading = false
  }

  function loadGunInfo() {
    this.gunsInfo = !this.unit ? []
      : getBulletsInfoForPrimaryGuns(this.unit).map(@(gInfo, idx) gInfo.__merge({
          gunIdx = idx
          unallocated = gInfo.total
          notInitedCount = 0
        }))
  }

  function loadBulGroups() {
    this.bulGroups = []
    this.groupsActiveMask = this.unit ? getActiveBulletsGroupInt(this.unit, {
      checkPurchased = this.checkPurchased,
      isForcedAvailable = this.isForcedAvailable
    }) : 0 //!!FIX ME: better to detect actives in manager too.
    if (!this.unit)
      return

    let ammoCounstraintsByTrigger = getAmmoStowageConstraintsByTrigger(this.unit)

    // Preparatory work of Bullet Groups creation
    let bulletDataByGroup = {}
    let bullGroupsCountersByGun = {}
    let bulletsTotal = this.unit.unitType.canUseSeveralBulletsForGun
      ? this.unit.unitType.bulletSetsQuantity : getBulletsGroupCount(this.unit)

    for (local groupIndex = 0; groupIndex < bulletsTotal; groupIndex++) {
      let linkedIdx = getLinkedGunIdx(groupIndex, this.getGunTypesCount(),
        this.unit.unitType.bulletSetsQuantity)

      let bullets = getOptionsBulletsList(this.unit, groupIndex, false, this.isForcedAvailable)
      let selectedName = bullets.values?[bullets.value] ?? ""
      let bulletsSet = getBulletsSetData(this.unit, selectedName)
      let constrainedTotalCount = getBulletsSetMaxAmmoWithConstraints(ammoCounstraintsByTrigger, bulletsSet)
      local maxToRespawn = bulletsSet?.maxToRespawn ?? 0
      if (maxToRespawn > 0 && constrainedTotalCount > 0)
        maxToRespawn = min(constrainedTotalCount, maxToRespawn)

      //!!FIX ME: Needs to have a bit more reliable way to determine bullets type like by TRIGGER_TYPE for example
      let currBulletType = bulletsSet?.isBulletBelt ? "belt" : bulletsSet?.bullets[0].split("_")[0]
      bulletDataByGroup[groupIndex] <- {
        linkedIdx = linkedIdx
        maxToRespawn = maxToRespawn
        constrainedTotalCount = constrainedTotalCount
      }

      if (!bullGroupsCountersByGun?[linkedIdx])
        bullGroupsCountersByGun[linkedIdx] <- {
          limitedGroupCount = 0
          groupCount = 0
          beltsCount = 0
          isUniform = true
          bulletType = currBulletType // Helper value to define isUniform
        }

      let currCounters = bullGroupsCountersByGun[linkedIdx]
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
    foreach (groupIndex, data in bulletDataByGroup) {
      let currCounters = bullGroupsCountersByGun[data.linkedIdx]
      let isUniformNoBelts = (currCounters.isUniform && currCounters.beltsCount == 0
        && currCounters.limitedGroupCount == currCounters.groupCount)
      this.bulGroups.append(::BulletGroup(this.unit, groupIndex, this.getGroupGunInfo(data.linkedIdx, isUniformNoBelts, data.maxToRespawn),
        {
          isActive = stdMath.is_bit_set(this.groupsActiveMask, groupIndex)
          canChangeActivity = this.canChangeBulletsActivity()
          isForcedAvailable = this.isForcedAvailable
          maxToRespawn = data.maxToRespawn
          constrainedTotalCount = data.constrainedTotalCount
        }))
    }
  }

  function forcedBulletsCount() {
    if (!this.gunsInfo.len())
      return

    let forceBulletGroupByGun = {}
    foreach (bulGroup in this.bulGroups)
      if (bulGroup.active && bulGroup.gunInfo.forcedMaxBulletsInRespawn) {
        let gIdx = bulGroup.getGunIdx()
        if (!forceBulletGroupByGun?[gIdx])
          forceBulletGroupByGun[gIdx] <- []

        forceBulletGroupByGun[gIdx].append(bulGroup)
      }

    foreach (_idx, gunBullets in forceBulletGroupByGun) {
      let countBullet = gunBullets.len()

      foreach (bulGroup in gunBullets)
        bulGroup.setBulletsCount(bulGroup.gunInfo.total / countBullet)
    }
  }

  function validateBullets() {
    if (!this.gunsInfo.len())
      return

    let selectedList = this.gunsInfo.map(@(_v) [])

    foreach (gIdx, bulGroup in this.bulGroups) {
      if (!bulGroup.active)
        continue
      let list = getTblValue(bulGroup.getGunIdx(), selectedList)
      if (!list)
        continue

      //check for duplicate bullets
      if (!bulGroup.setBulletNotFromList(list)) {
        bulGroup.active = false
        this.groupsActiveMask = stdMath.change_bit(this.groupsActiveMask, gIdx, 0)
        continue
      }

      let curBulletName = bulGroup.selectedName
      list.append(curBulletName)
    }
  }

  function validateBulletsCount() {
    if (!this.gunsInfo.len())
      return

    foreach (gInfo in this.gunsInfo) {
      gInfo.unallocated = gInfo.total
      gInfo.notInitedCount = 0
    }

    //update unallocated bullets, collect not inited
    let unallocatedPairBulGroup = {}
    local haveNotInited = false
    foreach (_gIdx, bulGroup in this.bulGroups) {
      let gInfo = bulGroup.gunInfo
      if (!bulGroup.active || !gInfo)
        continue

      if (bulGroup.bulletsCount < 0) {
        gInfo.notInitedCount++
        haveNotInited = true
        continue
      }

      let isPairBulletsGroup = bulGroup.isPairBulletsGroup()
      if (isPairBulletsGroup && !bulGroup.canChangePairBulletsCount()) {
        bulGroup.setBulletsCount(gInfo.unallocated)
        gInfo.unallocated = 0
        continue
      }

      let isSecondPairBulletsGroup = (gInfo.gunIdx in unallocatedPairBulGroup)
      if (gInfo.unallocated < bulGroup.bulletsCount || isSecondPairBulletsGroup) { //need set all count for pairs bullets
        bulGroup.setBulletsCount(gInfo.unallocated)
        gInfo.unallocated = 0
      }
      else
        gInfo.unallocated -= bulGroup.bulletsCount

      if (isSecondPairBulletsGroup)
        continue

      if (isPairBulletsGroup)
        unallocatedPairBulGroup[gInfo.gunIdx] <- true
    }

    if (!haveNotInited)
      return

    //init all active not inited bullets
    foreach (_gIdx, bulGroup in this.bulGroups) {
      if (!bulGroup.active || bulGroup.bulletsCount >= 0)
        continue
      let gInfo = bulGroup.gunInfo
      if (!gInfo || !gInfo.notInitedCount) {
        assert(false, "UnitBulletsManager Error: Incorrect not inited bullets count or gun not exist for unit " + this.unit.name)
        continue
      }

      //no point to check unallocated amount left after init. this will happen only once, and all bullets atthat moment will be filled up.
      let newCount = min(gInfo.unallocated / gInfo.notInitedCount, bulGroup.maxBulletsCount)
      bulGroup.setBulletsCount(newCount)
      gInfo.unallocated -= newCount
      gInfo.notInitedCount--
    }
  }

  function updateGroupsActiveMask() {
    if (!this.canChangeBulletsActivity())
      return

    this.groupsActiveMask = getActiveBulletsGroupInt(this.unit)
    foreach (gIdx, bulGroup in this.bulGroups)
      bulGroup.active = stdMath.is_bit_set(this.groupsActiveMask, gIdx)
  }

  function onEventUnitWeaponChanged(p) {
    if (this.unit && this.unit.name == getTblValue("unitName", p))
      this.updateGroupsActiveMask()
  }

  function onEventUnitBulletsChanged(p) {
    if (!this.unit || this.unit.name != p.unit?.name)
      return

    this.loadBulletsData() // Need to reload data because of maxToRespawn in bullet group might be recalculated
    if (p.groupIdx in this.bulGroups)
      this.changeBulletsValue(this.bulGroups[p.groupIdx], p.bulletName)
  }

  function getLinkedBulletsGroup(bulGroup) {
    let { gunInfo, groupIndex }= bulGroup
    if (gunInfo == null)
      return null

    let { gunIdx } = gunInfo
    foreach (linkedBulGroup in this.bulGroups)
      if (linkedBulGroup.groupIndex != groupIndex
          && linkedBulGroup.gunInfo?.gunIdx == gunIdx)
        return linkedBulGroup
    return null
  }
}

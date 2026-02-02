from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem

let { format } = require("string")
let { get_unit_option, set_unit_option, clearUnitOption } = require("guiOptions")
let { getBulletsListHeader } = require("%scripts/weaponry/weaponryDescription.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { setUnitLastBullets, isPairBulletsGroup
        getOptionsBulletsList } = require("%scripts/weaponry/bulletsInfo.nut")
let { AMMO,
        getAmmoAmount,
        isAmmoFree } = require("%scripts/weaponry/ammoInfo.nut")
let { getSavedBullets } = require("%scripts/weaponry/savedWeaponry.nut")
let { USEROPT_BULLETS0, USEROPT_BULLET_COUNT0 } = require("%scripts/options/optionsExtNames.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")

class BulletGroup {
  unit = null
  groupIndex = -1
  selectedName = ""   
  bullets = null  
  bulletsCount = -1
  maxBulletsCount = -1
  gunInfo = null
  guns = 1
  active = false
  canChangeActivity = false
  isForcedAvailable = false
  maxToRespawn = 0
  constrainedTotalCount = 0
  isBulletForTempUnit = false

  option = null 
  selectedBullet = null 

  constructor(v_unit, v_groupIndex, v_gunInfo, params) {
    this.unit = v_unit
    this.groupIndex = v_groupIndex
    this.gunInfo = v_gunInfo
    this.guns = max(this.gunInfo?.guns ?? 1, 1)
    this.active = params?.isActive ?? this.active
    this.canChangeActivity = params?.canChangeActivity ?? this.canChangeActivity
    this.isForcedAvailable = params?.isForcedAvailable ?? this.isForcedAvailable
    this.maxToRespawn = params?.maxToRespawn ?? this.maxToRespawn
    this.constrainedTotalCount = params?.constrainedTotalCount ?? this.constrainedTotalCount
    this.isBulletForTempUnit = params?.isBulletForTempUnit
    this.bullets = getOptionsBulletsList(this.unit, this.groupIndex, false, this.isForcedAvailable)
    this.selectedName = this.bullets.values?[this.bullets.value] ?? ""
    let saveValue = this.bullets.saveValues?[this.bullets.value] ?? ""

    if (!this.isBulletForTempUnit && getSavedBullets(this.unit.name, this.groupIndex) != saveValue)
      setUnitLastBullets(this.unit, this.groupIndex, this.selectedName)

    let bulletOptionId = USEROPT_BULLET_COUNT0 + this.groupIndex
    let count = get_unit_option(this.unit.name, bulletOptionId)
    if (type(count) == "string") 
      clearUnitOption(this.unit.name, bulletOptionId)
    else if (count != null)
      this.bulletsCount = (count / this.guns).tointeger()
    this.updateCounts()
  }

  function canChangeBulletsCount() {
    return this.gunInfo != null
  }

  hasEnableSecondValue =@() this.bullets.items?[1].enabled ?? false
  canChangePairBulletsCount = @() this.hasEnableSecondValue()

  function getGunIdx() {
    return getTblValue("gunIdx", this.gunInfo, 0)
  }

  function setBullet(bulletName) {
    if (this.selectedName == bulletName)
      return false

    let bulletIdx = this.bullets.values.indexof(bulletName)
    if (bulletIdx == null)
      return false

    this.selectedName = bulletName
    this.selectedBullet = null
    if (!this.isBulletForTempUnit)
      setUnitLastBullets(this.unit, this.groupIndex, this.selectedName)
    if (this.option)
      this.option.value = bulletIdx

    this.updateCounts()

    return true
  }

  
  function setBulletNotFromList(bList) {
    if (!isInArray(this.selectedName, bList))
      return true

    foreach (idx, value in this.bullets.values) {
      if (!this.bullets.items[idx].enabled)
        continue
      if (isInArray(value, bList))
        continue
      if (this.setBullet(value))
        return true
    }
    return false
  }

  function getBulletNameByIdx(idx) {
    return getTblValue(idx, this.bullets.values)
  }

  function setBulletsCount(count) {
    if (this.bulletsCount == count)
      return

    this.bulletsCount = count
    set_unit_option(this.unit.name, USEROPT_BULLET_COUNT0 + this.groupIndex, (count * this.guns).tointeger())
  }

  
  function updateCounts() {
    if (!this.gunInfo)
      return false

    local totalBulletsInGun = this.gunInfo.total
    if (this.constrainedTotalCount > 0)
      totalBulletsInGun = min(totalBulletsInGun, (this.constrainedTotalCount / this.guns).tointeger())

    this.maxBulletsCount = totalBulletsInGun
    if (!isAmmoFree(this.unit, this.selectedName, AMMO.PRIMARY)) {
      let boughtCount = (getAmmoAmount(this.unit, this.selectedName, AMMO.PRIMARY) / this.guns).tointeger()
      this.maxBulletsCount = this.isForcedAvailable ? totalBulletsInGun : min(boughtCount, totalBulletsInGun)
    }

    if (this.maxToRespawn > 0)
      this.maxBulletsCount = min(this.maxBulletsCount, this.maxToRespawn)

    if (this.bulletsCount < 0 || this.bulletsCount <= this.maxBulletsCount)
      return false

    this.setBulletsCount(this.maxBulletsCount)
    return true
  }

  function getGunMaxBullets() {
    return getTblValue("total", this.gunInfo, 0)
  }

  function getOption() {
    if (!this.option) {
      unitNameForWeapons.set(this.unit.name)
      this.option = get_option(USEROPT_BULLETS0 + this.groupIndex)
    }
    return this.option
  }

  function _tostring() {
    return format("BulletGroup( unit = %s, idx = %d, active = %s, selected = %s )",
                    this.unit.name, this.groupIndex, this.active.tostring(), this.selectedName)
  }

  function getHeader() {
    if (!this.bullets || !this.unit)
      return ""
    return getBulletsListHeader(this.unit, this.bullets)
  }

  function getBulletNameForCode(bulName) {
    let mod = this.getModByBulletName(bulName)
    return "isDefaultForGroup" in mod ? "" : mod.name
  }

  function getModByBulletName(bulName) {
    local mod = getModificationByName(this.unit, bulName)
    if (!mod) 
      mod = { name = bulName, isDefaultForGroup = this.groupIndex, type = weaponsItem.modification }
    return mod
  }

  _bulletsModsList = null
  function getBulletsModsList() {
    if (!this._bulletsModsList) {
      this._bulletsModsList = []
      foreach (bulName in this.bullets.values)
        this._bulletsModsList.append(this.getModByBulletName(bulName))
    }
    return this._bulletsModsList
  }

  function getSelBullet() {
    if (!this.selectedBullet)
      this.selectedBullet = this.getModByBulletName(this.selectedName)
    return this.selectedBullet
  }

  function shouldHideBullet() {
    return this.gunInfo?.forcedMaxBulletsInRespawn ?? false
  }

  canChangeBullet = @() this.bullets.values.len() > 1
    && !this.isPairBulletsGroup()

  isPairBulletsGroup = @() isPairBulletsGroup(this.bullets)

  function getWeaponName() {
    let needSetWeaponName = this.unit.isAir() || this.unit.isHelicopter()
    return needSetWeaponName ? this.gunInfo?.weapName ?? "" : ""
  }
}

return BulletGroup

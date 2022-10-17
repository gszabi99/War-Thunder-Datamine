let { format } = require("string")
let { getBulletsListHeader } = require("%scripts/weaponry/weaponryDescription.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { setUnitLastBullets,
        getOptionsBulletsList } = require("%scripts/weaponry/bulletsInfo.nut")
let { AMMO,
        getAmmoAmount,
        isAmmoFree } = require("%scripts/weaponry/ammoInfo.nut")
local { clearUnitOption } = ::require_native("guiOptions")

::BulletGroup <- class
{
  unit = null
  groupIndex = -1
  selectedName = ""   //selected bullet name
  bullets = null  //bullets list for this group
  bulletsCount = -1
  maxBulletsCount = -1
  gunInfo = null
  guns = 1
  active = false
  canChangeActivity = false
  isForcedAvailable = false
  maxToRespawn = 0

  option = null //bullet option. initialize only on request because generate descriptions
  selectedBullet = null //selected bullet from modifications list

  constructor(v_unit, v_groupIndex, v_gunInfo, params)
  {
    unit = v_unit
    groupIndex = v_groupIndex
    gunInfo = v_gunInfo
    guns = ::getTblValue("guns", gunInfo) || 1
    active = params?.isActive ?? active
    canChangeActivity = params?.canChangeActivity ?? canChangeActivity
    isForcedAvailable = params?.isForcedAvailable ?? isForcedAvailable
    maxToRespawn = params?.maxToRespawn ?? maxToRespawn

    bullets = getOptionsBulletsList(unit, groupIndex, false, isForcedAvailable)
    selectedName = ::getTblValue(bullets.value, bullets.values, "")
    let saveValue = getBulletNameForCode(selectedName)

    if (::get_last_bullets(unit.name, groupIndex) != saveValue)
      setUnitLastBullets(unit, groupIndex, selectedName)

    let bulletOptionId = ::USEROPT_BULLET_COUNT0 + groupIndex
    let count = ::get_unit_option(unit.name, bulletOptionId)
    if (type(count) == "string") //validate bullets option type
      clearUnitOption(unit.name, bulletOptionId)
    else if (count != null)
      bulletsCount = (count / guns).tointeger()
    updateCounts()
  }

  function canChangeBulletsCount()
  {
    return gunInfo != null
  }

  function getGunIdx()
  {
    return getTblValue("gunIdx", gunInfo, 0)
  }

  function setBullet(bulletName)
  {
    if (selectedName == bulletName)
      return false

    let bulletIdx = bullets.values.indexof(bulletName)
    if (bulletIdx == null)
      return false

    selectedName = bulletName
    selectedBullet = null
    setUnitLastBullets(unit, groupIndex, selectedName)
    if (option)
      option.value = bulletIdx

    updateCounts()

    return true
  }

  //return is new bullet not from list
  function setBulletNotFromList(bList)
  {
    if (!::isInArray(selectedName, bList))
      return true

    foreach(idx, value in bullets.values)
    {
      if (!bullets.items[idx].enabled)
        continue
      if (::isInArray(value, bList))
        continue
      if (setBullet(value))
        return true
    }
    return false
  }

  function getBulletNameByIdx(idx)
  {
    return ::getTblValue(idx, bullets.values)
  }

  function setBulletsCount(count)
  {
    if (bulletsCount == count)
      return

    bulletsCount = count
    ::set_unit_option(unit.name, ::USEROPT_BULLET_COUNT0 + groupIndex, (count * guns).tointeger())
  }

  //return bullets changed
  function updateCounts()
  {
    if (!gunInfo)
      return false

    maxBulletsCount = gunInfo.total
    if (!isAmmoFree(unit, selectedName, AMMO.PRIMARY))
    {
      let boughtCount = (getAmmoAmount(unit, selectedName, AMMO.PRIMARY) / guns).tointeger()
      maxBulletsCount = isForcedAvailable? gunInfo.total : min(boughtCount, gunInfo.total)
    }

    if (maxToRespawn > 0)
      maxBulletsCount = min(maxBulletsCount, maxToRespawn)

    if (bulletsCount < 0 || bulletsCount <= maxBulletsCount)
      return false

    setBulletsCount(maxBulletsCount)
    return true
  }

  function getGunMaxBullets()
  {
    return ::getTblValue("total", gunInfo, 0)
  }

  function getOption()
  {
    if (!option)
    {
      ::aircraft_for_weapons = unit.name
      option = ::get_option(::USEROPT_BULLETS0 + groupIndex)
    }
    return option
  }

  function _tostring()
  {
    return format("BulletGroup( unit = %s, idx = %d, active = %s, selected = %s )",
                    unit.name, groupIndex, active.tostring(), selectedName)
  }

  function getHeader()
  {
    if (!bullets || !unit)
      return ""
    return getBulletsListHeader(unit, bullets)
  }

  function getBulletNameForCode(bulName) {
    let mod = getModByBulletName(bulName)
    return "isDefaultForGroup" in mod? "" : mod.name
  }

  function getModByBulletName(bulName)
  {
    local mod = getModificationByName(unit, bulName)
    if (!mod) //default
      mod = { name = bulName, isDefaultForGroup = groupIndex, type = weaponsItem.modification }
    return mod
  }

  _bulletsModsList = null
  function getBulletsModsList()
  {
    if (!_bulletsModsList)
    {
      _bulletsModsList = []
      foreach(bulName in bullets.values)
        _bulletsModsList.append(getModByBulletName(bulName))
    }
    return _bulletsModsList
  }

  function getSelBullet()
  {
    if (!selectedBullet)
      selectedBullet = getModByBulletName(selectedName)
    return selectedBullet
  }

  function shouldHideBullet()
  {
    return gunInfo?.forcedMaxBulletsInRespawn ?? false
  }
}

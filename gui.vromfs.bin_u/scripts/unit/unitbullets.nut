from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let { getBulletSetNameByBulletName, getBulletsSearchName, getBulletsSetData,
  getModificationBulletsEffect } = require("%scripts/weaponry/bulletsInfo.nut")
let { format } = require("string")
let { getUnitWeaponry } = require("%scripts/weaponry/weaponryInfo.nut")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")

let unitBulletsCache = {}

function addOnceUnitBullet(unit, bullet, showAsSingleBullet = false, isShip = false) {
  if (unit.name not in unitBulletsCache)
    unitBulletsCache[unit.name] <- []

  let { bulletName = "", bulletType, caliber } = bullet

  if (unitBulletsCache[unit.name].findindex(@(v) v.bulletType == bulletType) != null)
    return

  let ammoType = bulletName != "" ? bulletName : bulletType
  let bulletSetName = getBulletSetNameByBulletName(unit, ammoType)

  if (!showAsSingleBullet) {
    unitBulletsCache[unit.name].append({
      bulletName
      bulletType
      getLocName = @() isShip ? loc($"{bulletType}/name/short") : loc(bulletName)
      caliber
      tooltipId = getTooltipType("MODIFICATION").getTooltipId(unit.name, bulletSetName)
    })
    return
  }

  let bulletsSet = getBulletsSetData(unit, bulletSetName)

  let { shellAnimation = null } = bullet

  let bSet = bulletsSet.__merge({
    bullets = [bulletName]
    bulletAnimations = [shellAnimation]
  })

  let searchName = getBulletsSearchName(unit, bulletName)
  let useDefaultBullet = searchName != bulletName
  let bulletParameters = calculate_tank_bullet_parameters(unit.name,
    (useDefaultBullet && bulletsSet?.weaponBlkName) || getModificationBulletsEffect(searchName),
    useDefaultBullet, false)

  let bulletParams = bulletParameters.findvalue(@(p) p.bulletType == bulletType)

  unitBulletsCache[unit.name].append({
    bulletName
    bulletType
    getLocName = @() isShip ? loc($"{bulletType}/name/short") : $"{format(loc("caliber/mm"), caliber * 1000)} {loc($"{bulletType}/name/short")}"
    caliber
    tooltipId = getTooltipType("SINGLE_BULLET").getTooltipId(unit.name, bulletType, {
      modName = bulletType
      bSet
      bulletParams
    })
  })
}

function cacheTankBullets(unit) {
  if (unit.name in unitBulletsCache)
    return

  unitBulletsCache[unit.name] <- []
  let weapons = getUnitWeaponry(unit)
  let cannons = weapons?.weaponsByTypes.cannon ?? weapons?.weaponsByTypes.guns
  if (cannons == null)
    return

  for (local i = 0; i < cannons.len(); i++) {
    let weaponBlocks = cannons[i].weaponBlocks.values()
    for (local j = 0; j < weaponBlocks.len(); j++) {
      let weaponBlock = weaponBlocks[j]
      let weaponBlk = blkOptFromPath(weaponBlock.blk)
      let notUseDefaultBulletInGui = weaponBlk?.notUseDefaultBulletInGui ?? false
      if (!notUseDefaultBulletInGui) {
        let bullets = weaponBlk % "bullet"
        bullets.each(@(v) addOnceUnitBullet(unit v, bullets.len() > 1))
      }

      let bulletsBlockCount = weaponBlk.blockCount()
      for (local b = 0; b < bulletsBlockCount; b++) {
        let bulletBlk = weaponBlk.getBlock(b)
        let modName = bulletBlk.getBlockName()
        if (modName == "bullet" || unit.modifications.findindex(@(v) v.name == modName) == null)
          continue
        let bullets = bulletBlk % "bullet"
        bullets.each(@(v) addOnceUnitBullet(unit, v, bullets.len() > 1))
      }
    }
  }
}

function cacheShipBullets(unit) {
  if (unit.name in unitBulletsCache)
    return

  unitBulletsCache[unit.name] <- []

  let unitBlk = getFullUnitBlk(unit.name)
  let weapons = unitBlk.commonWeapons % "Weapon"
  let neededWeaponsBlk = weapons
    .filter(@(v) ["primary", "secondary"].contains(v.triggerGroup))
    .reduce(function(res, v) {
      appendOnce(v.blk, res)
      return res
    }, [])

  for (local i = 0; i < neededWeaponsBlk.len(); i++) {
    let weaponBlk = blkOptFromPath(neededWeaponsBlk[i])
    let notUseDefaultBulletInGui = weaponBlk?.notUseDefaultBulletInGui ?? false
    if (!notUseDefaultBulletInGui) {
      let bullets = weaponBlk % "bullet"
      bullets.each(@(v) addOnceUnitBullet(unit, v, bullets.len() > 1, true))
    }

    let bulletsBlockCount = weaponBlk.blockCount()
    for (local b = 0; b < bulletsBlockCount; b++) {
      let bulletBlk = weaponBlk.getBlock(b)
      let modName = bulletBlk.getBlockName()
      if (modName == "bullet" || unit.modifications.findindex(@(v) v.name == modName) == null)
        continue
      let bullets = bulletBlk % "bullet"
      bullets.each(@(v) addOnceUnitBullet(unit, v, bullets.len() > 1, true))
    }
  }
}

function cacheUnitBullets(unitName, unitType) {
  let unit = getAircraftByName(unitName)
  if (unitType == ES_UNIT_TYPE_TANK) {
    cacheTankBullets(unit)
    return
  }
  cacheShipBullets(unit)
}

function getUnitBulletsMarkup(unitName, unitType) {
  cacheUnitBullets(unitName, unitType)

  let bullets = unitBulletsCache[unitName]
  let items = []
  for (local i = 0; i < bullets.len(); i++) {
    let caliber = bullets[i].caliber
    local bulletsByCaliber = items.findvalue(@(v) v.caliber == caliber)
    if (bulletsByCaliber == null) {
      bulletsByCaliber = { caliber, bullets = [], getCaliber = @() format(loc("caliber/mm"), caliber * 1000) }
      items.append(bulletsByCaliber)
    }
    bulletsByCaliber.bullets.append(bullets[i].__merge({ isLastItem = i == bullets.len() - 1 }))
  }
  return handyman.renderCached("%gui/unitInfo/unitBullets.tpl", { items })
}

return {
  getUnitBulletsMarkup
}
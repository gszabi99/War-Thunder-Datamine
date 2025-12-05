from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { blkOptFromPath } = require("%sqstd/datablock.nut")
let { getBulletSetNameByBulletName,
   getBulletsSearchName, getBulletsSetData, getModificationBulletsEffect } = require("%scripts/weaponry/bulletsInfo.nut")
let { format } = require("string")
let { getUnitWeaponry } = require("%scripts/weaponry/weaponryInfo.nut")
let { calculate_tank_bullet_parameters } = require("unitCalculcation")

let unitBulletsCache = {}

function addOnceUnitBullet(unit, bullet, showAsSingleBullet = false) {
  if (unit.name not in unitBulletsCache)
    unitBulletsCache[unit.name] <- []

  if (unitBulletsCache[unit.name].findindex(@(v) v.bulletName == bullet.bulletName) != null)
    return

  let bulletSetName = getBulletSetNameByBulletName(unit, bullet.bulletName)

  if (!showAsSingleBullet) {
    let bulletName = bullet.bulletName
    unitBulletsCache[unit.name].append({
      bulletName
      getLocName = @() loc(bulletName)
      tooltipId = getTooltipType("MODIFICATION").getTooltipId(unit.name, bulletSetName)
    })
    return
  }

  let bulletsSet = getBulletsSetData(unit, bulletSetName)

  let { bulletName, caliber, bulletType = null, shellAnimation = null } = bullet

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
    getLocName = @() $"{format(loc("caliber/mm"), caliber * 1000)} {loc($"{bulletType}/name/short")}"
    tooltipId = getTooltipType("SINGLE_BULLET").getTooltipId(unit.name, bulletType, {
      modName = bulletType
      bSet
      bulletParams
    })
  })
}

function cacheUnitBullets(unitName) {
  if (unitName in unitBulletsCache)
    return

  unitBulletsCache[unitName] <- []
  let unit = getAircraftByName(unitName)
  let weapons = getUnitWeaponry(unit)
  let cannons = weapons?.weaponsByTypes.cannon
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

function getUnitBulletsMarkup(unitName) {
  cacheUnitBullets(unitName)

  let bullets = unitBulletsCache[unitName].map(function(data, idx, arr) {
    let { getLocName, tooltipId } = data
    return {
      itemName = getLocName()
      tooltipId
      isLastItem = idx == arr.len() - 1
    }
  })
  return handyman.renderCached("%gui/unitInfo/unitBullets.tpl", { items = bullets })
}

return {
  getUnitBulletsMarkup
}
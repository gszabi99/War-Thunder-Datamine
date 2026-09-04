from "%globalScripts/templates.nut" import getTemplateCompValue
from "string" import format
from "chardResearch" import shopIsModificationPurchased
from "%sqstd/datablock.nut" import blkOptFromPath
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import weaponsItem, infantryDefaultBeltName

let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { setUnitLastBullets, getBulletsNamesBySet } = require("%scripts/weaponry/bulletsInfo.nut")
let { getSavedBullets } = require("%scripts/weaponry/savedWeaponry.nut")
let { USEROPT_BULLETS0 } = require("%scripts/options/optionsExtNames.nut")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { get_option } = require("%scripts/options/optionsExt.nut")
let { getUnitTemplateNames } = require("%scripts/weaponry/infantryTemplates.nut")

const DEFAULT_BELT_IMAGE = "!#ui/gameuiskin#magazine_medium.svg"
const PRIMARY_WEAPON_SLOT_NAME = "primary"

let unitBeltsCache = {}



function getUnitAmmoBelts(unitName) {
  if (unitName in unitBeltsCache)
    return unitBeltsCache[unitName]

  let res = []
  unitBeltsCache[unitName] <- res
  let weaponSlotsBlk = getFullUnitBlk(unitName)?.WeaponSlots
  if (weaponSlotsBlk == null)
    return res

  foreach (ammunitionBlk in (weaponSlotsBlk % "Ammunition")) {
    if ((ammunitionBlk?.index ?? -1) != 0)
      continue
    foreach (setBlk in (ammunitionBlk % "AmmunitionSet")) {
      let reqModification = setBlk?.reqModification ?? ""
      res.append({
        id = reqModification != "" ? reqModification : infantryDefaultBeltName
        reqModification
        ammoTypeEcsTemplate = setBlk?.ammoTypeEcsTemplate ?? ""
      })
    }
  }
  return res
}

let unitBeltSetsCache = {}




function getInfantryBeltBulletsSet(unit, beltId) {
  let cacheId = $"{unit.name}/{beltId}"
  if (cacheId in unitBeltSetsCache)
    return unitBeltSetsCache[cacheId]

  unitBeltSetsCache[cacheId] <- null
  let belt = getUnitAmmoBelts(unit.name).findvalue(@(b) b.id == beltId)
  if (belt == null || belt.ammoTypeEcsTemplate == "")
    return null

  let primaryWeaponTemplateName = getUnitTemplateNames(unit).primaryWeaponTemplateName
  if (primaryWeaponTemplateName == "")
    return null

  let beltType = getTemplateCompValue(belt.ammoTypeEcsTemplate, "ammo_holder__beltType") ?? 0
  let ammoSet = getTemplateCompValue(primaryWeaponTemplateName, "gun__ammoSetsInfo")?[beltType]
  if (ammoSet == null)
    return null

  let res = {
    bullets = []
    bulletNames = []
    caliber = 0.0
    isBulletBelt = true
    cartridge = 0
  }
  foreach (shell in ammoSet) {
    let bulletBlk = blkOptFromPath(shell?.blk ?? "")
    if (bulletBlk == null)
      continue
    res.bullets.append(bulletBlk?.bulletType ?? "ball")
    res.bulletNames.append(bulletBlk?.bulletName ?? "")
    res.caliber = max(res.caliber, bulletBlk?.caliber ?? 0.0)
  }
  if (res.bullets.len() == 0)
    return null

  unitBeltSetsCache[cacheId] = res
  return res
}


function mkCountedList(names, separator) {
  let counted = []
  foreach (name in names) {
    if (name == "")
      continue
    let last = counted.len() > 0 ? counted.top() : null
    if (last != null && last.name == name)
      last.count++
    else
      counted.append({ name, count = 1 })
  }
  return separator.join(counted.map(@(v) v.count > 1
    ? "".concat(v.name, format(loc("weapons/counter"), v.count))
    : v.name))
}


function getInfantryBeltAnnotation(unit, beltId) {
  let set = getInfantryBeltBulletsSet(unit, beltId)
  if (set == null)
    return ""

  let { setText, annotation } = getBulletsNamesBySet(set)
  let res = []
  if (setText != "")
    res.append("".concat(loc("shop/ammo"), loc("ui/colon"), setText))

  let bulletsText = mkCountedList(set.bulletNames.map(@(n) n != "" ? loc(n) : ""), ", ")
  if (bulletsText != "")
    res.append(bulletsText)

  if (annotation != "")
    res.append(annotation)

  return "\n".join(res, true)
}

let InfantryBeltGroup = class {
  unit = null
  groupIndex = 0
  selectedName = ""
  bullets = null
  bulletsCount = 0
  maxBulletsCount = 0
  gunInfo = null
  guns = 1
  active = true
  canChangeActivity = false
  isForcedAvailable = false
  maxCntPerPilon = 1
  selectedBullet = null
  option = null
  _bulletsModsList = null

  constructor(v_unit, v_groupIndex, belts, params = {}) {
    this.unit = v_unit
    this.groupIndex = v_groupIndex
    this.isForcedAvailable = params?.isForcedAvailable ?? false

    this.bullets = {
      values = belts.map(@(b) b.id)
      saveValues = belts.map(@(b) b.reqModification)
      items = belts.map(@(_b) { enabled = true })
      value = 0
    }

    let saved = getSavedBullets(this.unit.name, this.groupIndex)
    local selIdx = saved != "" ? this.bullets.values.indexof(saved) : null
    if (selIdx != null && !this.isBeltAvailable(this.bullets.values[selIdx]))
      selIdx = null
    if (selIdx == null)
      selIdx = belts.findindex(@(b) b.reqModification == "") ?? 0

    this.bullets.value = selIdx
    this.selectedName = this.bullets.values?[selIdx] ?? ""
    if (getSavedBullets(this.unit.name, this.groupIndex) != (this.bullets.saveValues?[selIdx] ?? ""))
      setUnitLastBullets(this.unit, this.groupIndex, this.selectedName)
  }

  function isBeltAvailable(beltId) {
    return this.isForcedAvailable || getModificationByName(this.unit, beltId) == null
      || shopIsModificationPurchased(this.unit.name, beltId) != 0
  }

  function setBullet(bulletName) {
    if (this.selectedName == bulletName)
      return false

    let bulletIdx = this.bullets.values.indexof(bulletName)
    if (bulletIdx == null || !this.isBeltAvailable(bulletName))
      return false

    this.selectedName = bulletName
    this.selectedBullet = null
    this.bullets.value = bulletIdx
    setUnitLastBullets(this.unit, this.groupIndex, this.selectedName)
    return true
  }

  function getModByBulletName(bulName) {
    local mod = getModificationByName(this.unit, bulName)
    if (!mod) 
      mod = { name = bulName, isDefaultForGroup = this.groupIndex, type = weaponsItem.modification,
        image = DEFAULT_BELT_IMAGE }
    return mod
  }

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

  function getBulletNameForCode(bulName) {
    let mod = this.getModByBulletName(bulName)
    return "isDefaultForGroup" in mod ? "" : mod.name
  }

  function getBulletNameByIdx(idx) {
    return this.bullets.values?[idx]
  }

  function getOption() {
    if (!this.option) {
      unitNameForWeapons.set(this.unit.name)
      this.option = get_option(USEROPT_BULLETS0 + this.groupIndex)
    }
    return this.option
  }

  function getEnabledItemsCount() {
    local count = 0
    foreach (v in this.bullets.values)
      if (this.isBeltAvailable(v))
        count++
    return count
  }

  canChangeBullet = @() this.bullets.values.len() > 1 && this.getEnabledItemsCount() > 1

  function setBulletNotFromList(_list) {
    return true
  }

  function updateBulletLimits(_bulletName = null) {}
  function updateCounts() { return false }
  function setBulletsCount(_count) {}
  canChangeBulletsCount = @() false
  canChangePairBulletsCount = @() false
  isPairBulletsGroup = @() false
  shouldHideBullet = @() false
  getGunIdx = @() 0
  getGunMaxBullets = @() 0
  getHeader = @() loc("shop/ammo")
  getWeaponName = @() PRIMARY_WEAPON_SLOT_NAME

  function _tostring() {
    return $"InfantryBeltGroup( unit = {this.unit.name}, idx = {this.groupIndex}, selected = {this.selectedName} )"
  }
}

return {
  getUnitAmmoBelts
  getInfantryBeltBulletsSet
  getInfantryBeltAnnotation
  InfantryBeltGroup
}

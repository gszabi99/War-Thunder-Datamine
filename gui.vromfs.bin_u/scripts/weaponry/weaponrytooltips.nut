//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { format } = require("string")
let { addTooltipTypes } = require("%scripts/utils/genericTooltipTypes.nut")
let { getModificationByName } = require("%scripts/weaponry/modificationInfo.nut")
let { getFakeBulletsModByName, getModificationName } = require("%scripts/weaponry/bulletsInfo.nut")
let { getSingleBulletParamToDesc } = require("%scripts/weaponry/bulletsVisual.nut")
let { updateModType, getTierDescTbl, getSingleWeaponDescTbl, updateSpareType, updateWeaponTooltip,
  validateWeaponryTooltipParams
} = require("%scripts/weaponry/weaponryTooltipPkg.nut")

const INFO_DELAY = 2.0
local infoUnit = null
local infoMod = null
local infoHandler = null
local infoParams = null
let infoShownTiers = {}

local infoTooltipTime = 0.0

let lockedTimerHandler = {
  function onUpdateWeaponTooltip(obj, dt) {
    if (infoTooltipTime <= 0 || infoMod == null)
      return
    infoTooltipTime -= dt
    if (infoTooltipTime > 0)
      return

    let tooltipObj = obj.getParent()
    infoShownTiers[infoMod?.tier ?? 1] <- true
    updateWeaponTooltip(tooltipObj, infoUnit, infoMod, infoHandler, infoParams)
    infoMod = null
    infoHandler = null
  }
}

let tooltipTypes = {
  SINGLE_BULLET = {
    getTooltipId = function(unitName, bulletName = "", params = null, _p3 = null) {
      let p = params ? clone params : {}
      p.bulletName <- bulletName
      return this._buildId(unitName, p)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params) {
      let unit = getAircraftByName(unitName)
      if (!unit)
        return false
      let { modName = "", bulletName = "", bulletParams = {}, bSet = {} } = params

      let locName = " ".concat(format(loc("caliber/mm"), bSet.caliber),
        getModificationName(unit, modName), loc($"{bulletName}/name/short"))
      let data = handyman.renderCached(("%gui/weaponry/weaponTooltip.tpl"),
        getSingleBulletParamToDesc(unit, locName, bulletName, bSet, bulletParams))
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }
  MODIFICATION = { //by unitName, modName
    getTooltipId = function(unitName, modName = "", params = null, _p3 = null) {
      let p = validateWeaponryTooltipParams(params)
      p.modName <- modName
      return this._buildId(unitName, p)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params) {
      let unit = getAircraftByName(unitName)
      if (!unit)
        return false
      let { modName = "" } = params
      let mod = getModificationByName(unit, modName) ?? getFakeBulletsModByName(unit, modName)
      if (!mod)
        return false

      updateModType(unit, mod)
      updateWeaponTooltip(obj, unit, mod, handler, params)
      return true
    }
  }

  PRIMARY_WEAPON = {
    getTooltipId = @(unitName, modName = "", params = null, _p3 = null)
      this._buildId(unitName,
        (validateWeaponryTooltipParams(params)).__merge({ modName }))
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params) {
      let unit = getAircraftByName(unitName)
      if (!unit)
        return false
      let { modName = "" } = params
      let mod = modName == "" ? null : getModificationByName(unit, modName)
      let weaponMod = {
        name = modName,
        type = weaponsItem.primaryWeapon,
        weaponUpgrades = mod == null ? unit.weaponUpgrades : mod?.weaponUpgrades
      }
      updateWeaponTooltip(obj, unit, weaponMod, handler, params)
      return true
    }
  }

  SINGLE_WEAPON = {
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params) {
      if (!obj?.isValid())
        return false

      let unit = getAircraftByName(unitName)
      if (!unit)
        return false

      let data = handyman.renderCached(("%gui/weaponry/weaponTooltip.tpl"), getSingleWeaponDescTbl(unit, params))
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)
      return true
    }
  }

  WEAPON = { //by unitName
    getTooltipId = function(unitName, weaponName = "", params = null, _p3 = null) {
      let p = validateWeaponryTooltipParams(params)
      p.weaponName <- weaponName
      return this._buildId(unitName, p)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params) {
      if (!obj?.isValid())
        return false

      let unit = getAircraftByName(unitName)
      if (!unit)
        return false

      let weaponName = params?.weaponName ?? ""
      let { hasPlayerInfo = true, curEdiff = null } = params
      let effect = hasPlayerInfo ? null : {}
      let weapon = unit.getWeapons().findvalue(@(w) w.name == weaponName)

      if (!weapon)
        return false

      updateWeaponTooltip(obj, unit, weapon, handler, {
        hasPlayerInfo
        curEdiff
        weaponsFilterFunc = params?.weaponBlkPath ? (@(path, _blk) path == params.weaponBlkPath) : null
      }, effect)

      return true
    }
  }

  SPARE = { //by unit name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, ...) {
      if (!checkObj(obj))
        return false

      let unit = getAircraftByName(unitName)
      let spare = getTblValue("spare", unit)
      if (!spare)
        return false

      updateSpareType(spare)
      updateWeaponTooltip(obj, unit, spare, handler)
      return true
    }
  }

  WEAPON_PRESET_TIER = {
    getTooltipId = @(unitName, params)
      this._buildId(unitName, params)

    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params) {
      if (!checkObj(obj))
        return false

      let unit = getAircraftByName(unitName)
      if (!unit)
        return false
      let data = handyman.renderCached(("%gui/weaponry/weaponTooltip.tpl"),
        getTierDescTbl(unit, params))
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)

      return true
    }
  }

  MODIFICATION_DELAYED_TIER = { //by unitName, modName
    getTooltipId = @(unitName, modName = "", params = null, _p3 = null)
      this._buildId(unitName, (params ?? {}).__merge({ modName }))
    isCustomTooltipFill = true

    function fillTooltip(obj, handler, unitName, params) {
      let unit = getAircraftByName(unitName)
      if (!unit)
        return false
      let { modName = "" } = params
      let mod = getModificationByName(unit, modName)
      if (!mod)
        return false

      let { tier = 1 } = mod
      if (unit != infoUnit) {
        infoUnit = unit
        infoShownTiers.clear()
      }
      let canDisplayInfo = tier <= 1 || (infoShownTiers?[tier] ?? false)
      updateModType(unit, mod)
      updateWeaponTooltip(obj, unit, mod, handler, (params ?? {}).__merge({ canDisplayInfo }))

      infoMod = mod
      infoHandler = handler
      infoParams = params
      infoTooltipTime = INFO_DELAY
      obj.findObject("weapons_timer").setUserData(canDisplayInfo ? null : lockedTimerHandler)
      return true
    }

    function onClose(_obj) {
      infoHandler = null
      infoMod = null
    }
  }
}

return addTooltipTypes(tooltipTypes)
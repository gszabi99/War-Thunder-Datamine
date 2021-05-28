local { addTooltipTypes } = require("scripts/utils/genericTooltipTypes.nut")
local { getModificationByName } = require("scripts/weaponry/modificationInfo.nut")
local { getFakeBulletsModByName } = require("scripts/weaponry/bulletsInfo.nut")
local { updateModType, getTierDescTbl, updateSpareType, updateWeaponTooltip
} = require("scripts/weaponry/weaponryTooltipPkg.nut")

const INFO_DELAY = 2.0
local infoUnit = null
local infoMod = null
local infoHandler = null
local infoShownTiers = {}
local infoTooltipTime = 0.0

local lockedTimerHandler = {
  function onUpdateWeaponTooltip(obj, dt) {
    if (infoTooltipTime <= 0 || infoMod == null)
      return
    infoTooltipTime -= dt
    if (infoTooltipTime > 0)
      return

    local tooltipObj = obj.getParent()
    infoShownTiers[infoMod?.tier ?? 1] <- true
    updateWeaponTooltip(tooltipObj, infoUnit, infoMod, infoHandler)
    infoMod = null
    infoHandler = null
  }
}

local tooltipTypes = {
  MODIFICATION = { //by unitName, modName
    getTooltipId = function(unitName, modName = "", params = null, p3 = null)
    {
      local p = params ? clone params : {}
      p.modName <- modName
      return _buildId(unitName, p)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params)
    {
      local unit = getAircraftByName(unitName)
      if (!unit)
        return false
      local { modName = "" } = params
      local mod = getModificationByName(unit, modName) ?? getFakeBulletsModByName(unit, modName)
      if (!mod)
        return false

      updateModType(unit, mod)
      updateWeaponTooltip(obj, unit, mod, handler, params)
      return true
    }
  }

  PRIMARY_WEAPON = {
    getTooltipId = @(unitName, modName = "", params = null, p3 = null)
      _buildId(unitName, (params ?? {}).__merge({ modName }))
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params)
    {
      local unit = getAircraftByName(unitName)
      if (!unit)
        return false
      local { modName = "" } = params
      local mod = modName == "" ? null : getModificationByName(unit, modName)
      local weaponMod = {
        name = modName,
        type = weaponsItem.primaryWeapon,
        weaponUpgrades = mod == null ? unit.weaponUpgrades : mod?.weaponUpgrades
      }
      updateWeaponTooltip(obj, unit, weaponMod, handler, params)
      return true
    }
  }

  WEAPON = { //by unitName, weaponName
    getTooltipId = function(unitName, weaponName = "", params = null, p3 = null)
    {
      local p = params ? clone params : {}
      p.weaponName <- weaponName
      return _buildId(unitName, p)
    }
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params)
    {
      if (!::checkObj(obj))
        return false

      local unit = getAircraftByName(unitName)
      if (!unit)
        return false

      local weaponName = ::getTblValue("weaponName", params, "")
      local hasPlayerInfo = params?.hasPlayerInfo ?? true
      local effect = hasPlayerInfo ? null : {}
      local weapon = ::u.search(unit.weapons, (@(weaponName) function(w) { return w.name == weaponName })(weaponName))
      if (!weapon)
        return false

      updateWeaponTooltip(obj, unit, weapon, handler, {
        hasPlayerInfo = hasPlayerInfo
        weaponsFilterFunc = params?.weaponBlkPath ? (@(path, blk) path == params.weaponBlkPath) : null
      }, effect)
      return true
    }
  }

  SPARE = { //by unit name
    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, ...)
    {
      if (!::checkObj(obj))
        return false

      local unit = getAircraftByName(unitName)
      local spare = ::getTblValue("spare", unit)
      if (!spare)
        return false

      updateSpareType(spare)
      updateWeaponTooltip(obj, unit, spare, handler)
      return true
    }
  }

  WEAPON_PRESET_TIER = {
    getTooltipId = @(unitName, weaponry, presetName, tierId)
      _buildId(unitName, {weaponry = weaponry, presetName = presetName , tierId = tierId})

    isCustomTooltipFill = true
    fillTooltip = function(obj, handler, unitName, params)
    {
      if (!::check_obj(obj))
        return false

      local unit = getAircraftByName(unitName)
      if (!unit)
        return false
      local data = ::handyman.renderCached(("gui/weaponry/weaponTooltip"),
        getTierDescTbl(unit, params.weaponry, params.presetName, params.tierId))
      obj.getScene().replaceContentFromText(obj, data, data.len(), handler)

      return true
    }
  }

  MODIFICATION_DELAYED_TIER = { //by unitName, modName
    getTooltipId = @(unitName, modName = "", params = null, p3 = null)
      _buildId(unitName, (params ?? {}).__merge({ modName }))
    isCustomTooltipFill = true

    function fillTooltip(obj, handler, unitName, params) {
      local unit = getAircraftByName(unitName)
      if (!unit)
        return false
      local { modName = "" } = params
      local mod = getModificationByName(unit, modName)
      if (!mod)
        return false

      local { tier = 1 } = mod
      if (unit != infoUnit) {
        infoUnit = unit
        infoShownTiers.clear()
      }
      local canDisplayInfo = tier <= 1 || (infoShownTiers?[tier] ?? false)
      updateModType(unit, mod)
      updateWeaponTooltip(obj, unit, mod, handler, (params ?? {}).__merge({ canDisplayInfo }))

      infoMod = mod
      infoHandler = handler
      infoTooltipTime = INFO_DELAY
      obj.findObject("weapons_timer").setUserData(canDisplayInfo ? null : lockedTimerHandler)
      return true
    }

    function onClose(obj) {
      infoHandler = null
      infoMod = null
    }
  }
}

return addTooltipTypes(tooltipTypes)
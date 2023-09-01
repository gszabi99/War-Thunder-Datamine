//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let WwFormation = class {
  name = ""
  owner = null
  units = null
  morale = -1
  unitType = ::g_ww_unit_type.UNKNOWN.code
  isUnitsValid = false

  armyGroup = null
  armyView = null
  formationId = null
  mapObjectName = "army"
  artilleryAmmo = null
  hasArtilleryAbility = false
  overrideIconId = ""
  loadedArmyType = ""

  function clear() {
    this.owner?.clear()
    this.units?.clear()

    this.name = ""
    this.morale = -1
    this.unitType = ::g_ww_unit_type.UNKNOWN.code
    this.isUnitsValid = false
    this.artilleryAmmo = null
  }

  function getArmyGroup() {
    if (!this.armyGroup)
      this.armyGroup = ::g_world_war.getArmyGroupByArmy(this)
    return this.armyGroup
  }

  function getView() {
    if (!this.armyView)
      this.armyView = ::WwArmyView(this)
    return this.armyView
  }

  function getUnitType() {
    return this.unitType
  }

  function getUnits(excludeInfantry = false) {
    this.updateUnits()
    if (excludeInfantry)
      return this.units.filter(@(unit) !::g_ww_unit_type.isInfantry(unit.getWwUnitType().code))
    return this.units
  }

  function updateUnits() {} //default func

  function showArmyGroupText() {
    return false
  }

  function getClanId() {
    let group = this.getArmyGroup()
    return group ? group.getClanId() : ""
  }

  function getClanTag() {
    let group = this.getArmyGroup()
    return group ? group.getClanTag() : ""
  }

  function isBelongsToMyClan() {
    let group = this.getArmyGroup()
    return group ? group.isBelongsToMyClan() : false
  }

  function getArmySide() {
    return this.owner.getSide()
  }

  function isMySide(side) {
    return this.getArmySide() == side
  }

  function getArmyGroupIdx() {
    return this.owner.getArmyGroupIdx()
  }

  function getArmyCountry() {
    return this.owner.getCountry()
  }

  function getUnitsNameArray() {
    let res = []
    foreach (unit in this.units)
      res.append(unit.getFullName())

    return res
  }

  function hasManageAccess() {
    let group = this.getArmyGroup()
    return group ? group.hasManageAccess() : false
  }

  function hasObserverAccess() {
    let group = this.getArmyGroup()
    return group ? group.hasObserverAccess() : false
  }

  function isEntrenched() {
    return false
  }

  function isInBattle() {
    return ::g_world_war.getBattleForArmy(this) != null
  }

  function isMove() {
    return false
  }

  function setName(nameText) {
    this.name = nameText
  }

  function setFormationID(id) {
    this.formationId = id
  }

  function getFormationID() {
    return this.formationId
  }

  function setUnitType(wwUnitTypeCode) {
    this.unitType = wwUnitTypeCode
  }

  function getMoral() {
    return this.morale
  }

  function getPosition() {
    return null
  }

  function isFormation() {
    return true
  }

  function hasStrike() {
    return this.artilleryAmmo ? this.artilleryAmmo.hasStrike() : null
  }

  function hasAmmo() {
    return this.getAmmoCount() > 0
  }

  function getAmmoCount() {
    return this.artilleryAmmo ? this.artilleryAmmo.getAmmoCount() : 0
  }

  function getNextAmmoRefillTime() {
    return this.artilleryAmmo ? this.artilleryAmmo.getNextAmmoRefillTime() : -1
  }

  function getMaxAmmoCount() {
    return this.artilleryAmmo ? this.artilleryAmmo.getMaxAmmoCount() : 0
  }

  function getMapObjectName() {
    return this.mapObjectName
  }

  function getOverrideIcon() {
    if (u.isEmpty(this.overrideIconId))
      return null

    return ::ww_get_army_override_icon(this.overrideIconId, this.loadedArmyType, this.hasArtilleryAbility)
  }

  function getOverrideUnitType() {
    switch (this.overrideIconId) {
      case "infantry":
        return ::g_ww_unit_type.INFANTRY.code
      case "helicopter":
        return ::g_ww_unit_type.HELICOPTER.code
    }

    return null
  }

  function setMapObjectName(mapObjName) {
    this.mapObjectName = mapObjName
  }

  function getUnitsNumber() {
    local count = 0
    foreach (unit in this.units)
      count += unit.getCount()

    return count
  }
}

return {WwFormation}
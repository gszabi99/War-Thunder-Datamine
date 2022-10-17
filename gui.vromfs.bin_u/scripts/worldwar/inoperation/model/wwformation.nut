from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

::WwFormation <- class
{
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

  function clear()
  {
    owner?.clear()
    units?.clear()

    name = ""
    morale = -1
    unitType = ::g_ww_unit_type.UNKNOWN.code
    isUnitsValid = false
    artilleryAmmo = null
  }

  function getArmyGroup()
  {
    if (!armyGroup)
      armyGroup = ::g_world_war.getArmyGroupByArmy(this)
    return armyGroup
  }

  function getView()
  {
    if (!armyView)
      armyView = ::WwArmyView(this)
    return armyView
  }

  function getUnitType()
  {
    return unitType
  }

  function getUnits(excludeInfantry = false)
  {
    updateUnits()
    if (excludeInfantry)
      return ::u.filter(units, function (unit) {
        return !::g_ww_unit_type.isInfantry(unit.getWwUnitType().code)
      })
    return units
  }

  function updateUnits() {} //default func

  function showArmyGroupText()
  {
    return false
  }

  function getClanId()
  {
    let group = getArmyGroup()
    return group ? group.getClanId() : ""
  }

  function getClanTag()
  {
    let group = getArmyGroup()
    return group ? group.getClanTag() : ""
  }

  function isBelongsToMyClan()
  {
    let group = getArmyGroup()
    return group ? group.isBelongsToMyClan() : false
  }

  function getArmySide()
  {
    return owner.getSide()
  }

  function isMySide(side)
  {
    return getArmySide() == side
  }

  function getArmyGroupIdx()
  {
    return owner.getArmyGroupIdx()
  }

  function getArmyCountry()
  {
    return owner.getCountry()
  }

  function getUnitsNameArray()
  {
    let res = []
    foreach (unit in units)
      res.append(unit.getFullName())

    return res
  }

  function hasManageAccess()
  {
    let group = getArmyGroup()
    return group ? group.hasManageAccess() : false
  }

  function hasObserverAccess()
  {
    let group = getArmyGroup()
    return group ? group.hasObserverAccess() : false
  }

  function isEntrenched()
  {
    return false
  }

  function isInBattle()
  {
    return ::g_world_war.getBattleForArmy(this) != null
  }

  function isMove()
  {
    return false
  }

  function setName(nameText)
  {
    name = nameText
  }

  function setFormationID(id)
  {
    formationId = id
  }

  function getFormationID()
  {
    return formationId
  }

  function setUnitType(wwUnitTypeCode)
  {
    unitType = wwUnitTypeCode
  }

  function getMoral()
  {
    return morale
  }

  function getPosition()
  {
    return null
  }

  function isFormation()
  {
    return true
  }

  function hasStrike()
  {
    return artilleryAmmo ? artilleryAmmo.hasStrike() : null
  }

  function hasAmmo()
  {
    return getAmmoCount() > 0
  }

  function getAmmoCount()
  {
    return artilleryAmmo ? artilleryAmmo.getAmmoCount() : 0
  }

  function getNextAmmoRefillTime()
  {
    return artilleryAmmo ? artilleryAmmo.getNextAmmoRefillTime() : -1
  }

  function getMaxAmmoCount()
  {
    return artilleryAmmo ? artilleryAmmo.getMaxAmmoCount() : 0
  }

  function getMapObjectName()
  {
    return mapObjectName
  }

  function getOverrideIcon()
  {
    if (::u.isEmpty(overrideIconId))
      return null

    return ::ww_get_army_override_icon(overrideIconId, loadedArmyType, hasArtilleryAbility)
  }

  function getOverrideUnitType()
  {
    switch (overrideIconId)
    {
      case "infantry":
        return ::g_ww_unit_type.INFANTRY.code
      case "helicopter":
        return ::g_ww_unit_type.HELICOPTER.code
    }

    return null
  }

  function setMapObjectName(mapObjName)
  {
    mapObjectName = mapObjName
  }

  function getUnitsNumber()
  {
    local count = 0
    foreach (unit in units)
      count += unit.getCount()

    return count
  }
}

from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")


::WwReinforcementArmy <- class extends ::WwFormation
{
  suppliesEndMillisec = 0
  entrenchEndMillisec = 0
  availableAtMillisec = 0
  loadedArmies = null

  constructor(reinforcementBlock)
  {
    this.units = []
    this.artilleryAmmo = ::WwArtilleryAmmo()
    update(reinforcementBlock)
  }

  function update(reinforcementBlock)
  {
    if (!reinforcementBlock)
      return

    let armyBlock = reinforcementBlock.army
    this.name = armyBlock.name
    this.owner = ::WwArmyOwner(armyBlock.getBlockByName("owner"))

    this.morale = armyBlock?.morale ?? -1
    availableAtMillisec = reinforcementBlock?.availableAtMillisec ?? 0
    suppliesEndMillisec = armyBlock?.suppliesEndMillisec ?? 0
    entrenchEndMillisec = armyBlock?.entrenchEndMillisec ?? 0

    this.unitType = ::g_ww_unit_type.getUnitTypeByTextCode(armyBlock?.specs?.unitType).code
    this.overrideIconId = armyBlock?.iconOverride ?? ""
    this.loadedArmyType = ::ww_get_loaded_army_type(this.name, true)
    this.hasArtilleryAbility = armyBlock?.specs.canArtilleryFire ?? false
    this.units = wwActionsWithUnitsList.loadUnitsFromBlk(armyBlock.getBlockByName("units"))
    loadedArmies = ::build_blk_from_container(reinforcementBlock?.loadedArmies)

    let armyArtilleryParams = this.hasArtilleryAbility ?
      ::g_world_war.getArtilleryUnitParamsByBlk(armyBlock.getBlockByName("units")) : null
    this.artilleryAmmo.setArtilleryParams(armyArtilleryParams)
    this.artilleryAmmo.update(this.name, armyBlock.getBlockByName("artilleryAmmo"))
  }

  function clear()
  {
    base.clear()

    suppliesEndMillisec = 0
    entrenchEndMillisec = 0
    availableAtMillisec = 0
    loadedArmies = null
  }

  function getName()
  {
    return this.name
  }

  function getFullName()
  {
    local fullName = getName()
    fullName += loc("ui/parentheses/space", {text = getDescription()})

    return fullName
  }

  function getDescription()
  {
    let desc = []

    if (this.morale >= 0)
      desc.append(loc("worldwar/morale", {morale = (this.morale + 0.5).tointeger()}))

    if (suppliesEndMillisec > 0)
    {
      let elapsed = max(0, (suppliesEndMillisec - ::ww_get_operation_time_millisec()) * 0.001)

      desc.append(loc("worldwar/suppliesfinishedIn",
          {time = time.hoursToString(time.secondsToHours(elapsed), true, true)}))
    }

    let elapsed = secondsLeftToEntrench();
    if (elapsed == 0)
    {
      desc.append(loc("worldwar/armyEntrenched"))
    }
    else if (elapsed > 0)
    {
      desc.append(loc("worldwar/armyEntrenching",
          {time = time.hoursToString(time.secondsToHours(elapsed), true, true)}))
    }

    return ::g_string.implode(desc, "\n")
  }

  function getArrivalTime()
  {
    return max(0, (availableAtMillisec - ::ww_get_operation_time_millisec()))
  }

  function isReady()
  {
    return getArrivalTime() == 0
  }

  function getArrivalStatusText()
  {
    let arrivalTime = getArrivalTime()
    if (arrivalTime == 0)
      return loc("worldwar/state/reinforcement_ready")

    return time.secondsToString(time.millisecondsToSeconds(arrivalTime), false)
  }

  function getFullDescription()
  {
    local desc = getFullName()
    desc += "\n"
    desc += ::g_string.implode(getUnitsMapFullName(), "\n")
    return desc
  }

  function getUnitsMapFullName()
  {
    return ::u.map(this.getUnits(), function(unit) { return unit.getFullName() })
  }

  function secondsLeftToEntrench()
  {
    if (entrenchEndMillisec <= 0)
      return -1

    return max(0, (entrenchEndMillisec - ::ww_get_operation_time_millisec()) * 0.001)
  }

  static function sortReadyReinforcements(a, b)
  {
    if (a.getArmyGroupIdx() != b.getArmyGroupIdx())
      return a.getArmyGroupIdx() < b.getArmyGroupIdx() ? -1 : 1

    if (a.getUnitType() != b.getUnitType())
      return a.getUnitType() < b.getUnitType() ? -1 : 1
    return 0
  }

  static function sortNewReinforcements(a, b)
  {
    if (a.getArmyGroupIdx() != b.getArmyGroupIdx())
      return a.getArmyGroupIdx() < b.getArmyGroupIdx() ? -1 : 1

    if (a.getArrivalTime() != b.getArrivalTime())
      return a.getArrivalTime() < b.getArrivalTime() ? -1 : 1

    if (a.getUnitType() != b.getUnitType())
      return a.getUnitType() < b.getUnitType() ? -1 : 1

    return 0
  }

  function isFormation()
  {
    return false
  }
}

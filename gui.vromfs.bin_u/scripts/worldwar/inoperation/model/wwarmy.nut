from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { WW_MAP_TOOLTIP_TYPE_ARMY } = require("%scripts/worldWar/wwGenericTooltipTypes.nut")

local transportTypeByTextCode = {
  TT_NONE      = TT_NONE
  TT_GROUND    = TT_GROUND
  TT_AIR       = TT_AIR
  TT_WATER     = TT_WATER
  TT_INFANTRY  = TT_INFANTRY
  TT_TOTAL     = TT_TOTAL
}

::WwArmy <- class extends ::WwFormation
{
  suppliesEndMillisec = 0
  entrenchEndMillisec = 0
  stoppedAtMillisec = 0
  pathTracker = null
  savedArmyBlk = null
  armyIsDead = false
  deathReason = ""
  armyFlags = 0
  transportType = TT_NONE

  constructor(armyName, blk = null)
  {
    savedArmyBlk = blk
    this.units = []
    this.owner = ::WwArmyOwner()
    pathTracker = ::WwPathTracker()
    this.artilleryAmmo = ::WwArtilleryAmmo()
    update(armyName)
  }

  function update(armyName)
  {
    if (!armyName)
      return

    this.name = armyName
    this.owner = ::WwArmyOwner()

    let blk = savedArmyBlk ? savedArmyBlk : getBlk(this.name)
    this.owner.update(blk.getBlockByName("owner"))
    pathTracker.update(blk.getBlockByName("pathTracker"))

    let unitTypeTextCode = blk?.specs.unitType ?? ""
    this.unitType = ::g_ww_unit_type.getUnitTypeByTextCode(unitTypeTextCode).code
    this.morale = getTblValue("morale", blk, -1)
    armyIsDead = get_blk_value_by_path(blk, "specs/isDead", false)
    deathReason = get_blk_value_by_path(blk, "specs/deathReason", "")
    armyFlags = get_blk_value_by_path(blk, "specs/flags", 0)
    transportType = transportTypeByTextCode?[blk?.specs.transportInfo.type ?? "TT_NONE"] ?? TT_NONE
    if (isTransport())
      this.loadedArmyType = blk?.loadedArmyType ?? ::ww_get_loaded_army_type(armyName, false)
    suppliesEndMillisec = getTblValue("suppliesEndMillisec", blk, 0)
    entrenchEndMillisec = getTblValue("entrenchEndMillisec", blk, 0)
    stoppedAtMillisec = getTblValue("stoppedAtMillisec", blk, 0)
    this.overrideIconId = getTblValue("iconOverride", blk, "")
    this.hasArtilleryAbility = blk?.specs.canArtilleryFire ?? false

    let armyArtilleryParams = this.hasArtilleryAbility ?
      ::g_world_war.getArtilleryUnitParamsByBlk(blk.getBlockByName("units")) : null
    this.artilleryAmmo.setArtilleryParams(armyArtilleryParams)
    this.artilleryAmmo.update(this.name, blk.getBlockByName("artilleryAmmo"))
  }

  static _loadingBlk = ::DataBlock()
  function getBlk(armyName)
  {
    _loadingBlk.reset()
    ::ww_get_army_info(armyName, _loadingBlk)
    return _loadingBlk
  }

  function isValid()
  {
    return this.name != "" && this.owner.isValid()
  }

  function clear()
  {
    base.clear()

    suppliesEndMillisec = 0
    entrenchEndMillisec = 0
    stoppedAtMillisec = 0
    pathTracker = null
    armyFlags = 0
  }

  function updateUnits()
  {
    if (this.isUnitsValid || this.name.len() <= 0)
      return

    this.isUnitsValid = true
    let blk = savedArmyBlk ? savedArmyBlk : getBlk(this.name)

    this.units.extend(wwActionsWithUnitsList.loadUnitsFromBlk(blk.getBlockByName("units")))
    this.units.extend(wwActionsWithUnitsList.getFakeUnitsArray(blk))
  }

  function getName()
  {
    return this.name
  }

  function getArmyFlags()
  {
    return armyFlags
  }

  function getUnitType()
  {
    return this.unitType
  }

  function getFullName()
  {
    local fullName = this.name

    let group = this.getArmyGroup()
    if (group)
      fullName += " " + group.getFullName()

    fullName += loc("ui/parentheses/space", {text = getDescription()})

    return fullName
  }

  function isDead()
  {
    return armyIsDead
  }

  function getMoral()
  {
    return (this.morale + 0.5).tointeger()
  }

  function getDescription()
  {
    let desc = []

    let recalMoral = getMoral()
    if (recalMoral >= 0)
      desc.append(loc("worldwar/morale", {morale = recalMoral}))

    let suppliesEnd = getSuppliesFinishTime()
    if (suppliesEnd > 0)
    {
      let timeText = time.hoursToString(time.secondsToHours(suppliesEnd), true, true)
      local suppliesEndLoc = "worldwar/suppliesfinishedIn"
      if (::g_ww_unit_type.isAir(this.unitType))
        suppliesEndLoc = "worldwar/returnToAirfieldIn"
      desc.append( loc(suppliesEndLoc, { time = timeText }) )
    }

    let entrenchTime = secondsLeftToEntrench()
    if (entrenchTime == 0)
    {
      desc.append(loc("worldwar/armyEntrenched"))
    }
    else if (entrenchTime > 0)
    {
      desc.append(loc("worldwar/armyEntrenching",
          {time = time.hoursToString(time.secondsToHours(entrenchTime), true, true)}))
    }

    return ::g_string.implode(desc, "\n")
  }

  function getFullDescription()
  {
    local desc = getFullName()
    desc += "\n"
    desc += ::g_string.implode(getUnitsFullNamesList(), "\n")
    return desc
  }

  function getUnitsFullNamesList()
  {
    return ::u.map(this.getUnits(), function(unit) { return unit.getFullName() })
  }

  function getSuppliesFinishTime()
  {
    local finishTimeMillisec = 0
    if (suppliesEndMillisec > 0)
      finishTimeMillisec = suppliesEndMillisec - ::ww_get_operation_time_millisec()
    else if (this.isInBattle() && suppliesEndMillisec < 0)
      finishTimeMillisec = -suppliesEndMillisec

    return time.millisecondsToSeconds(finishTimeMillisec).tointeger()
  }

  function secondsLeftToEntrench()
  {
    if (entrenchEndMillisec <= 0)
      return -1

    let leftToEntrenchTime = entrenchEndMillisec - ::ww_get_operation_time_millisec()
    return time.millisecondsToSeconds(leftToEntrenchTime).tointeger()
  }

  function secondsLeftToFireEnable()
  {
    if (stoppedAtMillisec <= 0)
      return -1

    let coolDownMillisec = this.artilleryAmmo.getCooldownAfterMoveMillisec()
    let leftToFireEnableTime = stoppedAtMillisec + coolDownMillisec - ::ww_get_operation_time_millisec()
    return max(time.millisecondsToSeconds(leftToFireEnableTime).tointeger(), 0)
  }

  function needUpdateDescription()
  {
    return getSuppliesFinishTime() >= 0 ||
           secondsLeftToEntrench() >= 0 ||
           this.getNextAmmoRefillTime() >= 0 ||
           secondsLeftToFireEnable() >= 0 ||
           this.hasStrike()
  }

  function isEntrenched()
  {
    return entrenchEndMillisec > 0
  }

  function isMove()
  {
    return pathTracker.isMove()
  }

  function canFire()
  {
    if (!this.hasArtilleryAbility)
      return false

    if (isIdle() && secondsLeftToFireEnable() == -1)
      return false

    let hasCoolDown = secondsLeftToFireEnable() > 0
    return this.hasAmmo() && !isMove() && !this.hasStrike() && !hasCoolDown
  }

  function isIdle()
  {
    return !isEntrenched() && !isMove() && !this.isInBattle()
  }

  function isSurrounded()
  {
    return ::g_ww_unit_type.canBeSurrounded(this.unitType) && getSuppliesFinishTime() > 0
  }

  function isStatusEqual(army)
  {
    return getActionStatus() == army.getActionStatus() && isSurrounded() == army.isSurrounded()
  }

  function getActionStatus()
  {
    if (isMove())
      return WW_ARMY_ACTION_STATUS.IN_MOVE
    if (this.isInBattle())
      return WW_ARMY_ACTION_STATUS.IN_BATTLE
    if (isEntrenched())
      return WW_ARMY_ACTION_STATUS.ENTRENCHED
    return WW_ARMY_ACTION_STATUS.IDLE
  }

  getTooltipId = @() WW_MAP_TOOLTIP_TYPE_ARMY.getTooltipId(this.name, {armyName = this.name})

  function getPosition()
  {
    if (!pathTracker)
      return null

    return pathTracker.getCurrentPos()
  }

  function isStrikePreparing()
  {
    return this.hasStrike() && this.artilleryAmmo.isStrikePreparing()
  }

  function isStrikeInProcess()
  {
    return this.hasStrike() && !this.artilleryAmmo.isStrikePreparing()
  }

  function isStrikeOnCooldown()
  {
    return secondsLeftToFireEnable() > 0
  }

  function isFormation()
  {
    return false
  }

  function isTransport()
  {
    return transportType > TT_NONE && transportType < TT_TOTAL
  }

  static function sortArmiesByUnitType(a, b)
  {
    return a.getUnitType() - b.getUnitType()
  }

  static function getCasualtiesCount(blk)
  {
    let artilleryUnits = ::g_world_war.getArtilleryUnits()
    local unitsCount = 0
    for (local i = 0; i < blk.casualties.paramCount(); i++)
      if (!::g_ww_unit_type.isArtillery(this.unitType) ||
          blk.casualties.getParamName(i) in artilleryUnits)
        unitsCount += blk.casualties.getParamValue(i)

    return unitsCount
  }
}

//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let { get_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { WW_MAP_TOOLTIP_TYPE_ARMY } = require("%scripts/worldWar/wwGenericTooltipTypes.nut")
let DataBlock  = require("DataBlock")

local transportTypeByTextCode = {
  TT_NONE      = TT_NONE
  TT_GROUND    = TT_GROUND
  TT_AIR       = TT_AIR
  TT_WATER     = TT_WATER
  TT_INFANTRY  = TT_INFANTRY
  TT_TOTAL     = TT_TOTAL
}

::WwArmy <- class extends ::WwFormation {
  suppliesEndMillisec = 0
  entrenchEndMillisec = 0
  stoppedAtMillisec = 0
  pathTracker = null
  savedArmyBlk = null
  armyIsDead = false
  deathReason = ""
  armyFlags = 0
  transportType = TT_NONE

  constructor(armyName, blk = null) {
    this.savedArmyBlk = blk
    this.units = []
    this.owner = ::WwArmyOwner()
    this.pathTracker = ::WwPathTracker()
    this.artilleryAmmo = ::WwArtilleryAmmo()
    this.update(armyName)
  }

  function update(armyName) {
    if (!armyName)
      return

    this.name = armyName
    this.owner = ::WwArmyOwner()

    let blk = this.savedArmyBlk ? this.savedArmyBlk : this.getBlk(this.name)
    this.owner.update(blk.getBlockByName("owner"))
    this.pathTracker.update(blk.getBlockByName("pathTracker"))

    let unitTypeTextCode = blk?.specs.unitType ?? ""
    this.unitType = ::g_ww_unit_type.getUnitTypeByTextCode(unitTypeTextCode).code
    this.morale = getTblValue("morale", blk, -1)
    this.armyIsDead = get_blk_value_by_path(blk, "specs/isDead", false)
    this.deathReason = get_blk_value_by_path(blk, "specs/deathReason", "")
    this.armyFlags = get_blk_value_by_path(blk, "specs/flags", 0)
    this.transportType = transportTypeByTextCode?[blk?.specs.transportInfo.type ?? "TT_NONE"] ?? TT_NONE
    if (this.isTransport())
      this.loadedArmyType = blk?.loadedArmyType ?? ::ww_get_loaded_army_type(armyName, false)
    this.suppliesEndMillisec = getTblValue("suppliesEndMillisec", blk, 0)
    this.entrenchEndMillisec = getTblValue("entrenchEndMillisec", blk, 0)
    this.stoppedAtMillisec = getTblValue("stoppedAtMillisec", blk, 0)
    this.overrideIconId = getTblValue("iconOverride", blk, "")
    this.hasArtilleryAbility = blk?.specs.canArtilleryFire ?? false

    let armyArtilleryParams = this.hasArtilleryAbility ?
      ::g_world_war.getArtilleryUnitParamsByBlk(blk.getBlockByName("units")) : null
    this.artilleryAmmo.setArtilleryParams(armyArtilleryParams)
    this.artilleryAmmo.update(this.name, blk.getBlockByName("artilleryAmmo"))
  }

  static _loadingBlk = DataBlock()
  function getBlk(armyName) {
    this._loadingBlk.reset()
    ::ww_get_army_info(armyName, this._loadingBlk)
    return this._loadingBlk
  }

  function isValid() {
    return this.name != "" && this.owner.isValid()
  }

  function clear() {
    base.clear()

    this.suppliesEndMillisec = 0
    this.entrenchEndMillisec = 0
    this.stoppedAtMillisec = 0
    this.pathTracker = null
    this.armyFlags = 0
  }

  function updateUnits() {
    if (this.isUnitsValid || this.name.len() <= 0)
      return

    this.isUnitsValid = true
    let blk = this.savedArmyBlk ? this.savedArmyBlk : this.getBlk(this.name)

    this.units.extend(wwActionsWithUnitsList.loadUnitsFromBlk(blk.getBlockByName("units")))
    this.units.extend(wwActionsWithUnitsList.getFakeUnitsArray(blk))
  }

  function getName() {
    return this.name
  }

  function getArmyFlags() {
    return this.armyFlags
  }

  function getUnitType() {
    return this.unitType
  }

  function getFullName() {
    local fullName = this.name

    let group = this.getArmyGroup()
    if (group)
      fullName += " " + group.getFullName()

    fullName += loc("ui/parentheses/space", { text = this.getDescription() })

    return fullName
  }

  function isDead() {
    return this.armyIsDead
  }

  function getMoral() {
    return (this.morale + 0.5).tointeger()
  }

  function getDescription() {
    let desc = []

    let recalMoral = this.getMoral()
    if (recalMoral >= 0)
      desc.append(loc("worldwar/morale", { morale = recalMoral }))

    let suppliesEnd = this.getSuppliesFinishTime()
    if (suppliesEnd > 0) {
      let timeText = time.hoursToString(time.secondsToHours(suppliesEnd), true, true)
      local suppliesEndLoc = "worldwar/suppliesfinishedIn"
      if (::g_ww_unit_type.isAir(this.unitType))
        suppliesEndLoc = "worldwar/returnToAirfieldIn"
      desc.append(loc(suppliesEndLoc, { time = timeText }))
    }

    let entrenchTime = this.secondsLeftToEntrench()
    if (entrenchTime == 0) {
      desc.append(loc("worldwar/armyEntrenched"))
    }
    else if (entrenchTime > 0) {
      desc.append(loc("worldwar/armyEntrenching",
          { time = time.hoursToString(time.secondsToHours(entrenchTime), true, true) }))
    }

    return "\n".join(desc, true)
  }

  function getFullDescription() {
    local desc = this.getFullName()
    desc += "\n"
    desc += "\n".join(this.getUnitsFullNamesList(), true)
    return desc
  }

  function getUnitsFullNamesList() {
    return u.map(this.getUnits(), function(unit) { return unit.getFullName() })
  }

  function getSuppliesFinishTime() {
    local finishTimeMillisec = 0
    if (this.suppliesEndMillisec > 0)
      finishTimeMillisec = this.suppliesEndMillisec - ::ww_get_operation_time_millisec()
    else if (this.isInBattle() && this.suppliesEndMillisec < 0)
      finishTimeMillisec = -this.suppliesEndMillisec

    return time.millisecondsToSeconds(finishTimeMillisec).tointeger()
  }

  function secondsLeftToEntrench() {
    if (this.entrenchEndMillisec <= 0)
      return -1

    let leftToEntrenchTime = this.entrenchEndMillisec - ::ww_get_operation_time_millisec()
    return time.millisecondsToSeconds(leftToEntrenchTime).tointeger()
  }

  function secondsLeftToFireEnable() {
    if (this.stoppedAtMillisec <= 0)
      return -1

    let coolDownMillisec = this.artilleryAmmo.getCooldownAfterMoveMillisec()
    let leftToFireEnableTime = this.stoppedAtMillisec + coolDownMillisec - ::ww_get_operation_time_millisec()
    return max(time.millisecondsToSeconds(leftToFireEnableTime).tointeger(), 0)
  }

  function needUpdateDescription() {
    return this.getSuppliesFinishTime() >= 0 ||
           this.secondsLeftToEntrench() >= 0 ||
           this.getNextAmmoRefillTime() >= 0 ||
           this.secondsLeftToFireEnable() >= 0 ||
           this.hasStrike()
  }

  function isEntrenched() {
    return this.entrenchEndMillisec > 0
  }

  function isMove() {
    return this.pathTracker.isMove()
  }

  function canFire() {
    if (!this.hasArtilleryAbility)
      return false

    if (this.isIdle() && this.secondsLeftToFireEnable() == -1)
      return false

    let hasCoolDown = this.secondsLeftToFireEnable() > 0
    return this.hasAmmo() && !this.isMove() && !this.hasStrike() && !hasCoolDown
  }

  function isIdle() {
    return !this.isEntrenched() && !this.isMove() && !this.isInBattle()
  }

  function isSurrounded() {
    return ::g_ww_unit_type.canBeSurrounded(this.unitType) && this.getSuppliesFinishTime() > 0
  }

  function isStatusEqual(army) {
    return this.getActionStatus() == army.getActionStatus() && this.isSurrounded() == army.isSurrounded()
  }

  function getActionStatus() {
    if (this.isMove())
      return WW_ARMY_ACTION_STATUS.IN_MOVE
    if (this.isInBattle())
      return WW_ARMY_ACTION_STATUS.IN_BATTLE
    if (this.isEntrenched())
      return WW_ARMY_ACTION_STATUS.ENTRENCHED
    return WW_ARMY_ACTION_STATUS.IDLE
  }

  getTooltipId = @() WW_MAP_TOOLTIP_TYPE_ARMY.getTooltipId(this.name, { armyName = this.name })

  function getPosition() {
    if (!this.pathTracker)
      return null

    return this.pathTracker.getCurrentPos()
  }

  function isStrikePreparing() {
    return this.hasStrike() && this.artilleryAmmo.isStrikePreparing()
  }

  function isStrikeInProcess() {
    return this.hasStrike() && !this.artilleryAmmo.isStrikePreparing()
  }

  function isStrikeOnCooldown() {
    return this.secondsLeftToFireEnable() > 0
  }

  function isFormation() {
    return false
  }

  function isTransport() {
    return this.transportType > TT_NONE && this.transportType < TT_TOTAL
  }

  static function sortArmiesByUnitType(a, b) {
    return a.getUnitType() - b.getUnitType()
  }

  static function getCasualtiesCount(blk) {
    let artilleryUnits = ::g_world_war.getArtilleryUnits()
    local unitsCount = 0
    for (local i = 0; i < blk.casualties.paramCount(); i++)
      if (!::g_ww_unit_type.isArtillery(this.unitType) ||
          blk.casualties.getParamName(i) in artilleryUnits)
        unitsCount += blk.casualties.getParamValue(i)

    return unitsCount
  }
}

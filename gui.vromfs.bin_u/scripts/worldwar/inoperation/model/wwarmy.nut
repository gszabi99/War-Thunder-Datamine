from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
let { getBlkValueByPath } = require("%sqstd/datablock.nut")
let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let { WW_MAP_TOOLTIP_TYPE_GROUP, WW_MAP_TOOLTIP_TYPE_ARMY } = require("%scripts/worldWar/wwGenericTooltipTypes.nut")
let DataBlock  = require("DataBlock")
let { wwGetPlayerSide, wwGetZoneName, wwGetOperationTimeMillisec, wwGetArmyInfo,
  wwGetArmyOverrideIcon, wwGetLoadedArmyType } = require("worldwar")
let { WwArmyOwner } = require("%scripts/worldWar/inOperation/model/wwArmyOwner.nut")
let { WwArtilleryAmmo } = require("%scripts/worldWar/inOperation/model/wwArtilleryAmmo.nut")
let { WwPathTracker } = require("%scripts/worldWar/inOperation/model/wwPathTracker.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { ceil } = require("math")
let { getLoadedTransport } = require("%scripts/worldWar/inOperation/wwTransportManager.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")

local WwArmy
function getTransportedArmiesData(formation) {
  let armies = []
  let loadedTransport = getLoadedTransport()
  let transportedArmies = loadedTransport?[formation.name].armies ?? formation?.loadedArmies
  local totalUnitsNum = 0
  if (transportedArmies != null)
    for (local i = 0; i < transportedArmies.blockCount(); i++) {
      let armyBlk = transportedArmies.getBlock(i)
      let army  = WwArmy(armyBlk.getBlockName(), armyBlk)
      armies.append(army)
      totalUnitsNum += army.getUnits().len()
    }

  return { armies, totalUnitsNum }
}

let WwArmyView = class {
  redrawData = null
  formation = null
  customId = null
  name = ""
  hasVersusText = false
  selectedSide = SIDE_NONE

  static unitsInArmyRowsMax = 5

  constructor(v_formation) {
    this.formation = v_formation
    this.name = this.formation.name
    this.setRedrawArmyStatusData()
  }

  function getName() {
    return this.name
  }

  function setId(id) {
    this.customId = id
  }

  function getId() {
    if (this.customId)
      return this.customId

    return "".concat("commander_block_", this.formation.getArmyCountry(),
                "_", this.formation.getArmySide(), "_", this.formation.getArmyGroupIdx(), "_", this.formation.name)
  }

  function getUnitTypeText() {
    return g_ww_unit_type.getUnitTypeFontIcon(this.formation.getUnitType())
  }

  function getUnitTypeCustomText() {
    let overrideIcon = "getOverrideIcon" in this.formation ? this.formation.getOverrideIcon() : null
    return overrideIcon || this.getUnitTypeText()
  }

  function getDescription() {
    return this.formation.getDescription()
  }

  function getSectionsView(sections, isMultipleColumns) {
    let view = { infoSections = [] }
    foreach (sect in sections) {
      let sectView = {
        title = sect?.title,
        columns = [],
        multipleColumns = isMultipleColumns,
        hasSpaceBetweenUnits = true
      }
      let units = sect.units
      if (!isMultipleColumns)
        sectView.columns.append({ unitString = units })
      else {
        let unitsInRow = ceil(units.len() / 2.0).tointeger()
        sectView.columns.append({ unitString = units.slice(0, unitsInRow), first = true })
        sectView.columns.append({ unitString = units.slice(unitsInRow) })
      }
      view.infoSections.append(sectView)
    }
    return view
  }

  function unitsList() {
    let wwUnits = this.formation.getUnits().reduce(function (memo, unit) {
      if (unit.getActiveCount())
        memo.append(unit)
      return memo
    }, [])
    let transportedArmiesData = getTransportedArmiesData(this.formation)
    let rowsCount = wwUnits.len() + transportedArmiesData.armies.len()
      + transportedArmiesData.totalUnitsNum
    let isMultipleColumns = rowsCount > this.unitsInArmyRowsMax
    let sections = [{ units = wwActionsWithUnitsList.getUnitsListViewParams({ wwUnits = wwUnits }) }]
    foreach (army in transportedArmiesData.armies)
      sections.append({
        units = wwActionsWithUnitsList.getUnitsListViewParams({ wwUnits = army.getUnits() }),
        title = "".concat(loc("worldwar/transportedArmy"),
          loc("ui/parentheses/space", {
            text = army.getOverrideIcon() ?? g_ww_unit_type.getUnitTypeFontIcon(army.unitType) }),
          loc("ui/colon"))
      })
    let view = this.getSectionsView(sections, isMultipleColumns)
    return handyman.renderCached("%gui/worldWar/worldWarMapArmyInfoUnitsList.tpl", view)
  }

  /** exclude infantry */
  function unitsCount(excludeInfantry = true, onlyArtillery = false) {
    local res = 0
    foreach (unit in this.formation.getUnits(excludeInfantry))
      res += (!onlyArtillery || unit.isArtillery()) ? unit.getActiveCount() : 0

    return res
  }

  function inactiveUnitsCount(excludeInfantry = true, onlyArtillery = false) {
    local res = 0
    foreach (unit in this.formation.getUnits(excludeInfantry))
      res += (!onlyArtillery || unit.isArtillery()) ? unit.inactiveCount : 0

    return res
  }

  function isDead() {
    return "isDead" in this.formation ? this.formation.isDead() : false
  }

  function isInfantry() {
    return g_ww_unit_type.isInfantry(this.formation.getUnitType())
  }

  function isArtillery() {
    return g_ww_unit_type.isArtillery(this.formation.getUnitType())
  }

  function hasArtilleryAbility() {
    return this.formation.hasArtilleryAbility
  }

  function getUnitsCountText() {
    return this.unitsCount(true, this.isArtillery())
  }

  function getInactiveUnitsCountText() {
    return this.inactiveUnitsCount(true, this.isArtillery())
  }

  function hasManageAccess() {
    return this.formation.hasManageAccess()
  }

  function getArmyGroupIdx() {
    return this.formation.getArmyGroupIdx()
  }

  function clanId() {
    return this.formation.getClanId()
  }

  function clanTag() {
    return this.formation.getClanTag()
  }

  function getTextAfterIcon() {
    return this.clanTag()
  }

  function showArmyGroupText() {
    return this.formation.showArmyGroupText()
  }

  function isBelongsToMyClan() {
    return this.formation.isBelongsToMyClan()
  }

  function getTeamColor() {
    local side = wwGetPlayerSide()
    if (side == SIDE_NONE)
     side = this.selectedSide

    return this.formation.isMySide(side) ? "blue" : "red"
  }

  function getReinforcementArrivalTime() {
    return "getArrivalStatusText" in this.formation ? this.formation.getArrivalStatusText() : null
  }

  function getMoral() {
    return "getMoral" in this.formation ? this.formation.getMoral() : ""
  }

  function getSuppliesFinishTime() {
    let finishTime = "getSuppliesFinishTime" in this.formation ? this.formation.getSuppliesFinishTime() : 0
    if (finishTime > 0)
      return " ".concat(time.hoursToString(time.secondsToHours(finishTime), false, true), loc("icon/timer"))

    return null
  }

  function getAirFuelLastTime() {
    if (g_ww_unit_type.isAir(this.formation.getUnitType()))
      return this.getSuppliesFinishTime() ?? ""
    return ""
  }

  function getAmmoRefillTime() {
    let refillTimeSec = this.formation.getNextAmmoRefillTime()
    if (refillTimeSec > 0)
      return " ".concat(time.hoursToString(time.secondsToHours(refillTimeSec), false, true),
        loc("weapon/torpedoIcon"))
    return ""
  }

  function getGroundSurroundingTime() {
    if (g_ww_unit_type.canBeSurrounded(this.formation.getUnitType()))
      return this.getSuppliesFinishTime()
    return null
  }

  function getActionStatusTime() {
    if ("secondsLeftToEntrench" in this.formation) {
      let entrenchTime = this.formation.secondsLeftToEntrench()
      if (entrenchTime >= 0)
        return time.hoursToString(time.secondsToHours(entrenchTime), false, true)
    }

    return ""
  }

  function getActionStatusIcon() {
    local statusText = []
    if (g_ww_unit_type.isArtillery(this.formation.getUnitType()) && this.formation.hasStrike())
      statusText.append(loc("worldWar/iconStrike"))
    if (this.formation.isInBattle())
      statusText.append(loc("worldWar/iconBattle"))
    if (this.formation.isEntrenched())
      statusText.append(loc("worldWar/iconEntrenched"))
    if (this.formation.isMove())
      statusText = [loc("worldWar/iconMove")]
    return statusText.len() ? "".join(statusText) : loc("worldWar/iconIdle")
  }

  function getActionStatusIconTooltip() {
    local tooltipText = []
    if (g_ww_unit_type.isArtillery(this.formation.getUnitType()) && this.formation.hasStrike())
      tooltipText.append("\n", loc("worldWar/iconStrike"), " ", loc("worldwar/tooltip/army_deals_strike"))
    if (this.formation.isInBattle())
      tooltipText.append("\n", loc("worldWar/iconBattle"), " ", loc("worldwar/tooltip/army_in_battle"))
    if (this.formation.isEntrenched())
      tooltipText.append("\n", loc("worldWar/iconEntrenched"), " ", loc("worldwar/tooltip/army_is_entrenched"))
    if (this.formation.isMove())
      tooltipText.append("\n", loc("worldWar/iconMove"), " ", loc("worldwar/tooltip/army_is_moving"))
    if (tooltipText.len()==0)
      tooltipText.append("\n", loc("worldWar/iconIdle"), " ", loc("worldwar/tooltip/army_is_waiting"))

    return "".join([loc("worldwar/tooltip/army_status"), loc("ui/colon")].extend(tooltipText))
  }

  function getMoraleIconTooltip() {
    return "".concat(loc("worldwar/tooltip/army_morale"), loc("ui/colon"), this.getMoral())
  }

  function getAmmoTooltip() {
    return loc("worldwar/tooltip/ammo_amount")
  }

  function getUnitsIconTooltip() {
    return "".concat(loc("worldwar/tooltip/vehicle_amount"), loc("ui/colon"), this.getUnitsCountText())
  }

  function getArmyReturnTimeTooltip() {
    return loc("worldwar/tooltip/army_return_time")
  }

  function getAmmoRefillTimeTooltip() {
    return loc("worldwar/tooltip/ammo_refill_time")
  }

  function getCountryIcon() {
    return getCustomViewCountryData(this.formation.getArmyCountry()).icon
  }

  function getClanId() {
    return this.formation.getClanId()
  }

  function getClanTag() {
    return this.formation.getClanTag()
  }

  function isEntrenched() {
    return ("isEntrenched" in this.formation) ? this.formation.isEntrenched() : false
  }

  function getFormationID() {
    return this.formation.getFormationID()
  }

  isFormation    = @() this.formation?.isFormation() ?? false
  getTooltipId   = @() WW_MAP_TOOLTIP_TYPE_GROUP.getTooltipId(this.getClanId(), {})

  function getArmyAlertText() {
    if (this.isDead())
      return loc("debriefing/ww_army_state_dead")

    let groundSurroundingTime = this.getGroundSurroundingTime()
    if (groundSurroundingTime)
      return "".concat(loc("worldwar/groundsurrended"), loc("ui/colon"), groundSurroundingTime)

    let inactiveUnitsCountText = this.getInactiveUnitsCountText()
    if (inactiveUnitsCountText)
      return loc("worldwar/active_units", {
        active = this.unitsCount(true, this.isArtillery()),
        inactive = inactiveUnitsCountText
      })

    return ""
  }

  function getArmyInfoText() {
    if (!this.hasArtilleryAbility())
      return ""

    if (this.formation.isMove())
      return loc("worldwar/artillery/is_move")

    if (!this.formation.hasAmmo())
      return loc("worldwar/artillery/no_ammo")

    if (this.formation.isStrikePreparing()) {
      let timeToPrepareStike = this.formation.artilleryAmmo.getTimeToNextStrike()
      return "".concat(loc("worldwar/artillery/aiming"), loc("ui/colon"),
        time.hoursToString(time.secondsToHours(timeToPrepareStike), false, true))
    }

    if (this.formation.isStrikeInProcess()) {
      let timeToFinishStike = this.formation.artilleryAmmo.getTimeToCompleteStrikes()
      return "".concat(loc("worldwar/artillery/firing"), loc("ui/colon"),
        time.hoursToString(time.secondsToHours(timeToFinishStike), false, true))
    }

    if (this.formation.isStrikeOnCooldown())
      return "".concat(loc("worldwar/artillery/preparation"), loc("ui/colon"),
        time.hoursToString(time.secondsToHours(this.formation.secondsLeftToFireEnable()), false, true))

    return loc("worldwar/artillery/can_fire")
  }

  function isAlert() { // warning disable: -named-like-return-bool
    if (this.isDead() || this.getGroundSurroundingTime())
      return "yes"

    return "no"
  }

  function getActionStatusTimeText() {
    return " ".concat(this.getActionStatusTime(), this.getActionStatusIcon())
  }

  function getUnitsCountTextIcon() {
    return this.isInfantry() ? "" : " ".concat(this.getUnitsCountText(), this.getUnitTypeText())
  }

  function getMoralText() {
    return  " ".concat(this.getMoral(), loc("worldWar/iconMoral"))
  }

  function getAmmoText() {
    return  "".concat(this.formation.getAmmoCount(), "/", this.formation.getMaxAmmoCount(), " ",
      loc("weapon/torpedoIcon"))
  }

  function getShortInfoText() {
    local text = [this.getUnitsCountTextIcon()]
    if (!this.isArtillery())
      text.append(" ", this.getMoralText())
    return u.isEmpty(text) ? "" : loc("ui/parentheses", { text = "".join(text) })
  }

  function setRedrawArmyStatusData() {
    this.redrawData = {
      army_status_time = this.getActionStatusTimeText
      army_count = this.getUnitsCountTextIcon
      army_morale = this.getMoralText
      army_return_time = this.getAirFuelLastTime
      army_ammo = this.getAmmoText
      army_ammo_refill_time = this.getAmmoRefillTime
      army_alert_text = this.getArmyAlertText
      army_info_text = this.getArmyInfoText
    }
  }

  function getRedrawArmyStatusData() {
    return this.redrawData
  }

  function getMapObjectName() {
    return this.formation.getMapObjectName()
  }

  function getZoneName() {
    let wwArmyPosition = this.formation.getPosition()
    if (!wwArmyPosition)
      return ""

    if (g_ww_unit_type.isAir(this.formation.getUnitType()))
      return ""

    return loc("ui/parentheses",
      { text = wwGetZoneName(::ww_get_zone_idx_world(wwArmyPosition)) })
  }

  function getHasVersusText() {
    return this.hasVersusText
  }

  function setHasVersusText(val) {
    this.hasVersusText = val
  }

  function setSelectedSide(side) {
    this.selectedSide = side
  }

  function hasManagersStat() {
    return this.formation?.hasManagersStat()
  }

  function getManagersInfoLines() {
    let lines = []
    if (this.hasManagersStat())
      foreach (inst in this.formation.armyManagers)
        lines.append({
          managerInfo = "".concat(inst.name, loc("ui/hyphen"), inst.activity, "%")
        })

    return lines
  }

  needSmallSize = @() this.hasArtilleryAbility() && !this.isArtillery()
}


let WwFormation = class {
  name = ""
  owner = null
  units = null
  morale = -1
  unitType = g_ww_unit_type.UNKNOWN.code
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
    this.unitType = g_ww_unit_type.UNKNOWN.code
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
      this.armyView = WwArmyView(this)
    return this.armyView
  }

  function getUnitType() {
    return this.unitType
  }

  function getUnits(excludeInfantry = false) {
    this.updateUnits()
    if (excludeInfantry)
      return this.units.filter(@(unit) !g_ww_unit_type.isInfantry(unit.getWwUnitType().code))
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
    return this.artilleryAmmo ? this.artilleryAmmo.hasStrike() : false
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

    return wwGetArmyOverrideIcon(this.overrideIconId, this.loadedArmyType, this.hasArtilleryAbility)
  }

  function getOverrideUnitType() {
    switch (this.overrideIconId) {
      case "infantry":
        return g_ww_unit_type.INFANTRY.code
      case "helicopter":
        return g_ww_unit_type.HELICOPTER.code
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

let transportTypeByTextCode = {
  TT_NONE      = TT_NONE
  TT_GROUND    = TT_GROUND
  TT_AIR       = TT_AIR
  TT_WATER     = TT_WATER
  TT_INFANTRY  = TT_INFANTRY
  TT_TOTAL     = TT_TOTAL
}

WwArmy = class(WwFormation) {
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
    this.owner = WwArmyOwner()
    this.pathTracker = WwPathTracker()
    this.artilleryAmmo = WwArtilleryAmmo()
    this.update(armyName)
  }

  function update(armyName) {
    if (!armyName)
      return

    this.name = armyName
    this.owner = WwArmyOwner()

    let blk = this.savedArmyBlk ? this.savedArmyBlk : this.getBlk(this.name)
    this.owner.update(blk.getBlockByName("owner"))
    this.pathTracker.update(blk.getBlockByName("pathTracker"))

    let unitTypeTextCode = blk?.specs.unitType ?? ""
    this.unitType = g_ww_unit_type.getUnitTypeByTextCode(unitTypeTextCode).code
    this.morale = getTblValue("morale", blk, -1)
    this.armyIsDead = getBlkValueByPath(blk, "specs/isDead", false)
    this.deathReason = getBlkValueByPath(blk, "specs/deathReason", "")
    this.armyFlags = getBlkValueByPath(blk, "specs/flags", 0)
    this.transportType = transportTypeByTextCode?[blk?.specs.transportInfo.type ?? "TT_NONE"] ?? TT_NONE
    if (this.isTransport())
      this.loadedArmyType = blk?.loadedArmyType ?? wwGetLoadedArmyType(armyName, false)
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
    wwGetArmyInfo(armyName, this._loadingBlk)
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
    let fullName = [this.name]

    let group = this.getArmyGroup()
    if (group)
      fullName.append(" ",group.getFullName())

    fullName.append(loc("ui/parentheses/space", { text = this.getDescription() }))

    return "".join(fullName)
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
      if (g_ww_unit_type.isAir(this.unitType))
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
    let desc = [this.getFullName()]
              .extend(this.getUnitsFullNamesList())
    return "\n".join(desc, true)
  }

  function getUnitsFullNamesList() {
    return this.getUnits().map(@(unit) unit.getFullName())
  }

  function getSuppliesFinishTime() {
    local finishTimeMillisec = 0
    if (this.suppliesEndMillisec > 0)
      finishTimeMillisec = this.suppliesEndMillisec - wwGetOperationTimeMillisec()
    else if (this.isInBattle() && this.suppliesEndMillisec < 0)
      finishTimeMillisec = -this.suppliesEndMillisec

    return time.millisecondsToSeconds(finishTimeMillisec).tointeger()
  }

  function secondsLeftToEntrench() {
    if (this.entrenchEndMillisec <= 0)
      return -1

    let leftToEntrenchTime = this.entrenchEndMillisec - wwGetOperationTimeMillisec()
    return time.millisecondsToSeconds(leftToEntrenchTime).tointeger()
  }

  function secondsLeftToFireEnable() {
    if (this.stoppedAtMillisec <= 0)
      return -1

    let coolDownMillisec = this.artilleryAmmo.getCooldownAfterMoveMillisec()
    let leftToFireEnableTime = this.stoppedAtMillisec + coolDownMillisec - wwGetOperationTimeMillisec()
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
    return g_ww_unit_type.canBeSurrounded(this.unitType) && this.getSuppliesFinishTime() > 0
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

  function getCasualtiesCount(blk) {
    let artilleryUnits = ::g_world_war.getArtilleryUnits()
    local unitsCount = 0
    for (local i = 0; i < blk.casualties.paramCount(); i++)
      if (!g_ww_unit_type.isArtillery(this.unitType) ||
          blk.casualties.getParamName(i) in artilleryUnits)
        unitsCount += blk.casualties.getParamValue(i)

    return unitsCount
  }
}
return { WwArmy, WwArmyView, WwFormation }
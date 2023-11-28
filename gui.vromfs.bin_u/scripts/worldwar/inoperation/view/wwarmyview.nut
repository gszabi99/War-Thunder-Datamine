//-file:plus-string
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let time = require("%scripts/time.nut")
let { ceil } = require("math")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let wwTransportManager = require("%scripts/worldWar/inOperation/wwTransportManager.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { WW_MAP_TOOLTIP_TYPE_GROUP } = require("%scripts/worldWar/wwGenericTooltipTypes.nut")
let { wwGetPlayerSide } = require("worldwar")

::WwArmyView <- class {
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

    return "commander_block_" + this.formation.getArmyCountry() + "_" + this.formation.getArmySide() + "_" + this.formation.getArmyGroupIdx() + "_" + this.formation.name
  }

  function getUnitTypeText() {
    return ::g_ww_unit_type.getUnitTypeFontIcon(this.formation.getUnitType())
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
    let transportedArmiesData = wwTransportManager.getTransportedArmiesData(this.formation)
    let rowsCount = wwUnits.len() + transportedArmiesData.armies.len()
      + transportedArmiesData.totalUnitsNum
    let isMultipleColumns = rowsCount > this.unitsInArmyRowsMax
    let sections = [{ units = wwActionsWithUnitsList.getUnitsListViewParams({ wwUnits = wwUnits }) }]
    foreach (army in transportedArmiesData.armies)
      sections.append({
        units = wwActionsWithUnitsList.getUnitsListViewParams({ wwUnits = army.getUnits() }),
        title = "".concat(loc("worldwar/transportedArmy"),
          loc("ui/parentheses/space", {
            text = army.getOverrideIcon() ?? ::g_ww_unit_type.getUnitTypeFontIcon(army.unitType) }),
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
    return ::g_ww_unit_type.isInfantry(this.formation.getUnitType())
  }

  function isArtillery() {
    return ::g_ww_unit_type.isArtillery(this.formation.getUnitType())
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
      return time.hoursToString(time.secondsToHours(finishTime), false, true) + " " + loc("icon/timer")

    return null
  }

  function getAirFuelLastTime() {
    if (::g_ww_unit_type.isAir(this.formation.getUnitType()))
      return this.getSuppliesFinishTime() ?? ""
    return ""
  }

  function getAmmoRefillTime() {
    let refillTimeSec = this.formation.getNextAmmoRefillTime()
    if (refillTimeSec > 0)
      return time.hoursToString(time.secondsToHours(refillTimeSec), false, true) + " " +
        loc("weapon/torpedoIcon")
    return ""
  }

  function getGroundSurroundingTime() {
    if (::g_ww_unit_type.canBeSurrounded(this.formation.getUnitType()))
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
    local statusText = ""
    if (::g_ww_unit_type.isArtillery(this.formation.getUnitType()) && this.formation.hasStrike())
      statusText += loc("worldWar/iconStrike")
    if (this.formation.isInBattle())
      statusText += loc("worldWar/iconBattle")
    if (this.formation.isEntrenched())
      statusText += loc("worldWar/iconEntrenched")
    if (this.formation.isMove())
      statusText = loc("worldWar/iconMove")
    return statusText.len() ? statusText : loc("worldWar/iconIdle")
  }

  function getActionStatusIconTooltip() {
    local tooltipText = ""
    if (::g_ww_unit_type.isArtillery(this.formation.getUnitType()) && this.formation.hasStrike())
      tooltipText += "\n" + loc("worldWar/iconStrike") + " " + loc("worldwar/tooltip/army_deals_strike")
    if (this.formation.isInBattle())
      tooltipText += "\n" + loc("worldWar/iconBattle") + " " + loc("worldwar/tooltip/army_in_battle")
    if (this.formation.isEntrenched())
      tooltipText += "\n" + loc("worldWar/iconEntrenched") + " " + loc("worldwar/tooltip/army_is_entrenched")
    if (this.formation.isMove())
      tooltipText += "\n" + loc("worldWar/iconMove") + " " + loc("worldwar/tooltip/army_is_moving")
    if (!tooltipText.len())
      tooltipText += "\n" + loc("worldWar/iconIdle") + " " + loc("worldwar/tooltip/army_is_waiting")

    return loc("worldwar/tooltip/army_status") + loc("ui/colon") + tooltipText
  }

  function getMoraleIconTooltip() {
    return loc("worldwar/tooltip/army_morale") + loc("ui/colon") + this.getMoral()
  }

  function getAmmoTooltip() {
    return loc("worldwar/tooltip/ammo_amount")
  }

  function getUnitsIconTooltip() {
    return loc("worldwar/tooltip/vehicle_amount") + loc("ui/colon") + this.getUnitsCountText()
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
    return this.getActionStatusTime() + " " + this.getActionStatusIcon()
  }

  function getUnitsCountTextIcon() {
    return this.isInfantry() ? "" : this.getUnitsCountText() + " " + this.getUnitTypeText()
  }

  function getMoralText() {
    return this.getMoral() + " " + loc("worldWar/iconMoral")
  }

  function getAmmoText() {
    return this.formation.getAmmoCount() + "/" + this.formation.getMaxAmmoCount() + " " +
      loc("weapon/torpedoIcon")
  }

  function getShortInfoText() {
    local text = this.getUnitsCountTextIcon()
    if (!this.isArtillery())
      text += " " + this.getMoralText()
    return u.isEmpty(text) ? "" : loc("ui/parentheses", { text = text })
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

    if (::g_ww_unit_type.isAir(this.formation.getUnitType()))
      return ""

    return loc("ui/parentheses",
      { text = ::ww_get_zone_name(::ww_get_zone_idx_world(wwArmyPosition)) })
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

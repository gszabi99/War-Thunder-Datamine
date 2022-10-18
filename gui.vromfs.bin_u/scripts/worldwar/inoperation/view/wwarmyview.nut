let time = require("%scripts/time.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let wwTransportManager = require("%scripts/worldWar/inOperation/wwTransportManager.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { WW_MAP_TOOLTIP_TYPE_GROUP } = require("%scripts/worldWar/wwGenericTooltipTypes.nut")

::WwArmyView <- class
{
  redrawData = null
  formation = null
  customId = null
  name = ""
  hasVersusText = false
  selectedSide = ::SIDE_NONE

  static unitsInArmyRowsMax = 5

  constructor(v_formation)
  {
    formation = v_formation
    name = formation.name
    setRedrawArmyStatusData()
  }

  function getName()
  {
    return name
  }

  function setId(id)
  {
    customId = id
  }

  function getId()
  {
    if (customId)
      return customId

    return "commander_block_" + formation.getArmyCountry() + "_" + formation.getArmySide() + "_" + formation.getArmyGroupIdx() + "_" + formation.name
  }

  function getUnitTypeText()
  {
    return ::g_ww_unit_type.getUnitTypeFontIcon(formation.getUnitType())
  }

  function getUnitTypeCustomText()
  {
    let overrideIcon = "getOverrideIcon" in formation ? formation.getOverrideIcon() : null
    return overrideIcon || getUnitTypeText()
  }

  function getDescription()
  {
    return formation.getDescription()
  }

  function getSectionsView(sections, isMultipleColumns)
  {
    let view = {infoSections = []}
    foreach (sect in sections)
    {
      let sectView = {
        title = sect?.title,
        columns = [],
        multipleColumns = isMultipleColumns,
        hasSpaceBetweenUnits = true
      }
      let units = sect.units
      if (!isMultipleColumns)
        sectView.columns.append({unitString = units})
      else
      {
        let unitsInRow = ::ceil(units.len() / 2.0).tointeger()
        sectView.columns.append({unitString = units.slice(0, unitsInRow), first = true})
        sectView.columns.append({unitString = units.slice(unitsInRow)})
      }
      view.infoSections.append(sectView)
    }
    return view
  }

  function unitsList()
  {
    let wwUnits = formation.getUnits().reduce(function (memo, unit) {
      if (unit.getActiveCount())
        memo.append(unit)
      return memo
    }, [])
    let transportedArmiesData = wwTransportManager.getTransportedArmiesData(formation)
    let rowsCount = wwUnits.len() + transportedArmiesData.armies.len()
      + transportedArmiesData.totalUnitsNum
    let isMultipleColumns = rowsCount > unitsInArmyRowsMax
    let sections = [{units = wwActionsWithUnitsList.getUnitsListViewParams({wwUnits = wwUnits})}]
    foreach (army in transportedArmiesData.armies)
      sections.append({
        units = wwActionsWithUnitsList.getUnitsListViewParams({wwUnits = army.getUnits()}),
        title = "".concat(::loc("worldwar/transportedArmy"),
          ::loc("ui/parentheses/space", {
            text = army.getOverrideIcon() ?? ::g_ww_unit_type.getUnitTypeFontIcon(army.unitType)}),
          ::loc("ui/colon"))
      })
    let view = getSectionsView(sections, isMultipleColumns)
    return ::handyman.renderCached("%gui/worldWar/worldWarMapArmyInfoUnitsList", view)
  }

  /** exclude infantry */
  function unitsCount(excludeInfantry = true, onlyArtillery = false)
  {
    local res = 0
    foreach (unit in formation.getUnits(excludeInfantry))
      res += (!onlyArtillery || unit.isArtillery()) ? unit.getActiveCount() : 0

    return res
  }

  function inactiveUnitsCount(excludeInfantry = true, onlyArtillery = false)
  {
    local res = 0
    foreach (unit in formation.getUnits(excludeInfantry))
      res += (!onlyArtillery || unit.isArtillery()) ? unit.inactiveCount : 0

    return res
  }

  function isDead()
  {
    return "isDead" in formation ? formation.isDead() : false
  }

  function isInfantry()
  {
    return ::g_ww_unit_type.isInfantry(formation.getUnitType())
  }

  function isArtillery()
  {
    return ::g_ww_unit_type.isArtillery(formation.getUnitType())
  }

  function hasArtilleryAbility()
  {
    return formation.hasArtilleryAbility
  }

  function getUnitsCountText()
  {
    return unitsCount(true, isArtillery())
  }

  function getInactiveUnitsCountText()
  {
    return inactiveUnitsCount(true, isArtillery())
  }

  function hasManageAccess()
  {
    return formation.hasManageAccess()
  }

  function getArmyGroupIdx()
  {
    return formation.getArmyGroupIdx()
  }

  function clanId()
  {
    return formation.getClanId()
  }

  function clanTag()
  {
    return formation.getClanTag()
  }

  function getTextAfterIcon()
  {
    return clanTag()
  }

  function showArmyGroupText()
  {
    return formation.showArmyGroupText()
  }

  function isBelongsToMyClan()
  {
    return formation.isBelongsToMyClan()
  }

  function getTeamColor()
  {
    local side = ::ww_get_player_side()
    if (side == ::SIDE_NONE)
     side = selectedSide

    return formation.isMySide(side) ? "blue" : "red"
  }

  function getReinforcementArrivalTime()
  {
    return "getArrivalStatusText" in formation? formation.getArrivalStatusText() : null
  }

  function getMoral()
  {
    return "getMoral" in formation ? formation.getMoral() : ""
  }

  function getSuppliesFinishTime()
  {
    let finishTime = "getSuppliesFinishTime" in formation? formation.getSuppliesFinishTime() : 0
    if (finishTime > 0)
      return time.hoursToString(time.secondsToHours(finishTime), false, true) + " " + ::loc("icon/timer")

    return null
  }

  function getAirFuelLastTime()
  {
    if (::g_ww_unit_type.isAir(formation.getUnitType()))
      return getSuppliesFinishTime()
    return ""
  }

  function getAmmoRefillTime()
  {
    let refillTimeSec = formation.getNextAmmoRefillTime()
    if (refillTimeSec > 0)
      return time.hoursToString(time.secondsToHours(refillTimeSec), false, true) + " " +
        ::loc("weapon/torpedoIcon")
    return ""
  }

  function getGroundSurroundingTime()
  {
    if (::g_ww_unit_type.canBeSurrounded(formation.getUnitType()))
      return getSuppliesFinishTime()
    return null
  }

  function getActionStatusTime()
  {
    if ("secondsLeftToEntrench" in formation)
    {
      let entrenchTime = formation.secondsLeftToEntrench()
      if (entrenchTime >= 0)
        return time.hoursToString(time.secondsToHours(entrenchTime), false, true)
    }

    return ""
  }

  function getActionStatusIcon()
  {
    local statusText = ""
    if (::g_ww_unit_type.isArtillery(formation.getUnitType()) && formation.hasStrike())
      statusText += ::loc("worldWar/iconStrike")
    if (formation.isInBattle())
      statusText += ::loc("worldWar/iconBattle")
    if (formation.isEntrenched())
      statusText += ::loc("worldWar/iconEntrenched")
    if (formation.isMove())
      statusText = ::loc("worldWar/iconMove")
    return statusText.len() ? statusText : ::loc("worldWar/iconIdle")
  }

  function getActionStatusIconTooltip()
  {
    local tooltipText = ""
    if (::g_ww_unit_type.isArtillery(formation.getUnitType()) && formation.hasStrike())
      tooltipText += "\n" + ::loc("worldWar/iconStrike") + " " + ::loc("worldwar/tooltip/army_deals_strike")
    if (formation.isInBattle())
      tooltipText += "\n" + ::loc("worldWar/iconBattle") + " " + ::loc("worldwar/tooltip/army_in_battle")
    if (formation.isEntrenched())
      tooltipText += "\n" + ::loc("worldWar/iconEntrenched") + " " + ::loc("worldwar/tooltip/army_is_entrenched")
    if (formation.isMove())
      tooltipText += "\n" + ::loc("worldWar/iconMove") + " " + ::loc("worldwar/tooltip/army_is_moving")
    if (!tooltipText.len())
      tooltipText += "\n" + ::loc("worldWar/iconIdle") + " " + ::loc("worldwar/tooltip/army_is_waiting")

    return ::loc("worldwar/tooltip/army_status") + ::loc("ui/colon") + tooltipText
  }

  function getMoraleIconTooltip()
  {
    return ::loc("worldwar/tooltip/army_morale") + ::loc("ui/colon") + getMoral()
  }

  function getAmmoTooltip()
  {
    return ::loc("worldwar/tooltip/ammo_amount")
  }

  function getUnitsIconTooltip()
  {
    return ::loc("worldwar/tooltip/vehicle_amount") + ::loc("ui/colon") + getUnitsCountText()
  }

  function getArmyReturnTimeTooltip()
  {
    return ::loc("worldwar/tooltip/army_return_time")
  }

  function getAmmoRefillTimeTooltip()
  {
    return ::loc("worldwar/tooltip/ammo_refill_time")
  }

  function getCountryIcon()
  {
    return getCustomViewCountryData(formation.getArmyCountry()).icon
  }

  function getClanId()
  {
    return formation.getClanId()
  }

  function getClanTag()
  {
    return formation.getClanTag()
  }

  function isEntrenched()
  {
    return ("isEntrenched" in formation) ? formation.isEntrenched() :false
  }

  function getFormationID()
  {
    return formation.getFormationID()
  }

  isFormation    = @() formation?.isFormation() ?? false
  getTooltipId   = @() WW_MAP_TOOLTIP_TYPE_GROUP.getTooltipId(getClanId(), {})

  function getArmyAlertText()
  {
    if (isDead())
      return ::loc("debriefing/ww_army_state_dead")

    let groundSurroundingTime = getGroundSurroundingTime()
    if (groundSurroundingTime)
      return ::loc("worldwar/groundsurrended") + ::loc("ui/colon") + groundSurroundingTime

    let inactiveUnitsCountText = getInactiveUnitsCountText()
    if (inactiveUnitsCountText)
      return ::loc("worldwar/active_units", {
        active = unitsCount(true, isArtillery()),
        inactive = inactiveUnitsCountText
      })

    return null
  }

  function getArmyInfoText()
  {
    if (!hasArtilleryAbility())
      return null

    if (formation.isMove())
      return ::loc("worldwar/artillery/is_move")

    if (!formation.hasAmmo())
      return ::loc("worldwar/artillery/no_ammo")

    if (formation.isStrikePreparing())
    {
      let timeToPrepareStike = formation.artilleryAmmo.getTimeToNextStrike()
      return ::loc("worldwar/artillery/aiming") + ::loc("ui/colon") +
             time.hoursToString(time.secondsToHours(timeToPrepareStike), false, true)
    }

    if (formation.isStrikeInProcess())
    {
      let timeToFinishStike = formation.artilleryAmmo.getTimeToCompleteStrikes()
      return ::loc("worldwar/artillery/firing") + ::loc("ui/colon") +
             time.hoursToString(time.secondsToHours(timeToFinishStike), false, true)
    }

    if (formation.isStrikeOnCooldown())
      return ::loc("worldwar/artillery/preparation") + ::loc("ui/colon") +
             time.hoursToString(time.secondsToHours(formation.secondsLeftToFireEnable()), false, true)

    return ::loc("worldwar/artillery/can_fire")
  }

  function isAlert() // warning disable: -named-like-return-bool
  {
    if (isDead() || getGroundSurroundingTime())
      return "yes"

    return "no"
  }

  function getActionStatusTimeText()
  {
    return getActionStatusTime() + " " + getActionStatusIcon()
  }

  function getUnitsCountTextIcon()
  {
    return isInfantry() ? "" : getUnitsCountText() + " " + getUnitTypeText()
  }

  function getMoralText()
  {
    return getMoral() + " " + ::loc("worldWar/iconMoral")
  }

  function getAmmoText()
  {
    return formation.getAmmoCount() + "/" + formation.getMaxAmmoCount() + " " +
      ::loc("weapon/torpedoIcon")
  }

  function getShortInfoText()
  {
    local text = getUnitsCountTextIcon()
    if (!isArtillery())
      text += " " + getMoralText()
    return ::u.isEmpty(text) ? "" : ::loc("ui/parentheses", { text = text })
  }

  function setRedrawArmyStatusData()
  {
    redrawData = {
      army_status_time = getActionStatusTimeText
      army_count = getUnitsCountTextIcon
      army_morale = getMoralText
      army_return_time = getAirFuelLastTime
      army_ammo = getAmmoText
      army_ammo_refill_time = getAmmoRefillTime
      army_alert_text = getArmyAlertText
      army_info_text = getArmyInfoText
    }
  }

  function getRedrawArmyStatusData()
  {
    return redrawData
  }

  function getMapObjectName()
  {
    return formation.getMapObjectName()
  }

  function getZoneName()
  {
    let wwArmyPosition = formation.getPosition()
    if (!wwArmyPosition)
      return ""

    if(::g_ww_unit_type.isAir(formation.getUnitType()))
      return ""

    return ::loc("ui/parentheses",
      {text = ::ww_get_zone_name(::ww_get_zone_idx_world(wwArmyPosition))})
  }

  function getHasVersusText()
  {
    return hasVersusText
  }

  function setHasVersusText(val)
  {
    hasVersusText = val
  }

  function setSelectedSide(side)
  {
    selectedSide = side
  }

  function hasManagersStat()
  {
    return formation?.hasManagersStat()
  }

  function getManagersInfoLines()
  {
    let lines = []
    if(hasManagersStat())
      foreach(inst in formation.armyManagers)
        lines.append({
          managerInfo = "".concat(inst.name, ::loc("ui/hyphen"), inst.activity, "%")
        })

    return lines
  }

  needSmallSize = @() hasArtilleryAbility() && !isArtillery()
}

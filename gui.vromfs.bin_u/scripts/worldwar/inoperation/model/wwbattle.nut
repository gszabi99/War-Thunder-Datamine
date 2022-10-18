let time = require("%scripts/time.nut")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let wwQueuesData = require("%scripts/worldWar/operations/model/wwQueuesData.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let wwOperationUnitsGroups = require("%scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")
let slotbarPresets = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getMissionLocName } = require("%scripts/missions/missionsUtilsModule.nut")
let { getMyStateData } = require("%scripts/user/userUtils.nut")

const WW_BATTLES_SORT_TIME_STEP = 120
const WW_MAX_PLAYERS_DISBALANCE_DEFAULT = 3
const MAX_BATTLE_WAIT_TIME_MIN_DEFAULT = 30

::WwBattle <- class
{
  id = ""
  status = 0
  teams = null
  pos = null
  maxPlayersPerArmy = null
  minPlayersPerArmy = null
  opponentsType = null
  updateAppliedOnHost = -1
  missionName = ""
  localizeConfig = null
  missionInfo = null
  battleActivateMillisec = 0
  battleStartMillisec = 0
  ordinalNumber = 0
  sessionId = ""
  totalPlayersNumber = 0
  maxPlayersNumber = 0
  sortTimeFactor = null
  sortFullnessFactor = null

  queueInfo = null
  unitTypeMask = 0

  creationTimeMillisec = 0
  operationTimeOnCreationMillisec = 0
  unitsGroups = null

  constructor(blk = ::DataBlock(), params = null)
  {
    id = blk?.id ?? blk.getBlockName() ?? ""
    status = blk?.status? ::ww_battle_status_name_to_val(blk.status) : 0
    pos = blk?.pos ? ::Point2(blk.pos.x, blk.pos.y) : ::Point2()
    maxPlayersPerArmy = blk?.maxPlayersPerArmy ?? 0
    minPlayersPerArmy = blk?.minTeamSize ?? 0
    battleActivateMillisec = (blk?.activationTime ?? 0).tointeger()
    battleStartMillisec = (blk?.battleStartTimestamp ?? 0).tointeger()
    ordinalNumber = blk?.ordinalNumber ?? 0
    opponentsType = blk?.opponentsType ?? -1
    updateAppliedOnHost = blk?.updateAppliedOnHost ?? -1
    missionName = blk?.desc.missionName ?? ""
    sessionId = blk?.desc.sessionId ?? ""
    missionInfo = ::get_mission_meta_info(missionName)
    creationTimeMillisec = blk?.creationTime ?? 0
    operationTimeOnCreationMillisec = blk?.operationTimeOnCreation ?? 0
    unitsGroups = wwOperationUnitsGroups.getUnitsGroups()

    createLocalizeConfig(blk?.desc)

    updateParams(blk, params)
    updateTeamsInfo(blk)
    applyBattleUpdates(blk)
    updateSortParams()
  }

  function updateParams(blk, params) {}

  function applyBattleUpdates(blk)
  {
    let updatesBlk = blk.getBlockByName("battleUpdates")
    if (!updatesBlk)
      return

    for (local i = 0; i < updatesBlk.blockCount(); i++)
    {
      let updateBlk = updatesBlk.getBlock(i)
      if ((updateBlk?.updateId ?? -1) <= updateAppliedOnHost)
        continue

      let teamsBlk = updateBlk.getBlockByName("teams")
      for (local j = 0; j < teamsBlk.blockCount(); j++)
      {
        let teamBlk = teamsBlk.getBlock(j)
        if (teamBlk == null)
          continue

        let teamName = teamBlk.getBlockName() || ""
        if (teamName.len() == 0)
          continue

        let unitsAddedBlock = teamBlk.getBlockByName("unitsAdded")
        let team = teams[teamName]
        let newUnits = []

        for(local k = 0; k < unitsAddedBlock.blockCount(); k++)
        {
          let unitBlock = unitsAddedBlock.getBlock(k)
          if (unitBlock == null)
            continue

          let unitName = unitBlock.getBlockName() || ""
          if (unitName.len() == 0)
            continue

          local hasUnit = false
          foreach(idx, wwUnit in team.unitsRemain)
            if (wwUnit.name == unitName)
            {
              hasUnit = true
              wwUnit.count += unitBlock.count
              break
            }

          if (!hasUnit)
            newUnits.append(unitBlock)
        }

        foreach(idx, unitBlk in newUnits)
          team.unitsRemain.append(::WwUnit(unitBlk))
      }
    }
  }

  function isValid()
  {
    return id.len() > 0
  }

  function isWaiting()
  {
    return status == ::EBS_WAITING ||
           status == ::EBS_STALE
  }

  function isStale()
  {
    return status == ::EBS_STALE
  }

  function isActive()
  {
    return status == ::EBS_ACTIVE_STARTING ||
           status == ::EBS_ACTIVE_MATCHING ||
           status == ::EBS_ACTIVE_CONFIRMED
  }

  function isStarting()
  {
    return status == ::EBS_ACTIVE_STARTING ||
           status == ::EBS_ACTIVE_MATCHING
  }

  function isStarted()
  {
    return status == ::EBS_ACTIVE_MATCHING ||
           status == ::EBS_ACTIVE_CONFIRMED
  }

  function isConfirmed()
  {
    return status == ::EBS_ACTIVE_CONFIRMED
  }

  function isFinished()
  {
    return status == ::EBS_FINISHED ||
           status == ::EBS_FINISHED_APPLIED
  }

  function isFullSessionByTeam(side = null)
  {
    side = side || ::ww_get_player_side()
    local team = getTeamBySide(side)
    return !team || team.players == team.maxPlayers
  }

  function getLocName(side = null)
  {
    side = side ?? getSide(::get_profile_country_sq())
    let teamName = getTeamNameBySide(side)
    if (localizeConfig == null)
      return id

    let locId = ((localizeConfig?[$"locNameTeam{teamName}"].len() ?? 0) > 0)
      ? $"locNameTeam{teamName}"
      : "locName"
    return getMissionLocName(localizeConfig, locId)
  }

  function getOrdinalNumber()
  {
    return ordinalNumber
  }

  function getLocDesc()
  {
    return localizeConfig ? getMissionLocName(localizeConfig, "locDesc") : id
  }

  function getMissionName()
  {
    return !::u.isEmpty(missionName) ? missionName : ""
  }

  function getView(customPlayerSide = null)
  {
    return ::WwBattleView(this, customPlayerSide)
  }

  function getSessionId()
  {
    return sessionId
  }

  function createLocalizeConfig(descBlk)
  {
    localizeConfig = {
      locName = descBlk?.locName ?? ""
      locNameTeamA = descBlk?.locNameTeamA ?? ""
      locNameTeamB = descBlk?.locNameTeamB ?? ""
      locDesc = descBlk?.locDesc ?? ""
      locDescTeamA = descBlk?.locDescTeamA ?? ""
      locDescTeamB = descBlk?.locDescTeamB ?? ""
    }
  }

  function updateTeamsInfo(blk)
  {
    teams = {}
    totalPlayersNumber = 0
    maxPlayersNumber = 0
    unitTypeMask = 0

    let teamsBlk = blk.getBlockByName("teams")
    let descBlk = blk.getBlockByName("desc")
    let waitingTeamsBlk = descBlk ? descBlk.getBlockByName("teamsInfo") : null
    if (!teamsBlk || (isWaiting() && !waitingTeamsBlk))
      return

    for (local i = 0; i < teamsBlk.blockCount(); ++i)
    {
      let teamBlk = teamsBlk.getBlock(i)
      let teamName = teamBlk.getBlockName() || ""
      if (teamName.len() == 0)
        continue

      let teamSideName = teamBlk?.side ?? ""
      if (teamSideName.len() == 0)
        continue

      let numPlayers = teamBlk?.players ?? 0
      let teamMaxPlayers = teamBlk?.maxPlayers ?? 0

      let armyNamesBlk = teamBlk.getBlockByName("armyNames")
      let teamArmyNames = []
      let teamUnitTypes = []
      local firstArmyCountry = ""
      let countries = {}
      if (armyNamesBlk)
      {
        for (local j = 0; j < armyNamesBlk.paramCount(); ++j)
        {
          let armyName = armyNamesBlk.getParamValue(j) || ""
          if (armyName.len() == 0)
            continue

          let army = g_world_war.getArmyByName(armyName)
          if (!army)
          {
            ::script_net_assert_once("WW can't find army", "ww: can't find army " + armyName)
            continue
          }

          if (!(army.owner.country in countries))
            countries[army.owner.country] <- []
          countries[army.owner.country].append(army)

          if (firstArmyCountry.len() == 0)
            firstArmyCountry = army.owner.country

          teamArmyNames.append(armyName)
          ::u.appendOnce(army.unitType, teamUnitTypes)
          let wwUnitType = ::g_ww_unit_type.getUnitTypeByCode(army.unitType)
          if (wwUnitType.canBeControlledByPlayer)
            unitTypeMask = unitTypeMask | unitTypes.getByEsUnitType(wwUnitType.esUnitCode).bit
        }
      }

      let teamUnitsRemain = []
      if (!isWaiting())
      {
        let unitsRemainBlk = teamBlk.getBlockByName("unitsRemain")
        let aiUnitsBlk = teamBlk.getBlockByName("aiUnits")
        teamUnitsRemain.extend(wwActionsWithUnitsList.loadUnitsFromBlk(unitsRemainBlk, aiUnitsBlk))
        teamUnitsRemain.extend(wwActionsWithUnitsList.getFakeUnitsArray(teamBlk))
      }

      let teamInfo = {name = teamName
                        players = numPlayers
                        maxPlayers = teamMaxPlayers
                        minPlayers = minPlayersPerArmy
                        side = ::ww_side_name_to_val(teamSideName)
                        country = firstArmyCountry
                        countries = countries
                        armyNames = teamArmyNames
                        unitsRemain = teamUnitsRemain
                        unitTypes = teamUnitTypes}
      if(teamBlk?.autoBattleWinChancePercent != null)
        teamInfo.autoBattleWinChancePercent <- teamBlk.autoBattleWinChancePercent
      teams[teamName] <- teamInfo
      totalPlayersNumber += numPlayers
      maxPlayersNumber += teamMaxPlayers
    }
  }

  function getCantJoinReasonData(side, needCheckSquad = true)
  {
    let res = {
      code = WW_BATTLE_CANT_JOIN_REASON.CAN_JOIN
      canJoin = false
      reasonText = ""
      shortReasonText = ""
      fullReasonText = ""
    }

    if (!::g_world_war.canJoinWorldwarBattle())
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_WW_ACCESS
      res.reasonText = ::loc("worldWar/noAccess")
      res.fullReasonText = ::g_world_war.getPlayWorldwarConditionText()
      return res
    }

    if (isFinished())
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
      res.reasonText = ::loc("worldwar/battle_finished_need_refresh")
      return res
    }

    if (!isValid())
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
      res.reasonText = ::loc("worldWar/battleNotSelected")
      return res
    }

    if (!isActive())
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
      res.reasonText = ::loc(isStillInOperation() ? "worldwar/battleNotActive" : "worldwar/battle_finished")
      return res
    }

    if (::ww_get_player_side() != ::SIDE_NONE && ::ww_get_player_side() != side)
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.WRONG_SIDE
      res.reasonText = ::loc("worldWar/cant_fight_for_enemy_side")
      return res
    }

    if (side == ::SIDE_NONE)
    {
      ::script_net_assert_once("WW check battle without player side", "ww: check battle without player side")
      res.code = WW_BATTLE_CANT_JOIN_REASON.UNKNOWN_SIDE
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    if (getBattleActivateLeftTime() > 0)
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.EXCESS_PLAYERS
      res.reasonText = ::loc("worldWar/battle_activate_countdown")
      return res
    }

    let team = getTeamBySide(side)
    if (!team)
    {
      ::script_net_assert_once("WW can't find team in battle", "ww: can't find team in battle")
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_TEAM
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    if (!team.country)
    {
      ::script_net_assert_once("WW can't get country",
                               "ww: can't get country for team "+team.name)
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_COUNTRY_IN_TEAM
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    if (::g_squad_manager.isSquadLeader())
    {
      let notAllowedInWorldWarMembers = ::g_squad_manager.getMembersNotAllowedInWorldWar()
      if (notAllowedInWorldWarMembers.len() > 0)
      {
        let tArr = notAllowedInWorldWarMembers.map(@(m) ::colorize("warningTextColor", m.name))
        let text = ::g_string.implode(tArr, ",")
        res.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_MEMBERS_NO_WW_ACCESS
        res.reasonText = ::loc("worldwar/squad/notAllowedMembers")
        res.fullReasonText = ::loc("worldwar/squad/notAllowedMembers") + ::loc("ui/colon") + "\n" + text
        return res
      }
    }

    if ((::g_squad_manager.isSquadLeader() || !::g_squad_manager.isInSquad())
      && isLockedByExcessPlayers(side, team.name))
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.EXCESS_PLAYERS
      res.reasonText = ::loc("worldWar/battle_is_unbalanced")
      return res
    }

    let maxPlayersInTeam = team.maxPlayers
    let queue = wwQueuesData.getData()?[id]
    let isInQueueAmount = getPlayersInQueueByTeamName(queue, team.name)
    if (isInQueueAmount >= maxPlayersInTeam)
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.QUEUE_FULL
      res.reasonText = ::loc("worldwar/queue_full")
      return res
    }

    let countryName = getCountryNameBySide(side)
    if (!countryName)
    {
      ::script_net_assert_once("WW can't get country",
                  "ww: can't get country for team "+team.name+" from "+team.country)
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_COUNTRY_BY_SIDE
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    let teamName = getTeamNameBySide(side)
    if (!teamName)
    {
      ::script_net_assert_once("WW can't get team",
              "ww: can't get team for team "+team.name+" for battle "+id)
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_TEAM_NAME_BY_SIDE
      res.reasonText = ::loc("msgbox/internal_error_header")
      return res
    }

    if (team.players >= maxPlayersInTeam)
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.TEAM_FULL
      res.reasonText = ::loc("worldwar/army_full")
      return res
    }

    if (!hasAvailableUnits(team))
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_AVAILABLE_UNITS
      res.reasonText = ::loc("worldwar/airs_not_available")
      return res
    }

    let remainUnits = getUnitsRequiredForJoin(team, side)
    let myCheckingData = ::g_squad_utils.getMemberAvailableUnitsCheckingData(
      getMyStateData(), remainUnits, team.country)
    if (myCheckingData.joinStatus != memberStatus.READY)
    {
      res.code = WW_BATTLE_CANT_JOIN_REASON.UNITS_NOT_ENOUGH_AVAILABLE
      res.reasonText = ::loc(::g_squad_utils.getMemberStatusLocId(myCheckingData.joinStatus))
      return res
    }

    if (needCheckSquad && ::g_squad_manager.isInSquad())
    {
      updateCantJoinReasonDataBySquad(team, side, isInQueueAmount, res)
      if (!::u.isEmpty(res.reasonText))
        return res
    }

    res.canJoin = true

    return res
  }

  function isPlayerTeamFull()
  {
    let team = getTeamBySide(::ww_get_player_side())
    if (team)
      return team.players >= team.maxPlayers
    return false
  }

  function hasAvailableUnits(team = null)
  {
    if (!team)
    {
      let side = getSide(::get_profile_country_sq())
      if (side == ::SIDE_NONE)
        return false

      team = getTeamBySide(side)
    }
    return team ? getTeamRemainUnits(team).len() > 0 : false
  }

  function isStillInOperation()
  {
    let battles = ::g_world_war.getBattles(
        (@(id) function(checkedBattle) {
          return checkedBattle.id == id
        })(id)
      )
    return battles.len() > 0
  }

  function updateCantJoinReasonDataBySquad(team, side, isInQueueAmount, reasonData)
  {
    if (!::g_squad_manager.isSquadLeader())
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_LEADER
      reasonData.reasonText = ::loc("worldwar/squad/onlyLeaderCanJoinBattle")
      return reasonData
    }

    if (!::g_squad_utils.canJoinByMySquad(null, team.country))
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_WRONG_SIDE
      reasonData.reasonText = ::loc("worldWar/squad/membersHasDifferentSide")
      return reasonData
    }

    let maxPlayersInTeam = team.maxPlayers
    if (team.players + ::g_squad_manager.getOnlineMembersCount() > maxPlayersInTeam)
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_TEAM_FULL
      reasonData.reasonText = ::loc("worldwar/squad/army_full")
      return reasonData
    }

    if (isInQueueAmount + ::g_squad_manager.getOnlineMembersCount() > maxPlayersInTeam)
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_QUEUE_FULL
      reasonData.reasonText = ::loc("worldwar/squad/queue_full")
      return reasonData
    }

    if (!::g_squad_manager.readyCheck(false))
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_ALL_READY
      reasonData.reasonText = ::loc("squad/not_all_ready")
      return reasonData
    }

    if (::has_feature("WorldWarSquadInfo") && !::g_squad_manager.crewsReadyCheck())
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_ALL_CREWS_READY
      reasonData.reasonText = ::loc("squad/not_all_crews_ready")
      return reasonData
    }

    let remainUnits = getUnitsRequiredForJoin(team, side)
    let membersCheckingDatas = ::g_squad_utils.getMembersAvailableUnitsCheckingData(remainUnits, team.country)

    let langConfig = []
    local shortMessage = ""
    foreach (idx, data in membersCheckingDatas)
    {
      if (data.joinStatus != memberStatus.READY && data.memberData.online == true)
      {
        let memberLangConfig = [
          systemMsg.makeColoredValue(COLOR_TAG.USERLOG, data.memberData.name),
          "ui/colon",
          ::g_squad_utils.getMemberStatusLocId(data.joinStatus)
        ]
        langConfig.append(memberLangConfig)
        if (!shortMessage.len())
          shortMessage = systemMsg.configToLang(memberLangConfig) || ""
      }

      if (!langConfig.len())
        data.unitsCountUnderLimit <- getAvailableUnitsCountUnderLimit(data.unbrokenAvailableUnits,
                                                                      remainUnits, ::g_squad_manager.getSquadSize())
    }

    if (langConfig.len())
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_MEMBER_ERROR
      reasonData.reasonText = systemMsg.configToLang(langConfig, null, "\n") || ""
      reasonData.shortReasonText = shortMessage
      return reasonData
    }

    if (!checkAvailableSquadUnitsAdequacy(membersCheckingDatas, remainUnits))
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_UNITS_NOT_ENOUGH_AVAILABLE
      reasonData.reasonText = ::loc("worldwar/squad/insufficiently_available_units")
      return reasonData
    }

    if (!::g_squad_manager.readyCheck(true))
    {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_HAVE_UNACCEPTED_INVITES
      reasonData.reasonText = ::loc("squad/revoke_non_accept_invites")
      reasonData.shortReasonText = ::loc("squad/has_non_accept_invites")
      return reasonData
    }

    return reasonData
  }

  function tryToJoin(side)
  {
    let cantJoinReasonData = getCantJoinReasonData(side, true)
    if (!cantJoinReasonData.canJoin)
    {
      ::showInfoMsgBox(cantJoinReasonData.reasonText)
      return
    }

    let joinCb = ::Callback(@() join(side), this)
    let warningReasonData = getWarningReasonData(side)
    if (warningReasonData.needMsgBox &&
        !::loadLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false))
    {
      ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox,
        {
          parentHandler = this
          message = ::u.isEmpty(warningReasonData.fullWarningText)
            ? warningReasonData.warningText
            : warningReasonData.fullWarningText
          ableToStartAndSkip = true
          onStartPressed = joinCb
          skipFunc = @(value) ::saveLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, value)
        })
      return
    }

    joinCb()
  }

  function join(side)
  {
    let opId = ::ww_get_operation_id()
    let countryName = getCountryNameBySide(side)
    let teamName = getTeamNameBySide(side)

    ::dagor.debug("ww: join ww battle op:" + opId.tostring() + ", battle:" + id +
                ", country:" + countryName + ", team:" + teamName)

    ::WwBattleJoinProcess(this, side)
    ::ww_event("JoinBattle", {battleId = id})
  }

  function checkAvailableSquadUnitsAdequacy(membersCheckingDatas, remainUnits)
  {
    membersCheckingDatas.sort(function(a, b) {
                                if (a.unitsCountUnderLimit != b.unitsCountUnderLimit)
                                  return a.unitsCountUnderLimit > b.unitsCountUnderLimit ? -1 : 1
                                return 0
                              })

    for (local i = membersCheckingDatas.len() - 1; i >= 0; i--)
      if (membersCheckingDatas[i].unitsCountUnderLimit >= membersCheckingDatas.len())
        membersCheckingDatas.remove(i)

    let unbrokenAvailableUnits = []
    foreach (idx, data in membersCheckingDatas)
      unbrokenAvailableUnits.append(data.unbrokenAvailableUnits)

    return ::g_squad_utils.checkAvailableUnits(unbrokenAvailableUnits, remainUnits)
  }

  function getAvailableUnitsCountUnderLimit(availableUnits, remainUnits, limit)
  {
    local unitsSummary = 0
    foreach(idx, name in availableUnits)
    {
      unitsSummary += remainUnits[name]
      if (unitsSummary >= limit)
        break
    }

    return unitsSummary
  }

  function isArmyJoined(armyName)
  {
    foreach(teamData in teams)
      if (::isInArray(armyName, teamData.armyNames))
        return true
    return false
  }

  function getWarningReasonData(side)
  {
    let res = {
        needShow = false
        needMsgBox = false
        warningText = ""
        fullWarningText = ""
        availableUnits = []
        country = ""
      }

    if (!isValid() || isFinished())
      return res

    let team = getTeamBySide(side)
    let isCrewByUnitsGroup = isBattleByUnitsGroup()
    let countryCrews = isCrewByUnitsGroup
      ? slotbarPresets.getCurPreset().countryPresets?[team?.country ?? ""].units
      : ::get_crews_list_by_country(team.country)

     if (countryCrews == null)
       return res

    let availableUnits = getTeamRemainUnits(team, isCrewByUnitsGroup)
    let crewNames = []
    foreach(crew in countryCrews)
    {
      let crewUnit = isCrewByUnitsGroup
        ? crew
        : ::g_crew.getCrewUnit(crew)
      if (crewUnit != null)
        crewNames.append(crewUnit.name)
    }

    local isAllBattleUnitsInSlots = true
    res.availableUnits = availableUnits
    res.country = team.country
    foreach(unitName, count in availableUnits)
      if (!::isInArray(unitName, crewNames))
      {
        if (isCrewByUnitsGroup)
        {
          res.needShow = true
          res.needMsgBox = true
          res.warningText = ::loc("worldWar/warning/can_insert_higher_rank_units")
          res.fullWarningText = ::loc("worldWar/warning/can_insert_higher_rank_units_full")
          return res
        }
        else if (::getAircraftByName(unitName)?.canUseByPlayer() ?? false)
        {
          res.needShow = true
          res.needMsgBox = true
          res.warningText = ::loc("worldWar/warning/can_insert_more_available_units")
          res.fullWarningText = ::loc("worldWar/warning/can_insert_more_available_units_full")
          return res
        }
        else
          isAllBattleUnitsInSlots = false
      }

    if (!isAllBattleUnitsInSlots)
    {
      res.needShow = true
      res.warningText = ::loc("worldWar/warning/has_not_all_battle_units")
      res.fullWarningText = ::loc("worldWar/warning/has_not_all_battle_units_full")
    }

    return res
  }

  function getUnitsRequiredForJoin(team, side)
  {
    let unitAvailability = ::g_world_war.getSetting("checkUnitAvailability",
      WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)

    if (unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)
      return getTeamRemainUnits(team)
    else if (unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.OPERATION_UNITS)
      return ::g_operations.getAllOperationUnitsBySide(side)
    else if (unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.NO_MATCHING_UNITS)
      return {}

    return null
  }

  function getTeamRemainUnits(team, onlyBestAvailableFromGroup = false)
  {
    let availableUnits = {}
    let eDiff = ::DIFFICULTY_REALISTIC
    let curPreset = slotbarPresets.getCurPreset()
    let country = team?.country ?? ""
    let curSlotbarUnits = curPreset?.countryPresets[country].units ?? []
    foreach(unit in team.unitsRemain)
    {
      if (unit.count <= 0 || unit.isControlledByAI())
        continue

      let groupUnits = unitsGroups?[unit.name].units
      if (groupUnits == null)
        availableUnits[unit.name] <- unit.count
      else
      {
        if (!onlyBestAvailableFromGroup)
        {
          availableUnits.__update(groupUnits.map(@(u) unit.count))
          continue
        }

        let sortedUnits = groupUnits.values().map(
          @(u) { unit = u, rank = u.getBattleRating(eDiff), isInSlotbar = ::isInArray(u, curSlotbarUnits) })
        sortedUnits.sort(@(a, b) b.rank <=> a.rank
          || b.isInSlotbar <=> a.isInSlotbar
          || a.unit.name <=> b.unit.name)
        local bestAvailableUnit = sortedUnits.findvalue(
          @(u) slotbarPresets.canAssignInSlot(u.unit, curPreset.groupsList, country))
        availableUnits[(bestAvailableUnit?.unit.name ?? unitsGroups[unit.name].defaultUnit.name)] <- unit.count
      }
    }

    return availableUnits
  }

  function getCountryNameBySide(side = -1)
  {
    if (side == -1)
      side = ::ww_get_player_side()

    local team = getTeamBySide(side)
    return team?.country
  }

  function getTeamNameBySide(side = -1)
  {
    if (side == -1)
      side = ::ww_get_player_side()

    let team = getTeamBySide(side)
    return team ? ::g_string.cutPrefix(team.name, "team") : ""
  }

  function getTeamBySide(side)
  {
    return ::u.search(teams,
                      (@(side) function (team) {
                        return team.side == side
                      })(side)
                     )
  }

  function getQueueId()
  {
    return ::ww_get_operation_id() + "_" + id
  }

  function getAvailableUnitTypes()
  {
    switch(opponentsType)
    {
      case "BUT_AIR":
        return [::ES_UNIT_TYPE_AIRCRAFT]

      case "BUT_GROUND":
        return [::ES_UNIT_TYPE_TANK]

      case "BUT_AIR_GROUND":
      case "BUT_ARTILLERY_AIR":
        return [::ES_UNIT_TYPE_AIRCRAFT, ::ES_UNIT_TYPE_TANK]

      case "BUT_INFANTRY":
      case "BUT_ARTILLERY_GROUND":
        return []
    }

    return []
  }

  function getSectorName()
  {
    if (!isValid())
      return ""

    let sectorIdx = ::ww_get_zone_idx_world(pos)
    return sectorIdx >= 0 ? ::ww_get_zone_name(sectorIdx) : ""
  }

  function getBattleActivateLeftTime()
  {
    if (!isStarted() || isConfirmed())
      return 0

    if (getMyAssignCountry())
      return 0

    if (battleActivateMillisec <= 0)
      return 0

    let waitTimeSec = ::g_world_war.getSetting("joinBattleDelayTimeSec", 0)
    let passedSec = ::get_charserver_time_sec() -
      time.millisecondsToSecondsInt(battleActivateMillisec)

    return waitTimeSec - passedSec
  }

  function getBattleDurationTime()
  {
    if (!battleStartMillisec)
      return 0

    return ::get_charserver_time_sec() - time.millisecondsToSecondsInt(battleStartMillisec)
  }

  function isTanksCompatible()
  {
    return ::isInArray(opponentsType, ["BUT_GROUND", "BUT_AIR_GROUND", "BUT_ARTILLERY_AIR"])
  }

  function isAutoBattle()
  {
    if (!isStillInOperation())
      return false

    if (status == ::EBS_ACTIVE_AUTO ||
        status == ::EBS_ACTIVE_FAKE)
      return true

    switch(opponentsType)
    {
      case "BUT_INFANTRY":
      case "BUT_ARTILLERY_GROUND":
        return true
    }

    return false
  }

  function getTotalPlayersInfo(side)
  {
    if (!::has_feature("worldWarMaster") && !getMyAssignCountry())
      return totalPlayersNumber

    local friendlySideNumber = 0
    local enemySideNumber = 0
    if (teams)
      foreach(team in teams)
        if (team.side == side)
          friendlySideNumber += team.players
        else
          enemySideNumber += team.players

    return friendlySideNumber + " " + ::loc("country/VS") + " " + enemySideNumber
  }

  function getTotalPlayersInQueueInfo(side)
  {
    let queue = wwQueuesData.getData()?[id]
    if (!queue)
      return 0

    let friendlySideNumber = getPlayersInQueueBySide(queue, side)
    let enemySideNumber = getPlayersInQueueBySide(queue, ::g_world_war.getOppositeSide(side))

    if (!::has_feature("worldWarMaster") && !getMyAssignCountry())
      return friendlySideNumber + enemySideNumber

    return friendlySideNumber + " " + ::loc("country/VS") + " " + enemySideNumber
  }

  function getExcessPlayersSide(side, joinPlayersCount)
  {
    if (!isConfirmed())
      return ::SIDE_NONE

    local side1Players = getTeamBySide(::SIDE_1)?.players ?? 0
    local side2Players = getTeamBySide(::SIDE_2)?.players ?? 0
    side1Players += (side == ::SIDE_1) ? joinPlayersCount : 0
    side2Players += (side == ::SIDE_2) ? joinPlayersCount : 0

    if (::abs(side1Players - side2Players) <= getMaxPlayersDisbalance())
      return ::SIDE_NONE

    return side1Players > side2Players ? ::SIDE_1 : ::SIDE_2
  }

  function getPlayersInQueueBySide(queue, side)
  {
    let team = getTeamBySide(side)
    if (!team)
      return 0

    return getPlayersInQueueByTeamName(queue, team.name)
  }

  function getPlayersInQueueByTeamName(queue, teamName)
  {
    let teamData = queue?[teamName]
    if (!teamData)
      return 0

    local count = teamData?.playersOther ?? 0
    let clanPlayers = teamData?.playersInClans ?? []
    foreach(clanPlayer in clanPlayers)
      count += clanPlayer?.count ?? 0

    return count
  }

  function getMaxPlayersDisbalance()
  {
    return ::g_world_war.getSetting("maxBattlePlayersDisbalance",
      WW_MAX_PLAYERS_DISBALANCE_DEFAULT)
  }

  function isLockedByExcessPlayers(side, teamName)
  {
    if (getMyAssignCountry())
      return false

    let joinPlayersCount = ::g_squad_manager.getOnlineMembersCount()
    let excessPlayersSide = getExcessPlayersSide(side, joinPlayersCount)
    if (excessPlayersSide != ::SIDE_NONE && excessPlayersSide == side)
      return true

    return isQueueExcessPlayersInTeam(teamName, joinPlayersCount)
  }

  function isQueueExcessPlayersInTeam(teamName, joinPlayersCount)
  {
    let queue = wwQueuesData.getData()?[id]
    if (!queue)
      return false

    local teamACount = getPlayersInQueueByTeamName(queue, "teamA")
    local teamBCount = getPlayersInQueueByTeamName(queue, "teamB")
    teamACount += (teamName == "teamA") ? joinPlayersCount : 0
    teamBCount += (teamName == "teamB") ? joinPlayersCount : 0

    if (::abs(teamACount - teamBCount) <= getMaxPlayersDisbalance())
      return false

    return (teamACount > teamBCount ? "teamA" : "teamB") == teamName
  }

  function getSide(country = null)
  {
    return ::ww_get_player_side()
  }

  function getMyAssignCountry()
  {
    let operation = getOperationById(::ww_get_operation_id())
    return operation ? operation.getMyAssignCountry() : null
  }

  function hasEnoughSpaceInTeam(team)
  {
    if (::g_squad_manager.isInSquad())
      return team.players + ::g_squad_manager.getOnlineMembersCount() <= team.maxPlayers

    return team.players < team.maxPlayers
  }

  function hasUnitsToFight(country, team, side)
  {
    let requiredUnits = getUnitsRequiredForJoin(team, side)

    if (!requiredUnits)
      return true

    foreach(unitName, value in requiredUnits)
    {
      let unit = ::all_units?[unitName]
      if (!unit)
        continue

      if (unit.canAssignToCrew(country))
        return true
    }

    return false
  }

  function hasQueueInfo()
  {
    return !!wwQueuesData.getData()?[id]
  }

  function isEqual(battle)
  {
    if (battle.id != id || battle.status != status)
      return false

    foreach (teamName, teamData in battle.teams)
    {
      let curTeamData = teams?[teamName]
      if (!curTeamData)
        return false

      if (teamData.players != curTeamData.players ||
          teamData.unitsRemain.len() != curTeamData.unitsRemain.len())
        return false

      foreach(idx, unitsData in teamData.unitsRemain)
      {
        let curUnitsData = curTeamData.unitsRemain[idx]
        if (unitsData.name != curUnitsData.name ||
            unitsData.count != curUnitsData.count)
          return false
      }
    }

    return true
  }

  function setFromBattle(battle)
  {
    foreach(key, value in battle)
      if (!u.isFunction(value)
        && (key in this)
        && !u.isFunction(this[key])
      )
        this[key] = value
    return this
  }

  function setStatus(newStatus)
  {
    status = newStatus
  }

  function updateSortParams()
  {
    sortTimeFactor = getBattleDurationTime() / WW_BATTLES_SORT_TIME_STEP
    sortFullnessFactor = totalPlayersNumber / ::floor(maxPlayersNumber || 1)
  }

  function getGroupId()
  {
    let playerSide = getSide(::get_profile_country_sq())
    let playerTeam = getTeamBySide(playerSide)
    if (!playerTeam)
      return ""

    let unitTypeArray = playerTeam.unitTypes.map(@(u) u.tostring())
    unitTypeArray.append("vs")

    foreach(team in teams)
      if (team.side != playerSide)
        unitTypeArray.extend(team.unitTypes.map(@(u) u.tostring()))
    return ::g_string.implode(unitTypeArray)
  }

  function getTimeStartAutoBattle()
  {
    let hasOperationTimeOnCreation = operationTimeOnCreationMillisec > 0
    let creationTime = hasOperationTimeOnCreation ? operationTimeOnCreationMillisec : creationTimeMillisec
    if (creationTime <= 0)
      return 0

    let maxBattleWaitTimeSec = time.minutesToSeconds(
      ::g_world_war.getWWConfigurableValue("maxBattleWaitTimeMin", MAX_BATTLE_WAIT_TIME_MIN_DEFAULT))
    if (maxBattleWaitTimeSec <= 0)
      return 0

    return (maxBattleWaitTimeSec / (hasOperationTimeOnCreation ? ::ww_get_speedup_factor() : 1)).tointeger()
      - ((hasOperationTimeOnCreation ? ::g_world_war.getOperationTimeSec() : ::get_charserver_time_sec())
        - time.millisecondsToSecondsInt(creationTime))
  }

  function isBattleByUnitsGroup()
  {
    return unitsGroups != null
  }
}

from "%scripts/dagui_natives.nut" import ww_get_zone_idx_world, ww_side_name_to_val, ww_battle_status_name_to_val
from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/squads/squadsConsts.nut" import *
from "%scripts/mainConsts.nut" import COLOR_TAG

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { abs, floor } = require("math")
let { Point2 } = require("dagor.math")
let time = require("%scripts/time.nut")
let systemMsg = require("%scripts/utils/systemMsg.nut")
let wwQueuesData = require("%scripts/worldWar/operations/model/wwQueuesData.nut")
let wwActionsWithUnitsList = require("%scripts/worldWar/inOperation/wwActionsWithUnitsList.nut")
let wwOperationUnitsGroups = require("%scripts/worldWar/inOperation/wwOperationUnitsGroups.nut")
let { getCurPreset, getBestAvailableUnitByGroup,
  getWarningTextTbl } = require("%scripts/slotbar/slotbarPresetsByVehiclesGroups.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { getMissionLocName } = require("%scripts/missions/missionsUtilsModule.nut")
let { getMyStateData } = require("%scripts/user/userUtils.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let DataBlock  = require("DataBlock")
let { cutPrefix } = require("%sqstd/string.nut")
let { get_meta_mission_info_by_name } = require("guiMission")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_charserver_time_sec } = require("chard")
let { wwGetOperationId, wwGetPlayerSide, wwGetZoneName, wwGetSpeedupFactor } = require("worldwar")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { WwBattleJoinProcess } = require("%scripts/worldWar/worldWarBattleJoinProcess.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { WwUnit } = require("%scripts/worldWar/inOperation/model/wwUnit.nut")
let { g_ww_unit_type } = require("%scripts/worldWar/model/wwUnitType.nut")
let { getCrewsListByCountry } = require("%scripts/slotbar/slotbarState.nut")

const WW_BATTLES_SORT_TIME_STEP = 120
const WW_MAX_PLAYERS_DISBALANCE_DEFAULT = 3
const MAX_BATTLE_WAIT_TIME_MIN_DEFAULT = 30

local WwBattleView //forward declaration

let WwBattle = class {
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

  constructor(blk = DataBlock(), params = null) {
    this.id = blk?.id ?? blk.getBlockName() ?? ""
    this.status = blk?.status ? ww_battle_status_name_to_val(blk.status) : 0
    this.pos = blk?.pos ? Point2(blk.pos.x, blk.pos.y) : Point2()
    this.maxPlayersPerArmy = blk?.maxPlayersPerArmy ?? 0
    this.minPlayersPerArmy = blk?.minTeamSize ?? 0
    this.battleActivateMillisec = (blk?.activationTime ?? 0).tointeger()
    this.battleStartMillisec = (blk?.battleStartTimestamp ?? 0).tointeger()
    this.ordinalNumber = blk?.ordinalNumber ?? 0
    this.opponentsType = blk?.opponentsType ?? -1
    this.updateAppliedOnHost = blk?.updateAppliedOnHost ?? -1
    this.missionName = blk?.desc.missionName ?? ""
    this.sessionId = blk?.desc.sessionId ?? ""
    this.missionInfo = get_meta_mission_info_by_name(this.missionName)
    this.creationTimeMillisec = blk?.creationTime ?? 0
    this.operationTimeOnCreationMillisec = blk?.operationTimeOnCreation ?? 0
    this.unitsGroups = wwOperationUnitsGroups.getUnitsGroups()

    this.createLocalizeConfig(blk?.desc)

    this.updateParams(blk, params)
    this.updateTeamsInfo(blk)
    this.applyBattleUpdates(blk)
    this.updateSortParams()
  }

  function updateParams(_blk, _params) {}

  function applyBattleUpdates(blk) {
    let updatesBlk = blk.getBlockByName("battleUpdates")
    if (!updatesBlk)
      return

    for (local i = 0; i < updatesBlk.blockCount(); i++) {
      let updateBlk = updatesBlk.getBlock(i)
      if ((updateBlk?.updateId ?? -1) <= this.updateAppliedOnHost)
        continue

      let teamsBlk = updateBlk.getBlockByName("teams")
      for (local j = 0; j < teamsBlk.blockCount(); j++) {
        let teamBlk = teamsBlk.getBlock(j)
        if (teamBlk == null)
          continue

        let teamName = teamBlk.getBlockName() || ""
        if (teamName.len() == 0)
          continue

        let unitsAddedBlock = teamBlk.getBlockByName("unitsAdded")
        let team = this.teams[teamName]
        let newUnits = []

        for (local k = 0; k < unitsAddedBlock.blockCount(); k++) {
          let unitBlock = unitsAddedBlock.getBlock(k)
          if (unitBlock == null)
            continue

          let unitName = unitBlock.getBlockName() || ""
          if (unitName.len() == 0)
            continue

          local hasUnit = false
          foreach (_idx, wwUnit in team.unitsRemain)
            if (wwUnit.name == unitName) {
              hasUnit = true
              wwUnit.count += unitBlock.count
              break
            }

          if (!hasUnit)
            newUnits.append(unitBlock)
        }

        foreach (_idx, unitBlk in newUnits)
          team.unitsRemain.append(WwUnit(unitBlk))
      }
    }
  }

  function isValid() {
    return this.id.len() > 0
  }

  function isWaiting() {
    return this.status == EBS_WAITING ||
           this.status == EBS_STALE
  }

  function isStale() {
    return this.status == EBS_STALE
  }

  function isActive() {
    return this.status == EBS_ACTIVE_STARTING ||
           this.status == EBS_ACTIVE_MATCHING ||
           this.status == EBS_ACTIVE_CONFIRMED
  }

  function isStarting() {
    return this.status == EBS_ACTIVE_STARTING ||
           this.status == EBS_ACTIVE_MATCHING
  }

  function isStarted() {
    return this.status == EBS_ACTIVE_MATCHING ||
           this.status == EBS_ACTIVE_CONFIRMED
  }

  function isConfirmed() {
    return this.status == EBS_ACTIVE_CONFIRMED
  }

  function isFinished() {
    return this.status == EBS_FINISHED ||
           this.status == EBS_FINISHED_APPLIED
  }

  function isFullSessionByTeam(side = null) {
    side = side || wwGetPlayerSide()
    local team = this.getTeamBySide(side)
    return !team || team.players == team.maxPlayers
  }

  function getLocName(side = null) {
    side = side ?? this.getSide(profileCountrySq.value)
    let teamName = this.getTeamNameBySide(side)
    if (this.localizeConfig == null)
      return this.id

    let locId = ((this.localizeConfig?[$"locNameTeam{teamName}"].len() ?? 0) > 0)
      ? $"locNameTeam{teamName}"
      : "locName"
    return getMissionLocName(this.localizeConfig, locId)
  }

  function getOrdinalNumber() {
    return this.ordinalNumber
  }

  function getLocDesc() {
    return this.localizeConfig ? getMissionLocName(this.localizeConfig, "locDesc") : this.id
  }

  function getMissionName() {
    return !u.isEmpty(this.missionName) ? this.missionName : ""
  }

  function getView(customPlayerSide = null) {
    return WwBattleView(this, customPlayerSide)
  }

  function getSessionId() {
    return this.sessionId
  }

  function createLocalizeConfig(descBlk) {
    this.localizeConfig = {
      locName = descBlk?.locName ?? ""
      locNameTeamA = descBlk?.locNameTeamA ?? ""
      locNameTeamB = descBlk?.locNameTeamB ?? ""
      locDesc = descBlk?.locDesc ?? ""
      locDescTeamA = descBlk?.locDescTeamA ?? ""
      locDescTeamB = descBlk?.locDescTeamB ?? ""
    }
  }

  function updateTeamsInfo(blk) {
    this.teams = {}
    this.totalPlayersNumber = 0
    this.maxPlayersNumber = 0
    this.unitTypeMask = 0

    let teamsBlk = blk.getBlockByName("teams")
    let descBlk = blk.getBlockByName("desc")
    let waitingTeamsBlk = descBlk ? descBlk.getBlockByName("teamsInfo") : null
    if (!teamsBlk || (this.isWaiting() && !waitingTeamsBlk))
      return

    for (local i = 0; i < teamsBlk.blockCount(); ++i) {
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
      if (armyNamesBlk) {
        for (local j = 0; j < armyNamesBlk.paramCount(); ++j) {
          let armyName = armyNamesBlk.getParamValue(j) || ""
          if (armyName.len() == 0)
            continue

          let army = ::g_world_war.getArmyByName(armyName)
          if (!army) {
            script_net_assert_once("WW can't find army", $"ww: can't find army {armyName}")
            continue
          }

          if (!(army.owner.country in countries))
            countries[army.owner.country] <- []
          countries[army.owner.country].append(army)

          if (firstArmyCountry.len() == 0)
            firstArmyCountry = army.owner.country

          teamArmyNames.append(armyName)
          u.appendOnce(army.unitType, teamUnitTypes)
          let wwUnitType = g_ww_unit_type.getUnitTypeByCode(army.unitType)
          if (wwUnitType.canBeControlledByPlayer)
            this.unitTypeMask = this.unitTypeMask | unitTypes.getByEsUnitType(wwUnitType.esUnitCode).bit
        }
      }

      let teamUnitsRemain = []
      if (!this.isWaiting()) {
        let unitsRemainBlk = teamBlk.getBlockByName("unitsRemain")
        let aiUnitsBlk = teamBlk.getBlockByName("aiUnits")
        teamUnitsRemain.extend(wwActionsWithUnitsList.loadUnitsFromBlk(unitsRemainBlk, aiUnitsBlk))
        teamUnitsRemain.extend(wwActionsWithUnitsList.getFakeUnitsArray(teamBlk))
      }

      let teamInfo = { name = teamName
                        players = numPlayers
                        maxPlayers = teamMaxPlayers
                        minPlayers = this.minPlayersPerArmy
                        side = ww_side_name_to_val(teamSideName)
                        country = firstArmyCountry
                        countries = countries
                        armyNames = teamArmyNames
                        unitsRemain = teamUnitsRemain
                        unitTypes = teamUnitTypes }
      if (teamBlk?.autoBattleWinChancePercent != null)
        teamInfo.autoBattleWinChancePercent <- teamBlk.autoBattleWinChancePercent
      this.teams[teamName] <- teamInfo
      this.totalPlayersNumber += numPlayers
      this.maxPlayersNumber += teamMaxPlayers
    }
  }

  function getCantJoinReasonData(side, needCheckSquad = true) {
    let res = {
      code = WW_BATTLE_CANT_JOIN_REASON.CAN_JOIN
      canJoin = false
      reasonText = ""
      shortReasonText = ""
      fullReasonText = ""
    }

    if (!::g_world_war.canJoinWorldwarBattle()) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_WW_ACCESS
      res.reasonText = loc("worldWar/noAccess")
      res.fullReasonText = ::g_world_war.getPlayWorldwarConditionText()
      return res
    }

    if (this.isFinished()) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
      res.reasonText = loc("worldwar/battle_finished_need_refresh")
      return res
    }

    if (!this.isValid()) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
      res.reasonText = loc("worldWar/battleNotSelected")
      return res
    }

    if (!this.isActive()) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
      res.reasonText = loc(this.isStillInOperation() ? "worldwar/battleNotActive" : "worldwar/battle_finished")
      return res
    }

    if (wwGetPlayerSide() != SIDE_NONE && wwGetPlayerSide() != side) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.WRONG_SIDE
      res.reasonText = loc("worldWar/cant_fight_for_enemy_side")
      return res
    }

    if (side == SIDE_NONE) {
      script_net_assert_once("WW check battle without player side", "ww: check battle without player side")
      res.code = WW_BATTLE_CANT_JOIN_REASON.UNKNOWN_SIDE
      res.reasonText = loc("msgbox/internal_error_header")
      return res
    }

    if (this.getBattleActivateLeftTime() > 0) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.EXCESS_PLAYERS
      res.reasonText = loc("worldWar/battle_activate_countdown")
      return res
    }

    let team = this.getTeamBySide(side)
    if (!team) {
      script_net_assert_once("WW can't find team in battle", "ww: can't find team in battle")
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_TEAM
      res.reasonText = loc("msgbox/internal_error_header")
      return res
    }

    if (!team.country) {
      script_net_assert_once("WW can't get country",
        $"ww: can't get country for team {team.name}")
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_COUNTRY_IN_TEAM
      res.reasonText = loc("msgbox/internal_error_header")
      return res
    }

    if (g_squad_manager.isSquadLeader()) {
      let notAllowedInWorldWarMembers = g_squad_manager.getMembersNotAllowedInWorldWar()
      if (notAllowedInWorldWarMembers.len() > 0) {
        let tArr = notAllowedInWorldWarMembers.map(@(m) colorize("warningTextColor", m.name))
        let text = ",".join(tArr, true)
        res.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_MEMBERS_NO_WW_ACCESS
        res.reasonText = loc("worldwar/squad/notAllowedMembers")
        res.fullReasonText = "".concat(loc("worldwar/squad/notAllowedMembers"), loc("ui/colon"), "\n", text)
        return res
      }
    }

    if ((g_squad_manager.isSquadLeader() || !g_squad_manager.isInSquad())
      && this.isLockedByExcessPlayers(side, team.name)) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.EXCESS_PLAYERS
      res.reasonText = loc("worldWar/battle_is_unbalanced")
      return res
    }

    let maxPlayersInTeam = team.maxPlayers
    let queue = wwQueuesData.getData()?[this.id]
    let isInQueueAmount = this.getPlayersInQueueByTeamName(queue, team.name)
    if (isInQueueAmount >= maxPlayersInTeam) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.QUEUE_FULL
      res.reasonText = loc("worldwar/queue_full")
      return res
    }

    let countryName = this.getCountryNameBySide(side)
    if (!countryName) {
      script_net_assert_once("WW can't get country",
        $"ww: can't get country for team {team.name} from {team.country}")
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_COUNTRY_BY_SIDE
      res.reasonText = loc("msgbox/internal_error_header")
      return res
    }

    let teamName = this.getTeamNameBySide(side)
    if (!teamName) {
      script_net_assert_once("WW can't get team",
        $"ww: can't get team for team {team.name} for battle {this.id}")
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_TEAM_NAME_BY_SIDE
      res.reasonText = loc("msgbox/internal_error_header")
      return res
    }

    if (team.players >= maxPlayersInTeam) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.TEAM_FULL
      res.reasonText = loc("worldwar/army_full")
      return res
    }

    if (!this.hasAvailableUnits(team)) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.NO_AVAILABLE_UNITS
      res.reasonText = loc("worldwar/airs_not_available")
      return res
    }

    let remainUnits = this.getUnitsRequiredForJoin(team, side)
    let myCheckingData = ::g_squad_utils.getMemberAvailableUnitsCheckingData(
      getMyStateData(), remainUnits, team.country)
    if (myCheckingData.joinStatus != memberStatus.READY) {
      res.code = WW_BATTLE_CANT_JOIN_REASON.UNITS_NOT_ENOUGH_AVAILABLE
      res.reasonText = loc(::g_squad_utils.getMemberStatusLocId(myCheckingData.joinStatus))
      return res
    }

    if (needCheckSquad && g_squad_manager.isInSquad()) {
      this.updateCantJoinReasonDataBySquad(team, side, isInQueueAmount, res)
      if (!u.isEmpty(res.reasonText))
        return res
    }

    res.canJoin = true

    return res
  }

  function isPlayerTeamFull() {
    let team = this.getTeamBySide(wwGetPlayerSide())
    if (team)
      return team.players >= team.maxPlayers
    return false
  }

  function hasAvailableUnits(team = null) {
    if (!team) {
      let side = this.getSide(profileCountrySq.value)
      if (side == SIDE_NONE)
        return false

      team = this.getTeamBySide(side)
    }
    return team ? this.getTeamRemainUnits(team).len() > 0 : false
  }

  function isStillInOperation() {
    let battles = ::g_world_war.getBattles(
        (@(id) function(checkedBattle) { //-ident-hides-ident
          return checkedBattle.id == id
        })(this.id)
      )
    return battles.len() > 0
  }

  function updateCantJoinReasonDataBySquad(team, side, isInQueueAmount, reasonData) {
    if (!g_squad_manager.isSquadLeader()) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_LEADER
      reasonData.reasonText = loc("worldwar/squad/onlyLeaderCanJoinBattle")
      return reasonData
    }

    if (!::g_squad_utils.canJoinByMySquad(null, team.country)) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_WRONG_SIDE
      reasonData.reasonText = loc("worldWar/squad/membersHasDifferentSide")
      return reasonData
    }

    let maxPlayersInTeam = team.maxPlayers
    if (team.players + g_squad_manager.getOnlineMembersCount() > maxPlayersInTeam) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_TEAM_FULL
      reasonData.reasonText = loc("worldwar/squad/army_full")
      return reasonData
    }

    if (isInQueueAmount + g_squad_manager.getOnlineMembersCount() > maxPlayersInTeam) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_QUEUE_FULL
      reasonData.reasonText = loc("worldwar/squad/queue_full")
      return reasonData
    }

    if (!g_squad_manager.readyCheck(false)) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_ALL_READY
      reasonData.reasonText = loc("squad/not_all_in_operation")
      return reasonData
    }

    if (hasFeature("WorldWarSquadInfo") && !g_squad_manager.crewsReadyCheck()) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_NOT_ALL_CREWS_READY
      reasonData.reasonText = loc("squad/not_all_crews_ready")
      return reasonData
    }

    let remainUnits = this.getUnitsRequiredForJoin(team, side)
    let membersCheckingDatas = ::g_squad_utils.getMembersAvailableUnitsCheckingData(remainUnits, team.country)

    let langConfig = []
    local shortMessage = ""
    foreach (_idx, data in membersCheckingDatas) {
      if (data.joinStatus != memberStatus.READY && data.memberData.online == true) {
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
        data.unitsCountUnderLimit <- this.getAvailableUnitsCountUnderLimit(data.unbrokenAvailableUnits,
                                                                      remainUnits, g_squad_manager.getSquadSize())
    }

    if (langConfig.len()) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_MEMBER_ERROR
      reasonData.reasonText = systemMsg.configToLang(langConfig, null, "\n") || ""
      reasonData.shortReasonText = shortMessage
      return reasonData
    }

    if (!this.checkAvailableSquadUnitsAdequacy(membersCheckingDatas, remainUnits)) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_UNITS_NOT_ENOUGH_AVAILABLE
      reasonData.reasonText = loc("worldwar/squad/insufficiently_available_units")
      return reasonData
    }

    if (!g_squad_manager.readyCheck(true)) {
      reasonData.code = WW_BATTLE_CANT_JOIN_REASON.SQUAD_HAVE_UNACCEPTED_INVITES
      reasonData.reasonText = loc("squad/revoke_non_accept_invites")
      reasonData.shortReasonText = loc("squad/has_non_accept_invites")
      return reasonData
    }

    return reasonData
  }

  function tryToJoin(side) {
    let cantJoinReasonData = this.getCantJoinReasonData(side, true)
    if (!cantJoinReasonData.canJoin) {
      showInfoMsgBox(cantJoinReasonData.reasonText)
      return
    }

    let joinCb = Callback(@() this.join(side), this)
    let warningReasonData = this.getWarningReasonData(side)
    if (warningReasonData.needMsgBox &&
        !loadLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false)) {
      loadHandler(gui_handlers.SkipableMsgBox,
        {
          parentHandler = this
          message = u.isEmpty(warningReasonData.fullWarningText)
            ? warningReasonData.warningText
            : warningReasonData.fullWarningText
          onStartPressed = joinCb
          skipFunc = @(value) saveLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, value)
        })
      return
    }

    joinCb()
  }

  function join(side) {
    let opId = wwGetOperationId()
    let countryName = this.getCountryNameBySide(side)
    let teamName = this.getTeamNameBySide(side)

    log("ww: join ww battle op:", opId.tostring(), ", battle:", this.id,
      ", country:", countryName, ", team:", teamName)

    WwBattleJoinProcess(this, side)
    wwEvent("JoinBattle", { battleId = this.id })
  }

  function checkAvailableSquadUnitsAdequacy(membersCheckingDatas, remainUnits) {
    membersCheckingDatas.sort(function(a, b) {
                                if (a.unitsCountUnderLimit != b.unitsCountUnderLimit)
                                  return a.unitsCountUnderLimit > b.unitsCountUnderLimit ? -1 : 1
                                return 0
                              })

    for (local i = membersCheckingDatas.len() - 1; i >= 0; i--)
      if (membersCheckingDatas[i].unitsCountUnderLimit >= membersCheckingDatas.len())
        membersCheckingDatas.remove(i)

    let unbrokenAvailableUnits = []
    foreach (_idx, data in membersCheckingDatas)
      unbrokenAvailableUnits.append(data.unbrokenAvailableUnits)

    return ::g_squad_utils.checkAvailableUnits(unbrokenAvailableUnits, remainUnits)
  }

  function getAvailableUnitsCountUnderLimit(availableUnits, remainUnits, limit) {
    local unitsSummary = 0
    foreach (_idx, name in availableUnits) {
      unitsSummary += remainUnits[name]
      if (unitsSummary >= limit)
        break
    }

    return unitsSummary
  }

  function isArmyJoined(armyName) {
    foreach (teamData in this.teams)
      if (isInArray(armyName, teamData.armyNames))
        return true
    return false
  }

  function getWarningReasonData(side) {
    let res = {
        needShow = false
        needMsgBox = false
        warningText = ""
        fullWarningText = ""
        availableUnits = []
        country = ""
      }

    if (!this.isValid() || this.isFinished())
      return res

    let team = this.getTeamBySide(side)
    let isCrewByUnitsGroup = this.isBattleByUnitsGroup()
    let countryCrews = isCrewByUnitsGroup
      ? getCurPreset().countryPresets?[team?.country ?? ""].units
      : getCrewsListByCountry(team.country)

     if (countryCrews == null)
       return res

    let availableUnits = this.getTeamRemainUnits(team, isCrewByUnitsGroup)
    res.availableUnits = availableUnits
    res.country = team.country

    return res.__update(getWarningTextTbl(availableUnits, countryCrews, isCrewByUnitsGroup))
  }

  function getUnitsRequiredForJoin(team, side) {
    let unitAvailability = ::g_world_war.getSetting("checkUnitAvailability",
      WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)

    if (unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.BATTLE_UNITS)
      return this.getTeamRemainUnits(team)
    else if (unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.OPERATION_UNITS)
      return ::g_operations.getAllOperationUnitsBySide(side)
    else if (unitAvailability == WW_BATTLE_UNITS_REQUIREMENTS.NO_MATCHING_UNITS)
      return {}

    return null
  }

  function getTeamRemainUnits(team, onlyBestAvailableFromGroup = false) {
    let availableUnits = {}
    let curPreset = getCurPreset()
    let country = team?.country ?? ""
    let curSlotbarUnits = curPreset?.countryPresets[country].units ?? []
    foreach (unit in team.unitsRemain) {
      if (unit.count <= 0 || unit.isControlledByAI())
        continue

      let groupUnits = this.unitsGroups?[unit.name].units
      if (groupUnits == null)
        availableUnits[unit.name] <- unit.count
      else {
        if (!onlyBestAvailableFromGroup) {
          availableUnits.__update(groupUnits.map(@(_u) unit.count))
          continue
        }

        let bestAvailableUnit = getBestAvailableUnitByGroup(
          curSlotbarUnits, groupUnits, curPreset.groupsList, country)
        availableUnits[(bestAvailableUnit?.unit.name
          ?? this.unitsGroups[unit.name].defaultUnit.name)] <- unit.count
      }
    }

    return availableUnits
  }

  function getCountryNameBySide(side = -1) {
    if (side == -1)
      side = wwGetPlayerSide()

    local team = this.getTeamBySide(side)
    return team?.country
  }

  function getTeamNameBySide(side = -1) {
    if (side == -1)
      side = wwGetPlayerSide()

    let team = this.getTeamBySide(side)
    return team ? cutPrefix(team.name, "team") : ""
  }

  function getTeamBySide(side) {
    return u.search(this.teams,
                       function (team) {
                        return team.side == side
                      }
                     )
  }

  function getQueueId() {
    return $"{wwGetOperationId()}_{this.id}"
  }

  function getAvailableUnitTypes() {
    let opType = this.opponentsType
    if ("BUT_AIR" == opType)
      return [ES_UNIT_TYPE_AIRCRAFT]

    if ("BUT_GROUND" == opType)
      return [ES_UNIT_TYPE_TANK]

    if ("BUT_AIR_GROUND"  == opType || "BUT_ARTILLERY_AIR" == opType)
      return [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_TANK]

    //"BUT_INFANTRY" || "BUT_ARTILLERY_GROUND"
    return []
  }

  function getSectorName() {
    if (!this.isValid())
      return ""

    let sectorIdx = ww_get_zone_idx_world(this.pos)
    return sectorIdx >= 0 ? wwGetZoneName(sectorIdx) : ""
  }

  function getBattleActivateLeftTime() {
    if (!this.isStarted() || this.isConfirmed())
      return 0

    if (this.getMyAssignCountry())
      return 0

    if (this.battleActivateMillisec <= 0)
      return 0

    let waitTimeSec = ::g_world_war.getSetting("joinBattleDelayTimeSec", 0)
    let passedSec = get_charserver_time_sec() -
      time.millisecondsToSecondsInt(this.battleActivateMillisec)

    return waitTimeSec - passedSec
  }

  function getBattleDurationTime() {
    if (!this.battleStartMillisec)
      return 0

    return get_charserver_time_sec() - time.millisecondsToSecondsInt(this.battleStartMillisec)
  }

  function isTanksCompatible() {
    return isInArray(this.opponentsType, ["BUT_GROUND", "BUT_AIR_GROUND", "BUT_ARTILLERY_AIR"])
  }

  function isAutoBattle() {
    if (!this.isStillInOperation())
      return false

    if (this.status == EBS_ACTIVE_AUTO ||
        this.status == EBS_ACTIVE_FAKE)
      return true

    if (this.opponentsType == "BUT_INFANTRY" || this.opponentsType == "BUT_ARTILLERY_GROUND") {
      return true
    }

    return false
  }

  function getTotalPlayersInfo(side) {
    if (!hasFeature("worldWarMaster") && !this.getMyAssignCountry())
      return this.totalPlayersNumber

    local friendlySideNumber = 0
    local enemySideNumber = 0
    if (this.teams)
      foreach (team in this.teams)
        if (team.side == side)
          friendlySideNumber += team.players
        else
          enemySideNumber += team.players

    return " ".concat(friendlySideNumber, loc("country/VS"), enemySideNumber)
  }

  function getTotalPlayersInQueueInfo(side) {
    let queue = wwQueuesData.getData()?[this.id]
    if (!queue)
      return "0"

    let friendlySideNumber = this.getPlayersInQueueBySide(queue, side)
    let enemySideNumber = this.getPlayersInQueueBySide(queue, ::g_world_war.getOppositeSide(side))

    if (!hasFeature("worldWarMaster") && !this.getMyAssignCountry())
      return $"{friendlySideNumber}{enemySideNumber}"

    return " ".concat(friendlySideNumber, loc("country/VS"), enemySideNumber)
  }

  function getExcessPlayersSide(side, joinPlayersCount) {
    if (!this.isConfirmed())
      return SIDE_NONE

    local side1Players = this.getTeamBySide(SIDE_1)?.players ?? 0
    local side2Players = this.getTeamBySide(SIDE_2)?.players ?? 0
    side1Players += (side == SIDE_1) ? joinPlayersCount : 0
    side2Players += (side == SIDE_2) ? joinPlayersCount : 0

    if (abs(side1Players - side2Players) <= this.getMaxPlayersDisbalance())
      return SIDE_NONE

    return side1Players > side2Players ? SIDE_1 : SIDE_2
  }

  function getPlayersInQueueBySide(queue, side) {
    let team = this.getTeamBySide(side)
    if (!team)
      return 0

    return this.getPlayersInQueueByTeamName(queue, team.name)
  }

  function getPlayersInQueueByTeamName(queue, teamName) {
    let teamData = queue?[teamName]
    if (!teamData)
      return 0

    local count = teamData?.playersOther ?? 0
    let clanPlayers = teamData?.playersInClans ?? []
    foreach (clanPlayer in clanPlayers)
      count += clanPlayer?.count ?? 0

    return count
  }

  function getMaxPlayersDisbalance() {
    return ::g_world_war.getSetting("maxBattlePlayersDisbalance",
      WW_MAX_PLAYERS_DISBALANCE_DEFAULT)
  }

  function isLockedByExcessPlayers(side, teamName) {
    if (this.getMyAssignCountry())
      return false

    let joinPlayersCount = g_squad_manager.getOnlineMembersCount()
    let excessPlayersSide = this.getExcessPlayersSide(side, joinPlayersCount)
    if (excessPlayersSide != SIDE_NONE && excessPlayersSide == side)
      return true

    return this.isQueueExcessPlayersInTeam(teamName, joinPlayersCount)
  }

  function isQueueExcessPlayersInTeam(teamName, joinPlayersCount) {
    let queue = wwQueuesData.getData()?[this.id]
    if (!queue)
      return false

    local teamACount = this.getPlayersInQueueByTeamName(queue, "teamA")
    local teamBCount = this.getPlayersInQueueByTeamName(queue, "teamB")
    teamACount += (teamName == "teamA") ? joinPlayersCount : 0
    teamBCount += (teamName == "teamB") ? joinPlayersCount : 0

    if (abs(teamACount - teamBCount) <= this.getMaxPlayersDisbalance())
      return false

    return (teamACount > teamBCount ? "teamA" : "teamB") == teamName
  }

  function getSide(_country = null) {
    return wwGetPlayerSide()
  }

  function getMyAssignCountry() {
    let operation = getOperationById(wwGetOperationId())
    return operation ? operation.getMyAssignCountry() : null
  }

  function hasEnoughSpaceInTeam(team) {
    if (g_squad_manager.isInSquad())
      return team.players + g_squad_manager.getOnlineMembersCount() <= team.maxPlayers

    return team.players < team.maxPlayers
  }

  function hasUnitsToFight(country, team, side) {
    let requiredUnits = this.getUnitsRequiredForJoin(team, side)

    if (!requiredUnits)
      return true

    foreach (unitName, _value in requiredUnits) {
      let unit = getAllUnits()?[unitName]
      if (!unit)
        continue

      if (unit.canAssignToCrew(country))
        return true
    }

    return false
  }

  function hasQueueInfo() {
    return !!wwQueuesData.getData()?[this.id]
  }

  function isEqual(battle) {
    if (battle.id != this.id || battle.status != this.status)
      return false

    foreach (teamName, teamData in battle.teams) {
      let curTeamData = this.teams?[teamName]
      if (!curTeamData)
        return false

      if (teamData.players != curTeamData.players ||
          teamData.unitsRemain.len() != curTeamData.unitsRemain.len())
        return false

      foreach (idx, unitsData in teamData.unitsRemain) {
        let curUnitsData = curTeamData.unitsRemain[idx]
        if (unitsData.name != curUnitsData.name ||
            unitsData.count != curUnitsData.count)
          return false
      }
    }

    return true
  }

  function setFromBattle(battle) {
    foreach (key, value in battle)
      if (!u.isFunction(value)
        && (key in this)
        && !u.isFunction(this[key])
      )
        this[key] = value
    return this
  }

  function setStatus(newStatus) {
    this.status = newStatus
  }

  function updateSortParams() {
    this.sortTimeFactor = this.getBattleDurationTime() / WW_BATTLES_SORT_TIME_STEP
    this.sortFullnessFactor = this.totalPlayersNumber / floor(this.maxPlayersNumber || 1)
  }

  function getGroupId() {
    let playerSide = this.getSide(profileCountrySq.value)
    let playerTeam = this.getTeamBySide(playerSide)
    if (!playerTeam)
      return ""

    let unitTypeArray = playerTeam.unitTypes.map(@(unitType) unitType.tostring())
    unitTypeArray.append("vs")

    foreach (team in this.teams)
      if (team.side != playerSide)
        unitTypeArray.extend(team.unitTypes.map(@(unitType) unitType.tostring()))
    return "".join(unitTypeArray, true)
  }

  function getTimeStartAutoBattle() {
    let hasOperationTimeOnCreation = this.operationTimeOnCreationMillisec > 0
    let creationTime = hasOperationTimeOnCreation ? this.operationTimeOnCreationMillisec : this.creationTimeMillisec
    if (creationTime <= 0)
      return 0

    let maxBattleWaitTimeSec = time.minutesToSeconds(
      ::g_world_war.getWWConfigurableValue("maxBattleWaitTimeMin", MAX_BATTLE_WAIT_TIME_MIN_DEFAULT))
    if (maxBattleWaitTimeSec <= 0)
      return 0

    return (maxBattleWaitTimeSec / (hasOperationTimeOnCreation ? wwGetSpeedupFactor() : 1)).tointeger()
      - ((hasOperationTimeOnCreation ? ::g_world_war.getOperationTimeSec() : get_charserver_time_sec())
        - time.millisecondsToSecondsInt(creationTime))
  }

  function isBattleByUnitsGroup() {
    return this.unitsGroups != null
  }
}


WwBattleView = class  {
  id = ""
  battle = null

  missionName = ""
  name = ""
  desc = ""
  maxPlayersPerArmy = -1

  teamBlock = null
  largeArmyGroupIconTeamBlock = null
  mediumArmyGroupIconTeamBlock = null

  showBattleStatus = false
  hideDesc = false

  sceneTplArmyViewsName = "%gui/worldWar/worldWarMapArmyItem.tpl"

  isControlHelpCentered = true
  controlHelpDesc = @() this.hasControlTooltip()
    ? loc("worldwar/battle_open_info") : this.getBattleStatusText()
  consoleButtonsIconName = @() showConsoleButtons.value && this.hasControlTooltip()
    ? WW_MAP_CONSPLE_SHORTCUTS.LMB_IMITATION : null
  controlHelpText = @() !showConsoleButtons.value && this.hasControlTooltip()
    ? loc("key/LMB") : null

  playerSide = null // need for show view for global battle

  constructor(v_battle = null, customPlayerSide = null) {
    this.battle = v_battle || WwBattle()
    this.playerSide = customPlayerSide ?? this.battle.getSide(profileCountrySq.value)
    this.missionName = this.battle.getMissionName()
    this.name = this.battle.isStarted() ? this.battle.getLocName(this.playerSide) : ""
    this.desc = this.battle.getLocDesc()
    this.maxPlayersPerArmy = this.battle.maxPlayersPerArmy
  }

  function getId() {
    return this.battle.id
  }

  function getMissionName() {
    return this.name
  }

  function getShortBattleName() {
    return loc("worldWar/shortBattleName", { number = this.battle.getOrdinalNumber() })
  }

  function getBattleName() {
    if (!this.battle.isValid())
      return ""

    return loc("worldWar/battleName", { number = this.battle.getOrdinalNumber() })
  }

  function getFullBattleName() {
    return loc("ui/comma").join([this.getBattleName(), this.battle.getLocName(this.playerSide)], true)
  }

  function defineTeamBlock(sides) {
    this.teamBlock = this.getTeamBlockByIconSize(sides, WW_ARMY_GROUP_ICON_SIZE.BASE)
  }

  getTeamsDataBySides = @(sides) this.getTeamBlockByIconSize(sides, WW_ARMY_GROUP_ICON_SIZE.BASE, true)

  function getTeamBlockByIconSize(sides, iconSize, isInBattlePanel = false, param = null) {
    if (iconSize == WW_ARMY_GROUP_ICON_SIZE.MEDIUM) {
      if (this.largeArmyGroupIconTeamBlock == null)
        this.largeArmyGroupIconTeamBlock = this.getTeamsData(sides, iconSize, isInBattlePanel, param)

      return this.largeArmyGroupIconTeamBlock
    }
    else if (iconSize == WW_ARMY_GROUP_ICON_SIZE.SMALL) {
      if (this.mediumArmyGroupIconTeamBlock == null)
        this.mediumArmyGroupIconTeamBlock = this.getTeamsData(sides, iconSize, isInBattlePanel, param)

      return this.mediumArmyGroupIconTeamBlock
    }
    else {
      if (this.teamBlock == null)
        this.teamBlock = this.getTeamsData(sides, WW_ARMY_GROUP_ICON_SIZE.BASE, isInBattlePanel, param)

      return this.teamBlock
    }
  }

  function getTeamsData(sides, iconSize, isInBattlePanel, param) {
    let teams = []
    local maxSideArmiesNumber = 0
    local isVersusTextAdded = false
    let hasArmyInfo = getTblValue("hasArmyInfo", param, true)
    let hasVersusText = getTblValue("hasVersusText", param)
    let canAlignRight = getTblValue("canAlignRight", param, true)
    foreach (sideIdx, side in sides) {
      let team = this.battle.getTeamBySide(side)
      if (!team)
        continue

      let armies = {
        countryIcon = ""
        countryIconBig = ""
        armyViews = ""
        maxSideArmiesNumber = 0
      }

      let mapName = getOperationById(wwGetOperationId())?.getMapId() ?? ""
      let armyViews = []
      foreach (country, armiesArray in team.countries) {
        let countryIcon = getCustomViewCountryData(country, mapName).icon
        armies.countryIcon = countryIcon
        armies.countryIconBig = countryIcon
        foreach (army in armiesArray) {
          let armyView = army.getView()
          armyView.setSelectedSide(this.playerSide)
          armyViews.append(armyView)
        }
      }

      if (armyViews.len()) {
        if (hasVersusText && !isVersusTextAdded) {
          armyViews.top().setHasVersusText(true)
          isVersusTextAdded = true
        }
        else
          armyViews.top().setHasVersusText(false)
      }

      maxSideArmiesNumber = max(maxSideArmiesNumber, armyViews.len())

      let view = {
        army = armyViews
        delimetrRightPadding = hasArmyInfo ? "8*@sf/@pf_outdated" : 0
        reqUnitTypeIcon = true
        hideArrivalTime = true
        showArmyGroupText = false
        battleDescriptionIconSize = iconSize
        isArmyAlwaysUnhovered = true
        needShortInfoText = hasArmyInfo
        hasTextAfterIcon = hasArmyInfo
        isInvert = canAlignRight && sideIdx != 0
      }

      armies.armyViews = handyman.renderCached(this.sceneTplArmyViewsName, view)
      let invert = sideIdx != 0

      let avaliableUnits = []
      let aiUnits = []
      foreach (unit in team.unitsRemain)
        if (unit.isControlledByAI())
          aiUnits.append(unit)
        else
          avaliableUnits.append(unit)

      teams.append({
        invert = invert
        teamName = team.name
        armies = armies
        teamSizeText = this.getTeamSizeText(team)
        haveUnitsList = avaliableUnits.len()
        unitsList = this.unitsList(avaliableUnits, invert && isInBattlePanel, isInBattlePanel)
        haveAIUnitsList = aiUnits.len()
        aiUnitsList = this.unitsList(aiUnits, invert && isInBattlePanel, isInBattlePanel)
      })
    }

    foreach (team in teams)
      team.armies.maxSideArmiesNumber = maxSideArmiesNumber

    return teams
  }

  function getTeamSizeText(team) {
    if (this.battle.isAutoBattle())
      return loc("worldWar/unavailable_for_team")

    let maxPlayers = getTblValue("maxPlayers", team)
    if (!maxPlayers)
      return loc("worldWar/unavailable_for_team")

    let minPlayers = getTblValue("minPlayers", team)
    let curPlayers = getTblValue("players", team)
    return this.battle.isConfirmed() && this.battle.getMyAssignCountry() ?
      loc("worldwar/battle/playersCurMax", { cur = curPlayers, max = maxPlayers }) :
      loc("worldwar/battle/playersMinMax", { min = minPlayers, max = maxPlayers })
  }

  function unitsList(wwUnits, isReflected, hasLineSpacing) {
    let view = { infoSections = [{
      columns = [{ unitString = wwActionsWithUnitsList.getUnitsListViewParams({
        wwUnits = wwUnits
        params = { needShopInfo = true }
      }) }]
      multipleColumns = false
      reflect = isReflected
      isShowTotalCount = true
      hasSpaceBetweenUnits = hasLineSpacing
    }] }
    return handyman.renderCached("%gui/worldWar/worldWarMapArmyInfoUnitsList.tpl", view)
  }

  function isStarted() {
    return this.battle.isStarted()
  }

  function hasBattleDurationTime() {
    return this.battle.getBattleDurationTime() > 0
  }

  function hasBattleActivateLeftTime() {
    return this.battle.getBattleActivateLeftTime() > 0
  }

  function getBattleDurationTime() {
    let durationTime = this.battle.getBattleDurationTime()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }

  function getBattleActivateLeftTime() {
    let durationTime = this.battle.getBattleActivateLeftTime()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }

  function getBattleStatusTextLocId() {
    if (!this.battle.isStillInOperation())
      return "worldwar/battle_finished"

    if (this.battle.isWaiting() ||
        this.battle.status == EBS_ACTIVE_STARTING)
      return "worldwar/battleNotActive"

    if (this.battle.status == EBS_ACTIVE_MATCHING)
      return "worldwar/battleIsStarting"

    if (this.battle.isAutoBattle())
      return "worldwar/battleIsInAutoMode"

    if (this.battle.isConfirmed()) {
      if (this.battle.isPlayerTeamFull())
        return "worldwar/battleIsFull"
      else
        return "worldwar/battleIsActive"
    }

    return "worldwar/battle_finished"
  }

  function getAutoBattleWinChancePercentText() {
    let percent = this.battle.getTeamBySide(this.playerSide)?.autoBattleWinChancePercent
    return percent != null ? $"{percent}{loc("measureUnits/percent")}" : ""
  }

  function needShowWinChance() {
    return  this.battle.isWaiting() || this.battle.status == EBS_ACTIVE_AUTO
  }

  function getBattleStatusText() {
    return this.battle.isValid() ? loc(this.getBattleStatusTextLocId()) : ""
  }

  function getBattleStatusDescText() {
    return this.battle.isValid() ? loc($"{this.getBattleStatusTextLocId()}/desc") : ""
  }

  function getCanJoinText() {
    if (this.playerSide == SIDE_NONE || g_squad_manager.isSquadMember())
      return ""

    let currentBattleQueue = ::queues.findQueueByName(this.battle.getQueueId(), true)
    local canJoinLocKey = ""
    if (currentBattleQueue != null)
      canJoinLocKey = "worldWar/canJoinStatus/in_queue"
    else if (this.battle.isStarted()) {
      let cantJoinReasonData = this.battle.getCantJoinReasonData(this.playerSide, false)
      if (cantJoinReasonData.canJoin)
        canJoinLocKey = this.battle.isPlayerTeamFull()
          ? "worldWar/canJoinStatus/no_free_places"
          : "worldWar/canJoinStatus/can_join"
      else
        canJoinLocKey = cantJoinReasonData.reasonText
    }

    return u.isEmpty(canJoinLocKey) ? "" : loc(canJoinLocKey)
  }

  function getBattleStatusWithTimeText() {
    local text = this.getBattleStatusText()
    let durationText = this.getBattleDurationTime()
    if (!u.isEmpty(durationText))
      text = loc("ui/colon").concat(text, durationText)

    return text
  }

  function getBattleStatusWithCanJoinText() {
    if (!this.battle.isValid())
      return ""

    local text = this.getBattleStatusText()
    let canJoinText = this.getCanJoinText()
    if (!u.isEmpty(canJoinText))
      text = $"{text}{loc("ui/dot")} {canJoinText}"

    return text
  }

  function getStatus() {
    if (!this.battle.isStillInOperation() || this.battle.isFinished())
      return "Finished"
    if (this.battle.isStarting())
      return "Active"
    if (this.battle.status == EBS_ACTIVE_AUTO || this.battle.status == EBS_ACTIVE_FAKE)
      return "Fake"
    if (this.battle.status == EBS_ACTIVE_CONFIRMED)
      return this.battle.isPlayerTeamFull() || !this.battle.hasAvailableUnits() ? "Full" : "OnServer"

    return "Inactive"
  }

  function getIconImage() {
    return (this.getStatus() == "Full" || this.battle.isFinished()) ?
      "#ui/gameuiskin#battles_closed" : "#ui/gameuiskin#battles_open"
  }

  function hasControlTooltip() {
    if (this.battle.isStillInOperation()) {
      let status = this.getStatus()
      if (status == "Active" || status == "Full")
        return true
    }
    else
      return true

    return false
  }

  function getReplayBtnTooltip() {
    return loc("mainmenu/btnViewReplayTooltip", { sessionID = this.battle.getSessionId() })
  }

  function isAutoBattle() {
    return this.battle.isAutoBattle()
  }

  function hasTeamsInfo() {
    return this.battle.isValid() && this.battle.isConfirmed()
  }

  function hasQueueInfo() {
    return this.battle.isValid() && this.battle.hasQueueInfo()
  }

  function getTotalPlayersInfoText() {
    return loc("ui/colon").concat(loc("worldwar/totalPlayers"),
      colorize("newTextColor", this.battle.getTotalPlayersInfo(this.playerSide)))
  }

  function getTotalQueuePlayersInfoText() {
    return loc("ui/colon").concat(loc("worldwar/totalInQueue"),
      colorize("newTextColor", this.battle.getTotalPlayersInQueueInfo(this.playerSide)))
  }
  needShowTimer = @() !this.battle.isFinished()

  function getTimeStartAutoBattle() {
    if (!this.battle.isWaiting())
      return ""

    let durationTime = this.battle.getTimeStartAutoBattle()
    if (durationTime > 0)
      return time.hoursToString(time.secondsToHours(durationTime), false, true)

    return ""
  }
}

return { WwBattle, WwBattleView }
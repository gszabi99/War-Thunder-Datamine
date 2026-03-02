from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/squads/squadsConsts.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let wwQueuesData = require("%scripts/worldWar/operations/model/wwQueuesData.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { getMyStateData } = require("%scripts/user/userUtils.nut")
let { getBattles } = require("%scripts/worldWar/worldWarState.nut")
let { wwGetPlayerSide } = require("worldwar")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { findQueueByName } = require("%scripts/queue/queueState.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let { getPlayWorldwarConditionText, canJoinWorldwarBattle
} = require("%scripts/worldWar/worldWarGlobalStates.nut")
let { getMemberStatusLocId, getSquadMemberAvailableUnitsCheckingData
} = require("%scripts/squads/squadUtils.nut")


function isStillInOperation(wwBattle) {
  let { id } = wwBattle
  return getBattles(@(battle) battle.id == id).len() > 0
}


function isAutoBattle(wwBattle) {
  if (isStillInOperation(wwBattle))
    return false

  if (wwBattle.status == EBS_ACTIVE_AUTO ||
      wwBattle.status == EBS_ACTIVE_FAKE)
    return true

  return wwBattle.opponentsType == "BUT_INFANTRY"
    || wwBattle.opponentsType == "BUT_ARTILLERY_GROUND"
}


function getCantJoinReasonData(wwBattle, side, needCheckSquad = true) {
  let res = {
    code = WW_BATTLE_CANT_JOIN_REASON.CAN_JOIN
    canJoin = false
    reasonText = ""
    shortReasonText = ""
    fullReasonText = ""
  }

  if (!canJoinWorldwarBattle()) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.NO_WW_ACCESS
    res.reasonText = loc("worldWar/noAccess")
    res.fullReasonText = getPlayWorldwarConditionText()
    return res
  }

  if (wwBattle.isFinished()) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
    res.reasonText = loc("worldwar/battle_finished_need_refresh")
    return res
  }

  if (!wwBattle.isValid()) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
    res.reasonText = loc("worldWar/battleNotSelected")
    return res
  }

  if (!wwBattle.isActive()) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.NOT_ACTIVE
    res.reasonText = loc(isStillInOperation(wwBattle) ? "worldwar/battleNotActive" : "worldwar/battle_finished")
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

  if (wwBattle.getBattleActivateLeftTime() > 0) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.EXCESS_PLAYERS
    res.reasonText = loc("worldWar/battle_activate_countdown")
    return res
  }

  let team = wwBattle.getTeamBySide(side)
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
    && wwBattle.isLockedByExcessPlayers(side, team.name)) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.EXCESS_PLAYERS
    res.reasonText = loc("worldWar/battle_is_unbalanced")
    return res
  }

  let maxPlayersInTeam = team.maxPlayers
  let queue = wwQueuesData.getData()?[wwBattle.id]
  let isInQueueAmount = wwBattle.getPlayersInQueueByTeamName(queue, team.name)
  if (isInQueueAmount >= maxPlayersInTeam) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.QUEUE_FULL
    res.reasonText = loc("worldwar/queue_full")
    return res
  }

  let countryName = wwBattle.getCountryNameBySide(side)
  if (!countryName) {
    script_net_assert_once("WW can't get country",
      $"ww: can't get country for team {team.name} from {team.country}")
    res.code = WW_BATTLE_CANT_JOIN_REASON.NO_COUNTRY_BY_SIDE
    res.reasonText = loc("msgbox/internal_error_header")
    return res
  }

  let teamName = wwBattle.getTeamNameBySide(side)
  if (!teamName) {
    script_net_assert_once("WW can't get team",
      $"ww: can't get team for team {team.name} for battle {wwBattle.id}")
    res.code = WW_BATTLE_CANT_JOIN_REASON.NO_TEAM_NAME_BY_SIDE
    res.reasonText = loc("msgbox/internal_error_header")
    return res
  }

  if (team.players >= maxPlayersInTeam) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.TEAM_FULL
    res.reasonText = loc("worldwar/army_full")
    return res
  }

  if (!wwBattle.hasAvailableUnits(team)) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.NO_AVAILABLE_UNITS
    res.reasonText = loc("worldwar/airs_not_available")
    return res
  }

  let remainUnits = wwBattle.getUnitsRequiredForJoin(team, side)
  let myCheckingData = getSquadMemberAvailableUnitsCheckingData(
    getMyStateData(), remainUnits, team.country)
  if (myCheckingData.joinStatus != memberStatus.READY) {
    res.code = WW_BATTLE_CANT_JOIN_REASON.UNITS_NOT_ENOUGH_AVAILABLE
    res.reasonText = loc(getMemberStatusLocId(myCheckingData.joinStatus))
    return res
  }

  if (needCheckSquad && g_squad_manager.isInSquad()) {
    wwBattle.updateCantJoinReasonDataBySquad(team, side, isInQueueAmount, res)
    if (!u.isEmpty(res.reasonText))
      return res
  }

  res.canJoin = true

  return res
}


function tryToJoin(wwBattle, side) {
  let cantJoinReasonData = getCantJoinReasonData(wwBattle, side, true)
  if (!cantJoinReasonData.canJoin) {
    showInfoMsgBox(cantJoinReasonData.reasonText)
    return
  }

  let joinCb = Callback(@() wwBattle.join(side), wwBattle)
  let warningReasonData = wwBattle.getWarningReasonData(side)
  if (warningReasonData.needMsgBox &&
      !loadLocalByAccount(WW_SKIP_BATTLE_WARNINGS_SAVE_ID, false)) {
    loadHandler(gui_handlers.SkipableMsgBox,
      {
        parentHandler = wwBattle
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


function getCanJoinText(wwBattleView) {
  if (wwBattleView.playerSide == SIDE_NONE || g_squad_manager.isSquadMember())
    return ""

  let currentBattleQueue = findQueueByName(wwBattleView.battle.getQueueId(), true)
  local canJoinLocKey = ""
  if (currentBattleQueue != null)
    canJoinLocKey = "worldWar/canJoinStatus/in_queue"
  else if (wwBattleView.battle.isStarted()) {
    let cantJoinReasonData = getCantJoinReasonData(wwBattleView.battle, wwBattleView.playerSide, false)
    if (cantJoinReasonData.canJoin)
      canJoinLocKey = wwBattleView.battle.isPlayerTeamFull()
        ? "worldWar/canJoinStatus/no_free_places"
        : "worldWar/canJoinStatus/can_join"
    else
      canJoinLocKey = cantJoinReasonData.reasonText
  }

  return u.isEmpty(canJoinLocKey) ? "" : loc(canJoinLocKey)
}


function getBattleStatusWithCanJoinText(wwBattleView) {
  if (!wwBattleView.battle.isValid())
    return ""

  local text = wwBattleView.getBattleStatusText()
  let canJoinText = getCanJoinText(wwBattleView)
  if (!u.isEmpty(canJoinText))
    text = $"{text}{loc("ui/dot")} {canJoinText}"

  return text
}


return {
  isStillInOperation
  isAutoBattle
  getCantJoinReasonData
  getBattleStatusWithCanJoinText
  tryToJoin
}

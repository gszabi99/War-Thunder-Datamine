global const WW_SKIP_BATTLE_WARNINGS_SAVE_ID = "worldWar/skipBattleWarnings"

global enum WW_ARMY_ACTION_STATUS
{
  IDLE = 0
  IN_MOVE = 1
  ENTRENCHED = 2
  IN_BATTLE = 3

  UNKNOWN = 100
}

global enum WW_ARMY_RELATION_ID
{
  CLAN,
  ALLY
}

global enum WW_GLOBAL_STATUS_TYPE //bit enum
{
  QUEUE              = 0x0001
  ACTIVE_OPERATIONS  = 0x0002
  MAPS               = 0x0004
  OPERATIONS_GROUPS  = 0x0008

  //masks
  ALL                = 0x000F
}

global enum WW_BATTLE_ACCESS
{
  NONE     = 0
  OBSERVER = 0x0001
  MANAGER  = 0x0002

  SUPREME  = 0xFFFF
}

global enum WW_UNIT_CLASS
{
  FIGHTER    = 0x0001
  BOMBER     = 0x0002
  ASSAULT    = 0x0004
  HELICOPTER = 0x0008
  UNKNOWN    = 0x0010

  NONE     = 0x0000
  COMBINED = 0x0003
}

global enum WW_BATTLE_UNITS_REQUIREMENTS
{
  NO_REQUIREMENTS   = "allow"
  BATTLE_UNITS      = "battle"
  OPERATION_UNITS   = "global"
  NO_MATCHING_UNITS = "deny"
}

global enum WW_BATTLE_CANT_JOIN_REASON
{
  CAN_JOIN
  NO_WW_ACCESS
  NOT_ACTIVE
  UNKNOWN_SIDE
  WRONG_SIDE
  EXCESS_PLAYERS
  NO_TEAM
  NO_COUNTRY_IN_TEAM
  NO_COUNTRY_BY_SIDE
  NO_TEAM_NAME_BY_SIDE
  NO_AVAILABLE_UNITS
  TEAM_FULL
  QUEUE_FULL
  UNITS_NOT_ENOUGH_AVAILABLE
  SQUAD_NOT_LEADER
  SQUAD_WRONG_SIDE
  SQUAD_TEAM_FULL
  SQUAD_QUEUE_FULL
  SQUAD_NOT_ALL_READY
  SQUAD_MEMBER_ERROR
  SQUAD_UNITS_NOT_ENOUGH_AVAILABLE
  SQUAD_HAVE_UNACCEPTED_INVITES
  SQUAD_NOT_ALL_CREWS_READY
  SQUAD_MEMBERS_NO_WW_ACCESS
}

global enum mapObjectSelect {
  NONE,
  ARMY,
  REINFORCEMENT,
  AIRFIELD,
  BATTLE,
  LOG_ARMY
}

global enum WW_ARMY_GROUP_ICON_SIZE {
  BASE   = "base",
  SMALL  = "small",
  MEDIUM = "medium"
}

global enum WW_MAP_HIGHLIGHT {
  LAYER_0,
  LAYER_1,
  LAYER_2,
  LAYER_3
}

global enum WW_UNIT_SORT_CODE {
  AIR,
  HELICOPTER,
  GROUND,
  WATER,
  ARTILLERY,
  INFANTRY,
  TRANSPORT,
  UNKNOWN
}

::strength_unit_expclass_group <- {
  bomber = "bomber"
  assault = "bomber"
  heavy_tank = "tank"
  tank = "tank"
  tank_destroyer = "tank"
  exp_torpedo_boat = "ships"
  exp_gun_boat = "ships"
  exp_torpedo_gun_boat = "ships"
  exp_submarine_chaser = "ships"
  exp_destroyer = "ships"
  exp_cruiser = "ships"
  exp_naval_ferry_barge = "ships"
}

::ww_gui_bhv <- {}

foreach (fn in [
                 "services/wwService.nut"
                 "operations/model/wwGlobalStatusType.nut"
                 "externalServices/worldWarTopMenuSectionsConfigs.nut"
                 "externalServices/wwQueue.nut"
                 "externalServices/inviteWwOperation.nut"
                 "externalServices/inviteWwOperationBattle.nut"
                 "bhvWorldWarMap.nut"
                 "model/wwUnitType.nut"
                 "inOperation/wwOperations.nut"
                 "inOperation/model/wwOperationArmies.nut"
                 "inOperation/model/wwOperationModel.nut"
                 "inOperation/model/wwAirfield.nut"
                 "inOperation/model/wwFormation.nut"
                 "inOperation/model/wwAirfieldFormation.nut"
                 "inOperation/model/wwCustomFormation.nut"
                 "inOperation/model/wwAirfieldCooldownFormation.nut"
                 "inOperation/model/wwArmy.nut"
                 "inOperation/model/wwArmyOwner.nut"
                 "inOperation/model/wwPathTracker.nut"
                 "inOperation/model/wwArtilleryAmmo.nut"
                 "inOperation/model/wwArmyGroup.nut"
                 "inOperation/model/wwBattle.nut"
                 "inOperation/model/wwBattleResults.nut"
                 "inOperation/model/wwUnit.nut"
                 "inOperation/model/wwObjectivesTypes.nut"
                 "inOperation/model/wwArmyMoveState.nut"
                 "inOperation/model/wwReinforcementArmy.nut"
                 "inOperation/model/wwMapControlsButtons.nut"
                 "inOperation/model/wwMapInfoTypes.nut"
                 "inOperation/model/wwMapReinforcementTabType.nut"
                 "inOperation/model/wwArmiesStatusTabType.nut"
                 "inOperation/model/wwOperationLog.nut"
                 "inOperation/model/wwOperationLogTypes.nut"
                 "inOperation/view/wwObjectiveView.nut"
                 "inOperation/view/wwArmyView.nut"
                 "inOperation/view/wwBattleView.nut"
                 "inOperation/view/wwBattleResultsView.nut"
                 "inOperation/view/wwOperationLogView.nut"
                 "inOperation/handler/wwMap.nut"
                 "inOperation/handler/wwObjective.nut"
                 "inOperation/handler/wwOperationLog.nut"
                 "inOperation/handler/wwAirfieldsList.nut"
                 "inOperation/handler/wwArmiesList.nut"
                 "inOperation/handler/wwCommanders.nut"
                 "inOperation/handler/wwArmyGroupHandler.nut"
                 "inOperation/handler/wwReinforcements.nut"
                 "inOperation/handler/wwBattleResults.nut"
                 "operations/model/wwMap.nut"
                 "operations/model/wwOperation.nut"
                 "operations/model/wwOperationsGroup.nut"
                 "operations/handler/wwMapDescription.nut"
                 "operations/handler/wwQueueDescriptionCustomHandler.nut"
                 "operations/handler/wwOperationDescriptionCustomHandler.nut"
                 "operations/handler/wwOperationsListModal.nut"
                 "operations/handler/wwOperationsMapsHandler.nut"
                 "handler/wwMapTooltip.nut"
                 "handler/wwQueueInfo.nut"
                 "handler/wwSquadList.nut"
                 "handler/wwBattleDescription.nut"
                 "handler/wwGlobalBattlesModal.nut"
                 "handler/wwAirfieldFlyOut.nut"
                 "handler/wwObjectivesInfo.nut"
                 "handler/wwMyClanSquadInviteModal.nut"
                 "handler/wwJoinBattleCondition.nut"
                 "handler/wwLeaderboard.nut"
                 "worldWarRender.nut"
                 "worldWarBattleJoinProcess.nut"
                 "externalServices/matchingNotifications/worldwar.nut"
                 "worldWarUtils.nut"
                 "debugTools/dbgUtils.nut"
               ])
  ::g_script_reloader.loadOnce("scripts/worldWar/" + fn) // no need to includeOnce to correct reload this scripts pack runtime

require("scripts/worldWar/wwGenericTooltipTypes.nut")
foreach(bhvName, bhvClass in ::ww_gui_bhv)
  ::replace_script_gui_behaviour(bhvName, bhvClass)

::ww_event <- function ww_event(name, params = {})
{
  ::broadcastEvent("WW" + name, params || {})
}

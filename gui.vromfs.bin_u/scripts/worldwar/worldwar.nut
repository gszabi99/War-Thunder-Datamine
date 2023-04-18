//-file:plus-string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

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
                 "externalServices/wwTopMenuOperationMapConfig.nut"
                 "externalServices/wwQueue.nut"
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
  ::g_script_reloader.loadOnce("%scripts/worldWar/" + fn) // no need to includeOnce to correct reload this scripts pack runtime

// Independed Modules
require("%scripts/worldWar/wwPromo.nut")
require("%scripts/worldWar/wwSquadManager.nut")
require("%scripts/worldWar/wwInvites.nut")
require("%scripts/worldWar/wwInviteOperation.nut")


foreach (bhvName, bhvClass in ::ww_gui_bhv)
  ::replace_script_gui_behaviour(bhvName, bhvClass)

::ww_event <- function ww_event(name, params = {}) {
  ::broadcastEvent("WW" + name, params || {})
}

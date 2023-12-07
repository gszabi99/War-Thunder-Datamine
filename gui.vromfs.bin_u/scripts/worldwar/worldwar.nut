from "%scripts/dagui_library.nut" import *

let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { worldWarMapControls } = require("bhvWorldWarMap.nut")

replace_script_gui_behaviour("worldWarMapControls", worldWarMapControls)

foreach (fn in [
                 "services/wwService.nut"
                 "operations/model/wwGlobalStatusType.nut"
                 "externalServices/worldWarTopMenuSectionsConfigs.nut"
                 "externalServices/wwTopMenuOperationMapConfig.nut"
                 "externalServices/wwQueue.nut"
                 "externalServices/inviteWwOperationBattle.nut"
                 "model/wwUnitType.nut"
                 "inOperation/wwOperations.nut"
                 "inOperation/model/wwOperationArmies.nut"
                 "inOperation/model/wwOperationModel.nut"
                 "inOperation/model/wwAirfield.nut"
                 "inOperation/model/wwArmy.nut"
                 "inOperation/model/wwArmyOwner.nut"
                 "inOperation/model/wwPathTracker.nut"
                 "inOperation/model/wwArtilleryAmmo.nut"
                 "inOperation/model/wwArmyGroup.nut"
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
  loadOnce($"%scripts/worldWar/{fn}") // no need to includeOnce to correct reload this scripts pack runtime

// Independed Modules
require("%scripts/worldWar/wwPromo.nut")
require("%scripts/worldWar/wwSquadManager.nut")
require("%scripts/worldWar/wwInvites.nut")
require("%scripts/worldWar/wwInviteOperation.nut")

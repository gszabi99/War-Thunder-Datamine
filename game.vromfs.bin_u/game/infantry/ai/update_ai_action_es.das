require ecs
require DngWalkerai
require HumanPhys

[es(tag=server, no_order)]
def update_ai_action_es(act : UpdateStageInfoAct; walker_agent__serverAiAction : int;
                        var walker_agent__nextAiActionUpdate : float&;
                        var walker_agent__currentAiAction : int&;
                        walker_agent__updateAiActionEvery : float = 1.0)
  if act.curTime >= walker_agent__nextAiActionUpdate
    walker_agent__currentAiAction = walker_agent__serverAiAction
    walker_agent__nextAiActionUpdate = act.curTime + walker_agent__updateAiActionEvery

[es(tag=server, after=beh_tree_update_es, before=update_ai_action_es)]
def update_ai_action_ex_es(act : UpdateStageInfoAct;
                           walker_agent : EntityAgent&;
                           var walker_agent__serverAiAction : int&)
  if walker_agent.reloading
    walker_agent__serverAiAction = int(AiAction.AI_ACTION_RELOADING)
    return

  let phys = walker_agent.phys

  if phys.currentState.standState == HUStandState.ESS_DOWNED
    walker_agent__serverAiAction = int(AiAction.AI_ACTION_DOWNED)
    return

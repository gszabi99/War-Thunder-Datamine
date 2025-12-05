require ecs
require DagorMath
require PhysVars
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.tnt_common


def tnt_exploder_anim_state_update(current_time : float;
                                   tnt_exploder__tntBlocks : EidList;
                                   tnt_exploder_anim__reloadTime : float;
                                   var tnt_exploder_anim__state : int&;
                                   var tnt_exploder_anim__stateStart : float&;
                                   var tnt_exploder_anim__stateEnd : float&;
                                   tnt_exploder_anim_skip_reloading_on_zero_tnt : Tag const?;
                                   throwable_launcher__itemsCount : int const?)
  if tnt_exploder_anim__stateEnd > current_time
    return

  if tnt_exploder_anim__state == int(TntExploderAnimState.TEAS_DETONATING)
    var skipReloading = false
    if tnt_exploder_anim_skip_reloading_on_zero_tnt != null
      skipReloading = length(tnt_exploder__tntBlocks) > 0
      skipReloading &&= throwable_launcher__itemsCount == null || (*throwable_launcher__itemsCount) > 0

    if skipReloading
      tnt_exploder_anim__state = int(TntExploderAnimState.TEAS_NONE)
    else
      tnt_exploder_anim__state = int(TntExploderAnimState.TEAS_RELOADING)
      tnt_exploder_anim__stateStart = tnt_exploder_anim__stateEnd
      tnt_exploder_anim__stateEnd += tnt_exploder_anim__reloadTime
  elif tnt_exploder_anim__state == int(TntExploderAnimState.TEAS_RELOADING)
    tnt_exploder_anim__state = int(TntExploderAnimState.TEAS_NONE)

[es(on_appear, before=anim_phys_init_es)]
def tnt_exploder_anim_init(evt : Event;
                           tnt_exploder_anim__detonationProgressVar : string;
                           tnt_exploder_anim__reloadProgressVar : string;
                           var tnt_exploder_anim__detonationProgressVarId : int&;
                           var tnt_exploder_anim__reloadProgressVarId : int&;
                           var phys_vars : PhysVars&)
  tnt_exploder_anim__detonationProgressVarId = phys_vars |> registerVar(tnt_exploder_anim__detonationProgressVar, 0.0)
  tnt_exploder_anim__reloadProgressVarId = phys_vars |> registerVar(tnt_exploder_anim__reloadProgressVar, 0.0)

[es(tag=gameClient, no_order)]
def tnt_exploder_anim_update_client(info : ParallelUpdateFrameDelayed;
                                    tnt_exploder__tntBlocks : EidList;
                                    tnt_exploder_anim__reloadTime : float;
                                    tnt_exploder_anim__detonationProgressVarId : int;
                                    tnt_exploder_anim__reloadProgressVarId : int;
                                    var tnt_exploder_anim__state : int&;
                                    var tnt_exploder_anim__stateStart : float&;
                                    var tnt_exploder_anim__stateEnd : float&;
                                    var phys_vars : PhysVars&;
                                    tnt_exploder_anim_skip_reloading_on_zero_tnt : Tag const?;
                                    throwable_launcher__itemsCount : int const?)
  if tnt_exploder_anim__state == int(TntExploderAnimState.TEAS_NONE)
    phys_vars |> setVar(tnt_exploder_anim__detonationProgressVarId, 0.0)
    phys_vars |> setVar(tnt_exploder_anim__reloadProgressVarId, 0.0)
    return

  tnt_exploder_anim_state_update(info.curTime, tnt_exploder__tntBlocks, tnt_exploder_anim__reloadTime, tnt_exploder_anim__state, tnt_exploder_anim__stateStart, tnt_exploder_anim__stateEnd, tnt_exploder_anim_skip_reloading_on_zero_tnt, throwable_launcher__itemsCount)

  let stateProgress = cvt(info.curTime, tnt_exploder_anim__stateStart, tnt_exploder_anim__stateEnd, 0.f, 1.0f)
  if tnt_exploder_anim__state == int(TntExploderAnimState.TEAS_DETONATING)
    phys_vars |> setVar(tnt_exploder_anim__detonationProgressVarId, stateProgress)
    phys_vars |> setVar(tnt_exploder_anim__reloadProgressVarId, 0.0)
  elif tnt_exploder_anim__state == int(TntExploderAnimState.TEAS_RELOADING)
    phys_vars |> setVar(tnt_exploder_anim__detonationProgressVarId, 0.0)
    phys_vars |> setVar(tnt_exploder_anim__reloadProgressVarId, stateProgress)

[es(tag=server, after=tnt_exploder_start_explode)]
def tnt_exploder_anim_state_update_server(info : UpdateStageInfoAct;
                                          tnt_exploder__tntBlocks : EidList;
                                          tnt_exploder_anim__reloadTime : float;
                                          var tnt_exploder_anim__state : int&;
                                          var tnt_exploder_anim__stateStart : float&;
                                          var tnt_exploder_anim__stateEnd : float&;
                                          tnt_exploder_anim_skip_reloading_on_zero_tnt : Tag const?;
                                          throwable_launcher__itemsCount : int const?)
  if tnt_exploder_anim__state == int(TntExploderAnimState.TEAS_NONE)
    return

  tnt_exploder_anim_state_update(info.curTime, tnt_exploder__tntBlocks, tnt_exploder_anim__reloadTime, tnt_exploder_anim__state, tnt_exploder_anim__stateStart, tnt_exploder_anim__stateEnd, tnt_exploder_anim_skip_reloading_on_zero_tnt, throwable_launcher__itemsCount)

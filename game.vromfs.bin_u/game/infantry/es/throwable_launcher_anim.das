require ecs
require DagorMath
require PhysVars
require %game.events


[es(on_appear, before=anim_phys_init_es)]
def throwable_launcher_anim_init(evt : Event;
                                 throwable_launcher_anim__throwProgressVar : string;
                                 var throwable_launcher_anim__throwProgressVarId : int&;
                                 var phys_vars : PhysVars&)
  throwable_launcher_anim__throwProgressVarId = phys_vars |> registerVar(throwable_launcher_anim__throwProgressVar, 0.0)

[es(tag=gameClient, no_order)]
def throwable_launcher_anim_update(info : ParallelUpdateFrameDelayed;
                                   throwable_launcher_anim__throwProgressVarId : int;
                                   throwable_launcher_anim__throwStart : float;
                                   throwable_launcher_anim__throwEnd : float;
                                   var throwable_launcher_anim__throwInProgress : bool&;
                                   var phys_vars : PhysVars&)
  if !throwable_launcher_anim__throwInProgress
    phys_vars |> setVar(throwable_launcher_anim__throwProgressVarId, 0.0)
    return

  throwable_launcher_anim__throwInProgress = throwable_launcher_anim__throwEnd > info.curTime
  let throwableLauncherProgress = cvt(info.curTime, throwable_launcher_anim__throwStart, throwable_launcher_anim__throwEnd, 0.f, 1.0f)
  phys_vars |> setVar(throwable_launcher_anim__throwProgressVarId, throwableLauncherProgress)

[es(tag=server, no_order)]
def throwable_launcher_anim_update_progress(info : UpdateStageInfoAct;
                                            throwable_launcher_anim__throwEnd : float;
                                            var throwable_launcher_anim__throwInProgress : bool&)
  if throwable_launcher_anim__throwInProgress
    throwable_launcher_anim__throwInProgress = throwable_launcher_anim__throwEnd > info.curTime

[es(tag=gameClient, REQUIRE=throwable_item, on_appear, track=throwable_item__throwed)]
def throwable_launcher_anim_disable_render_on_throwable_item_throwed(evt : Event;
                                                                     throwable_item__launcher : EntityId;
                                                                     throwable_item__throwed : bool)
  if !throwable_item__throwed
    return

  query(throwable_item__launcher) <| $ [es] (throwable_launcher_anim__disableRenderOnItemAppear : bool;
                                             throwable_launcher_anim__throwInProgress : bool;
                                             var animchar_render__enabled : bool&)
    if !throwable_launcher_anim__disableRenderOnItemAppear || !throwable_launcher_anim__throwInProgress
      return
    animchar_render__enabled = false

[es(tag=gameClient, track=throwable_launcher_anim__throwInProgress)]
def throwable_launcher_anim_on_launch_animation_complete(evt : Event;
                                                         eid : EntityId;
                                                         gun__owner : EntityId;
                                                         throwable_launcher_anim__throwInProgress : bool;
                                                         var animchar_render__enabled : bool&)
  if throwable_launcher_anim__throwInProgress
    return

  query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId)
    if human_weap__currentGunEid == eid
      animchar_render__enabled = true

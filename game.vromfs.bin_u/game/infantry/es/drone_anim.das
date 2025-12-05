require app
require ecs
require ecs.common
require PhysVars
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.tactical_phone_common
require %appGame.infantry.es.drone_launcher_common
require DagorMath


[es(on_appear, before=anim_phys_init_es)]
def drone_launcher_anim_init(evt : Event;
                             drone_launcher_anim__launchProgressVar : string;
                             var drone_launcher_anim__launchProgressVarId : int&;
                             var phys_vars : PhysVars&)
  drone_launcher_anim__launchProgressVarId = phys_vars |> registerVar(drone_launcher_anim__launchProgressVar, 0.0)


[es(no_order)]
def drone_launcher_anim_update(info : ParallelUpdateFrameDelayed;
                               drone_launcher_anim__launchProgressVarId : int;
                               drone_launcher_anim__launchStart : float;
                               drone_launcher_anim__launchEnd : float;
                               var drone_launcher_anim__launchInProgress : bool&;
                               var phys_vars : PhysVars&)
  if !drone_launcher_anim__launchInProgress
    phys_vars |> setVar(drone_launcher_anim__launchProgressVarId, 0.0)
    return

  drone_launcher_anim__launchInProgress = drone_launcher_anim__launchEnd > info.curTime
  let droneLauncherProgress = cvt(info.curTime, drone_launcher_anim__launchStart, drone_launcher_anim__launchEnd, 0.f, 1.0f)
  if droneLauncherProgress >= 0.0
    phys_vars |> setVar(drone_launcher_anim__launchProgressVarId, droneLauncherProgress)


[es(tag=gameClient, track=drone_launcher_anim__launchEnd)]
def drone_launcher_anim_start_launch(evt : Event;
                                     drone_launcher_anim__launchEnd : float;
                                     var drone_launcher_anim__launchInProgress : bool&)
  drone_launcher_anim__launchInProgress = drone_launcher_anim__launchEnd > get_sync_time()


[es(tag=gameClient, on_appear)]
def drone_launcher_anim_replace_animation_with_entity_on_drone_appear(evt : Event;
                                                                      drone__launcherEid : EntityId;
                                                                      var animchar_render__enabled aka drone_animchar_render__enabled : bool&)
  query(drone__launcherEid) <| $ [es] (drone_launcher_anim__replaceAnimationWithEntity : bool;
                                       drone_launcher_anim__launchInProgress : bool;
                                       var animchar_render__enabled : bool&)
    if !drone_launcher_anim__launchInProgress
      return
    drone_animchar_render__enabled = drone_launcher_anim__replaceAnimationWithEntity
    animchar_render__enabled = !drone_launcher_anim__replaceAnimationWithEntity


[es(tag=gameClient, track=(drone_launcher_anim__replaceAnimationWithEntity))]
def drone_launcher_anim_replace_animation_with_entity(evt : Event;
                                                      drone_launcher__drone : EntityId;
                                                      drone_launcher_anim__launchInProgress : bool;
                                                      drone_launcher_anim__replaceAnimationWithEntity : bool;
                                                      var animchar_render__enabled : bool&)
  if drone_launcher_anim__launchInProgress
    animchar_render__enabled = !drone_launcher_anim__replaceAnimationWithEntity
  query(drone_launcher__drone) <| $ [es(REQUIRE=isDrone)] (possessedByPlr : EntityId;
                                                           var animchar_render__enabled : bool&)
    if possessedByPlr != get_local_player_eid()
      animchar_render__enabled = drone_launcher_anim__replaceAnimationWithEntity


[es(tag=gameClient, track=drone_launcher_anim__launchInProgress)]
def drone_launcher_anim_on_launch_animation_complete(evt : Event;
                                                     eid aka drone_launcher_eid : EntityId;
                                                     gun__owner : EntityId;
                                                     drone_launcher__tacticalPhone : EntityId;
                                                     drone_launcher__state : int;
                                                     drone_launcher_anim__launchInProgress : bool;
                                                     var animchar_render__enabled : bool&)
  if drone_launcher_anim__launchInProgress
    return

  if drone_launcher__state != int(DroneLauncherState.DLS_READY)
    sendEvent(drone_launcher__tacticalPhone, EventRequestTakeTactialPhone(ownerEid = gun__owner, mode = int(TacticalPhoneMode.TPM_DRONE)))
  else
    query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId)
      if human_weap__currentGunEid == drone_launcher_eid
        animchar_render__enabled = true
require ecs
require math.interpolation
require DagorMath

require %appGame.wt_events
require %appGame.infantry.es.concussion_common
require PropsManager
require DaWeapons
require Weapon
require Grid


[es(tag=server, no_order)]
def concussion_timer(info : UpdateStageInfoAct;
                     concussion__endTime : float;
                     var concussion__isActive : bool&)
  if concussion__isActive && info.curTime > concussion__endTime
    concussion__isActive = false

[es(tag=server, track=isAlive)]
def on_death_disable_concussion(evt : Event; isAlive : bool; var concussion__isActive : bool&)
  if !isAlive
    concussion__isActive = false 

[es(tag=server, track=concussion__isActive, on_appear)]
def concussion_screen_effect_toggle(evt : Event; concussion__isActive : bool; var hasConcussedVision : bool&)
  hasConcussedVision = concussion__isActive

[es(tag=server, track=concussion__isActive, on_appear)]
def concussion_sound_toggle(evt : Event; concussion__isActive : bool; var hasConcussedSound : bool&)
  hasConcussedSound = concussion__isActive

def apply_concussion_in_radius(pos : float3;
                               radius : float;
                               is_blocks_sprint : bool;
                               look_sens_mult : float;
                               look_inertia : float;
                               move_inertia : float)
  apply_concussion_in_radius(pos, radius, is_blocks_sprint, look_sens_mult, look_inertia, move_inertia) <| $ [unused_argument(object_pos)] (object_pos) => 1.0


def apply_concussion_in_radius(pos : float3;
                               radius : float;
                               is_blocks_sprint : bool;
                               look_sens_mult : float;
                               look_inertia : float;
                               move_inertia : float;
                               calc_intensity_cb : block<(object_pos : float3) : float>)
  if radius > 0.
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, radius), GridEntCheck.BOUNDING) <| $(eid : EntityId)
      query(eid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform : float3x4; concussion__duration : float; isInVehicleHidden : bool = false)
        if !isInVehicleHidden
          enable_concussion_affect([
            owner_eid=eid,
            duration=concussion__duration,
            intensity=invoke(calc_intensity_cb, transform[3]),
            is_blocks_sprint = is_blocks_sprint,
            look_sens_mult = look_sens_mult,
            look_inertia = look_inertia,
            move_inertia = move_inertia
          ])
    
    
    
    


[es(tag=server)]
def on_flash_explosion_concussion(evt : EventShellExplodedServer;
                                  flash_shell__concussionIntensityByDistSq : Point2List;
                                  shell__concussionLookSensMult : float = 1.0;
                                  shell__concussionLookInertia : float = 0.0;
                                  shell__concussionMoveInertia : float = 0.0;
                                  shell__concussionBlocksSprint : Tag const?)
  assume concussionIntensityByDistSq = flash_shell__concussionIntensityByDistSq

  if empty(concussionIntensityByDistSq)
    return

  let maxRadiusSq = concussionIntensityByDistSq[length(concussionIntensityByDistSq) - 1].x
  if maxRadiusSq <= 0.0
    return

  let maxRadius = sqrt(maxRadiusSq)
  apply_concussion_in_radius(evt.pos, maxRadius, shell__concussionBlocksSprint != null, shell__concussionLookSensMult, shell__concussionLookInertia, shell__concussionMoveInertia) <| $(object_pos)
    let distSq = distance_sq(evt.pos, object_pos)
    let mult = interpolate_by_point_list(concussionIntensityByDistSq, distSq)
    return mult


[es(tag=server, REQUIRE_NOT=launch_desc)]
def on_explosion_concussion(evt : EventShellExplodedServer;
                            shell__shell_id__shell_id : PropsId;
                            shell__concussionMinRadius : float = 0.0;
                            shell__concussionMaxRadius : float = -1.0;
                            shell__concussionLookSensMult : float = 1.0;
                            shell__concussionLookInertia : float = 0.0;
                            shell__concussionMoveInertia : float = 0.0;
                            shell__concussionBlocksSprint : Tag const?)
  let damageRadius = get_shell_max_radius(shell__shell_id__shell_id)
  let concussionRadius = clamp(damageRadius, shell__concussionMinRadius, shell__concussionMaxRadius >= 0. ? shell__concussionMaxRadius : damageRadius)
  apply_concussion_in_radius(evt.pos, concussionRadius, shell__concussionBlocksSprint != null, shell__concussionLookSensMult, shell__concussionLookInertia, shell__concussionMoveInertia)

[es(tag=server)]
def on_visual_explosion_concussion(evt : EventOnVisualExplosion)
  apply_concussion_in_radius(evt.pos, evt.explosion_radius, false, 1.0, 0.0, 0.0) <| $(object_pos)
    let dist = distance(evt.pos, object_pos)
    let mult = lerp(1.0, 0.0, clamp(safediv(dist, evt.explosion_radius), 0.0, 1.0))
    return mult

[es(tag=server)]
def on_explosion_concussion_launch_desc(evt : EventShellExplodedServer;
                                        launch_desc : LaunchDesc;
                                        shell__concussionMinRadius : float = 0.0;
                                        shell__concussionMaxRadius : float = -1.0;
                                        shell__concussionLookSensMult : float = 1.0;
                                        shell__concussionLookInertia : float = 0.0;
                                        shell__concussionMoveInertia : float = 0.0;
                                        shell__concussionBlocksSprint : Tag const?)
  assume shellId = launch_desc.shellId
  let damageRadius = get_shell_max_radius(shellId)
  let concussionRadius = clamp(damageRadius, shell__concussionMinRadius, shell__concussionMaxRadius >= 0. ? shell__concussionMaxRadius : damageRadius)
  apply_concussion_in_radius(evt.pos, concussionRadius, shell__concussionBlocksSprint != null, shell__concussionLookSensMult, shell__concussionLookInertia, shell__concussionMoveInertia)























































[es(tag=server, on_appear)]
def apply_concussion_duration_mult(evt : Event;
                                   entity_mods__concussionDurationMult : float;
                                   var concussion__duration : float&;
                                   var concussion__handsShakeFadeTime : float&)
  concussion__duration = max(0., concussion__duration * entity_mods__concussionDurationMult)
  concussion__handsShakeFadeTime = max(0., concussion__handsShakeFadeTime * entity_mods__concussionDurationMult)

[es(tag=server, on_appear)]
def apply_concussion_shake_mult(evt : Event;
                                entity_mods__concussionShakeMult : float;
                                var concussion__handsShakeMagnitude : float&;
                                var concussion__handsShakeSpeedMult : float&)
  concussion__handsShakeMagnitude = max(0., concussion__handsShakeMagnitude * entity_mods__concussionShakeMult)
  concussion__handsShakeSpeedMult = max(0., concussion__handsShakeSpeedMult * entity_mods__concussionShakeMult)


[es(tag=gameClient, on_appear, track=(concussion__isActive, concussion__lookSensMult))]
def concussion_update_look_sens_mult(evt : Event;
                                     concussion__isActive : bool;
                                     concussion__lookSensMult : float;
                                     var human_input__concussionSensMult : float&)
  human_input__concussionSensMult = concussion__isActive ? concussion__lookSensMult : 1.0


[es(tag=gameClient, on_appear, track=(concussion__isActive, concussion__lookInertia))]
def concussion_update_look_inertia(evt : Event;
                                   concussion__isActive : bool;
                                   concussion__lookInertia : float;
                                   var human_input__aimInputInertia : float&)
  human_input__aimInputInertia = concussion__isActive ? concussion__lookInertia : 0.0


[es(tag=gameClient, on_appear, track=(concussion__isActive, concussion__moveInertia))]
def concussion_update_move_inertia(evt : Event;
                                   concussion__isActive : bool;
                                   concussion__moveInertia : float;
                                   var human_input__moveInputInertia : float&)
  human_input__moveInputInertia = concussion__isActive ? concussion__moveInertia : 0.0

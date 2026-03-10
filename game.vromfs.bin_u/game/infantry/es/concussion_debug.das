options no_aot

require ecs
require DagorConsole
require %appGame.infantry.es.concussion_common
require %appGame.infantry.es.net_console_macro

require %appGame.wt_events
require DagorDebug3D
require PropsManager
require Weapon
require DaWeapons


[console_cmd(name="affect.concussion", hint="Enable a concussion affect for the hero")]
def console_activate_concussion(intensity : float = 1.0;
                                is_blocks_sprint : bool = false;
                                look_sens_mult : float = 1.0;
                                look_inertia : float = 0.0;
                                move_inertia : float = 0.0)
  find_query() <| $ [es(REQUIRE=hero)] (eid : EntityId; concussion__duration : float; var concussion__isActive : bool&)
    if concussion__isActive
      concussion__isActive = false
    else
      enable_concussion_affect(eid, concussion__duration, intensity, is_blocks_sprint, look_sens_mult, look_inertia, move_inertia)
    return true

[console_cmd(name="affect.concussion.all", hint="Enable a concussion affect for all humans")]
def console_activate_concussion_all(intensity : float = 1.0;
                                    is_blocks_sprint : bool = false;
                                    look_sens_mult : float = 1.0;
                                    look_inertia : float = 0.0;
                                    move_inertia : float = 0.0)
  query() <| $ [es(REQUIRE=human)] (eid : EntityId; concussion__duration : float; var concussion__isActive : bool&)
    if concussion__isActive
      concussion__isActive = false
    else
      enable_concussion_affect(eid, concussion__duration, intensity, is_blocks_sprint, look_sens_mult, look_inertia, move_inertia)

















[es(tag=server, REQUIRE_NOT=launch_desc, REQUIRE=debugConcussion)]
def on_explosion_concussion_debug(evt : EventShellExplodedServer;
                                  shell__shell_id__shell_id : PropsId;
                                  concussion_debug__frames : int = 10000;
                                  shell__concussionMinRadius : float = 0.0;
                                  shell__concussionMaxRadius : float = -1.0)
  let damageRadius = get_shell_max_radius(shell__shell_id__shell_id)
  let concussionRadius = clamp(damageRadius, shell__concussionMinRadius, shell__concussionMaxRadius >= 0. ? shell__concussionMaxRadius : damageRadius)
  draw_debug_sphere_buffered(evt.pos, concussionRadius, E3DCOLOR(0xFFFF0000), concussion_debug__frames)

[es(tag=server, REQUIRE=debugConcussion)]
def on_explosion_concussion_launch_desc_debug(evt : EventShellExplodedServer;
                                              launch_desc : LaunchDesc;
                                              concussion_debug__frames : int = 10000;
                                              shell__concussionMinRadius : float = 0.0;
                                              shell__concussionMaxRadius : float = -1.0)
  assume shellId = launch_desc.shellId
  let damageRadius = get_shell_max_radius(shellId)
  let concussionRadius = clamp(damageRadius, shell__concussionMinRadius, shell__concussionMaxRadius >= 0. ? shell__concussionMaxRadius : damageRadius)
  draw_debug_sphere_buffered(evt.pos, concussionRadius, E3DCOLOR(0xFFFF0000), concussion_debug__frames)

[net_console_cmd(name="affect.disable_screen_effects", hint="Toggle concussion and blood screen effects")]
def console_disable_screen_effects(@net_hero eid : EntityId)
  query(eid) <| $ [es] (var human__disableScreenEffects : bool&)
    human__disableScreenEffects = !human__disableScreenEffects
    console_print("screen effects disabled = {human__disableScreenEffects}")

[net_console_cmd(name="affect.disable_camera_shake_on_hit", hint="Toggle camera shake on hit")]
def console_disable_camera_shake_on_hit(@net_hero eid : EntityId)
  query(eid) <| $ [es] (var human__disableCameraShakeOnHit : bool&)
    human__disableCameraShakeOnHit = !human__disableCameraShakeOnHit
    console_print("camera shake on hit disabled = {human__disableCameraShakeOnHit}")

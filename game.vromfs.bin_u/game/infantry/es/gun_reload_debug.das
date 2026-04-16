options no_aot
require ecs
require ecs.ecs_template
require DagorConsole
require %game.events
require %appGame.infantry.es.gun_reload_common


[ecs_template]
struct gun_reload_debug
  gun_reload_debug : Tag

[console_cmd(name="gun_reload.show_state", hint="Show progress and name of current reload state")]
def gun_reload_debug_command()
  let found = find_query() <| $ [es(REQUIRE=gun_reload_debug)] (eid : EntityId)
    destroyEntity(eid)
    return true

  if !found
    createEntity("gun_reload_debug")
  console_print("{found ? "deactivated" : "activated"} gun reload debug")


[es(after=gun_reload_calc_progress, REQUIRE=gun_reload_debug)]
def gun_reload_display_state_info(info : ParallelUpdateFrameDelayed)
  query() <| $ [es] (eid : EntityId;
                     gun_reload__isReloading : bool;
                     gun_reload__stateAcceptsInterruptRequest : bool;
                     gun_reload__state : int;
                     gun_reload__stateStartTime : float;
                     gun_reload__stateEndTime : float)
    if !gun_reload__isReloading
      return

    let progress = cvt(info.curTime,
                      gun_reload__stateStartTime,
                      gun_reload__stateEndTime,
                      0.0, 1.0)
    visual_log("State: {GUN_RELOAD_STATE_NAMES[gun_reload__state]}  CanInterrupt: {gun_reload__stateAcceptsInterruptRequest}  Progress: {progress}  for {eid}<{getEntityTemplateName(eid)}>")

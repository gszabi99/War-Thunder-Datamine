options no_aot
require ecs
require ecs.ecs_template
require DagorConsole
require %game.events
require %appGame.infantry.es.gun_reload_common
require %appGame.infantry.es.human_reload_common


[ecs_template]
struct gun_reload_debug
  gun_reload_debug : Tag

[console_cmd(name="gun_reload.show_state", hint="Show progress and name of current reload state")]
def gun_reload_debug_command()
  var heroEid = INVALID_ENTITY_ID
  let found = find_query() <| $ [es(REQUIRE=hero)] (eid : EntityId)
    heroEid = eid
    return has(eid, "gun_reload_debug")
  if heroEid == INVALID_ENTITY_ID
    console_print("no controlled hero, cannot toggle gun reload debug")
    return
  if found
    removeSubTemplate(heroEid, "gun_reload_debug")
  else
    addSubTemplate(heroEid, "gun_reload_debug")
  console_print("{found ? "deactivated" : "activated"} gun reload debug")


[es(after=gun_reload_calc_progress, REQUIRE=(hero, gun_reload_debug))]
def gun_reload_display_state_info(info : ParallelUpdateFrameDelayed;
                                  human_weap__currentGunEid : EntityId)
  query(human_weap__currentGunEid) <| $ [es] (eid : EntityId;
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


[es(REQUIRE=(hero, gun_reload_debug))]
def human_weap_reload_display_state_info(info : ParallelUpdateFrameDelayed;
                                         human_weap__currentGunEid : EntityId;
                                         human_weap__reloadGunEid : EntityId;
                                         human_weap__reloadStartTime : float;
                                         human_weap__reloadAtTime : float;
                                         human_weap__inspectStartTime : float;
                                         human_weap__inspectEndTime : float;
                                         human_weap__isQuickReload : bool;
                                         human_weap__isDualMagReload : bool;
                                         human_weap__singleReload : bool)
  let isReloading = human_weap__reloadAtTime > human_weap__reloadStartTime && human_weap__reloadStartTime <= info.curTime && info.curTime <= human_weap__reloadAtTime
  let isInspecting = human_weap__inspectStartTime <= info.curTime && info.curTime <= human_weap__inspectEndTime
  if !isReloading && !isInspecting
    return

  let progress = isReloading ? cvt(info.curTime, human_weap__reloadStartTime, human_weap__reloadAtTime, 0.0, 1.0) : cvt(info.curTime, human_weap__inspectStartTime, human_weap__inspectEndTime, 0.0, 1.0)
  let duration = isReloading ? (human_weap__reloadAtTime - human_weap__reloadStartTime) : (human_weap__inspectEndTime - human_weap__inspectStartTime)
  let styleGunEid = isReloading ? human_weap__reloadGunEid : human_weap__currentGunEid
  query(styleGunEid) <| $ [es] (eid : EntityId; gun_anim__reloadStyle : int)
    let styleName = (gun_anim__reloadStyle >= 0 && gun_anim__reloadStyle < length(GUN_RELOAD_STYLE_NAMES)) ? GUN_RELOAD_STYLE_NAMES[gun_anim__reloadStyle] : "INVALID({gun_anim__reloadStyle})"
    visual_log("Style: {styleName}  Duration: {duration}  Inspecting: {isInspecting}  Quick: {human_weap__isQuickReload}  DualMag: {human_weap__isDualMagReload}  Single: {human_weap__singleReload}  Progress: {progress}  for {eid}<{getEntityTemplateName(eid)}>")

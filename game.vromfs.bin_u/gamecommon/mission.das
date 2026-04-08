require ecs
require Unit
require IGroundModel
require Mission
require %game.events

[es(on_event=EventMissionUnload)]
def unload_mission_entities(evt : Event)
  ecs::query() <| $ [es(REQUIRE=missionObject)] (eid : EntityId)
    destroyEntity(eid)

[es(no_order)]
def delayed_action_update_es(act : ecs::UpdateStageInfoAct;
                             eid : EntityId;
                             delayed_action__doAtTime : float)
  if (delayed_action__doAtTime <= act.curTime)
    destroyEntity(eid)

[es(on_event=EventEntityCreated)]
def delayed_action_create_es(evt : Event;
                             var delayed_action__doAtTime : float&;
                             delayed_action__timer : float)
  if (delayed_action__doAtTime < 0.0)
    delayed_action__doAtTime = float(get_total_time()) + delayed_action__timer

[es(on_event=EventEntityDestroyed)]
def delayed_unit_shot_action_es(evt : Event;
                                delayed_unit_shot__unitName : string;
                                delayed_unit_shot__triggerGroup : int)
  find_query() <| $ [es] (unit__missionName : string; var unit__ref : UnitRef)
    let found = unit__missionName == delayed_unit_shot__unitName
    if (found)
      unit_single_shot(unit__ref.unit, delayed_unit_shot__triggerGroup)
    return found

[es(no_order)]
def disable_move_es(evt : CmdDisableMove;
                    disable__targets_list : StringList)
  for target_name in disable__targets_list
    if target_name == evt.name
      var gm = get_unit_by_eid(evt.eid) |> as_gm()
      if gm != null && gm.moveSys != null
        gm.moveSys.inactive = true

[es(tag=server, on_appear, REQUIRE=unit_tag__gm)]
def set_aimers_custom_settings_es(evt : Event;
                                  var unit__ref : UnitRef&;
                                  aimer_custom_setting__checkVisibilityTarget : bool;
                                  aimer_custom_setting__ignoreStopForFire : bool;
                                  aimer_custom_setting__targetAAA : bool;
                                  aimer_custom_setting__moveSpeedKAtShooting : float)
  var gm = unit__ref.unit |> as_gm()
  *gm |> set_check_visibility_target(aimer_custom_setting__checkVisibilityTarget)
  gm.mayTargetAAA = aimer_custom_setting__targetAAA
  gm.moveSpeedKAtShooting = aimer_custom_setting__moveSpeedKAtShooting
  if aimer_custom_setting__ignoreStopForFire
    *gm |> set_ignore_stop_for_fire(true)

[es(tag=server, on_appear, REQUIRE=unit_tag__gm)]
def set_custom_gun_properties_settings_es(evt : Event;
                                          var unit__ref : UnitRef&;
                                          custom_gun_properties__tiggerGroupNo : IntList;
                                          custom_gun_properties__aimMinDist : float;
                                          custom_gun_properties__aimMaxDist : float;
                                          custom_gun_properties__attackMaxDist : float;
                                          custom_gun_properties__attackMinHeight : float;
                                          custom_gun_properties__attackMaxHeight : float)
  var gm = unit__ref.unit |> as_gm()
  for triggerNo in custom_gun_properties__tiggerGroupNo
    (*gm) |> set_gun_properties_from_mission(triggerNo, false, custom_gun_properties__aimMaxDist,
                                             custom_gun_properties__aimMinDist,
                                             custom_gun_properties__attackMaxDist,
                                             custom_gun_properties__attackMinHeight,
                                             custom_gun_properties__attackMaxHeight)

[es(tag=server, on_event=CmdInitComponent, REQUIRE=(unit_tag__gm, disable_radar_on_start))]
def disable_radar_on_start_es(evt : Event;
                              var unit__ref : UnitRef&)
  var gm = unit__ref.unit |> as_gm()
  gm.useSearchRadar = false

[es(tag=server, on_appear, REQUIRE=unit_tag__gm)]
def set_rearm_on_field_time_es(evt : Event;
                               var unit__ref : UnitRef&;
                               unit_params__rearmOnFieldTime : float)
  if unit_params__rearmOnFieldTime > 0.
    var gm = as_gm(unit__ref.unit)
    gm.rearmOnField.rearmTime = unit_params__rearmOnFieldTime
    gm.rearmOnField.isRearmAllowedByMission = true
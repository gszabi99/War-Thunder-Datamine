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


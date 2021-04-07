require ecs
require Mission

[es (on_event=EventMissionUnload)]
def unload_mission_entities(evt : Event)
  ecs::query() <| $ [es(REQUIRE=missionObject)] (eid : EntityId)
    destroyEntity(eid)

[es (no_order)]
def delayed_action_update_es(act : ecs::UpdateStageInfoAct;
                      eid : EntityId;
                      delayed_action_dot_doAtTime : float)
  if (delayed_action_dot_doAtTime <= act.curTime)
    destroyEntity(eid)

[es (on_event=EventEntityCreated)]
def delayed_action_create_es(evt:Event;
                             var delayed_action_dot_doAtTime : float&;
                             delayed_action_dot_timer : float)
  if (delayed_action_dot_doAtTime < 0.0)
    delayed_action_dot_doAtTime = float(get_total_time()) + delayed_action_dot_timer

[es (on_event=EventEntityDestroyed)]
def delayed_unit_shot_action_es(evt:Event;
                                delayed_unit_shot_dot_unitName : string;
                                delayed_unit_shot_dot_triggerGroup : int)
  find_query() <| $ [es](missionUnitName : string; uid : int)
    let found = missionUnitName == delayed_unit_shot_dot_unitName
    if (found)
      unit_single_shot(uid, delayed_unit_shot_dot_triggerGroup)
    return found
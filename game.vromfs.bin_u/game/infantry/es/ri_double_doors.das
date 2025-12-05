require ecs
require %appGame.infantry.es.ri_double_doors_common
require RendInst








[es(tag=server, REQUIRE=isDoor, on_appear)] 
def double_doors_spawned_es(evt : Event;
                            eid : EntityId;
                            door_operations__openedAngle : float;
                            door_operations__closedAngle : float;
                            ri_extra : RiExtraComponent;
                            transform aka current_transform : float3x4;
                            var pair_door__eid aka current_pair_door__eid : EntityId&;
                            pair_door__searchDist : float = 3.0;
                            pair_door__checkMargin : float = 0.05)
  pair_riextra_door_impl(eid, door_operations__openedAngle, door_operations__closedAngle, ri_extra, current_transform, current_pair_door__eid, pair_door__searchDist, pair_door__checkMargin)
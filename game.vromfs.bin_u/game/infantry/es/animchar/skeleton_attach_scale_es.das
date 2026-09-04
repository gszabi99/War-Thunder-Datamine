require ecs
require AnimV20
require DagorSystem
require GeomNodeTree

require %appGame.wt_events
require %appGame.infantry.es.animchar.attach_common
require ecs.safe
require ecs.common


[es(tag=server, on_appear)]
def skeleton_hide_node_attach_created_es(evt : Event;
                                         animchar_attach__attachedTo : EntityId)
  let parentEid = find_base_attach_parent(animchar_attach__attachedTo)
  query(parentEid) <| $ [es(REQUIRE=human_equipment__slots)] ()
    sendEvent(parentEid, CmdInitScaleSkeletonAttach())

[es(tag=server, on_appear, on_event=CmdInitScaleSkeletonAttach, track=human_equipment__slots)]
def skeleton_hide_node_attach_init_es(evt : Event;
                                      human_equipment__slots : Object)
  apply_slots_scale_attaches(human_equipment__slots)
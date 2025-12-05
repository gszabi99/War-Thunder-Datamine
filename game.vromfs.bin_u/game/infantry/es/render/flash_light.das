require ecs
require %game.events
require AnimV20
require GeomNodeTree


[es(tag=render, on_appear)]
def flash_light_init(evt : Event;
                     animchar : AnimcharBaseComponent;
                     flashlight__nodeName : string;
                     var flashlight__nodeId : int&)
  flashlight__nodeId = geomtree_findNodeIndex(*animchar.nodeTree, flashlight__nodeName)

[es(tag=render, on_appear, track=flashlight__on, after=flash_light_init)]
def flash_light_create_light(evt : Event;
                             flashlight__on : bool;
                             flashlight__template : string;
                             flashlight__nodeId : int;
                             var flashlight__eid : EntityId&)
  if flashlight__nodeId > 0
    if flashlight__on
      if !flashlight__eid
        flashlight__eid = createEntity(flashlight__template)
    elif !!flashlight__eid
      destroyEntity(flashlight__eid)
      flashlight__eid = INVALID_ENTITY_ID

[es(tag=render, on_disappear)]
def flash_light_destroy_light(evt : Event;
                              flashlight__eid : EntityId)
  if !!flashlight__eid
    destroyEntity(flashlight__eid)

[es(tag=render, on_appear, track=flashlight__on)]
def switch_flash_light(evt : Event;
                       flashlight__eid : EntityId&;
                       flashlight__on : bool;
                       flashlight__brightness : float)
  query(flashlight__eid) <| $ [es] (var light__brightness : float&)
    light__brightness = flashlight__on ? flashlight__brightness : 0.

[es(tag=render, on_appear)]
def switch_flash_light_appear(evt : Event;
                              eid : EntityId;
                              var light__brightness : float&)
  query() <| $ [es] (flashlight__eid : EntityId&;
                     flashlight__on : bool;
                     flashlight__brightness : float)
    if flashlight__eid == eid
      light__brightness = flashlight__on ? flashlight__brightness : 0.

[es(tag=render)]
def switch_blinking_flash_light(info : ParallelUpdateFrameDelayed;
                                flashlight__blinkOnPeriod : float;
                                flashlight__blinkOffPeriod : float;
                                flashlight__blinking : bool;
                                var flashlight__on : bool&;
                                var flashlight__blinkNextTime : float&)
  if !flashlight__blinking || flashlight__blinkNextTime > info.curTime
    return
  flashlight__on = !flashlight__on
  flashlight__blinkNextTime = info.curTime + (flashlight__on ? flashlight__blinkOnPeriod : flashlight__blinkOffPeriod)

[es(tag=render, on_event=ParallelUpdateFrameDelayed)]
def flash_light_update(evt : Event;
                       animchar : AnimcharBaseComponent;
                       flashlight__nodeId : int;
                       flashlight__eid : EntityId;
                       flashlight__inverseTm = true)
  query(flashlight__eid) <| $ [es] (var transform : float3x4&)
    geomtree_getNodeWtmScalar(*animchar.nodeTree, flashlight__nodeId, transform)
    if flashlight__inverseTm
      transform[0] *= -1.
      transform[2] *= -1.

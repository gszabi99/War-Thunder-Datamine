require ecs
require %game.events
require %gameDev.dev_events
require %appGame.wt_events

[es(tag=gameClient, on_appear, after=anim_init_irq_listener_es)]
def shooting_soldier_irq_on_init(evt : Event;
                                 anim_irq__eventNames : Object;
                                 var shooting_soldier__irqId : int&)
  for event in anim_irq__eventNames
    let eventObj = get_ecs_object(event.value)
    if eventObj != null
      let eventName = event.key
      if !empty(eventName) && eventName == "shoot"
        shooting_soldier__irqId = get_int(*eventObj, "irqId") ?? -1
        break


[es(tag=gameClient)]
def shooting_soldier_on_irq_event(evt : EventAnimIrq;
                                  eid : EntityId;
                                  shooting_soldier__irqId : int)
  if evt.irqType == shooting_soldier__irqId
    sendEventImmediate(eid, EventShot())

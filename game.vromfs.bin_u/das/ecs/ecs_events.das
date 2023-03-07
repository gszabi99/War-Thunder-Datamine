module ecs_events shared public
require ecs
require daslib/templates

//example
//def my_es(evt : Event)
//  if evt.eventType == get_ecs_event_type(type<MyEvent>)
[template(t), unused_argument(t)]
def get_ecs_event_type(t : auto(T))
  let evt_name = typeinfo(undecorated_typename type<T- const>)
  return ecs_hash(evt_name)

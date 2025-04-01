require ecs
require DagorSystem

[es(on_appear)]
def ammo_item(evt : Event;
              eid : EntityId;
              ammo_holder__templateName : string;
              var ammo_holder__id : int&)
  if !(ammo_holder__templateName |> empty())
    ammo_holder__id = int(ecs_hash(ammo_holder__templateName))
  else
    logerr("Unacceptable to have empty \"ammo_holder.templateName\" component in template {getEntityTemplateName(eid)}")

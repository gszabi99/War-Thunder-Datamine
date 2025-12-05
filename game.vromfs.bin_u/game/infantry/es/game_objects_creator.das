require ecs
require DagorMath

def is_point_in_box_zone(pos : float3; transform : float3x4)
  var zonePos : float3 = inverse(transform) * float3(pos.x, 0.0, pos.z)
  zonePos.y = 0.5
  return BBox3(float3(-0.5, 0.0, -0.5), float3(0.5, 1.0, 0.5)) & zonePos

[es(tag=server, REQUIRE=object_creator, on_appear)]
def on_game_objects_creator_init(evt : Event;
                                 transform aka object_transform : float3x4;
                                 object_creator__template : string;
                                 object_creator__requireTag : string;
                                 var object_creator__createdEid : EntityId&)
  if !!object_creator__createdEid
    return
  find_query() <| $ [es] (transform aka zone_transform : float3x4;
                          object_creator__zoneTag : string)
    if object_creator__requireTag == object_creator__zoneTag && is_point_in_box_zone(object_transform[3], zone_transform)
      object_creator__createdEid = createEntity(object_creator__template) <| $(var init : ComponentsInitializer)
        set(init, "transform", object_transform)
      return true
    return false

[es(tag=server, on_appear)]
def on_game_objects_creator_zone_init(evt : Event;
                                      transform aka zone_transform : float3x4;
                                      object_creator__zoneTag : string)
  query() <| $ [es] (transform aka object_transform : float3x4;
                     object_creator__template : string;
                     object_creator__requireTag : string;
                     var object_creator__createdEid : EntityId&)
    if !object_creator__createdEid && object_creator__requireTag == object_creator__zoneTag && is_point_in_box_zone(object_transform[3], zone_transform)
      object_creator__createdEid = createEntity(object_creator__template) <| $(var init : ComponentsInitializer)
        set(init, "transform", object_transform)
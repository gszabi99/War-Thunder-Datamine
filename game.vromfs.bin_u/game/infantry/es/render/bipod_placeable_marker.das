require ecs
require math.base
require %game.events

[es(tag=render, REQUIRE=hero, track=bipod__placeable, track=bipod__enabled)]
def bipod_spawn_placeable_marker(evt : Event;
                                 bipod__placeable : bool;
                                 bipod__enabled : bool;
                                 bipod__placePos : float3;
                                 var bipod__placeableMarker : EntityId&)
  if bipod__placeable && !bipod__enabled
    if !bipod__placeableMarker
      bipod__placeableMarker = createEntity("bipod_placeable_marker") <| $(var init)
        set(init, "bipod_marker__reachPos", bipod__placePos)
        set(init, "bipod_marker__placePos", bipod__placePos)
  else
    if !!bipod__placeableMarker
      destroyEntity(bipod__placeableMarker)
      bipod__placeableMarker = INVALID_ENTITY_ID

[es(tag=render, REQUIRE=hero)]
def bipod_change_placeable_tm(info : ParallelUpdateFrameDelayed;
                              bipod__placeableMarker : EntityId;
                              bipod__placePos : float3)
  if !!bipod__placeableMarker
    query(bipod__placeableMarker) <| $ [es] (var bipod_marker__reachPos : float3&;
                                             var bipod_marker__placePos : float3&;
                                             bipod_marker__reachThreshold : float;
                                             bipod_marker__viscosity : float)
      if distance_sq(bipod_marker__reachPos, bipod__placePos) > square(bipod_marker__reachThreshold)
        bipod_marker__reachPos = bipod__placePos
      bipod_marker__placePos = approach(bipod_marker__placePos, bipod_marker__reachPos, info.dt, bipod_marker__viscosity)


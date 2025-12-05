require ecs
require ecs.safe
require soundEvent
require DagorMath


[es(tag=sound, on_appear, track=sound_preset__isLoaded, REQUIRE=(watchedByPlr, deadEntity))]
def dead_human_snapshot_sound_appear(evt : Event;
                                     sound_preset__isLoaded : bool;
                                     dead_human_snapshot_sound__path : string;
                                     var dead_human_snapshot_sound__event : SoundEvent&;
                                     transform : float3x4)
  if sound_preset__isLoaded
    dead_human_snapshot_sound__event.abandonOnReset = true
    dead_human_snapshot_sound__event |> play(dead_human_snapshot_sound__path, transform[3])
  else
    dead_human_snapshot_sound__event |> release()


[es(tag=sound, on_disappear, REQUIRE=(watchedByPlr, deadEntity))]
def dead_human_snapshot_sound_disappear(evt : Event;
                                        var dead_human_snapshot_sound__event : SoundEvent&)
  abandon(dead_human_snapshot_sound__event)


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, REQUIRE=(watchedByPlr, deadEntity))]
def dead_human_snapshot_sound_update(evt : Event;
                                     dead_human_snapshot_sound__event : SoundEvent&;
                                     dead_human_snapshot_sound__colorGradingItem : string)

  if !is_valid_handle_value(dead_human_snapshot_sound__event)
    return

  var saturation = 1.
  find_query() <| $ [es] (color_grading_items : Array)

    let itemUniqueId = ecs_hash(dead_human_snapshot_sound__colorGradingItem)
    for itemCmp in color_grading_items 
      let itemObj = itemCmp as Object
      if uint(itemObj?.unique_id ?? 0) == itemUniqueId
        let lifeTime = get_float(*itemObj, "life_time") ?? 0.
        let timings = get_Point3(*itemObj, "timings") ?? float3(0, 10000, 0)
        let state = lifeTime < timings.x ? safediv(lifeTime, timings.x) : lifeTime < timings.x + timings.y ? 1. : saturate(1. - safediv((lifeTime - timings.x - timings.y), timings.z))
        saturation = 1. - saturate(state)
        break

    return true

  set_var(dead_human_snapshot_sound__event, "death_cam_saturation", saturation)

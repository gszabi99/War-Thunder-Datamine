require ecs


[es(tag=sound, on_appear, REQUIRE=disableVehicleSound)]
def vehicle_sound_disable_on_appear(evt : Event)
  query() <| $ [es(REQUIRE=vehicleSound)] (var sound_control__allowSound : bool&)
    sound_control__allowSound = false


[es(tag=sound, on_disappear, REQUIRE=disableVehicleSound)]
def vehicle_sound_disable_on_disappear(evt : Event)
  query() <| $ [es(REQUIRE=vehicleSound)] (var sound_control__allowSound : bool&)
    sound_control__allowSound = true


[es(tag=sound, on_appear, REQUIRE=vehicleSound)]
def vehicle_sound_enable(evt : Event; var sound_control__allowSound : bool&)
  sound_control__allowSound = !(find_query() <| $ [es(REQUIRE=disableVehicleSound)] () => true)

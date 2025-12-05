require ecs
require vehicle
require sound_utils.modules.sound_player_common


[es(tag=sound, on_event=ParallelUpdateFrameDelayed, after=(vehicle_phys_es, sound_control_update, sound_begin_update_es), before=sound_end_update_es)]
def ground_vehicle_gear_sound(evt : Event;
                              vehicle_net_phys : VehiclePhysActor;
                              var ground_vehicle_gear_sound__gear : int&;
                              @shared_comp ground_vehicle_gear_sound__path : Object;
                              is_watched_sound : bool;
                              sound_tags : Object;
                              transform : float3x4)
  if ground_vehicle_gear_sound__gear != int(vehicle_net_phys.phys.currentState.currentGear) && ground_vehicle_gear_sound__gear >= 0
    sound_player_common::play_path(ground_vehicle_gear_sound__path, sound_tags, is_watched_sound, transform[3])
  ground_vehicle_gear_sound__gear = int(vehicle_net_phys.phys.currentState.currentGear)

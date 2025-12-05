require ecs
require math.base
require DagorMath
require CollRes
require Dacoll
require PhysMat
require vehicle
require soundEvent
require vehicleSoundProps
require sound_utils.modules.sound_player_common
require danetlibs.renderer.includes.pufd_events


[es(tag=sound, after=sound_begin_update_es, before=(vehicle_tracks_sound, sound_end_update_es))]
def ground_vehicle_suspension_sound(info : ParallelUpdateFrameDelayed;
                                    vehicle_net_phys : VehiclePhysActor;
                                    ground_vehicle_suspension_sound__hitToVar : float2;
                                    var ground_vehicle_suspension_sound__event : SoundEvent&;
                                    var ground_vehicle_suspension_sound__hitTime : float&;
                                    var ground_vehicle_suspension_sound__hitForce : float&;
                                    vehicle_sound_phys_state__noiseReduction : float;
                                    @shared_comp ground_vehicle_suspension_sound__path : Object;
                                    sound_tags : Object;
                                    isAlive : bool;
                                    transform : float3x4)
  var total = 0.
  if isAlive
    for idx in range(int(vehicle_net_phys.phys.currentState.wheelCount))
      let wheel = vehicle_phys_get_wheel(vehicle_net_phys.phys, idx)
      if wheel != null
        total += cvt(abs((*wheel).velocity), ground_vehicle_suspension_sound__hitToVar.x, ground_vehicle_suspension_sound__hitToVar.y, 0., 1.)
    total *= vehicle_sound_phys_state__noiseReduction
  sound_player_common::play_parameterized(ground_vehicle_suspension_sound__event, total, ground_vehicle_suspension_sound__hitForce, "force", transform[3], ground_vehicle_suspension_sound__path, sound_tags, true, info.curTime, ground_vehicle_suspension_sound__hitTime)

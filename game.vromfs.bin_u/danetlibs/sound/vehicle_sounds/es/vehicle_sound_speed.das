require ecs
require DagorMath
require math.base
require math.ang
require vehicle
require danetlibs.renderer.includes.pufd_events




[es(tag=sound, on_appear)]
def vehicle_sound_speed_appear(evt : Event;
                               var vehicle_sound_speed__prevTransform : float3x4&;
                               transform : float3x4)
  vehicle_sound_speed__prevTransform = transform


[es(tag=sound, after=(vehicle_phys_es, sound_control_update, sound_begin_update_es), before=sound_end_update_es)]
def vehicle_sound_speed_update(info : ParallelUpdateFrameDelayed;
                               var vehicle_sound_speed__prevTransform : float3x4&;
                               var vehicle_sound_speed_state__speed : float&;
                               var vehicle_sound_speed__summary : float4&;
                               var vehicle_sound_speed_state__linearVelocity : float3&;
                               transform : float3x4)
  vehicle_sound_speed_state__linearVelocity = (transform[3] - vehicle_sound_speed__prevTransform[3]) * safeinv(info.dt)
  vehicle_sound_speed__prevTransform = transform
  vehicle_sound_speed__summary = float4(length(vehicle_sound_speed_state__linearVelocity), vehicle_sound_speed__summary.x, vehicle_sound_speed__summary.y, vehicle_sound_speed__summary.z)
  vehicle_sound_speed_state__speed = (vehicle_sound_speed__summary.x + vehicle_sound_speed__summary.y + vehicle_sound_speed__summary.z + vehicle_sound_speed__summary.w) * 0.25

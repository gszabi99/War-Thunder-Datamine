require ecs
require app
require DagorShaders
require DagorMath
require %game.events
require %game.unit.unit_events


let drone_white_noise_effectVarId = get_shader_variable_id("postfx_static_tv_fade", true)


[es(tag=render, track=static_tv_rendering__noise_level, on_appear)]
def apply_white_noise_effect_es(evt : Event;
                                static_tv_rendering__noise_level : float)
  DagorShaders::set_real(drone_white_noise_effectVarId, static_tv_rendering__noise_level)


[es(tag=render, no_order, REQUIRE=static_tv_rendering__noise_level)]
def white_noise_effect_timer_es(info : ParallelUpdateFrameDelayed;
                                eid : EntityId;
                                var static_tv_rendering__noise_end_time : float&)
  if static_tv_rendering__noise_end_time > 0.0 && info.curTime > static_tv_rendering__noise_end_time
    static_tv_rendering__noise_end_time = -1.0
    set(eid, "static_tv_rendering__noise_level", -1.0)


[es(tag=render, REQUIRE=(isDrone, controlledHero), before=player_send_lost_control_on_unit_death_es)]
def set_white_noise_effect_on_drone_crash_es(evt : EventUnitBecameDead;
                                             drone__owner : EntityId)
  query(drone__owner) <| $ [es(REQUIRE=human)] (human_white_noise_effect__maxIntensity : float;
                                                human_white_noise_effect__duration : float)
    query() <| $ [es] (var static_tv_rendering__noise_level : float&;
                       var static_tv_rendering__noise_end_time : float&)
      static_tv_rendering__noise_end_time = get_sync_time() + human_white_noise_effect__duration
      static_tv_rendering__noise_level = human_white_noise_effect__maxIntensity


[es(tag=render, no_order, REQUIRE=(controlledHero, isDrone))]
def drone_white_noise_on_distance(info : ParallelUpdateFrameDelayed;
                                  isAlive : bool;
                                  drone__owner : EntityId;
                                  transform aka drone_transform : float3x4;
                                  drone__coverageArea : float2;
                                  drone__distanceWhiteNoiseIntensity : float2 = float2(0.1, 0.6))
  if !isAlive
    return
  query(drone__owner) <| $ [es] (transform aka owner_transform : float3x4)
    let distance = length(drone_transform[3] - owner_transform[3])
    let intensityLevel = clamp(cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                   drone__distanceWhiteNoiseIntensity.x, drone__distanceWhiteNoiseIntensity.y), 0.0, 1.0)
    query() <| $ [es] (var static_tv_rendering__noise_level : float&)
      static_tv_rendering__noise_level = intensityLevel


[es(tag=render, track=human__controlledDrone, REQUIRE=(controlledHero, human), on_appear)]
def drone_white_noise_on_switch_to_soldier(evt : Event;
                                           human__controlledDrone : EntityId)
  if !human__controlledDrone
    query() <| $ [es] (static_tv_rendering__noise_end_time : float;
                       var static_tv_rendering__noise_level : float&)
      if static_tv_rendering__noise_end_time < 0.0
        static_tv_rendering__noise_level = -1.0

require ecs
require app
require DagorMath
require %game.events
require %game.unit.unit_events


[es(tag=render, no_order, REQUIRE=drone_camera_vhs_effect)]
def white_noise_effect_timer_es(info : ParallelUpdateFrameDelayed;
                                vhs_camera__resolutionDownscaleDefault : float;
                                var vhs_camera__noiseEndTime : float&;
                                var vhs_camera__isActive : bool&;
                                var vhs_camera__resolutionDownscale : float&)
  if vhs_camera__isActive && vhs_camera__noiseEndTime > 0.0 && info.curTime > vhs_camera__noiseEndTime
    vhs_camera__isActive = false
    vhs_camera__resolutionDownscale = vhs_camera__resolutionDownscaleDefault
    vhs_camera__noiseEndTime = -1.0


[es(tag=render, REQUIRE=(isDrone, watchedByPlr), before=player_send_lost_control_on_unit_death_es)]
def set_white_noise_effect_on_drone_crash_es(evt : EventUnitBecameDead;
                                             drone__owner : EntityId)
  query(drone__owner) <| $ [es(REQUIRE=human)] (human_white_noise_effect__duration : float)
    query() <| $ [es(REQUIRE=drone_camera_vhs_effect)] (vhs_camera__noiseIntensityDestroyed : float;
                                                        vhs_camera__saturationMultiplierDestroyed : float;
                                                        vhs_camera__dynamicRangeMinDestroyed : float;
                                                        vhs_camera__dynamicRangeMaxDestroyed : float;
                                                        vhs_camera__dynamicRangeGammaDestroyed : float;
                                                        vhs_camera__scanlineHeightDestroyed : float;
                                                        vhs_camera__noiseSaturationDestroyed : float;
                                                        vhs_camera__noiseUvScaleDestroyed : float;
                                                        vhs_camera__chromaticAberrationIntensityDestroyed : float;
                                                        vhs_camera__chromaticAberrationStartDestroyed : float;
                                                        vhs_camera__resolutionDownscaleDestroyed : float;
                                                        var vhs_camera__noiseEndTime : float&;
                                                        var vhs_camera__isActive : bool&;
                                                        var vhs_camera__noiseIntensity : float&;
                                                        var vhs_camera__saturationMultiplier : float&;
                                                        var vhs_camera__dynamicRangeMin : float&;
                                                        var vhs_camera__dynamicRangeMax : float&;
                                                        var vhs_camera__dynamicRangeGamma : float&;
                                                        var vhs_camera__scanlineHeight : float&;
                                                        var vhs_camera__noiseSaturation : float&;
                                                        var vhs_camera__noiseUvScale : float&;
                                                        var vhs_camera__chromaticAberrationIntensity : float&;
                                                        var vhs_camera__chromaticAberrationStart : float&;
                                                        var vhs_camera__resolutionDownscale : float&)
      vhs_camera__isActive = true
      vhs_camera__noiseIntensity = vhs_camera__noiseIntensityDestroyed
      vhs_camera__saturationMultiplier = vhs_camera__saturationMultiplierDestroyed
      vhs_camera__dynamicRangeMin = vhs_camera__dynamicRangeMinDestroyed
      vhs_camera__dynamicRangeMax = vhs_camera__dynamicRangeMaxDestroyed
      vhs_camera__dynamicRangeGamma = vhs_camera__dynamicRangeGammaDestroyed
      vhs_camera__scanlineHeight = vhs_camera__scanlineHeightDestroyed
      vhs_camera__noiseSaturation = vhs_camera__noiseSaturationDestroyed
      vhs_camera__noiseUvScale = vhs_camera__noiseUvScaleDestroyed
      vhs_camera__chromaticAberrationIntensity = vhs_camera__chromaticAberrationIntensityDestroyed
      vhs_camera__chromaticAberrationStart = vhs_camera__chromaticAberrationStartDestroyed
      vhs_camera__resolutionDownscale = vhs_camera__resolutionDownscaleDestroyed
      vhs_camera__noiseEndTime = get_sync_time() + human_white_noise_effect__duration


[es(tag=render, no_order, REQUIRE=(watchedByPlr, isDrone))]
def drone_white_noise_on_distance(info : ParallelUpdateFrameDelayed;
                                  isAlive : bool;
                                  drone__owner : EntityId;
                                  transform aka drone_transform : float3x4;
                                  drone__coverageArea : float2)
  if !isAlive
    return
  query(drone__owner) <| $ [es] (transform aka owner_transform : float3x4)
    let distance = length(drone_transform[3] - owner_transform[3])
    query() <| $ [es(REQUIRE=drone_camera_vhs_effect)] (vhs_camera__noiseIntensityNear : float;
                                                        vhs_camera__noiseIntensityFar : float;
                                                        vhs_camera__saturationMultiplierNear : float;
                                                        vhs_camera__saturationMultiplierFar : float;
                                                        vhs_camera__dynamicRangeMinNear : float;
                                                        vhs_camera__dynamicRangeMinFar : float;
                                                        vhs_camera__dynamicRangeMaxNear : float;
                                                        vhs_camera__dynamicRangeMaxFar : float;
                                                        vhs_camera__dynamicRangeGammaNear : float;
                                                        vhs_camera__dynamicRangeGammaFar : float;
                                                        vhs_camera__scanlineHeightNear : float;
                                                        vhs_camera__scanlineHeightFar : float;
                                                        vhs_camera__noiseSaturationNear : float;
                                                        vhs_camera__noiseSaturationFar : float;
                                                        vhs_camera__noiseUvScaleNear : float;
                                                        vhs_camera__noiseUvScaleFar : float;
                                                        vhs_camera__chromaticAberrationIntensityNear : float;
                                                        vhs_camera__chromaticAberrationIntensityFar : float;
                                                        vhs_camera__chromaticAberrationStartNear : float;
                                                        vhs_camera__chromaticAberrationStartFar : float;
                                                        var vhs_camera__noiseIntensity : float&;
                                                        var vhs_camera__saturationMultiplier : float&;
                                                        var vhs_camera__dynamicRangeMin : float&;
                                                        var vhs_camera__dynamicRangeMax : float&;
                                                        var vhs_camera__dynamicRangeGamma : float&;
                                                        var vhs_camera__scanlineHeight : float&;
                                                        var vhs_camera__noiseSaturation : float&;
                                                        var vhs_camera__noiseUvScale : float&;
                                                        var vhs_camera__chromaticAberrationIntensity : float&;
                                                        var vhs_camera__chromaticAberrationStart : float&;
                                                        var vhs_camera__isActive : bool&)
      vhs_camera__noiseIntensity = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                       vhs_camera__noiseIntensityNear, vhs_camera__noiseIntensityFar)
      vhs_camera__saturationMultiplier = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                             vhs_camera__saturationMultiplierNear, vhs_camera__saturationMultiplierFar)
      vhs_camera__dynamicRangeMin = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                        vhs_camera__dynamicRangeMinNear, vhs_camera__dynamicRangeMinFar)
      vhs_camera__dynamicRangeMax = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                        vhs_camera__dynamicRangeMaxNear, vhs_camera__dynamicRangeMaxFar)
      vhs_camera__dynamicRangeGamma = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                          vhs_camera__dynamicRangeGammaNear, vhs_camera__dynamicRangeGammaFar)
      vhs_camera__scanlineHeight = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                       vhs_camera__scanlineHeightNear, vhs_camera__scanlineHeightFar)
      vhs_camera__noiseSaturation = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                        vhs_camera__noiseSaturationNear, vhs_camera__noiseSaturationFar)
      vhs_camera__noiseUvScale = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                     vhs_camera__noiseUvScaleNear, vhs_camera__noiseUvScaleFar)
      vhs_camera__chromaticAberrationIntensity = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                                     vhs_camera__chromaticAberrationIntensityNear, vhs_camera__chromaticAberrationIntensityFar)
      vhs_camera__chromaticAberrationStart = cvt(distance, drone__coverageArea.x, drone__coverageArea.y,
                                                 vhs_camera__chromaticAberrationStartNear, vhs_camera__chromaticAberrationStartFar)
      vhs_camera__isActive = true


[es(tag=render, track=human__controlledDrone, REQUIRE=(watchedByPlr, human), on_appear)]
def drone_white_noise_on_switch_to_soldier(evt : Event;
                                           human__controlledDrone : EntityId)
  if !human__controlledDrone
    query() <| $ [es(REQUIRE=drone_camera_vhs_effect)] (vhs_camera__noiseEndTime : float;
                                                        vhs_camera__resolutionDownscaleDefault : float;
                                                        var vhs_camera__isActive : bool&;
                                                        var vhs_camera__resolutionDownscale : float&)
      if vhs_camera__noiseEndTime < 0.0
        vhs_camera__isActive = false
        vhs_camera__resolutionDownscale = vhs_camera__resolutionDownscaleDefault

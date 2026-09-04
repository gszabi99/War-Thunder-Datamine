require ecs
require math.base
require DagorMath
require strings
require DagorDataBlock
require Unit
require HeavyVehicleModel
require vehicle
require soundEvent
require WTHangar
require %game.events
require %game.sound.sound_events
require app
require DagorConsole


[es(tag=sound, on_appear, REQUIRE=(heroVehicle))]
def suspension_sound_appear_hero_vehicle_es(evt : Event;
                                            eid : EntityId;
                                            unit__className : string)
  if is_in_hangar()
    return
  if has(eid, "suspension_sound__event")
    return
  datablock_load_cached("gameData/units/" + unit__className + ".blk") <| $(modelBlk : DataBlock)
    let soundBlk = modelBlk |> datablock_get_block_by_name("sound")
    if soundBlk == null
      return
    let trackName = soundBlk |> datablock_getStr("TrackSoundName", "")
    if trackName |> find("tracks") < 0
      return
    let path = soundBlk |> datablock_getStr("TrackSoundPathStudio", "")
    let suspEvent = trackName |> replace("tracks", "suspension")
    if path == "" || !has(suspEvent, path)
      return

    addSubTemplate(eid, "gm_suspension_sound") <| $(var init : ComponentsInitializer)
      set(init, "suspension_sound__event_name", path + "/" + suspEvent)
      set(init, "suspension_sound__prev_shock", VERY_BIG_NUMBER)


[es(tag=sound, on_disappear, REQUIRE=(heroVehicle))]
def suspension_sound_disappear_hero_vehicle_es(evt : Event;
                                               eid : EntityId)
  removeSubTemplate(eid, "gm_suspension_sound")


[es(tag=sound)]
def suspension_sound_update_es(act : ParallelUpdateFrameDelayed;
                               unit__ref : UnitRef;
                               vehicle_net_phys : VehiclePhysActor;
                               suspension_sound__event_name : das_string;
                               var suspension_sound__event : SoundEvent&;
                               var suspension_sound__last_sinking : FloatList&;
                               var suspension_sound__prev_shock : float&)
  let unit = unit__ref.unit
  if unit == null
    return

  if unit.isDelayed || !unit.isAlive
    if is_playing(suspension_sound__event)
      abandon(suspension_sound__event)
    return

  let hv = unit |> as_hv()
  if hv == null
    return
  let wheelCount = int(vehicle_net_phys.phys.currentState.wheelCount)
  if wheelCount == 0
    return

  let startDelay = 25
  if !is_playing(suspension_sound__event)
    if vehicle_net_phys.phys.currentState.atTick > startDelay && suspension_sound__event_name != ""
      suspension_sound__event |> play(string(suspension_sound__event_name), unit.pos)
    if !is_playing(suspension_sound__event)
      return

  if length(suspension_sound__last_sinking) < wheelCount
    suspension_sound__last_sinking |> resize(wheelCount)

  var skew = 0.
  for i in range(wheelCount)
    let wheel = vehicle_phys_get_wheel(vehicle_net_phys.phys, i)
    let sinking = vehicle_phys_get_wheel_sinking(vehicle_net_phys.phys.currentState, i)
    var delta = abs(sinking - suspension_sound__last_sinking[i])
    suspension_sound__last_sinking[i] = lerp(suspension_sound__last_sinking[i], sinking, act.dt)
    if wheel != null
      let suspLimit = abs(wheel.maxOffsets.z - wheel.maxOffsets.y)
      if suspLimit > 0.
        delta = cvt(delta, 0., suspLimit, 0., 1.)
        skew = max(delta, skew)

  let shockSummary = vehicle_net_phys.phys.currentState.soundShockSummary
  let shockDelta = shockSummary > suspension_sound__prev_shock ? shockSummary - suspension_sound__prev_shock : 0.
  suspension_sound__prev_shock = shockSummary
  let weight = cvt(shockDelta, 0.34, 1.5, 0., 1.)

  let maxSpeed = hv.getMaxSpeed
  let speed = cvt(unit.speed, 0., maxSpeed > 0. ? maxSpeed : 1., 0., 100.)

  suspension_sound__event |> set_var_optional("skew", skew)
  suspension_sound__event |> set_var_optional("weight", weight)
  suspension_sound__event |> set_var_optional("speed", speed)
  suspension_sound__event |> set_pos(unit.pos)

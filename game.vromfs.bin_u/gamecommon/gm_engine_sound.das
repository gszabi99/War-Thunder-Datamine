require ecs
require DagorMath
require math.base
require DagorSystem
require DagorConsole
require Unit
require IGroundModel
require soundEvent
require soundSystem
require DagorDataBlock
require HeroManager
require %game.unit.unit_events
require %game.events
require strings
require app


[es(tag=sound)]
def gm_engine_sound_init_es(evt : CmdInitComponent;
                            eid : EntityId;
                            uid : int;
                            var gm_engine_sound__pos_offset : float3&;
                            var gm_engine_sound__load_smooth : float&;
                            var gm_engine_sound__event_name : das_string&;
                            var gm_engine_sound__event_inside_name : das_string&;
                            var gm_engine_sound__start_event_name : das_string&;
                            var gm_engine_sound__stop_event_name : das_string&;
                            var gm_engine_sound__start_inside_name : das_string&;
                            var gm_engine_sound__stop_inside_name : das_string&)
  let unit = get_unit(uid)
  if unit == null
    addSubTemplate(eid, "disabled_update")
    return

  let gm = unit |> as_gm()
  if gm == null
    addSubTemplate(eid, "disabled_update")
    return
  if !gm.needLoadSounds
    addSubTemplate(eid, "disabled_update")
    return
  let hero = get_controlled_hero()
  let is_hero = (hero != null) ? hero.eid == eid : false

  let engineName = is_hero ? "EngineName" : "EngineNameAi"
  let modelSoundBlk = *evt.modelBlk |> datablock_get_block_by_name("sound")
  if modelSoundBlk == null
    addSubTemplate(eid, "disabled_update")
    return

  let engineBlkName = modelSoundBlk |> datablock_getStr(engineName, "")
  using() <| $(var sndBlk : DataBlock)
    if datablock_load(sndBlk, "config/sound_studio.blk")
      let useNewEngineSound = sndBlk |> datablock_getBool("useNewEngineSound", false)
      if !useNewEngineSound
        addSubTemplate(eid, "disabled_update") // delete with old engineSound system for gm
        return
      var engineBlk = sndBlk |> datablock_get_block_by_name(engineBlkName)
      if !is_hero && !is_low_mem_mode()
        let mainEngineBlkName = modelSoundBlk |> datablock_getStr("EngineName", "")
        var mainEngineBlk = sndBlk |> datablock_get_block_by_name(mainEngineBlkName)
        if mainEngineBlk != null
          let aiBlk = *mainEngineBlk |> datablock_get_block_by_name("ai")
          if aiBlk != null
            engineBlk = aiBlk
      if engineBlk == null
        addSubTemplate(eid, "disabled_update")
        return

      let outsideBlk = *engineBlk |> datablock_get_block_by_name("outside")
      if outsideBlk != null
        let path = outsideBlk |> datablock_getStr("path", "")
        let event = outsideBlk |> datablock_getStr("eventBack", "")
        gm_engine_sound__event_name := path + "/" + event
        gm_engine_sound__load_smooth = outsideBlk |> datablock_getReal("loadSmooth", 0.05)
        gm_engine_sound__pos_offset = outsideBlk |> datablock_getPoint3("offsetPos", float3(0, 0, 0))

      let insideBlk = *engineBlk |> datablock_get_block_by_name("cockpit")
      if insideBlk != null
        let path = insideBlk |> datablock_getStr("path", "")
        let event = insideBlk |> datablock_getStr("event_cockpit_l", "event_cockpit_r")
        gm_engine_sound__event_inside_name := path + "/" + event
        let eventStart = insideBlk |> datablock_getStr("event_start_cockpit_l", "")
        gm_engine_sound__start_inside_name := path + "/" + eventStart
        let eventStop = insideBlk |> datablock_getStr("event_stop_cockpit_l", "")
        gm_engine_sound__stop_inside_name := path + "/" + eventStop

      let effectsBlk = *engineBlk |> datablock_get_block_by_name("effects")
      if effectsBlk != null
        let path = effectsBlk |> datablock_getStr("path", "")
        let eventStart = effectsBlk |> datablock_getStr("eventStart", "")
        gm_engine_sound__start_event_name := path + "/" + eventStart
        let eventStop = effectsBlk |> datablock_getStr("eventStop", "")
        gm_engine_sound__stop_event_name := path + "/" + eventStop

      let can_patch_engines_for_enemies = sndBlk |> datablock_getBool("canPatchEnginesForEnemies", false)
      let is_enemy = !is_hero && unit.isTank && hero != null && hero.army != unit.army && can_patch_engines_for_enemies
      if is_enemy
        gm_engine_sound__event_name := string(gm_engine_sound__event_name) |> replace("/ai/", "/ai/_enemies/")
        gm_engine_sound__start_event_name := string(gm_engine_sound__event_name) |> replace("/ai/", "/ai/_enemies/")
        gm_engine_sound__stop_event_name := string(gm_engine_sound__event_name) |> replace("/ai/", "/ai/_enemies/")


[es(tag=sound, REQUIRE = controlledHero, REQUIRE_NOT = disabled)]
def gm_engine_sound_update_inside_es(act : UpdateStageInfoAct;
                                     uid : int;
                                     gm_engine_sound__should_play : bool;
                                     gm_engine_sound__event_inside_name : das_string;
                                     var gm_engine_sound__loadswitch : bool&;
                                     var gm_engine_sound__is_inside : bool&;
                                     var gm_engine_sound__event : SoundEvent&;
                                     var gm_engine_sound__start_inside_event : SoundEvent&;
                                     var gm_engine_sound__stop_inside_event : SoundEvent&;
                                     var gm_engine_sound__event_inside : SoundEvent&)
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return

  if gm_engine_sound__is_inside != unit.isCameraInCockpit
    gm_engine_sound__loadswitch = false
  gm_engine_sound__is_inside = unit.isCameraInCockpit

  if unit.isCameraInCockpit
    if is_playing(gm_engine_sound__event.handle)
      abandon(gm_engine_sound__event.handle)
    if gm_engine_sound__should_play && !is_playing(gm_engine_sound__event_inside.handle)
      gm_engine_sound__event_inside |> play(string(gm_engine_sound__event_inside_name))
  else
    if is_playing(gm_engine_sound__event_inside.handle)
      abandon(gm_engine_sound__event_inside.handle)

  if !is_playing(gm_engine_sound__start_inside_event.handle)
    abandon(gm_engine_sound__start_inside_event.handle)
  if !is_playing(gm_engine_sound__stop_inside_event.handle)
    abandon(gm_engine_sound__stop_inside_event.handle)

[es(tag=sound, REQUIRE_NOT = disabled, after = gm_engine_sound_update_inside_es)]
def gm_engine_sound_update_es(act : ParallelUpdateFrameDelayed;
                              uid : int;
                              var gm_engine_sound__is_playing : bool&;
                              var gm_engine_sound__loadswitch : bool&;
                              gm_engine_sound__load_smooth : float;
                              var gm_engine_sound__update_interval : float&;
                              var gm_engine_sound__load : float&;
                              var gm_engine_sound__start_event : SoundEvent&;
                              var gm_engine_sound__stop_event : SoundEvent&;
                              var gm_engine_sound__event : SoundEvent&;
                              gm_engine_sound__event_inside : SoundEvent;
                              gm_engine_sound__pos_offset : float3;
                              gm_engine_sound__is_inside : bool;
                              var gm_engine_sound__pos : float3&)
  let unit = get_unit(uid)
  if unit == null || unit.isDelayed
    return
  let gm = unit |> as_gm()
  if gm == null
    return

  gm_engine_sound__update_interval += act.dt
  if gm_engine_sound__update_interval < gm.engineSoundUpdateInterval
    return
  else
    gm_engine_sound__update_interval = 0.

  gm_engine_sound__is_playing = is_playing(gm_engine_sound__event.handle) || is_playing(gm_engine_sound__event_inside.handle)
  gm_engine_sound__pos = unit.unitTm * gm_engine_sound__pos_offset
  if gm_engine_sound__is_playing
    gm_engine_sound__event.handle |> set_pos(gm_engine_sound__pos)
  gm_engine_sound__stop_event.handle |> set_pos(gm_engine_sound__pos)
  gm_engine_sound__start_event.handle |> set_pos(gm_engine_sound__pos)

  let swim = gm.swimEffectIntensity
  let rpm = abs(gm.engineRelativeRPM) * 100.f
  let broken = gm.engineReadyness > ENGINE_READINESS_THRESHOLD ? 0. : 1.

  let loadScale = 6.
  var rawLoad = gm.engineLoad
  let speedVector = gm.speedSigned
  let absLoad = abs(rawLoad);
  if (sign(rawLoad) != sign(speedVector) && abs(speedVector) > 1.f)
    rawLoad = unit.isTank ? -absLoad : 0.
  else
    rawLoad = absLoad;

  let load = clamp(rawLoad * loadScale, 0., 1.)
  if gm_engine_sound__load_smooth > 0.
    gm_engine_sound__load = approach(gm_engine_sound__load, load, act.dt, 0.01 / gm_engine_sound__load_smooth)
  if is_equal_float(rawLoad, 0.)
    gm_engine_sound__loadswitch = true

  let velocityLen = length(gm.velocity)
  let speed = cvt(velocityLen, 0.f, 10.f, 0.f, 100.f)

  let climb = gm |> calcuate_climb(sign(speedVector), velocityLen)
  let visible = gm.isVisibleFromHero ? 1. : 0.
  assume curEvent = gm_engine_sound__is_inside ? gm_engine_sound__event_inside : gm_engine_sound__event
  if gm_engine_sound__is_playing
    curEvent.handle |> set_var_optional("rpm", rpm)
    curEvent.handle |> set_var_optional("swim", swim)
    curEvent.handle |> set_var_optional("broken", broken)
    curEvent.handle |> set_var_optional("load", gm_engine_sound__load)
    curEvent.handle |> set_var_optional("loadswitch", gm_engine_sound__loadswitch ? rawLoad : 0.)
    curEvent.handle |> set_var_optional("speed", speed)
    curEvent.handle |> set_var_optional("climb", climb)
    curEvent.handle |> set_var_optional("is_visible", visible)

  if !is_playing(gm_engine_sound__event.handle) && is_valid_event(gm_engine_sound__event.handle)
    release(gm_engine_sound__event.handle)

  if !is_playing(gm_engine_sound__start_event.handle) && is_valid_event(gm_engine_sound__start_event.handle)
    abandon(gm_engine_sound__start_event.handle)
  if !is_playing(gm_engine_sound__stop_event.handle) && is_valid_event(gm_engine_sound__stop_event.handle)
    abandon(gm_engine_sound__stop_event.handle)


[es(tag=sound, REQUIRE_NOT = disabled)]
def gm_engine_on_start_es(evt : CmdEngineStartSound;
                          gm_engine_sound__pos : float3;
                          gm_engine_sound__is_inside : bool;
                          var gm_engine_sound__should_play : bool&;
                          gm_engine_sound__event_name : das_string;
                          gm_engine_sound__event_inside_name : das_string;
                          var gm_engine_sound__event : SoundEvent&;
                          var gm_engine_sound__event_inside : SoundEvent&)
  assume curEvent = gm_engine_sound__is_inside ? gm_engine_sound__event_inside : gm_engine_sound__event
  assume curEventName = gm_engine_sound__is_inside ? gm_engine_sound__event_inside_name : gm_engine_sound__event_name
  if !is_playing(curEvent.handle)
    curEvent |> play(string(curEventName), gm_engine_sound__pos)
  gm_engine_sound__should_play = true


[es(tag=sound, REQUIRE_NOT = disabled)]
def gm_engine_on_stop_es(evt : CmdEngineStopSound;
                         var gm_engine_sound__should_play : bool&;
                         var gm_engine_sound__event : SoundEvent&;
                         var gm_engine_sound__event_inside : SoundEvent&)
  if is_playing(gm_engine_sound__event.handle)
    abandon(gm_engine_sound__event.handle)
  if is_playing(gm_engine_sound__event_inside.handle)
    abandon(gm_engine_sound__event_inside.handle)
  gm_engine_sound__should_play = false


[es(tag=sound, REQUIRE_NOT = disabled)]
def gm_engine_on_steal_es(evt : CmdEngineStealSound;
                          var gm_engine_sound__event : SoundEvent&)
  if is_playing(gm_engine_sound__event.handle)
    abandon(gm_engine_sound__event.handle)


[es(tag=sound, REQUIRE_NOT = disabled)]
def gm_engine_on_unsteal_es(evt : CmdEngineUnstealSound;
                            gm_engine_sound__pos : float3;
                            gm_engine_sound__event_name : das_string;
                            var gm_engine_sound__event : SoundEvent&)
  if !is_playing(gm_engine_sound__event.handle)
    gm_engine_sound__event |> play(string(gm_engine_sound__event_name), gm_engine_sound__pos)


[es(tag=sound, REQUIRE_NOT = disabled)]
def gm_engine_on_play_start_es(evt : CmdEnginePlayStartSound;
                               gm_engine_sound__pos : float3;
                               gm_engine_sound__is_inside : bool;
                               gm_engine_sound__start_event_name : das_string;
                               gm_engine_sound__start_inside_name : das_string;
                               var gm_engine_sound__stop_event : SoundEvent&;
                               var gm_engine_sound__start_event : SoundEvent&;
                               var gm_engine_sound__start_inside_event : SoundEvent&;
                               var gm_engine_sound__stop_inside_event : SoundEvent&)
  if is_playing(gm_engine_sound__stop_event.handle)
    release(gm_engine_sound__stop_event.handle)
  if is_playing(gm_engine_sound__stop_inside_event.handle)
    release(gm_engine_sound__stop_inside_event.handle)

  assume curEvent = gm_engine_sound__is_inside ? gm_engine_sound__start_inside_event : gm_engine_sound__start_event
  assume curEventName = gm_engine_sound__is_inside ? gm_engine_sound__start_inside_name : gm_engine_sound__start_event_name

  if !is_playing(curEvent.handle)
    curEvent |> play(string(curEventName), gm_engine_sound__pos)


[es(tag=sound, REQUIRE_NOT = disabled)]
def gm_engine_on_play_stop_es(evt : CmdEnginePlayStopSound;
                              gm_engine_sound__pos : float3;
                              gm_engine_sound__is_inside : bool;
                              gm_engine_sound__stop_event_name : das_string;
                              gm_engine_sound__stop_inside_name : das_string;
                              var gm_engine_sound__start_event : SoundEvent&;
                              var gm_engine_sound__start_inside_event : SoundEvent&;
                              var gm_engine_sound__stop_event : SoundEvent&;
                              var gm_engine_sound__stop_inside_event : SoundEvent&)
  if is_playing(gm_engine_sound__start_event.handle)
    release(gm_engine_sound__start_event.handle)
  if is_playing(gm_engine_sound__start_inside_event.handle)
    release(gm_engine_sound__start_inside_event.handle)

  assume curEvent = gm_engine_sound__is_inside ? gm_engine_sound__stop_inside_event : gm_engine_sound__stop_event
  assume curEventName = gm_engine_sound__is_inside ? gm_engine_sound__stop_inside_name : gm_engine_sound__stop_event_name

  if !is_playing(curEvent.handle)
    curEvent |> play(string(curEventName), gm_engine_sound__pos)
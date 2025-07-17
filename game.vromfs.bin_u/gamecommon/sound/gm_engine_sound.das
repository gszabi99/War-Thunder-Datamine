require ecs
require DagorMath
require math.base
require DagorSystem
require DagorRandom
require DagorConsole
require Unit
require IGroundModel
require soundEvent
require soundSystem
require DagorDataBlock
require HeroManager
require %game.unit.unit_events
require %game.events
require %game.sound.sound_events
require strings
require app
require Sound


def gm_engine_sound_init(modelBlk : DataBlock?;
                         is_hero : bool;
                         eid : EntityId;
                         var unit__ref : UnitRef;
                         unit__className : string;
                         unitType : int;
                         var gm_engine_sound__cached_params : FloatList&;
                         var gm_engine_sound__pos_offset : float3&;
                         var gm_engine_sound__load_smooth : float&;
                         var gm_engine_sound__event_name : das_string&;
                         var gm_engine_sound__event_inside_name : das_string&;
                         var gm_engine_sound__start_event_name : das_string&;
                         var gm_engine_sound__stop_event_name : das_string&;
                         var gm_engine_sound__start_inside_name : das_string&;
                         var gm_engine_sound__stop_inside_name : das_string&)
  let unit = unit__ref.unit
  assert(unit != null)

  let gm = unit |> as_gm()
  if gm == null
    removeSubTemplate(eid, "gm_engine_sound")
    return
  if !gm.needLoadSounds || modelBlk == null
    removeSubTemplate(eid, "gm_engine_sound")
    return
  let modelSoundBlk = *modelBlk |> datablock_get_block_by_name("sound")
  if modelSoundBlk == null
    removeSubTemplate(eid, "gm_engine_sound")
    return

  gm_engine_sound__cached_params |> resize(10)

  var modifyEngineSound = false
  if *modelSoundBlk |> datablock_param_exists("EngineNameModification", -1) && unit.modBlk != null
    modifyEngineSound = *unit.modBlk |> datablock_block_exists("engine")

  var engineName = is_hero ? modifyEngineSound ? "EngineNameModification" : "EngineName" : "EngineNameAi"

  let extendedEngineName = modelSoundBlk |> datablock_getStr("EngineNameEx", "")
  if extendedEngineName != ""
    let pkgExtendedName = extendedEngineName |> replace("engine_", "pkg_extended_")
    if is_hero && sound_banks_is_preset_loaded(pkgExtendedName)
      engineName = "EngineNameEx"

  let engineBlkName = modelSoundBlk |> datablock_getStr(engineName, "")
  using() <| $(var sndBlk : DataBlock)
    if datablock_load(sndBlk, "config/sound_studio.blk")
      var engineBlk = sndBlk |> datablock_get_block_by_name(engineBlkName)
      if !is_hero && !is_low_mem_mode()
        let mainEngineBlkName = modelSoundBlk |> datablock_getStr("EngineName", "")
        var mainEngineBlk = sndBlk |> datablock_get_block_by_name(mainEngineBlkName)
        if mainEngineBlk != null
          var aiBlk = *mainEngineBlk |> datablock_get_block_by_name("ai")
          if aiBlk != null
            engineBlk = aiBlk
      if engineBlk == null
        removeSubTemplate(eid, "gm_engine_sound")
        return

      let outsideBlk = *engineBlk |> datablock_get_block_by_name("outside")
      if outsideBlk != null
        let path = outsideBlk |> datablock_getStr("path", "")
        var event = outsideBlk |> datablock_getStr("eventBack", "")
        if event == ""
          event = outsideBlk |> datablock_getStr("eventBack_1", "")
        gm_engine_sound__event_name := path + "/" + event

        if *outsideBlk |> datablock_param_exists("eventBack_2", -1)
          let additionalEvent = outsideBlk |> datablock_getStr("eventBack_2", "")
          addSubTemplate(eid, "gm_additional_engine_sound") <| $(var init : ComponentsInitializer)
            set(init, "gm_additional_engine_sound__event_name", path + "/" + additionalEvent)
            set(init, "gm_additional_engine_sound__pos_offset",  outsideBlk |> datablock_getPoint3("pos_2", float3(0, 0, 0)))

        gm_engine_sound__load_smooth = outsideBlk |> datablock_getReal("loadSmooth", 0.05)
        let offsetParamName = *outsideBlk |> datablock_param_exists("offsetPos", -1) ? "offsetPos" : "pos_1"
        gm_engine_sound__pos_offset = outsideBlk |> datablock_getPoint3(offsetParamName, float3(0, 0, 0))

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
        if eventStart != ""
          gm_engine_sound__start_event_name := path + "/" + eventStart
        let eventStop = effectsBlk |> datablock_getStr("eventStop", "")
        if eventStop != ""
          gm_engine_sound__stop_event_name := path + "/" + eventStop

      let can_patch_engines_for_enemies = sndBlk |> datablock_getBool("canPatchEnginesForEnemies", false)
      let hero = get_controlled_hero()
      let is_enemy = !is_hero && unit.isTank && hero != null && hero.army != unit.army && can_patch_engines_for_enemies
      if is_enemy
        gm_engine_sound__event_name := string(gm_engine_sound__event_name) |> replace("/ai/", "/ai/_enemies/")
        gm_engine_sound__start_event_name := string(gm_engine_sound__start_event_name) |> replace("/ai/", "/ai/_enemies/")
        gm_engine_sound__stop_event_name := string(gm_engine_sound__stop_event_name) |> replace("/ai/", "/ai/_enemies/")

      if !is_mod_enabled()
        return

      using() <| $(var overloadsBlk : DataBlock)
        let overloadBlkName = (uint(unitType) == uint(UnitType.UT_Ship) || uint(unitType) == uint(UnitType.UT_Submarine)) ? "sound/mod/ship_sound_overloads.blk" : "sound/mod/tank_sound_overloads.blk"
        if datablock_load(overloadsBlk, overloadBlkName, DataBlockReadFlag.ROBUST)
          var modelName = unit__className
          let idx = modelName |> find("/")
          if idx >= 0
            modelName = modelName |> chop(idx + 1, length(modelName) - idx)
          let customSoundBlk = overloadsBlk |> datablock_get_block_by_name(modelName)
          if customSoundBlk == null
            return
          let customEngineSoundBlk = *customSoundBlk |> datablock_get_block_by_name("engine")
          if customEngineSoundBlk != null
            let cutomOutsideBlk = *customEngineSoundBlk |> datablock_get_block_by_name("outside")
            if cutomOutsideBlk != null
              let path = cutomOutsideBlk |> datablock_getStr("path", "")
              let event = cutomOutsideBlk |> datablock_getStr("name", "")
              gm_engine_sound__event_name := path + "/" + event
              let eventStart = cutomOutsideBlk |> datablock_getStr("eventStart", "")
              gm_engine_sound__start_event_name := path + "/" + eventStart
              let eventStop = cutomOutsideBlk |> datablock_getStr("eventStop", "")
              gm_engine_sound__stop_event_name := path + "/" + eventStop


            let cutomInsideBlk = *customEngineSoundBlk |> datablock_get_block_by_name("interior")
            if cutomInsideBlk != null
              let path = cutomInsideBlk |> datablock_getStr("path", "")
              let event = cutomInsideBlk |> datablock_getStr("name", "")
              gm_engine_sound__event_inside_name := path + "/" + event
              let eventStart = cutomInsideBlk |> datablock_getStr("eventStart", "")
              gm_engine_sound__start_inside_name := path + "/" + eventStart
              let eventStop = cutomInsideBlk |> datablock_getStr("eventStop", "")
              gm_engine_sound__stop_inside_name := path + "/" + eventStop


            if !is_hero
              let cutomAiBlk = *customEngineSoundBlk |> datablock_get_block_by_name("ai")
              if cutomAiBlk != null
                let path = cutomAiBlk |> datablock_getStr(is_enemy ? "pathEnemy" : "path", "")
                let event = cutomAiBlk |> datablock_getStr("name", "")
                gm_engine_sound__event_name := path + "/" + event
                let eventStart = cutomAiBlk |> datablock_getStr("eventStart", "")
                gm_engine_sound__start_event_name := path + "/" + eventStart
                let eventStop = cutomAiBlk |> datablock_getStr("eventStop", "")
                gm_engine_sound__stop_event_name := path + "/" + eventStop

[es(tag=sound)]
def gm_engine_sound_init_es(evt : CmdInitComponent;
                            eid : EntityId;
                            var unit__ref : UnitRef;
                            unit__playerId : int;
                            unit__className : string;
                            unitType : int;
                            var gm_engine_sound__cached_params : FloatList&;
                            var gm_engine_sound__pos_offset : float3&;
                            var gm_engine_sound__load_smooth : float&;
                            var gm_engine_sound__event_name : das_string&;
                            var gm_engine_sound__event_inside_name : das_string&;
                            var gm_engine_sound__start_event_name : das_string&;
                            var gm_engine_sound__stop_event_name : das_string&;
                            var gm_engine_sound__start_inside_name : das_string&;
                            var gm_engine_sound__stop_inside_name : das_string&)
  gm_engine_sound_init(evt.modelBlk,
                       unit__playerId == get_local_player_no(),
                       eid,
                       unit__ref,
                       unit__className,
                       unitType,
                       gm_engine_sound__cached_params,
                       gm_engine_sound__pos_offset,
                       gm_engine_sound__load_smooth,
                       gm_engine_sound__event_name,
                       gm_engine_sound__event_inside_name,
                       gm_engine_sound__start_event_name,
                       gm_engine_sound__stop_event_name,
                       gm_engine_sound__start_inside_name,
                       gm_engine_sound__stop_inside_name)


[es(tag=sound)]
def gm_engine_sound_reinit_es(evt : CmdEngineReinitSound;
                              eid : EntityId;
                              var unit__ref : UnitRef;
                              unit__className : string;
                              unitType : int;
                              var gm_engine_sound__event : SoundEvent&;
                              gm_engine_sound__should_play : bool;
                              gm_engine_sound__pos : float3;
                              var gm_engine_sound__cached_params : FloatList&;
                              var gm_engine_sound__pos_offset : float3&;
                              var gm_engine_sound__load_smooth : float&;
                              var gm_engine_sound__event_name : das_string&;
                              var gm_engine_sound__event_inside_name : das_string&;
                              var gm_engine_sound__start_event_name : das_string&;
                              var gm_engine_sound__stop_event_name : das_string&;
                              var gm_engine_sound__start_inside_name : das_string&;
                              var gm_engine_sound__stop_inside_name : das_string&)
  abandon(gm_engine_sound__event)
  gm_engine_sound_init(evt.modelBlk,
                       evt.forHero,
                       eid,
                       unit__ref,
                       unit__className,
                       unitType,
                       gm_engine_sound__cached_params,
                       gm_engine_sound__pos_offset,
                       gm_engine_sound__load_smooth,
                       gm_engine_sound__event_name,
                       gm_engine_sound__event_inside_name,
                       gm_engine_sound__start_event_name,
                       gm_engine_sound__stop_event_name,
                       gm_engine_sound__start_inside_name,
                       gm_engine_sound__stop_inside_name)
  if gm_engine_sound__should_play
    gm_engine_sound__event |> play(string(gm_engine_sound__event_name), gm_engine_sound__pos)


def reset_cached_params(var cached_params : FloatList&)
  cached_params[0] = -1. 
  cached_params[1] = 0.  
  cached_params[2] = 0. 
  cached_params[3] = -1. 
  cached_params[5] = -1. 
  cached_params[7] = 0.  


[es(tag=sound, REQUIRE = controlledHero, no_order)]
def gm_engine_sound_update_inside_es(act : UpdateStageInfoAct;
                                     unit__ref : UnitRef;
                                     gm_engine_sound__should_play : bool;
                                     gm_engine_sound__event_inside_name : das_string;
                                     var gm_engine_sound__loadswitch : bool&;
                                     var gm_engine_sound__is_inside : bool&;
                                     var gm_engine_sound__cached_params : FloatList&;
                                     var gm_engine_sound__event : SoundEvent&;
                                     var gm_engine_sound__start_inside_event : SoundEvent&;
                                     var gm_engine_sound__stop_inside_event : SoundEvent&;
                                     var gm_engine_sound__event_inside : SoundEvent&)
  let unit = unit__ref.unit
  if unit.isDelayed
    return

  if gm_engine_sound__is_inside != unit.isCameraInCockpit
    gm_engine_sound__loadswitch = false
    reset_cached_params(gm_engine_sound__cached_params)

  gm_engine_sound__is_inside = unit.isCameraInCockpit

  if unit.isCameraInCockpit
    if is_playing(gm_engine_sound__event)
      abandon(gm_engine_sound__event)
    if gm_engine_sound__should_play && !is_playing(gm_engine_sound__event_inside) && gm_engine_sound__event_inside_name != ""
      gm_engine_sound__event_inside |> play(string(gm_engine_sound__event_inside_name))
  else
    if is_playing(gm_engine_sound__event_inside)
      abandon(gm_engine_sound__event_inside)

  if !is_playing(gm_engine_sound__start_inside_event)
    abandon(gm_engine_sound__start_inside_event)
  if !is_playing(gm_engine_sound__stop_inside_event)
    abandon(gm_engine_sound__stop_inside_event)

def set_param_cached(sound_event : SoundEvent;
                     name : string;
                     new_val : float;
                     var cached_val : float&;
                     threshold : float)
  if !is_equal_float(cached_val, new_val, threshold)
    sound_event |> set_var_optional(name, new_val)
    cached_val = new_val

[es(tag=sound, after = gm_engine_sound_update_inside_es)]
def gm_engine_sound_update_es(act : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              unit__ref : UnitRef;
                              var gm_engine_sound__is_playing : bool&;
                              var gm_engine_sound__loadswitch : bool&;
                              gm_engine_sound__load_smooth : float;
                              var gm_engine_sound__update_interval : float&;
                              var gm_engine_sound__load : float&;
                              var gm_engine_sound__start_event : SoundEvent&;
                              var gm_engine_sound__stop_event : SoundEvent&;
                              var gm_engine_sound__event : SoundEvent&;
                              var gm_engine_sound__cached_params : FloatList&;
                              gm_engine_sound__event_inside : SoundEvent;
                              gm_engine_sound__pos_offset : float3;
                              gm_engine_sound__is_inside : bool;
                              var gm_engine_sound__pos : float3&;
                              tank_engine__stage : uint8)
  let unit = unit__ref.unit
  let gm = unit |> as_gm()
  if gm == null || unit.isDelayed
    return

  gm_engine_sound__update_interval -= act.dt
  if gm_engine_sound__update_interval > 0.
    return
  else
    let gmInterval = gm.engineSoundUpdateInterval
    gm_engine_sound__update_interval = rnd_float(gmInterval * 0.5, gmInterval)

  gm_engine_sound__is_playing = is_playing(gm_engine_sound__event) || is_playing(gm_engine_sound__event_inside)
  let newPos = unit.unitTm * gm_engine_sound__pos_offset
  if gm_engine_sound__is_playing && length_sq(newPos - gm_engine_sound__pos) > 0.09
    gm_engine_sound__event |> set_pos_and_ori(newPos, gm.velocity, unit.unitTm[0], unit.unitTm[1])
    gm_engine_sound__stop_event |> set_pos(newPos)
    gm_engine_sound__start_event |> set_pos(newPos)
    gm_engine_sound__pos = newPos

  if unit.isDelayed
    return

  let swim = gm.swimEffectIntensity
  let rpm = abs(gm.engineRelativeRPM) * 100.f
  let broken = gm.engineReadyness > ENGINE_READINESS_THRESHOLD ? 0. : 1.

  let loadScale = 6.
  var rawLoad = gm.engineLoad
  let speedVector = gm.speedSigned
  let absLoad = abs(rawLoad)
  if (sign(rawLoad) != sign(speedVector) && abs(speedVector) > 1.f)
    rawLoad = unit.isTank ? -absLoad : 0.
  else
    rawLoad = absLoad

  let load = clamp(rawLoad * loadScale, 0., 1.)
  if gm_engine_sound__load_smooth > 0.
    gm_engine_sound__load = approach(gm_engine_sound__load, load, act.dt, 0.01 / gm_engine_sound__load_smooth)
  if is_equal_float(rawLoad, 0.)
    gm_engine_sound__loadswitch = true

  let velocityLen = length(gm.velocity)
  let speed = cvt(velocityLen, 0.f, 10.f, 0.f, 100.f)
  let app = get_app()
  let depth = ((app != null) ? app.currentScene.waterLevel : 0.f) - gm_engine_sound__pos.y

  let climb = gm |> calcuate_climb(sign(speedVector), velocityLen)
  let visible = gm.isVisibleFromHero ? 1. : 0.
  assume curEvent = gm_engine_sound__is_inside ? gm_engine_sound__event_inside : gm_engine_sound__event
  if gm_engine_sound__is_playing
    set_param_cached(curEvent, "rpm", rpm, gm_engine_sound__cached_params[0], 1.0)
    set_param_cached(curEvent, "swim", swim, gm_engine_sound__cached_params[1], 0.1)
    set_param_cached(curEvent, "broken", broken, gm_engine_sound__cached_params[2], 0.5)
    set_param_cached(curEvent, "load", gm_engine_sound__load, gm_engine_sound__cached_params[3], 0.1)
    set_param_cached(curEvent, "loadswitch", gm_engine_sound__loadswitch ? rawLoad : 0., gm_engine_sound__cached_params[4], 0.1)
    set_param_cached(curEvent, "speed", speed, gm_engine_sound__cached_params[5], 5.0)
    set_param_cached(curEvent, "climb", climb, gm_engine_sound__cached_params[6], 0.5)
    set_param_cached(curEvent, "is_visible", visible, gm_engine_sound__cached_params[7], 0.5)
    set_param_cached(curEvent, "building_density", gm.buildingDensity, gm_engine_sound__cached_params[8], 1.0)
    set_param_cached(curEvent, "depth", depth, gm_engine_sound__cached_params[9], 1.0)

  if !is_playing(gm_engine_sound__event) && is_valid_event(gm_engine_sound__event)
    release(gm_engine_sound__event)

  if !is_playing(gm_engine_sound__start_event) && is_valid_event(gm_engine_sound__start_event)
    abandon(gm_engine_sound__start_event)
  if !is_playing(gm_engine_sound__stop_event) && is_valid_event(gm_engine_sound__stop_event)
    abandon(gm_engine_sound__stop_event)

  if !is_equal_float(broken, 1.f)
    if tank_engine__stage == uint8(TankEngineStage.STAGE_STARTING) || tank_engine__stage == uint8(TankEngineStage.STAGE_READY)
      sendEvent(eid, CmdEnginePlayStartSound())
    if tank_engine__stage == uint8(TankEngineStage.STAGE_STOPPING) || tank_engine__stage == uint8(TankEngineStage.STAGE_TURNING_OFF)
      sendEvent(eid, CmdEnginePlayStopSound())

[es(tag=sound)]
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
  if !is_playing(curEvent) && curEventName != ""
    curEvent |> play(string(curEventName), gm_engine_sound__pos)
  gm_engine_sound__should_play = true


[es(tag=sound)]
def gm_engine_on_stop_es(evt : CmdEngineStopSound;
                         var gm_engine_sound__should_play : bool&;
                         var gm_engine_sound__event : SoundEvent&;
                         var gm_engine_sound__event_inside : SoundEvent&)
  if is_playing(gm_engine_sound__event)
    abandon(gm_engine_sound__event)
  if is_playing(gm_engine_sound__event_inside)
    abandon(gm_engine_sound__event_inside)
  gm_engine_sound__should_play = false


[es(tag=sound)]
def gm_engine_on_steal_es(evt : CmdEngineStealSound;
                          var gm_engine_sound__event : SoundEvent&)
  if is_playing(gm_engine_sound__event)
    abandon(gm_engine_sound__event)


[es(tag=sound)]
def gm_engine_on_unsteal_es(evt : CmdEngineUnstealSound;
                            gm_engine_sound__pos : float3;
                            gm_engine_sound__event_name : das_string;
                            var gm_engine_sound__cached_params : FloatList&;
                            var gm_engine_sound__event : SoundEvent&)
  if !is_playing(gm_engine_sound__event) && gm_engine_sound__event_name != ""
    gm_engine_sound__event |> play(string(gm_engine_sound__event_name), gm_engine_sound__pos)
    reset_cached_params(gm_engine_sound__cached_params)


[es(tag=sound)]
def gm_engine_on_play_start_es(evt : CmdEnginePlayStartSound;
                               var tank_engine__soundStarted : bool&;
                               gm_engine_sound__pos : float3;
                               gm_engine_sound__is_inside : bool;
                               gm_engine_sound__start_event_name : das_string;
                               gm_engine_sound__start_inside_name : das_string;
                               var gm_engine_sound__cached_params : FloatList&;
                               var gm_engine_sound__stop_event : SoundEvent&;
                               var gm_engine_sound__start_event : SoundEvent&;
                               var gm_engine_sound__start_inside_event : SoundEvent&;
                               var gm_engine_sound__stop_inside_event : SoundEvent&)
  if tank_engine__soundStarted
    return
  tank_engine__soundStarted = true

  if is_playing(gm_engine_sound__stop_event)
    release(gm_engine_sound__stop_event)
  if is_playing(gm_engine_sound__stop_inside_event)
    release(gm_engine_sound__stop_inside_event)

  assume curEvent = gm_engine_sound__is_inside ? gm_engine_sound__start_inside_event : gm_engine_sound__start_event
  assume curEventName = gm_engine_sound__is_inside ? gm_engine_sound__start_inside_name : gm_engine_sound__start_event_name

  if (curEventName != "") && !is_playing(curEvent)
    curEvent |> play(string(curEventName), gm_engine_sound__pos)
    reset_cached_params(gm_engine_sound__cached_params)


[es(tag=sound)]
def gm_engine_on_play_stop_es(evt : CmdEnginePlayStopSound;
                              var tank_engine__soundStarted : bool&;
                              gm_engine_sound__pos : float3;
                              gm_engine_sound__is_inside : bool;
                              gm_engine_sound__stop_event_name : das_string;
                              gm_engine_sound__stop_inside_name : das_string;
                              var gm_engine_sound__start_event : SoundEvent&;
                              var gm_engine_sound__start_inside_event : SoundEvent&;
                              var gm_engine_sound__stop_event : SoundEvent&;
                              var gm_engine_sound__stop_inside_event : SoundEvent&)
  if tank_engine__soundStarted
    return
  tank_engine__soundStarted = true

  if is_playing(gm_engine_sound__start_event)
    release(gm_engine_sound__start_event)
  if is_playing(gm_engine_sound__start_inside_event)
    release(gm_engine_sound__start_inside_event)

  assume curEvent = gm_engine_sound__is_inside ? gm_engine_sound__stop_inside_event : gm_engine_sound__stop_event
  assume curEventName = gm_engine_sound__is_inside ? gm_engine_sound__stop_inside_name : gm_engine_sound__stop_event_name

  if (curEventName != "") && !is_playing(curEvent)
    curEvent |> play(string(curEventName), gm_engine_sound__pos)



[es(tag=sound)]
def gm_additional_engine_on_unsteal_es(evt : CmdEngineUnstealSound;
                                       gm_additional_engine_sound__pos : float3;
                                       gm_additional_engine_sound__event_name : das_string;
                                       var gm_additional_engine_sound__event : SoundEvent&)
  if !is_playing(gm_additional_engine_sound__event) && gm_additional_engine_sound__event_name != ""
    gm_additional_engine_sound__event |> play(string(gm_additional_engine_sound__event_name), gm_additional_engine_sound__pos)

[es(tag=sound)]
def gm_additional__on_steal_es(evt : CmdEngineStealSound;
                               var gm_additional_engine_sound__event : SoundEvent&)
  if is_playing(gm_additional_engine_sound__event)
    abandon(gm_additional_engine_sound__event)


[es(tag=sound, after = gm_engine_sound_update_inside_es)]
def gm_additional_engine_sound_update_es(act : ParallelUpdateFrameDelayed;
                                         unit__ref : UnitRef;
                                         gm_engine_sound__load : float;
                                         var gm_additional_engine_sound__pos : float3&;
                                         gm_additional_engine_sound__pos_offset : float3;
                                         gm_additional_engine_sound__event : SoundEvent)
  let unit = unit__ref.unit
  if unit.isDelayed
    return
  let gm = unit |> as_gm()
  if gm == null
    return

  let rpm = abs(gm.engineRelativeRPM) * 100.f
  gm_additional_engine_sound__pos = unit.unitTm * gm_additional_engine_sound__pos_offset
  if is_playing(gm_additional_engine_sound__event)
    gm_additional_engine_sound__event |> set_pos(gm_additional_engine_sound__pos)

    gm_additional_engine_sound__event |> set_var_optional("is_aero_on", rpm > 5. ? 1. : 0.)
    gm_additional_engine_sound__event |> set_var_optional("rpm", rpm)
    gm_additional_engine_sound__event |> set_var_optional("load", gm_engine_sound__load)


[es(tag=sound, REQUIRE = controlledHero)]
def tank_engine_speech_es(evt : EventTankEngineStageChanged;
                          eid : EntityId)
  if evt.newStage == uint8(TankEngineStage.STAGE_STARTING)
    play_speech(eid, "engineStart")

  elif evt.newStage == uint8(TankEngineStage.STAGE_STOPPING)
    play_speech(eid, "engineStop")


[es(tag=sound)]
def tank_engine_sound_stage_changed_es(evt : EventTankEngineStageChanged;
                                       var tank_engine__soundStarted : bool&)
  if evt.newStage == uint8(TankEngineStage.STAGE_READY)
    tank_engine__soundStarted = false

  elif evt.newStage == uint8(TankEngineStage.STAGE_TURNING_OFF)
    tank_engine__soundStarted = false

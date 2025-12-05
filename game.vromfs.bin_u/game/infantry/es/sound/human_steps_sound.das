require ecs
require ecs.safe
require soundHash
require soundSystem
require soundEvent
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require sound_utils.modules.sound_physmat_common
require danetlibs.renderer.includes.pufd_events
require common_sounds.modules.common_sounds_events
require human_sounds.modules.human_steps_sound_common
require DngHuman
require HeroManager
require DagorMath
require strings
require %appGame.infantry.es.hero_common
require %appGame.infantry.es.team_common
require PhysMat
require DagorConsole



[es(tag=sound, after=( sound_begin_update_es), before=(human_steps_sound_update, sound_end_update_es))]
def human_steps_sound_states_from_human_net_phys(info : ParallelUpdateFrameDelayed;
                                                 human_net_phys : HumanActor;
                                                 animchar__animSpeed : float;
                                                 var human_steps_sound__moveState : int&;
                                                 var human_steps_sound__animSpeed : float&)

  human_steps_sound__moveState = int(human_net_phys.phys.currentState.moveState)
  human_steps_sound__animSpeed = animchar__animSpeed


def human_steps_sound_states_from_human_navmesh_phys_impl(speed : float;
                                                          navmesh_phys__walkSpeedModifier = 0.5;
                                                          var human_steps_sound__moveState : int&;
                                                          var human_steps_sound__animSpeed : float&)
  
  human_steps_sound__animSpeed = speed
  if speed > navmesh_phys__walkSpeedModifier * 1.1
    human_steps_sound__moveState = int(HUMoveState.EMS_RUN)
  elif speed > FLT_EPSILON
    human_steps_sound__moveState = int(HUMoveState.EMS_WALK)
  else
    human_steps_sound__moveState = int(HUMoveState.EMS_STAND)


[es(tag=sound, REQUIRE_NOT=(human_net_phys, human_net_phys, loc_snapshots__snapshotData), after=sound_begin_update_es, before=human_steps_sound_update)]
def human_steps_sound_states_from_human_navmesh_phys_offline(info : ParallelUpdateFrameDelayed;
                                                             navmesh_phys__currentWalkVelocity : float3;
                                                             navmesh_phys__walkSpeedModifier = 0.5;
                                                             var human_steps_sound__moveState : int&;
                                                             var human_steps_sound__animSpeed : float&)
  
  let speed = length(navmesh_phys__currentWalkVelocity)
  human_steps_sound_states_from_human_navmesh_phys_impl(speed, navmesh_phys__walkSpeedModifier, human_steps_sound__moveState, human_steps_sound__animSpeed)





















def get_step_volume(distance_to_volume_friendly, distance_to_volume_enemy : float4;
                    team : int;
                    is_watched_sound : bool;
                    listener, pos : float3)

  if is_watched_sound
    return 1.

  let heroTeam = get_int(get_controlled_hero_eid(), "team") ?? TEAM_UNASSIGNED
  let r = is_teams_friendly(team, heroTeam) ? distance_to_volume_friendly : distance_to_volume_enemy
  return cvt(distance(listener, pos), r.x, r.y, r.z, r.w)

def raise_pos_above_collision(pos, up : float3) 
  return pos + up * 0.5

def apply_prefix(path : string; is_watched_sound : bool; is_enemy : bool) : string
  if should_apply_watched_prefix(path)
    return is_watched_sound ? "player{path}" : is_enemy ? "enemy{path}" : "ally{path}"
  return path


def play_step_sound_grains(desc : Object;
                           path : Object;
                           var step_sound_grains_event : SoundEvent&;
                           var ttl : float&;
                           force_start_new : bool;
                           sound_tags : Object;
                           volume : float;

                           human_eid : EntityId;
                           pos, up : float3;
                           should_trace_enemy : bool;
                           is_watched_sound : bool;
                           trace_offset_len : float2;
                           cur_biome_id : int;
                           puddle_depth : float;
                           var step_material_id : int&;
                           var step_water_depth : float&;
                           var human_net_phys : HumanActor?;
                           is_enemy : bool;
                           prefix : string = "")

  let normalizedUp = normalize(up)

  if human_net_phys == null 
    step_material_id = get_sound_step_material_id(get_material_id("default"))
    step_water_depth = 0.

  elif is_watched_sound || should_trace_enemy
    trace_footstep(human_eid,
                   pos,
                   normalizedUp,
                   trace_offset_len,
                   cur_biome_id,
                   puddle_depth,
                   step_material_id,
                   step_water_depth,
                   human_net_phys)

  if step_material_id < 0
    step_material_id = get_sound_step_material_id(get_material_id("default"))

  var pathStr : string
  if sound_player_common::get_option_path(path, sound_tags, is_watched_sound, pathStr)
    let offsetedPos = raise_pos_above_collision(pos, normalizedUp)
    let soundPath = apply_prefix(pathStr, is_watched_sound, is_enemy)
    var sndName = sound_player_common::get_name(desc, is_watched_sound)

    if !is_valid_handle_value(step_sound_grains_event) || force_start_new
      abandon(step_sound_grains_event)
      let fullPath = "{prefix}{soundPath}/{sndName}_grains"
      step_sound_grains_event |> play(fullPath, offsetedPos)
    set_var(step_sound_grains_event, "on_shot", 0.)

    if step_water_depth > 0.
      set_var(step_sound_grains_event, "depth", step_water_depth)
    if read_sound_tag("armored", sound_tags)
      set_var(step_sound_grains_event, "armored", 1.)
    set_volume(step_sound_grains_event, volume)
    set_var(step_sound_grains_event, "mat", float(step_material_id))

    step_sound_grains_event |> set_pos(offsetedPos)
    set_var(step_sound_grains_event, "on_shot", 1.)
    ttl = is_watched_sound ? 3.f : 2.f



[es(tag=sound, after=( sound_begin_update_es), before=sound_end_update_es)]
def human_steps_sound_update(info : ParallelUpdateFrameDelayed)

  let listenerPos = get_listener_pos()

  query() <| $ [es(REQUIRE_NOT=deadEntity)] (eid : EntityId;
                                             sound_control__state : int = default_sound_control_state();

                                             transform : float3x4;
                                             is_watched_sound : bool;

                                             human_net_phys__states : int = int(StateFlag.ST_ON_GROUND);
                                             human_net_phys__isClimbing : bool = false;
                                             var human_net_phys : HumanActor?;

                                             animchar__animSpeed : float;
                                             animchar__updatable : bool;
                                             animchar__visible : bool;

                                             human_steps_sound__moveState : int;
                                             human_steps_sound__animSpeed : float;
                                             human_steps_sound__animSpeedMul : float;
                                             human_steps_sound__farawayThresholdSq : float;

                                             var human_step_sound_grains__event : SoundEvent&;
                                             var human_step_sound_grains__ttl : float&;
                                             @shared_comp human_step_sound_grains__types : Object;
                                             var human_step_sound_grains__type : int&;
                                             human_step_sound_grains__isEnemy : bool;

                                             @shared_comp human_steps_sound__irqs : Array;

                                             var human_steps_sound__irqObjIdx : int&;
                                             var human_steps_sound__physStates : int&;
                                             var human_steps_sound__lastTimeOnGround : float&;

                                             var human_sound_landmesh_queries_vars__speedSq : float&;
                                             var human_sound_landmesh_queries_vars__isOnGround : bool&;

                                             var human_steps_sound_generator__lastStepAt_cooldown : float2&;
                                             human_steps_sound_generator__walkRunSprint_stand_intervals : float3;
                                             human_steps_sound_generator__walkRunSprint_crouch_intervals : float3;
                                             human_steps_sound_generator__enableForVisible : bool;
                                             human_steps_sound_generator__enableForInvisible : bool;
                                             human_steps_sound_generator__enableAlways : bool)

    if !have_sound(sound_control__state) || is_faraway_step(is_watched_sound, transform[3], human_steps_sound__farawayThresholdSq, listenerPos)
      human_sound_landmesh_queries_vars__speedSq = 0.
      human_sound_landmesh_queries_vars__isOnGround = true
      human_steps_sound__physStates = human_net_phys__states
      human_steps_sound__irqObjIdx = INVALID_IRQ_OBJ_IDX
      return

    var standState = HUStandState.ESS_STAND
    var moveState = human_steps_sound__moveState
    var animSpeed = human_steps_sound__animSpeed
    if human_net_phys != null
      standState = human_net_phys.phys.currentState.standState
      moveState = int(human_net_phys.phys.currentState.moveState)
      animSpeed = animchar__animSpeed

    let irqObjIdx = human_steps_sound_generate(human_steps_sound__irqObjIdx,
                                               info.curTime,
                                               info.dt,
                                               read_state(StateFlag.ST_ON_GROUND, human_net_phys__states),
                                               human_net_phys__isClimbing,
                                               moveState,
                                               standState,
                                               animSpeed * human_steps_sound__animSpeedMul,
                                               animchar__updatable,
                                               animchar__visible,
                                               human_steps_sound_generator__lastStepAt_cooldown,
                                               human_steps_sound_generator__walkRunSprint_stand_intervals,
                                               human_steps_sound_generator__walkRunSprint_crouch_intervals,
                                               human_steps_sound_generator__enableForVisible,
                                               human_steps_sound_generator__enableForInvisible,
                                               human_steps_sound_generator__enableAlways,
                                               human_steps_sound__irqs)

    human_steps_sound__irqObjIdx = INVALID_IRQ_OBJ_IDX
    human_sound_landmesh_queries_vars__speedSq = human_net_phys != null ? length_sq((*human_net_phys).phys.currentState.velocity.xz) : 0.
    human_sound_landmesh_queries_vars__isOnGround = read_state(StateFlag.ST_ON_GROUND, human_net_phys__states)

    let descId = human_steps_sound_update_states(info.curTime,
                                                 human_net_phys__states,
                                                 human_steps_sound__physStates,
                                                 human_steps_sound__lastTimeOnGround)

    if irqObjIdx == INVALID_IRQ_OBJ_IDX && empty(descId)
      return

    query(eid) <| $ [es] (sound_preset__isLoaded : bool;
                          sound_tags : Object;
                          team : int;

                          var sound_event_group : SoundEventGroup&;
                          human_steps_sound__traceStepOffsetLen : float2;
                          human_steps_sound__distanceToVolumeFriendly : float4;
                          human_steps_sound__distanceToVolumeEnemy : float4;
                          human_steps_sound__prefix = "";

                          @shared_comp human_steps_sound__path : Object;
                          @shared_comp human_steps_sound__descs : Object;
                          @shared_comp human_steps_sound__irqs : Array;
                          @shared_comp human_steps_sound__stepFx : Object;

                          var human_steps_sound__waterDepth : float&;
                          var human_steps_sound__smid : int&;
                          var human_steps_sound__stepIdx : uint&;

                          human_sound_landmesh_queries__biomeId : int;
                          human_sound_landmesh_queries__puddleDepth : float)
      if !sound_preset__isLoaded
        return

      var desc : Object const? = null
      var shouldTraceEnemy = false
      if !empty(descId)
        desc = sound_player_common::get_desc(human_steps_sound__descs, descId)
        shouldTraceEnemy = false
      elif irqObjIdx != INVALID_IRQ_OBJ_IDX
        desc = human_steps_sound__irqs?[irqObjIdx] ?as Object
        shouldTraceEnemy = (human_steps_sound__stepIdx & 1u) != 0u
        ++human_steps_sound__stepIdx

        if (human_steps_sound__stepIdx & 3u) == 0u && desc != null
          let stepFxPath = human_steps_sound__stepFx[desc.name ?? ""] ?as Object
          if stepFxPath != null
            sound_player_common::play_path(*stepFxPath, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group)
      
      if desc != null
        let volume = get_step_volume(human_steps_sound__distanceToVolumeFriendly, human_steps_sound__distanceToVolumeEnemy, team, is_watched_sound, listenerPos, transform[3])
        

        let grainsSoundType = human_step_sound_grains__types |> get_int(desc.name ?? "") ?? -1
        let force_start_new = grainsSoundType != human_step_sound_grains__type
        human_step_sound_grains__type = grainsSoundType

        if (grainsSoundType >= 0)
          play_step_sound_grains(*desc,
                      human_steps_sound__path,
                      human_step_sound_grains__event,
                      human_step_sound_grains__ttl,
                      force_start_new,
                      sound_tags,
                      volume,
                      eid,
                      transform[3],
                      transform[1],
                      shouldTraceEnemy,
                      is_watched_sound,
                      human_steps_sound__traceStepOffsetLen,
                      human_sound_landmesh_queries__biomeId,
                      human_sound_landmesh_queries__puddleDepth,
                      human_steps_sound__smid,
                      human_steps_sound__waterDepth,
                      human_net_phys,
                      human_step_sound_grains__isEnemy,
                      human_steps_sound__prefix)
        else
          play_footstep(*desc,
                      human_steps_sound__path,
                      sound_tags,
                      volume,
                      eid,
                      transform[3],
                      transform[1],
                      shouldTraceEnemy,
                      is_watched_sound,
                      human_steps_sound__traceStepOffsetLen,
                      human_sound_landmesh_queries__biomeId,
                      human_sound_landmesh_queries__puddleDepth,
                      human_steps_sound__smid,
                      human_steps_sound__waterDepth,
                      human_net_phys,
                      human_steps_sound__prefix)

[es(tag=sound, REQUIRE_NOT=deadEntity)]
def human_steps_sound_irq(evt : CmdSoundStepIrq;
                          var human_steps_sound__irqObjIdx : int&)
  human_steps_sound__irqObjIdx = evt.objIdx


def is_enemy_team(gun__owner : EntityId)
  var ret = false
  var curTeam = -1
  query(gun__owner) <| $ [es] (team : int)
    curTeam = team

  if curTeam != -1
    query() <| $ [es(REQUIRE=hero)] (team aka hero_team : int)
      ret = curTeam != hero_team
  return ret


[es(tag=sound, on_appear)]
def human_steps_sound_on_appear(evt : Event;
                                eid : EntityId;
                                human_steps_sound__tag : string;
                                var human_step_sound_grains__isEnemy : bool&;
                                var sound_flags : Object&)
  raise_sound_tag(human_steps_sound__tag, sound_flags)
  human_step_sound_grains__isEnemy = is_enemy_team(eid)


[es(tag=sound)]
def human_step_sound_grains_update(info : ParallelUpdateFrameDelayed,
                                   var human_step_sound_grains__event : SoundEvent&,
                                   var human_step_sound_grains__ttl : float&)
  human_step_sound_grains__ttl -= info.dt
  if human_step_sound_grains__ttl < 0.
    human_step_sound_grains__ttl = 0.
    abandon(human_step_sound_grains__event)

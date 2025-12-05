module human_steps_sound_common shared

require ecs
require ecs.safe

require math
require math.base
require DagorMath

require PhysMat
require HumanPhys
require DngHuman
require Dacoll
require GridCollision
require CollisionTraces
require DagorSystem

require soundEvent
require soundSystem
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_physmat_common



let INVALID_IRQ_OBJ_IDX = -1


def is_faraway_step(is_watched : bool; pos : float3; max_distance_sq : float; listener_pos : float3) : bool
  return !is_watched && distance_sq(listener_pos, pos) > max_distance_sq


def read_state(state_flag : StateFlag; states : int) : bool
  return (states & int(state_flag)) != 0


def trace_footstep(human_eid : EntityId;
                   pos, up : float3;
                   trace_offset_len : float2;
                   cur_biome_id : int;
                   puddle_depth : float;
                   var step_material_id : int&;
                   var step_water_depth : float&;
                   var human_net_phys : HumanActor? = null)

  let mayTraceDown = up.y > 0.9
  let traceDir = mayTraceDown ? float3(0., -1., 0.) : -normalize(up)
  let flags = ETF_LMESH | ETF_HEIGHTMAP | ETF_FRT | ETF_RI | ETF_STRUCTURES
  let from = pos - traceDir * trace_offset_len.x

  var len = trace_offset_len.y
  var pmid = PHYSMAT_INVALID
  var norm : float3

  if mayTraceDown
    if !tracedown_normalized(from, len, pmid, flags, human_net_phys != null ? ((*human_net_phys).phys |> human_phys_getTraceHandle()) : null)
      len = trace_offset_len.y
      pmid = PHYSMAT_INVALID
  else
    var riDesc = RendInstDesc()
    if !traceray_normalized(from, traceDir, len, pmid, norm, flags, riDesc, -1)
      len = trace_offset_len.y
      pmid = PHYSMAT_INVALID

  trace_entities_in_grid(ecs_hash("vehicles"), from, traceDir, len, human_eid, SortIntersections.NO) <| $(intersections : array<IntersectedEntity>#)
    for it in intersections
      if it.t < len + FLT_EPSILON
        len = it.t
        pmid = PHYSMAT_INVALID
        query(it.eid) <| $ [es] (material : string)
          pmid = get_material_id(material)
        if pmid == PHYSMAT_INVALID
          pmid = get_material_id("steel")

  var onLandMesh = false
  var curBiomeSoundId = -1
  var curBiomeOverridesWater = false

  step_water_depth = 0.

  if mayTraceDown
    let pos2d = pos.xz
    let intersection = from + traceDir * len
    let landMesh2dLevel = traceht_lmesh(pos2d)

    var waterLevel = 0.
    if traceht_water(pos, waterLevel)
      step_water_depth = max(0., waterLevel - pos.y)

    onLandMesh = landMesh2dLevel + 0.01 > intersection.y
    if onLandMesh
      step_water_depth = max(step_water_depth, puddle_depth)

    if onLandMesh && cur_biome_id >= 0
      query() <| $ [es(REQUIRE=soundStepSettings)] (landmesh_biomes_to_sound_material__biomeIdToSound : IPoint2List)
        if cur_biome_id < length(landmesh_biomes_to_sound_material__biomeIdToSound)
          curBiomeSoundId = landmesh_biomes_to_sound_material__biomeIdToSound[cur_biome_id].x
          curBiomeOverridesWater = landmesh_biomes_to_sound_material__biomeIdToSound[cur_biome_id].y != 0

  let isInWater = step_water_depth > 0.
  if curBiomeSoundId != -1 && (!isInWater || curBiomeOverridesWater)
    step_material_id = curBiomeSoundId
  elif isInWater
    step_material_id = get_sound_step_material_id(get_material_id("water"))
  else
    step_material_id = get_sound_step_material_id(pmid)









def private raise_pos_above_collision(pos, up : float3) 
  return pos + up * 0.5


def play_footstep(desc : Object;
                  path : Object;
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

  if step_material_id >= 0
    var pathStr : string
    if sound_player_common::get_option_path(path, sound_tags, is_watched_sound, pathStr)
      let offsetedPos = raise_pos_above_collision(pos, normalizedUp)
      let soundPath = apply_watched_prefix(pathStr, is_watched_sound)
      var handle = sound_player_common::play_desc_path(desc, "{prefix}{soundPath}", is_watched_sound, offsetedPos, false)
      if step_water_depth > 0.
        set_var(handle, "depth", step_water_depth)
      if read_sound_tag("armored", sound_tags)
        set_var(handle, "armored", 1.)
      set_volume(handle, volume)
      set_var(handle, "mat", float(step_material_id))
      abandon(handle)


def get_desc_id_from_human_state(move_state : int; stand_state : HUStandState; irqs : Array) : int

  let name = ((stand_state == HUStandState.ESS_CROUCH) ? "step" :
             (stand_state == HUStandState.ESS_CRAWL) ? "crawl" :
             (move_state == int(HUMoveState.EMS_SPRINT)) ? "sprint" :
             (move_state == int(HUMoveState.EMS_RUN)) ? "run" :
             "step")

  for it, idx in irqs, range(length(irqs))
    if ((it as Object)?.name ?? "") == name
      return idx

  sound_debug("desc with name {name} not in irqs")

  return INVALID_IRQ_OBJ_IDX



def use_generator(enable_for_visible, enable_for_invisible, updatable, visible : bool; move_state : int; stand_state : HUStandState)

  if move_state == int(HUMoveState.EMS_ROTATE_LEFT) || move_state == int(HUMoveState.EMS_ROTATE_RIGHT) || stand_state == HUStandState.ESS_CRAWL
    return false

  if (!updatable || !visible) && enable_for_invisible
    return true

  return (move_state == int(HUMoveState.EMS_SPRINT) || move_state == int(HUMoveState.EMS_RUN)) && enable_for_visible



def human_steps_sound_generate(irq_obj_idx : int;
                               cur_time : float;
                               dt : float;

                               is_on_ground : bool;
                               is_climbing : bool;
                               move_state : int;
                               stand_state : HUStandState;

                               animchar__animSpeed : float;
                               animchar__updatable : bool;
                               animchar__visible : bool;

                               var lastStepAt_cooldown : float2&;

                               walkRunSprint_stand_intervals : float3;
                               walkRunSprint_crouch_intervals : float3;

                               enable_for_visible : bool;
                               enable_for_invisible : bool;
                               enable_always : bool;

                               @shared_comp irqs : Array) : int

  assume last_step_at = lastStepAt_cooldown.x
  assume cooldown = lastStepAt_cooldown.y

  let useGenerator = (enable_always || use_generator(enable_for_visible, enable_for_invisible, animchar__updatable, animchar__visible, move_state, stand_state)) && animchar__animSpeed > VERY_SMALL_NUMBER

  if move_state == int(HUMoveState.EMS_STAND) || stand_state == HUStandState.ESS_DOWNED || !is_on_ground || is_climbing
    cooldown = min(cooldown + dt, 1.)
    return INVALID_IRQ_OBJ_IDX

  cooldown = max(0., cooldown - dt)

  if irq_obj_idx == INVALID_IRQ_OBJ_IDX && !useGenerator
    return INVALID_IRQ_OBJ_IDX

  if useGenerator

    assume stand_intervals = walkRunSprint_stand_intervals
    assume crouch_intervals = walkRunSprint_crouch_intervals
    

    let intervals = (stand_state == HUStandState.ESS_CROUCH ? crouch_intervals : stand_intervals)
    let interval = (move_state == int(HUMoveState.EMS_SPRINT)) ? intervals.z : (move_state == int(HUMoveState.EMS_RUN)) ? intervals.y : intervals.x
    let step = safediv(interval, animchar__animSpeed)
    cooldown = min(cooldown, step * 0.5)

    if cur_time >= last_step_at + step
      last_step_at = cur_time
      if cooldown != 0.
        return INVALID_IRQ_OBJ_IDX
      
      return get_desc_id_from_human_state(move_state, stand_state, irqs)

  elif irq_obj_idx != INVALID_IRQ_OBJ_IDX

    let irqCooldown = 0.2
    if (cur_time - last_step_at) * animchar__animSpeed >= irqCooldown
      last_step_at = cur_time
      
      return irq_obj_idx

  return INVALID_IRQ_OBJ_IDX


def human_steps_sound_update_states(cur_time : float;
                                    human_net_phys__states : int;
                                    var human_steps_sound__physStates : int&;
                                    var human_steps_sound__lastTimeOnGround : float&) : string

  if human_steps_sound__physStates < 0
    human_steps_sound__physStates = human_net_phys__states
  let raisedStates = human_net_phys__states & ~human_steps_sound__physStates
  let clearedStates = human_steps_sound__physStates & ~human_net_phys__states
  human_steps_sound__physStates = human_net_phys__states

  if (raisedStates | clearedStates) != 0

    if read_state(StateFlag.ST_ON_GROUND, clearedStates)
      human_steps_sound__lastTimeOnGround = cur_time

    if read_state(StateFlag.ST_JUMP, raisedStates)
      return "jump"

    elif read_state(StateFlag.ST_ON_GROUND, raisedStates)
      return "land"

    elif read_state(StateFlag.ST_SWIM, raisedStates)
      if !read_state(StateFlag.ST_ON_GROUND, human_net_phys__states)
        return "land"
    elif read_state(StateFlag.ST_CROUCH, raisedStates)
      return "downKnee"
    elif read_state(StateFlag.ST_CROUCH, clearedStates)
      return "upKnee"
    elif read_state(StateFlag.ST_DOWNED, raisedStates)
      return "downKnee"
    elif read_state(StateFlag.ST_DOWNED, clearedStates)
      return "upKnee"
    elif read_state(StateFlag.ST_CRAWL, raisedStates)
      return "downGround"
    elif read_state(StateFlag.ST_CRAWL, clearedStates)
      return "upGround"

  return ""

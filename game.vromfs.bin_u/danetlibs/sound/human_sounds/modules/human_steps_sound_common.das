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
require sound_utils.modules.sound_trace_common


let INVALID_IRQ_OBJ_IDX = -1


def is_faraway_step(is_watched : bool; pos : float3; max_distance_sq : float; listener_pos : float3) : bool
  return !is_watched && distance_sq(listener_pos, pos) > max_distance_sq


def read_state(state_flag : StateFlag; states : int) : bool
  return (states & int(state_flag)) != 0



def trace_footstep(human_eid : EntityId;
                   pos, human_up : float3;
                   trace_offset_len : float2;
                   cur_biome_id : int;
                   puddle_depth : float;
                   var step_material_id : int&;
                   var step_water_depth : float&;
                   var human_net_phys : HumanActor? = null)

  var traceLen = trace_offset_len.y
  var floorIsDown = false
  var pmid = PHYSMAT_INVALID;
  var dirToFloor : float3
  var traceHandle = human_net_phys != null ? ((*human_net_phys).phys |> human_phys_getTraceHandle()) : null

  trace_floor(pos, human_up, trace_offset_len.x, traceLen, pmid, dirToFloor, floorIsDown, traceHandle)

  trace_vehicles(human_eid, pos, dirToFloor, trace_offset_len.x, traceLen, pmid)

  var curBiomeSoundId = -1
  var curBiomeOverridesWater = false

  step_water_depth = 0.

  if floorIsDown
    var waterLevel = 0.
    if traceht_water(pos, waterLevel)
      step_water_depth = max(0., waterLevel - pos.y)

    query() <| $ [es(REQUIRE=soundStepSettings)] (sound_step_settings__maxDistToFloor : float; landmesh_biomes_to_sound_material__biomeIdToSound : IPoint2List)
      var inOnFloorTraceLen = sound_step_settings__maxDistToFloor
      var inOnFloorPMID = PHYSMAT_INVALID
      
      if trace_floor(pos, 0.3, inOnFloorTraceLen, inOnFloorPMID, dirToFloor, floorIsDown, traceHandle, get_trace_flags_for_biome_and_puddle_queries())
        step_water_depth = max(step_water_depth, puddle_depth)
        if cur_biome_id >= 0 && cur_biome_id < length(landmesh_biomes_to_sound_material__biomeIdToSound)
          curBiomeSoundId = landmesh_biomes_to_sound_material__biomeIdToSound[cur_biome_id].x
          curBiomeOverridesWater = landmesh_biomes_to_sound_material__biomeIdToSound[cur_biome_id].y != 0

  let isInWater = step_water_depth > 0.
  if curBiomeSoundId != -1 && (!isInWater || curBiomeOverridesWater)
    step_material_id = curBiomeSoundId
  elif isInWater
    step_material_id = get_sound_step_material_id(get_material_id("water"))
  else
    step_material_id = get_sound_step_material_id(pmid)









def private raise_pos_above_collision(stand_state : HUStandState; pos, up : float3) 
  let offset = (stand_state == HUStandState.ESS_STAND) ? 1. : 0.5
  return pos + up * offset


def play_footstep(desc : Object;
                  path : Object;
                  sound_tags : Object;
                  volume : float;

                  human_eid : EntityId;
                  pos, human_up : float3;
                  should_trace_enemy : bool;
                  is_watched_sound : bool;
                  trace_offset_len : float2;
                  cur_biome_id : int;
                  puddle_depth : float;
                  var step_material_id : int&;
                  var step_water_depth : float&;
                  var human_net_phys : HumanActor?;
                  prefix : string = "";
                  abandon_handle = true;
                  stand_state = HUStandState.ESS_STAND)

  let normalizedUp = normalize(human_up)

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
    if get_option_path(path, sound_tags, is_watched_sound, pathStr)
      let raisedPos = raise_pos_above_collision(stand_state, pos, normalizedUp)
      let soundPath = apply_watched_prefix(pathStr, is_watched_sound)
      var handle = play_desc_path(desc, "{prefix}{soundPath}", is_watched_sound, raisedPos, false)
      if step_water_depth > 0.
        set_var(handle, "depth", step_water_depth)
      if read_sound_tag("armored", sound_tags)
        set_var(handle, "armored", 1.)
      set_volume(handle, volume)
      set_var(handle, "mat", float(step_material_id))
      if abandon_handle
        abandon(handle)
      return handle
  return invalid_sound_event_handle()


def get_desc_id_from_human_state(move_state : int; stand_state : HUStandState; irqs : Array) : int

  let name = ((stand_state == HUStandState.ESS_CROUCH) ? "step" :
             (stand_state == HUStandState.ESS_CRAWL) ? "crawl" :
             (move_state == int(HUMoveState.EMS_SPRINT)) ? "sprint" :
             (move_state == int(HUMoveState.EMS_RUN)) ? "run" :
             "step")

  for it, idx in irqs, range(length(irqs))
    if ((it as Object)?.name ?? "") == name
      return idx

  for it, idx in irqs, range(length(irqs))
    if ((it as Object)?.name ?? "") == "footstep"
      return idx

  sound_debug("desc with name '{name}' not in irqs")

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
    elif read_state(StateFlag.ST_CRAWL, raisedStates)
      return "downGround"
    elif read_state(StateFlag.ST_CRAWL, clearedStates)
      return "upGround"
    elif read_state(StateFlag.ST_CROUCH, raisedStates)
      return "downKnee"
    elif read_state(StateFlag.ST_CROUCH, clearedStates)
      return "upKnee"
    elif read_state(StateFlag.ST_DOWNED, raisedStates)
      return "downKnee"
    elif read_state(StateFlag.ST_DOWNED, clearedStates)
      return "upKnee"

  return ""

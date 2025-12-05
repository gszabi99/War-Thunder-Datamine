require ecs
require ecs.common
require ecs.safe
require soundSystem
require DagorMath
require math.base
require PhysMat
require Dacoll
require danetlibs.renderer.includes.pufd_events
require gpuReadbackQuery
require landMesh
require puddleQueryManager
require DagorSystem


def invalid_query_id()
  return -1

def is_valid_query_id(query_id : int)
  return query_id != invalid_query_id()


[es(tag=sound, on_appear)]
def human_sound_landmesh_queries_appear(evt : Event;
                                        var human_sound_landmesh_queries__biomeQueryId : int&;
                                        var human_sound_landmesh_queries__puddleQueryId : int&)

  human_sound_landmesh_queries__biomeQueryId = invalid_query_id()
  human_sound_landmesh_queries__puddleQueryId = invalid_query_id()


def apply(biome_index : int; biome_weight : float;
          var human_sound_landmesh_queries__biomeId : int&)

  assume threshold = 0.05
  if biome_weight >= threshold
    human_sound_landmesh_queries__biomeId = biome_index
  else
    human_sound_landmesh_queries__biomeId = -1

















[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def human_sound_landmesh_queries_update(info : ParallelUpdateFrameDelayed;
                                        is_watched_sound : bool = false;
                                        transform : float3x4;

                                        human_sound_landmesh_queries_vars__speedSq : float;
                                        human_sound_landmesh_queries_vars__isOnGround : bool;

                                        human_sound_landmesh_queries__lmeshDiff : float;
                                        human_sound_landmesh_queries__farawayThreshold : float;
                                        human_sound_landmesh_queries__zeroSpeedThreshold : float;
                                        human_sound_landmesh_queries__heroSpeedToQueryInterval : float4;
                                        human_sound_landmesh_queries__enemySpeedToQueryInterval : float4;
                                        human_sound_landmesh_queries__heroEnemyInAirInterval : float2;
                                        human_sound_landmesh_queries__puddleQueryToDepth : float4;

                                        var human_sound_landmesh_queries__lastQueryTime : float&;
                                        var human_sound_landmesh_queries__biomeQueryId : int&;
                                        var human_sound_landmesh_queries__puddleQueryId : int&;
                                        var human_sound_landmesh_queries__biomeId : int&;
                                        var human_sound_landmesh_queries__puddleDepth : float&)

  if is_valid_query_id(human_sound_landmesh_queries__biomeQueryId)

    var biomeResult = BiomeQueryResult()
    let biomeState = biome_query_result(human_sound_landmesh_queries__biomeQueryId, biomeResult)
    if is_gpu_readback_query_successful(biomeState) || is_gpu_readback_query_failed(biomeState)
      human_sound_landmesh_queries__biomeQueryId = invalid_query_id()
      human_sound_landmesh_queries__biomeId = -1
      if is_gpu_readback_query_successful(biomeState)
        apply(biomeResult.mostFrequentBiomeGroupIndex, biomeResult.mostFrequentBiomeGroupWeight,
            human_sound_landmesh_queries__biomeId)

  elif is_valid_query_id(human_sound_landmesh_queries__puddleQueryId)

    var puddleResult = 0.
    let puddleState = puddle_query_value(human_sound_landmesh_queries__puddleQueryId, puddleResult)
    if is_gpu_readback_query_successful(puddleState) || is_gpu_readback_query_failed(puddleState)
      human_sound_landmesh_queries__puddleQueryId = invalid_query_id()
      human_sound_landmesh_queries__puddleDepth = 0.
      if is_gpu_readback_query_successful(puddleState)
        human_sound_landmesh_queries__puddleDepth = cvt(puddleResult,
          human_sound_landmesh_queries__puddleQueryToDepth.x, human_sound_landmesh_queries__puddleQueryToDepth.y,
          human_sound_landmesh_queries__puddleQueryToDepth.z, human_sound_landmesh_queries__puddleQueryToDepth.w)

  else
    var interval = -1.
    if human_sound_landmesh_queries_vars__isOnGround
      if human_sound_landmesh_queries_vars__speedSq >= square(human_sound_landmesh_queries__zeroSpeedThreshold)
        if is_watched_sound
          interval = cvt(sqrt(human_sound_landmesh_queries_vars__speedSq), human_sound_landmesh_queries__heroSpeedToQueryInterval.x, human_sound_landmesh_queries__heroSpeedToQueryInterval.y, human_sound_landmesh_queries__heroSpeedToQueryInterval.z, human_sound_landmesh_queries__heroSpeedToQueryInterval.w)
        else
          interval = cvt(sqrt(human_sound_landmesh_queries_vars__speedSq), human_sound_landmesh_queries__enemySpeedToQueryInterval.x, human_sound_landmesh_queries__enemySpeedToQueryInterval.y, human_sound_landmesh_queries__enemySpeedToQueryInterval.z, human_sound_landmesh_queries__enemySpeedToQueryInterval.w)
    else
      interval = is_watched_sound ? human_sound_landmesh_queries__heroEnemyInAirInterval.x : human_sound_landmesh_queries__heroEnemyInAirInterval.y

    if interval >= 0. && info.curTime >= human_sound_landmesh_queries__lastQueryTime + interval
      
      human_sound_landmesh_queries__lastQueryTime = info.curTime
      let pos = transform[3]
      if is_watched_sound || length_sq(get_listener_pos() - pos) < square(human_sound_landmesh_queries__farawayThreshold)
        let posXZ = pos.xz
        let ground = traceht_lmesh(posXZ)
        if pos.y - ground < human_sound_landmesh_queries__lmeshDiff
          human_sound_landmesh_queries__biomeQueryId = biome_query_start(float3(pos.x, ground, pos.z), 0.1)
          if human_sound_landmesh_queries__puddleQueryToDepth.w > 0. 
            human_sound_landmesh_queries__puddleQueryId = puddle_query_start(float3(pos.x, ground, pos.z))

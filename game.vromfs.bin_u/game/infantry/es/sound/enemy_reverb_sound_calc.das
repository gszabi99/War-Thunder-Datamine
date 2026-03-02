require ecs
require ecs.safe
require DagorConsole
require Sound
require DagorMath
require Dacoll
require PhysMat
require strings
require DagorMath


[es(no_order, tag=sound)]
def wt_enemy_reverb_sound_calculator_update(info : UpdateStageInfoAct;
                                            var wt_enemy_reverb_sound_calculator__eids : EidList&;
                                            wt_enemy_reverb_sound_calculator__distSq : float)
  let pos = get_cached_listener_pos()
  wt_enemy_reverb_sound_calculator__eids.clear()
  query() <| $ [es(REQUIRE_NOT = (deadEntity, watchedByPlr)), unused_argument(wt_enemy_reverb_sound__value)] (eid aka soldier_eid : EntityId; wt_enemy_reverb_sound__value : float; transform : float3x4)
    if length_sq(pos - transform[3]) < wt_enemy_reverb_sound_calculator__distSq
      wt_enemy_reverb_sound_calculator__eids |> push(soldier_eid)


[es(tag=sound, after=wt_enemy_reverb_sound_calculator_update)]
def wt_enemy_reverb_sound_calculator_update_values(info : UpdateStageInfoAct;
                                                   wt_enemy_reverb_sound_calculator__eids : EidList;
                                                   wt_enemy_reverb_sound_calculator__rays : Point3List;
                                                   wt_enemy_reverb_sound_calculator__traceLen : float;
                                                   var wt_enemy_reverb_sound_calculator__curEidIdx : int&)
  let numEids = length(wt_enemy_reverb_sound_calculator__eids)
  if numEids == 0
    return
  wt_enemy_reverb_sound_calculator__curEidIdx = (wt_enemy_reverb_sound_calculator__curEidIdx + 1) % numEids
  let maxRays = length(wt_enemy_reverb_sound_calculator__rays)
  query(wt_enemy_reverb_sound_calculator__eids[wt_enemy_reverb_sound_calculator__curEidIdx]) <| $ [es] (transform : float3x4;
                                                                                                        var wt_enemy_reverb_sound__value : float&;
                                                                                                        var wt_enemy_reverb_sound__rayIdx : int&;
                                                                                                        var wt_enemy_reverb_sound__raysLen : FloatList&)
    wt_enemy_reverb_sound__rayIdx = (wt_enemy_reverb_sound__rayIdx + 1) % maxRays
    let dir = wt_enemy_reverb_sound_calculator__rays[wt_enemy_reverb_sound__rayIdx]
    var t = wt_enemy_reverb_sound_calculator__traceLen
    var pmid = PHYSMAT_INVALID
    var norm : float3
    var riDesc = RendInstDesc()
    let start = transform[3] + float3(0, 1, 0)
    if traceray_normalized(start, dir, t, pmid, norm, ETF_LMESH | ETF_FRT | ETF_RI | ETF_STRUCTURES, riDesc, -1)
      wt_enemy_reverb_sound__raysLen[wt_enemy_reverb_sound__rayIdx] = t
    else
      wt_enemy_reverb_sound__raysLen[wt_enemy_reverb_sound__rayIdx] = wt_enemy_reverb_sound_calculator__traceLen

    var sumRayLen = 0.
    for rayLen in wt_enemy_reverb_sound__raysLen
      sumRayLen += rayLen
    wt_enemy_reverb_sound__value = 1. - sqrt(sumRayLen / (float(maxRays) * wt_enemy_reverb_sound_calculator__traceLen))
    wt_enemy_reverb_sound__value *= 100.f


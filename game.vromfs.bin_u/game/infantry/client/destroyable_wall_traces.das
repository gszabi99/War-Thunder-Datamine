require ecs
require Dacoll
require %game.events
require %appGame.infantry.client.destroyable_wall_client_common


[es(tag=gameClient, REQUIRE=hero)]
def mining_wall_check_availablity_on_update(evt : ParallelUpdateFrameDelayed;
                                            isDowned : bool;
                                            human__aimTm : float3x4;
                                            human_mining_wall__plantingMaxDist : float;
                                            human_mining_wall__bombEid : EntityId;
                                            human_mining_wall__plantingPosDistFromWall : float;
                                            human_mining_wall__plantingTraceInterval : float;
                                            human_mining_wall__bufferDistance : float;
                                            var human_mining_wall__isPlantingAvailable : bool&;
                                            var human_mining_wall__isContinuePlantingAvailable : bool&;
                                            var human_mining_wall__wallEid : EntityId&;
                                            var human_mining_wall__plantingPos : float3&;
                                            var human_mining_wall__plantingNorm : float3&;
                                            var human_mining_wall__plantingNextTraceTime : float&;
                                            var human_mining_wall__isReassemblingAvailable : bool&;
                                            var human_mining_wall__isContinueReassemblingAvailable : bool&;
                                            var human_mining_wall__reassemblingEntityId : EntityId&;
                                            var human_mining_wall__reassemblingPosition : float3&)
  if evt.curTime < human_mining_wall__plantingNextTraceTime
    return
  human_mining_wall__plantingNextTraceTime = evt.curTime + human_mining_wall__plantingTraceInterval

  human_mining_wall__isPlantingAvailable = false
  human_mining_wall__isContinuePlantingAvailable = false
  human_mining_wall__isReassemblingAvailable = false
  human_mining_wall__isContinueReassemblingAvailable = false

  if isDowned
    return

  var t = human_mining_wall__plantingMaxDist + human_mining_wall__bufferDistance
  var pmid = -1
  var riDesc = RendInstDesc()

  var traceStart = human__aimTm[3]
  var traceDir = human__aimTm[0]

  query() <| $ [es] (transform aka camera_transform : float3x4;
                                             camera__active : bool)
    if camera__active
      traceStart = camera_transform[3]
      traceDir = camera_transform[2]

  if traceray_normalized(traceStart, traceDir, t, pmid, human_mining_wall__plantingNorm, ETF_RI, riDesc, -1) && riDesc.isValid
    let riPoolId = int(handle_to_ri_type(riDesc.riExtraHandle))
    let riFlags = determine_mining_wall_flags(riPoolId)
    if (riFlags & int(MineWallFlag.CAN_MINE)) != 0
      if human_mining_wall__bombEid != INVALID_ENTITY_ID
        human_mining_wall__isPlantingAvailable = (t <= human_mining_wall__plantingMaxDist)
        human_mining_wall__isContinuePlantingAvailable = true
        human_mining_wall__plantingPos = traceStart + traceDir * (t - human_mining_wall__plantingPosDistFromWall)
        human_mining_wall__wallEid = find_ri_extra_eid(riDesc.riExtraHandle)
    human_mining_wall__reassemblingPosition = traceStart + traceDir * t
    if (riFlags & int(MineWallFlag.CAN_REASSEMBLE)) != 0
      human_mining_wall__isReassemblingAvailable = (t <= human_mining_wall__plantingMaxDist)
      human_mining_wall__isContinueReassemblingAvailable = true
      human_mining_wall__reassemblingEntityId = find_ri_extra_eid(riDesc.riExtraHandle)

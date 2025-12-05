module destroyable_wall_client_common shared

require ecs
require app
require RendInst


enum MineWallFlag
  CAN_MINE = 1
  CAN_REASSEMBLE = 2


def determine_mining_wall_flags(pool_id : int)
  if pool_id < 0
    return 0
  var flags = 0
  query() <| $ [es] (var destroyable_wall_config__riFlags : IntList&)
    assume arr = destroyable_wall_config__riFlags
    var cnt = length(arr)
    if cnt == 0
      query() <| $ [es] (destroyable_wall_config__riNames : StringList;
                         destroyable_wall_config__dmgRiNames : StringList;
                         var destroyable_wall_config__riFlagsGenStartTime : float&;
                         destroyable_wall_config__riFlagsGenTimeout : float)
        if destroyable_wall_config__riFlagsGenStartTime >= 0.0
          if get_sync_time() < destroyable_wall_config__riFlagsGenStartTime + destroyable_wall_config__riFlagsGenTimeout
            return

        var maxRi = -1
        var missing = 0
        for riName in destroyable_wall_config__riNames
          let idx = getRIGenExtraResIdx(string(riName))
          maxRi = max(maxRi, idx)
          if idx < 0
            ++missing
        for riName in destroyable_wall_config__dmgRiNames
          let idx = getRIGenExtraResIdx(string(riName))
          maxRi = max(maxRi, idx)
          if idx < 0
            ++missing

        if missing > 0
          if destroyable_wall_config__riFlagsGenStartTime < 0.0
            destroyable_wall_config__riFlagsGenStartTime = get_sync_time()
            return

        let numRi = max(1, maxRi + 1) 
        arr |> resize(numRi)
        for i in range(numRi)
          arr[i] = 0
        cnt = length(arr)

        for riName in destroyable_wall_config__riNames
          let idx = getRIGenExtraResIdx(string(riName))
          if idx >= 0
            arr[idx] |= int(MineWallFlag.CAN_MINE)
        for riName in destroyable_wall_config__dmgRiNames
          let idx = getRIGenExtraResIdx(string(riName))
          if idx >= 0
            arr[idx] |= int(MineWallFlag.CAN_REASSEMBLE)
    if pool_id < cnt
      flags = arr[pool_id]
  return flags

def determine_mining_wall_flags(ri_extra_eid : EntityId)
  var riFlags = 0
  query(ri_extra_eid) <| $ [es] (ri_extra : RiExtraComponent)
    let riType = handle_to_ri_type(ri_extra.handle)
    riFlags = determine_mining_wall_flags(int(riType))
  return riFlags

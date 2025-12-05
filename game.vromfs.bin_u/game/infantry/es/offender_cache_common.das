module offender_cache_common shared

require ecs
require ecs.common
require strings

struct CachedSoldier
  player : EntityId = INVALID_ENTITY_ID
  guid : string = ""

def get_offender_from_cache(eid)
  var res <- CachedSoldier()
  query() <| $ [es] (soldierInfoCache : Object)
    let cachedSoldier = get_ecs_object(soldierInfoCache, "{eid}")
    if cachedSoldier != null
      let playerId = get_int(cachedSoldier, "player")
      res.player = playerId != null ? EntityId(uint(*playerId)) : INVALID_ENTITY_ID
      res.guid = get_string(*cachedSoldier, "guid", "")
  return res

def is_valid_cache_soldier(cache : CachedSoldier)
  return !!cache.player && !empty(cache.guid)
from "%sqstd/ecs.nut" import *
let { get_local_mplayer } = require("mission")

let find_local_player_compsQuery = SqQuery("find_local_player_compsQuery", {comps_ro=[["eid", TYPE_EID],["base_player_id", TYPE_INT]]})
function find_local_player(){
  return find_local_player_compsQuery.perform(@(eid, _comp) eid, "eq(base_player_id,{0})".subst(get_local_mplayer().id)) ?? INVALID_ENTITY_ID
}

return {
  find_local_player
}
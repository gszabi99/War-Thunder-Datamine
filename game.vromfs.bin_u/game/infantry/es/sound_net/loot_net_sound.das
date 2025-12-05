require ecs
require app
require net
require soundHash
require %game.events

require %appGame.wt_events
require human_sounds.modules.human_sounds_events
require %game.utils.net_utils
require %appGame.infantry.es.inventory_common
require %appGame.infantry.es.team_common

let DEF_LOOT_RANGE : float = 20.

[es(tag=server)]
def loot_net_sound_on_loot_pickup(evt : EventOnLootPickup; eid : EntityId)
  let lootSoundType = get_string(evt.itemEid, "item__lootSoundType", "other")
  send_net_event(eid, CmdPlayLootSoundForEnemy(hash = sound_hash("pick_{lootSoundType}"), time = get_sync_time()),
                 enum_connections_near_entity(eid,  DEF_LOOT_RANGE, TEAM_UNASSIGNED, INVALID_ENTITY_ID, eid))

[es(tag=server)]
def loot_net_sound_on_loot_use(evt : EventOnLootUse; eid : EntityId)
  let lootSoundType = get_string(evt.itemEid, "item__lootSoundType", "other")
  send_net_event(eid, CmdPlayLootSound(hash = sound_hash("use_{lootSoundType}"), time = get_sync_time()),
                 enum_connections_near_entity(eid,  DEF_LOOT_RANGE))

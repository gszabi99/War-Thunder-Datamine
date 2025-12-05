require ecs
require app
require soundHash
require soundEvent
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.inventory_common
require human_sounds.modules.human_sounds_events
require sound_utils.modules.sound_utils_events


def play_sound(human_eid : EntityId; hash : uint; transform : float3x4; var loot_sound__time : float&)
  if get_sync_time() > loot_sound__time + 0.1
    loot_sound__time = get_sync_time()
    if should_play(transform[3])
      sendEvent(human_eid, CmdPlaySound(hash = hash, pos = transform[3]))

[es(tag=sound)]
def loot_sound(cmd : CmdPlayLootSound; eid : EntityId; transform : float3x4; var loot_sound__time : float&)
  if get_sync_time() < cmd.time + 5.
    play_sound(eid, cmd.hash, transform, loot_sound__time)

[es(tag=sound)]
def loot_sound_enemy(cmd : CmdPlayLootSoundForEnemy; eid : EntityId; transform : float3x4; var loot_sound__time : float&)
  if get_sync_time() < cmd.time + 5.
    play_sound(eid, cmd.hash, transform, loot_sound__time)

[es(tag=sound)]
def loot_sound_pickup(evt : EventOnLootPickup; eid : EntityId; transform : float3x4; var loot_sound__time : float&)
  let lootSoundType = get_string(evt.itemEid, "item__lootSoundType", "other")
  play_sound(eid, sound_hash("pick_{lootSoundType}"), transform, loot_sound__time)

[es(tag=sound)]
def loot_sound_drop(evt : EventOnLootDrop; eid : EntityId; transform : float3x4; is_watched_sound : bool; var loot_sound__time : float&)
  if is_watched_sound
    let lootSoundType = get_string(evt.itemEid, "item__lootSoundType", "other")
    play_sound(eid, sound_hash("drop_{lootSoundType}"), transform, loot_sound__time)

[es(tag=sound, REQUIRE=hero)]
def loot_sound_inventory_pickup(evt : CmdInventoryPickup)
  query(evt.itemEid) <| $ [es] (item__isInUse = false)
    if !item__isInUse
      sendEvent(evt.itemEid, CmdPlaySoundSimple(hash = sound_hash("inventoryPickup")))

[es(tag=sound)]
def ammo_box_resupply_play_sound(evt : CmdPlayItemUseSound;
                                 item__pickupSoundName : string;
                                 transform : float3x4)
  query(evt.requesterEid) <| $ [es] (is_watched_sound : bool; human_sound__prefix : string = "")
    let playerStr = is_watched_sound ? "player" : "enemy"
    oneshot("{human_sound__prefix}{playerStr}/{item__pickupSoundName}", transform[3])
require ecs
require ecs.common
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common


[es(tag=sound, on_appear, track=(human_inventory__entityToUse, isAlive, is_watched_sound, sound_preset__isLoaded), REQUIRE=humanSound)]
def human_using_item_sound(evt : Event;
                           sound_preset__isLoaded : bool;
                           sound_tags : Object;
                           human_inventory__entityToUse : EntityId;
                           var sound_event_group : SoundEventGroup&;
                           is_watched_sound : bool;
                           transform : float3x4;
                           isAlive : bool)
  reject_sound(sound_event_group, sound_hash("loot"))
  if human_inventory__entityToUse != INVALID_ENTITY_ID && isAlive && should_play(transform[3]) && sound_preset__isLoaded
    query(human_inventory__entityToUse) <| $ [es] (@shared_comp using_item_sound__path : Object; using_item_sound__prefix = "infantry/")
      play_path(using_item_sound__path, sound_tags, is_watched_sound, transform[3], sound_hash("loot"), sound_event_group, 0.f, using_item_sound__prefix)

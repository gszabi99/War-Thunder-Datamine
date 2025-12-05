require ecs
require sound_utils.modules.sound_player_common
require soundSystem

require %appGame.wt_events


[es(tag=sound, REQUIRE=watchedByPlr)]
def head_shot_kill_sound(evt : EventHeadShotKill;
                         sound_preset__isLoaded : bool;
                         @shared_comp human_hit_sound__paths : Object;
                         sound_tags : Object;
                         human_hit_sound__headshotSoundEnabled : bool;
                         human_hit_sound__prefix : string = "infantry/")
  if human_hit_sound__headshotSoundEnabled && sound_preset__isLoaded
    sound_player_common::play_path("heroHitEnemyHead", human_hit_sound__paths, sound_tags, true, get_listener_pos(), true, human_hit_sound__prefix)

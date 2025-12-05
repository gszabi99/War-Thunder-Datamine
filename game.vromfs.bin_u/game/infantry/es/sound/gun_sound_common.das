module gun_sound_common shared
require ecs
require DagorMath
require sound_utils.modules.sound_player_common
require strings


def get_gun_sound_pos(animchar_bbox : bbox3f)
  return (animchar_bbox.bmin.xyz + animchar_bbox.bmax.xyz) * 0.5


def make_gun_shot_sound_path_str(shot_path, tags : Object; is_watched, is_single_shot : bool) : string
  return make_final_path_str(shot_path, tags, is_watched, is_single_shot ? "shot_single" : "shot_loop")


def make_gun_shot_sound_path_str(shot_path : Object; path_id : int; is_watched, is_single_shot : bool) : string
  return make_final_path_str(shot_path, path_id, is_watched, is_single_shot ? "shot_single" : "shot_loop")

def make_gun_shot_sound_grain_path_str(shot_path, tags : Object; is_watched : bool) : string
  return make_final_path_str(shot_path, tags, is_watched, "shot_grains")

def is_watched_gun_sound(gun__owner : EntityId) : bool
  var isWatched = false
  query(gun__owner) <| $ [es] (is_watched_sound : bool; human_anim__vehicleSelected = INVALID_ENTITY_ID)
    isWatched = is_watched_sound
    query(human_anim__vehicleSelected) <| $ [es] (is_watched_sound : bool)
      isWatched ||= is_watched_sound
  return isWatched



















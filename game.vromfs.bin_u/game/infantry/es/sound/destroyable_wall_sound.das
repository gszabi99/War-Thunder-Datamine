require ecs
require DagorMath
require soundEvent
require soundSystem
require %game.events
require sound_utils.modules.sound_player_common


[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def mining_wall_planting_sound_on_update(info : ParallelUpdateFrameDelayed;
                                         transform : float3x4;
                                         human_mining_wall__plantingStartTime : float&;
                                         sound_preset__isLoaded : bool;
                                         human_mining_wall_planting__hero : string;
                                         human_mining_wall_planting__enemy : string;
                                         is_watched_sound : bool;
                                         var human_mining_wall_planting : SoundEvent&)
  if !sound_preset__isLoaded
    return
  if human_mining_wall__plantingStartTime > 0.0
    if !is_playing(human_mining_wall_planting)
      human_mining_wall_planting |> play(is_watched_sound ? human_mining_wall_planting__hero : human_mining_wall_planting__enemy, transform[3])
  elif is_playing(human_mining_wall_planting)
    keyoff(human_mining_wall_planting)

[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def mining_wall_reassembling_sound_on_update(info : ParallelUpdateFrameDelayed;
                                             transform : float3x4;
                                             human_mining_wall__reassemblingStartTime : float&;
                                             sound_preset__isLoaded : bool;
                                             human_mining_wall_reassembling__hero : string;
                                             human_mining_wall_reassembling__enemy : string;
                                             is_watched_sound : bool;
                                             var human_mining_wall_reassembling : SoundEvent&)
  if !sound_preset__isLoaded
    return
  if human_mining_wall__reassemblingStartTime > 0.0
    if !is_playing(human_mining_wall_reassembling)
      human_mining_wall_reassembling |> play(is_watched_sound ? human_mining_wall_reassembling__hero : human_mining_wall_reassembling__enemy, transform[3])
  elif is_playing(human_mining_wall_reassembling)
    keyoff(human_mining_wall_reassembling)

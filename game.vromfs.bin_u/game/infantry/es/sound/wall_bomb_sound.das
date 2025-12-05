require ecs
require DagorMath
require soundEvent
require soundSystem
require %game.events
require sound_utils.modules.sound_player_common

[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def planted_wall_bomb_tick_sound_on_update(info : ParallelUpdateFrameDelayed;
                                           transform : float3x4;
                                           wall_bomb__explosionDelay : float;
                                           wall_bomb_planted__explosionAtTime : float;
                                           wall_bomb_planted__tickSoundPath : string;
                                           var wall_bomb_planted__tickSoundEvent : SoundEvent&)
  let shouldPlay = wall_bomb_planted__explosionAtTime > 0. && sound_banks_is_master_preset_loaded()
  if wall_bomb_planted__tickSoundEvent |> play_or_release(wall_bomb_planted__tickSoundPath, transform[3], shouldPlay)

    let timeBegin = wall_bomb_planted__explosionAtTime - wall_bomb__explosionDelay
    let timeEnd = wall_bomb_planted__explosionAtTime
    let timer = cvt(info.curTime, timeBegin, timeEnd, 0.0, 1.0)
    set_var(wall_bomb_planted__tickSoundEvent, "explosive_timer", timer)

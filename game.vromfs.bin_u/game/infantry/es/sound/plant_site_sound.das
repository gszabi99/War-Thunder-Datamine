require ecs
require DagorMath
require soundEvent
require soundSystem
require %game.events
require sound_utils.modules.sound_player_common

[es(tag=sound, after=sound_begin_update_es, before=sound_end_update_es)]
def plant_site_tick_sound_on_update(info : ParallelUpdateFrameDelayed;
                                    transform : float3x4;
                                    bomb_site__explosionTimeEnd : float;
                                    bomb_site__timeToExplosion : float;
                                    bomb_site_tick_sound__path : string;
                                    var bomb_site_tick_sound__event : SoundEvent&)
  let shouldPlay = bomb_site__explosionTimeEnd > 0. && sound_banks_is_master_preset_loaded()
  if bomb_site_tick_sound__event |> play_or_release(bomb_site_tick_sound__path, transform[3], shouldPlay)
    let timeBegin = bomb_site__explosionTimeEnd - bomb_site__timeToExplosion
    let timer = cvt(info.curTime, timeBegin, bomb_site__explosionTimeEnd, 0.0, 1.0)
    set_var(bomb_site_tick_sound__event, "explosive_timer", timer)

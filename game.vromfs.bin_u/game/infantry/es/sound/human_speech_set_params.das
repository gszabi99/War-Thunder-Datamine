require ecs
require soundEvent
require %appGame.infantry.es.team_common
require DagorConsole

[es(tag=sound, on_event=EventOnHumanSpeak)]
def human_speech_set_params(evt : Event;
                            human_speech__event : SoundEvent&;
                            is_watched_sound : bool;
                            wt_enemy_reverb_sound__value : float;
                            team aka speaker_team : int)
  query() <| $ [es(REQUIRE=hero)] (team aka hero_team : int)
    set_var_optional(human_speech__event, "friendly", is_teams_friendly(hero_team, speaker_team) ? 1. : 0.)
  if !is_watched_sound
    set_var_optional(human_speech__event, "reverbindoor", wt_enemy_reverb_sound__value)

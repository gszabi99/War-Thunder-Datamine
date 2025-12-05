require ecs
require soundEvent
require %appGame.infantry.es.team_common


[es(tag=sound, on_event=EventOnHumanSpeak)]
def human_speech_is_friendly(evt : Event;
                             human_speech__event : SoundEvent&;
                             team aka speaker_team : int)
  query() <| $ [es(REQUIRE=hero)] (team aka hero_team : int)
    set_var_optional(human_speech__event, "friendly", is_teams_friendly(hero_team, speaker_team) ? 1. : 0.)

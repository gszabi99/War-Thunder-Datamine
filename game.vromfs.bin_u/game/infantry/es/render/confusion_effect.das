require ecs
require app
require DagorShaders
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.game_effect_macro

let
  confusion_effect_time_startVarId = get_shader_variable_id("confusion_effect_time_start", true)
  confusion_effect_durationVarId = get_shader_variable_id("confusion_effect_duration", true)
  confusion_effect_intensityVarId = get_shader_variable_id("confusion_effect_intensity", true)
  confusion_effect_speedVarId = get_shader_variable_id("confusion_effect_speed", true)


def enable_confusion_effect(watchedEid : EntityId)
  find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                          confusion__duration : float;
                          confusion__intensity : float;
                          confusion__speed : float)
    if game_effect__attachedTo == watchedEid
      DagorShaders::set_real(confusion_effect_time_startVarId, get_shader_global_time_phase(0.0, 0.0))
      DagorShaders::set_real(confusion_effect_durationVarId, confusion__duration)
      DagorShaders::set_real(confusion_effect_intensityVarId, confusion__intensity)
      DagorShaders::set_real(confusion_effect_speedVarId, confusion__speed)
      return true
    return false


def disable_confusion_effect()
  DagorShaders::set_real(confusion_effect_time_startVarId, -1000.0)


[es_game_effect(bool_flag=human__confusionScreenEffect, tag=confusionScreenEffect)]
def human_concussion_screen_effect_es() { pass; }


[es(tag=render, track=human__confusionScreenEffect, REQUIRE=watchedByPlr)]
def confusion_effect_track_es(evt : Event; eid : EntityId; human__confusionScreenEffect : bool)
  if human__confusionScreenEffect
    enable_confusion_effect(eid)
  else
    disable_confusion_effect()


[es(tag=render, on_appear, REQUIRE=watchedByPlr)]
def confusion_effect_enable_es(evt : Event; eid : EntityId; human__confusionScreenEffect : bool)
  if human__confusionScreenEffect
    enable_confusion_effect(eid)


[es(tag=render, on_disappear, REQUIRE=watchedByPlr, REQUIRE=human__confusionScreenEffect)]
def confusion_effect_disable_es(evt : Event)
  disable_confusion_effect()

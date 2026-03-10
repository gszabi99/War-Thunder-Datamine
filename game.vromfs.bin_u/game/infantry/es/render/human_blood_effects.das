require ecs
require app
require math.base
require DagorShaders
require %game.events
require app
require ecs
require math
require math.base
require math.random
require DagorMath


let blood_intensityVarId = get_shader_variable_id("blood_intensity", true)


[es(tag=render, on_appear, REQUIRE=(human, hero), REQUIRE_NOT=deadEntity)]
def human_bleeding_effect_on_human_appear(evt : Event;
                                          var human_bleeding_effect__activate : bool&)
  human_bleeding_effect__activate = false
  DagorShaders::set_real(blood_intensityVarId, 0.0)


[es(tag=render, no_order, REQUIRE=(human, hero), REQUIRE_NOT=deadEntity)]
def human_bleeding_effect(act : UpdateStageInfoAct;
                          human__disableScreenEffects : bool = false;
                          hitpoints__totalDotAmount : float;
                          hitpoints__maxHp : float;
                          human_bleeding_effect__minIntensity : float;
                          human_bleeding_effect__maxIntensity : float;
                          var human_bleeding_effect__activate : bool&;
                          var human_bleeding_effect__current : float&)
  if human__disableScreenEffects
    return
  let isBleeding = hitpoints__totalDotAmount > 0.f
  if human_bleeding_effect__activate || isBleeding
    let targetIntensity = hitpoints__totalDotAmount > 0.f ? cvt(hitpoints__totalDotAmount, 0.f, hitpoints__maxHp, human_bleeding_effect__minIntensity, human_bleeding_effect__maxIntensity) : 0.f
    human_bleeding_effect__current = approach(human_bleeding_effect__current, targetIntensity, act.dt, 0.5)
    if human_bleeding_effect__current < 0.01
      DagorShaders::set_real(blood_intensityVarId, 0.)
      human_bleeding_effect__activate = false
    else
      DagorShaders::set_real(blood_intensityVarId, human_bleeding_effect__current)
      human_bleeding_effect__activate = true


[es(tag=render, on_appear, REQUIRE=(deadEntity, human, hero))]
def human_bleeding_effect_on_human_die(evt : Event;
                                       var human_bleeding_effect__activate : bool&)
  human_bleeding_effect__activate = false
  DagorShaders::set_real(blood_intensityVarId, 0.0)

[es(tag=render, REQUIRE=(human, hero), track=human__disableScreenEffects)]
def track_disable_blood_screen_effect(evt : Event;
                                      human__disableScreenEffects : bool)
  if human__disableScreenEffects
    DagorShaders::set_real(blood_intensityVarId, 0.0)

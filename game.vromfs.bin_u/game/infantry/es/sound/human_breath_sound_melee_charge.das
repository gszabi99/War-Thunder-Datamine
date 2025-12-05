require ecs
require DagorMath
require %game.events


[es(tag=sound, after=sound_begin_update_es, before=(human_breath_sound_update, sound_end_update_es))]
def human_breath_sound_melee_charge(info : ParallelUpdateFrameDelayed;
                                    human_melee_charge__isOnCooldown : bool;
                                    human_melee_charge__chargeEndTime : float;
                                    human_melee_charge__cooldown : float;
                                    var human_breath_sound__breathShortness : float&)
  if human_melee_charge__isOnCooldown
    human_breath_sound__breathShortness += cvt(info.curTime, human_melee_charge__chargeEndTime, human_melee_charge__chargeEndTime + human_melee_charge__cooldown, 1., 0.)

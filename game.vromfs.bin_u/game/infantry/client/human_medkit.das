require ecs
require %game.events
require DagorDataBlock
require hud

[es(tag=gameClient, REQUIRE=hero)]
def human_medkit_update_need_display_heal_tip(info : ParallelUpdateFrameDelayed;
                                              isDowned : bool;
                                              burning__isBurning : bool;
                                              heal__continuousInput : bool;
                                              hitpoints__hp : float;
                                              hitpoints__maxHp : float;
                                              hitpoints__deathHpThreshold : float;
                                              human_inventory__hpThresholdForHealTip : float;
                                              human_inventory__entityUseEnd : float;
                                              human_inventory__canUseMedkit : bool;
                                              var human_medkit__needDisplayHealTip : bool&)
  let maxHp = !isDowned ? hitpoints__maxHp : -hitpoints__deathHpThreshold
  let needUseMedkitOrRevive = !burning__isBurning && human_inventory__entityUseEnd < info.curTime
  let isHpLessThanThreshold = hitpoints__hp > 0.0 && maxHp > 0.0 && hitpoints__hp / maxHp < human_inventory__hpThresholdForHealTip
  human_medkit__needDisplayHealTip = needUseMedkitOrRevive && human_inventory__canUseMedkit && heal__continuousInput && (isDowned || isHpLessThanThreshold)


[es(tag=gameClient, REQUIRE=hero, track=(human_medkit__needDisplayBleedingTip, human_medkit__needDisplayHealTip))]
def human_medkit_tip_show_es(evt : Event;
                             human_medkit__needDisplayBleedingTip : bool;
                             human_medkit__needDisplayHealTip : bool)
  using() <| $(var eventData : DataBlock)
    hud_notify_script(human_medkit__needDisplayHealTip && !human_medkit__needDisplayBleedingTip ? "hint:human_medkit_hint_show" : "hint:human_medkit_hint_hide", eventData)


[es(tag=gameClient, REQUIRE=hero)]
def human_medkit_update_need_display_bleeding_tip(info : ParallelUpdateFrameDelayed;
                                                  isDowned : bool;
                                                  burning__isBurning : bool;
                                                  heal__continuousInput : bool;
                                                  hitpoints__totalDotAmount : float;
                                                  hitpoints__maxHp : float;
                                                  human_inventory__dotThresholdForBleedingTip : float;
                                                  human_inventory__entityUseEnd : float;
                                                  human_inventory__canUseMedkit : bool;
                                                  var human_medkit__needDisplayBleedingTip : bool&)
  let needUseMedkitOrRevive = !isDowned && !burning__isBurning && human_inventory__entityUseEnd < info.curTime
  let isDotMoreThanThreshold = hitpoints__maxHp > 0.0 && hitpoints__totalDotAmount / hitpoints__maxHp > human_inventory__dotThresholdForBleedingTip
  human_medkit__needDisplayBleedingTip = needUseMedkitOrRevive && human_inventory__canUseMedkit && heal__continuousInput && isDotMoreThanThreshold

[es(tag=gameClient, REQUIRE=hero, track=human_medkit__needDisplayBleedingTip)]
def human_bleeding_tip_show_es(evt : Event;
                               human_medkit__needDisplayBleedingTip : bool)
  using() <| $(var eventData : DataBlock)
    hud_notify_script(human_medkit__needDisplayBleedingTip ? "hint:bleeding_tip_show" : "hint:bleeding_tip_hide", eventData)

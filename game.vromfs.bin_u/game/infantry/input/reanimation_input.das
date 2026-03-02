require ecs
require app
require net
require WTInput
require %game.input.input_events
require %appGame.wt_events
require %game.events


[es(tag=input, REQUIRE=controlledHero)]
def reanimation_input_action_triggered(evt : EventOnKeyDown;
                                       eid : EntityId;
                                       input__enabled : bool = true;
                                       human_reanimator__reanimationAvailable : bool;
                                       human_reanimator__reanimatedHumanEid : EntityId;
                                       human_reanimator__position : float3;
                                       human_reanimator__reanimationStartTime : float)
  if !input__enabled || human_reanimator__reanimationStartTime > 0.0
    return

  if evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    if human_reanimator__reanimationAvailable
      send_net_event(eid, CmdStartReanimation(reanimatedEid = human_reanimator__reanimatedHumanEid,
                                              reanimatedPos = human_reanimator__position))


[es(tag=input, REQUIRE=(human_reanimator__reanimatedHumanEid, controlledHero))]
def reanimation_input_action_terminated(evt : EventOnKeyUp;
                                        eid : EntityId;
                                        human_reanimator__reanimationStartTime : float;
                                        input__enabled : bool = true)
  if input__enabled && human_reanimator__reanimationStartTime > 0.0 && evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    send_net_event(eid, CmdStopReanimation())


[es(tag=input, REQUIRE=controlledHero)]
def reanimation_input_decline_reanimation_triggered(evt : EventOnKeyDown;
                                                    input__enabled : bool = true;
                                                    reanimation__knockedDown : bool;
                                                    reanimation__declineHoldDuration : float;
                                                    var reanimation__declineTime : float&)
  if !input__enabled || !reanimation__knockedDown
    return

  if evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    reanimation__declineTime = get_sync_time() + reanimation__declineHoldDuration


[es(tag=input, REQUIRE=controlledHero)]
def reanimation_input_decline_reanimation_terminated(evt : EventOnKeyUp;
                                                     input__enabled : bool = true;
                                                     reanimation__knockedDown : bool;
                                                     var reanimation__declineTime : float&)
  if !input__enabled || !reanimation__knockedDown || reanimation__declineTime < 0.0
    return

  if evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    reanimation__declineTime = -1.0


[es(tag=input, REQUIRE=controlledHero)]
def reanimation_decline_reanimation_decline_timeout(info : ParallelUpdateFrameDelayed;
                                                    eid : EntityId;
                                                    input__enabled : bool = true;
                                                    reanimation__knockedDown : bool;
                                                    var reanimation__declineTime : float&)
  if !input__enabled || !reanimation__knockedDown || reanimation__declineTime < 0.0
    return

  if info.curTime > reanimation__declineTime
    send_net_event(eid, CmdDeclineReanimation())
    reanimation__declineTime = -1.0

[es(tag=gameClient, REQUIRE=controlledHero)]
def reanimation_ask_for_help(evt : EventOnKeyDown;
                             eid : EntityId;
                             input__enabled : bool = true;
                             reanimation__knockedDown : bool;
                             reanimation__askForHelpTimeout : float;
                             reanimation__askForHelpAvailable : bool;
                             var reanimation__askForHelpAvailableAt : float&)
  if !input__enabled || !reanimation__knockedDown
    return

  let curTime = get_sync_time()
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_ASK_FOR_REANIMAION) && reanimation__askForHelpAvailable
    send_net_event(eid, CmdAskForHelpSpeech())
    reanimation__askForHelpAvailableAt = curTime + reanimation__askForHelpTimeout

require ecs
require app
require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common
require %appGame.infantry.es.team_common
require net
require DngHuman
require DagorMath
require DagorSystem
require soundEvent


[es(tag=server, on_appear, REQUIRE=deadEntity)]
def reanimation_start_death_timer_es(evt : Event;
                                     isAlive : bool;
                                     reanimation__available : bool;
                                     reanimation__deathTimeout : float;
                                     var reanimation__knockedDown : bool&;
                                     var reanimation__deathTime : float&)
  if !isAlive && reanimation__available
    reanimation__knockedDown = true
    reanimation__deathTime = get_sync_time() + reanimation__deathTimeout


[es(tag=server, no_order, REQUIRE=deadEntity)]
def reanimation_death_timer_es(info : UpdateStageInfoAct;
                               eid : EntityId;
                               isAlive : bool;
                               reanimation__available : bool;
                               var reanimation__knockedDown : bool&;
                               var reanimation__deathTime : float&)
  if reanimation__available && !isAlive && reanimation__deathTime > 0.0
    if info.curTime > reanimation__deathTime
      sendEvent(eid, EventDiedNotReanimated())
      reanimation__deathTime = -1.0
      reanimation__knockedDown = false


[es(tag=server, REQUIRE=(human, deadEntity))]
def on_reanimation_request_es(evt : CmdRequestReanimation)
  sendEvent(evt.reanimatedEid, EventDoReanimation(pos = evt.pos))


[es(tag=server, REQUIRE=deadEntity)]
def reanimation_es(evt : EventDoReanimation;
                   eid : EntityId;
                   reanimation__hitpointsAfterReanimation : float;
                   reanimation__maxDistToleranceSq : float;
                   transform : float3x4;
                   var human_net_phys : HumanActor;
                   var reanimation__available : bool&;
                   var reanimation__knockedDown : bool&;
                   var reanimation__numReanimations : int&;
                   var reanimation__deathTime : float&;
                   var hitpoints__hp : float&;
                   var isAlive : bool&)
  if reanimation__knockedDown
    if distance_sq(evt.pos, transform[3]) > reanimation__maxDistToleranceSq
      logerr("reanimated soldier ({eid}) is to far from it's reanimator ({evt.reanimatorEid}), suspicion of cheating")
      return
    clear_bleeding_for_eid(eid)
    isAlive = true
    hitpoints__hp = reanimation__hitpointsAfterReanimation
    reanimation__knockedDown = false
    reanimation__deathTime = -1.0
    reanimation__numReanimations--
    reanimation__available = reanimation__numReanimations > 0
    human_net_phys.phys.currentState.location.P = DPoint3(evt.pos)
    
    send_net_event(eid, EventOnEntityReanimated())


[es(on_event=EventOnEntityReanimated)]
def on_reanimation_compleated_es(evt : Event;
                                 var human_input__standState : int?;
                                 var human_net_phys : HumanActor)
  assume ct = human_net_phys.phys.producedCT
  assume aCt = human_net_phys.phys.appliedCT
  assume baseCurState = human_net_phys.phys.currentState
  assume basePrevState = human_net_phys.phys.previousState
  aCt |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, true)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, true)
  basePrevState.height = -1.0
  baseCurState.height = -1.0

  if human_input__standState != null
    *human_input__standState = int(HumanPhysControlType.HCT_CRAWL)


[es(tag=server, on_event=CmdDeclineReanimation)]
def reanimation_declining_es(evt : Event;
                             eid : EntityId;
                             var reanimation__deathTime : float&;
                             var reanimation__knockedDown : bool&)
  if reanimation__knockedDown
    sendEvent(eid, EventDiedNotReanimated())
    reanimation__deathTime = -1.0
    reanimation__knockedDown = false


[es]
def reanimation_on_start_client(evt : CmdStartReanimation;
                                human_reanimator__reanimationDuration : float;
                                var human_reanimator__reanimationStartTime : float&;
                                var human_reanimator__reanimationEndTime : float&)
  human_reanimator__reanimationStartTime = get_sync_time()
  human_reanimator__reanimationEndTime = human_reanimator__reanimationStartTime + human_reanimator__reanimationDuration

[es(tag=sound)]
def reanimation_start_sound(evt : CmdStartReanimation;
                            var human_reanimator__soundEvent : SoundEvent&;
                            human_reanimator__soundName : string;
                            human_sound__prefix : string = "";
                            is_watched_sound : bool)
  let playerStr = is_watched_sound ? "player/" : "enemy/"
  let path = "{human_sound__prefix}{playerStr}{human_reanimator__soundName}"
  play(human_reanimator__soundEvent, path, evt.reanimatedPos)


def reanimation_stop_sound(var human_reanimator__soundEvent : SoundEvent&)
  if is_playing(human_reanimator__soundEvent)
    abandon(human_reanimator__soundEvent)


[es(tag=server)]
def reaimation_on_start_server(evt : CmdStartReanimation;
                               var human_reanimator__reanimatedHumanEid : EntityId&;
                               var human_reanimator__position : float3&)
  human_reanimator__reanimatedHumanEid = evt.reanimatedEid
  human_reanimator__position = evt.reanimatedPos


def private stop_reanimation(var human_reanimator__reanimatedHumanEid : EntityId&;
                             var human_reanimator__position : float3&;
                             var human_reanimator__reanimationStartTime : float&;
                             var human_reanimator__reanimationEndTime : float&)
  human_reanimator__reanimatedHumanEid = INVALID_ENTITY_ID
  human_reanimator__reanimationStartTime = -1.0
  human_reanimator__reanimationEndTime = -1.0
  human_reanimator__position = float3()


[es]
def reanimation_on_stop(evt : CmdStopReanimation;
                        var human_reanimator__position : float3&;
                        var human_reanimator__reanimatedHumanEid : EntityId&;
                        var human_reanimator__reanimationStartTime : float&;
                        var human_reanimator__soundEvent : SoundEvent&;
                        var human_reanimator__reanimationEndTime : float&)
  stop_reanimation(human_reanimator__reanimatedHumanEid, human_reanimator__position, human_reanimator__reanimationStartTime, human_reanimator__reanimationEndTime)
  reanimation_stop_sound(human_reanimator__soundEvent)

[es(tag=netClient, no_order)]
def reanimation_stop_on_timer_client(info : UpdateStageInfoAct;
                                     var human_reanimator__position : float3&;
                                     var human_reanimator__reanimationStartTime : float&;
                                     var human_reanimator__reanimationEndTime : float&;
                                     var human_reanimator__soundEvent : SoundEvent&;
                                     var human_reanimator__reanimatedHumanEid : EntityId&)
  if human_reanimator__reanimationStartTime < 0.0 || !human_reanimator__reanimatedHumanEid
    return
  if info.curTime < human_reanimator__reanimationEndTime
    return

  stop_reanimation(human_reanimator__reanimatedHumanEid, human_reanimator__position, human_reanimator__reanimationStartTime, human_reanimator__reanimationEndTime)
  reanimation_stop_sound(human_reanimator__soundEvent)


[es(tag=server, no_order)]
def reanimation_on_update(info : UpdateStageInfoAct;
                          eid : EntityId;
                          human_reanimator__position : float3;
                          human_reanimator__reanimationStartTime : float;
                          human_reanimator__reanimationEndTime : float;
                          human_reanimator__reanimatedHumanEid : EntityId)
  if human_reanimator__reanimationStartTime < 0.0 || !human_reanimator__reanimatedHumanEid
    return

  var stopReanimation = true
  query(human_reanimator__reanimatedHumanEid) <| $ [es] (reanimation__knockedDown : bool;
                                                         var reanimation__deathTime : float&)
    if reanimation__knockedDown
      reanimation__deathTime += info.dt
      stopReanimation = false

  if stopReanimation
    send_net_event(eid, CmdStopReanimation())
    return

  if info.curTime < human_reanimator__reanimationEndTime
    return

  sendEvent(human_reanimator__reanimatedHumanEid, EventDoReanimation(pos = human_reanimator__position, reanimatorEid = eid))
  send_net_event(eid, CmdStopReanimation())


[es(tag=server)]
def reanimation_on_ask_for_help_speech(evt : CmdAskForHelpSpeech;
                                       eid aka requester_eid : EntityId;
                                       transform aka requester_transform : float3x4;
                                       team aka requester_team : int;
                                       reanimation__knockedDown : bool;
                                       reanimation__askForHelpRadiusSq : float)
  if reanimation__knockedDown
    query() <| $ [es(REQUIRE=human)] (eid aka human_eid : EntityId;
                                      team aka human_team : int;
                                      transform aka human_transform : float3x4)
      if requester_eid == human_eid
        send_net_event(human_eid, CmdRequestHelp(soundPath = "help_self", requesterEid = requester_eid))
      elif is_teams_friendly(requester_team, human_team) && distance_sq(requester_transform[3], human_transform[3]) < reanimation__askForHelpRadiusSq
        send_net_event(human_eid, CmdRequestHelp(soundPath = "help_teammates", requesterEid = requester_eid))

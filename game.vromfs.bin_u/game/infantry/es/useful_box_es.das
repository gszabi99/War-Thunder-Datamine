require ecs
require net
require %appGame.infantry.es.action_common
require app
require %appGame.wt_events
require %appGame.infantry.es.team_common
require %game.events
require PropsManager
require ecs.common


[es(tag=server, on_appear)]
def init_useful_box_refill_count_es(evt : Event; useful_box__maxUseCount : int; var useful_box__useCount : int&)
  useful_box__useCount = useful_box__maxUseCount

[es(tag=server)]
def useful_box_use_request_es(evt : CmdUse;
                              eid : EntityId;
                              useful_box__useCount : int;
                              team : int;
                              useful_box__cooldown : float;
                              useful_box__nextUseAtTimes : FloatList;
                              useful_box__requesters : EidList;
                              useful_box__anyTeam : Tag const?)
  let requester = evt.requesterEid
  if !requester || useful_box__useCount <= 0
    return
  if useful_box__cooldown > 0.f
    let time = get_sync_time()
    let findIndex = useful_box__requesters |> find_index(requester)
    if findIndex >= 0 && findIndex < length(useful_box__nextUseAtTimes)
      let nextUseAtTime = useful_box__nextUseAtTimes[findIndex]
      if time < nextUseAtTime
        return

  let ownedByTeam = team
  var isValidTeam = false
  query(requester) <| $ [es] (team : int)
    isValidTeam = useful_box__anyTeam != null || is_teams_friendly(team, ownedByTeam)

  if !isValidTeam
    send_net_event(requester, CmdHeroLogEvent(event = "enemy_crate", text = "resupply/enemy_crate"))
    return

  sendEvent(eid, CmdUseUsefulBox(requesterEid = requester))

[es(tag=server)]
def useful_box_use_finish_es(evt : CmdUseUsefulBox;
                             eid : EntityId;
                             useful_box__cooldown : float;
                             var useful_box__nextUseAtTimes : FloatList&;
                             var useful_box__requesters : EidList&;
                             var useful_box__requiredUseCount : int&;
                             var useful_box__useCount : int&;
                             var useful_box__successUse : bool&)
  if !useful_box__successUse
    return
  let requester = evt.requesterEid
  useful_box__useCount -= useful_box__requiredUseCount
  useful_box__requiredUseCount = 0
  useful_box__successUse = false
  if useful_box__cooldown > 0.f
    let timesLength = length(useful_box__nextUseAtTimes)
    let curTime = get_sync_time()
    for i in range(timesLength)
      let curIdx = timesLength - i - 1
      if curIdx >= 0 && curIdx < length(useful_box__requesters) && useful_box__nextUseAtTimes[curIdx ] <= curTime
        useful_box__requesters |> erase(curIdx)
        useful_box__nextUseAtTimes |> erase(curIdx)
    useful_box__requesters |> push(requester)
    useful_box__nextUseAtTimes |> push(curTime + useful_box__cooldown)
  send_net_event(evt.requesterEid, CmdUsefulBoxCompleteUse())
  sendEvent(eid, EventOnUsefulBoxSuccessfulUse(requester = evt.requesterEid))

[es(tag=gameClient, track=useful_box__useCount)]
def destroy_markers_for_empty_box(evt : Event; useful_box__useCount : int; var minimap__visibleForAll : bool&)
  if useful_box__useCount <= 0
    minimap__visibleForAll = false

[es(tag=gameClient, track=useful_box__useCount)]
def apply_amimvars_for_empty_box_es(evt : Event; eid : EntityId; useful_box__useCount : int)
  if useful_box__useCount <= 0
    sendEvent(eid, EventApplyCustomAnimcharVars())

[es(tag=gameClient, on_event=CmdUsefulBoxCompleteUse, REQUIRE=human)]
def useful_box_play_complete_animation_es(evt : Event; eid : EntityId)
  run_action(eid, "pickup")

[es(tag=server, track=useful_box__useCount, REQUIRE=useful_box__destroyEmpty)]
def destroy_useful_box_on_no_uses_left(evt : Event;
                                       eid : EntityId;
                                       useful_box__useCount : int)
  if useful_box__useCount <= 0
    destroyEntity(eid)

require app
require ecs
require net
require DngHuman
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.tnt_common
require %appGame.infantry.es.human_weap_common


def tnt_exploder_server_report_fail_explode(tnt_exploder : EntityId)
  send_net_event(tnt_exploder, ResponseTntExploderFailExplode())

[es(tag=gameClient, REQUIRE=watchedPlayerItem)]
def tnt_exploder_on_fail_explode_response(evt : ResponseTntExploderFailExplode;
                                          var tnt_exploder__inProgress : bool&;
                                          var tnt_exploder_anim__state : int&)
  tnt_exploder__inProgress = false
  tnt_exploder_anim__state = int(TntExploderAnimState.TEAS_NONE)

[es(tag=gameClient, REQUIRE=(tnt_exploder, tnt_launcher))]
def tnt_exploder_with_launcher_phys_es(evt : CmdWeapPhysUpdate;
                                       eid : EntityId;
                                       tnt_exploder__tntBlocks : EidList;
                                       throwable_launcher__inProgress : bool;
                                       tnt_exploder_anim__detonationTime : float;
                                       var tnt_exploder__inProgress : bool&;
                                       var tnt_exploder_anim__state : int&;
                                       var tnt_exploder_anim__stateStart : float&;
                                       var tnt_exploder_anim__stateEnd : float&;
                                       var tnt_exploder__explodeButtonPressed : bool&)
  if !evt.isForReal || tnt_exploder__inProgress || throwable_launcher__inProgress || length(tnt_exploder__tntBlocks) <= 0
    return

  if evt.gctrl.shoot != tnt_exploder__explodeButtonPressed
    tnt_exploder__explodeButtonPressed = evt.gctrl.shoot
    if tnt_exploder__explodeButtonPressed
      tnt_exploder__inProgress = true
      tnt_exploder_anim__state = int(TntExploderAnimState.TEAS_DETONATING)
      tnt_exploder_anim__stateStart = evt.atTime
      tnt_exploder_anim__stateEnd = evt.atTime + tnt_exploder_anim__detonationTime
      send_net_event(evt.owner, RequestTntBlockExploderStartExplode(tntExploderEid = eid, atTime = evt.atTime))
      return

[es(tag=server)]
def tnt_exploder_start_explode(evt : RequestTntBlockExploderStartExplode;
                               eid aka human_eid : EntityId;
                               human_weap__currentGunEid : EntityId)
  if human_weap__currentGunEid != evt.tntExploderEid
    return

  query(evt.tntExploderEid) <| $ [es] (gun__owner : EntityId;
                                       tnt_exploder__tntBlocks : EidList;
                                       tnt_exploder__explodeTime : float;
                                       tnt_exploder_anim__detonationTime : float;
                                       var tnt_exploder__inProgress : bool&;
                                       var tnt_exploder__explodeStatus : bool&;
                                       var tnt_exploder__explodeAtTime : float&;
                                       var tnt_exploder_anim__state : int&;
                                       var tnt_exploder_anim__stateStart : float&;
                                       var tnt_exploder_anim__stateEnd : float&;
                                       throwable_launcher__inProgress : bool = false)
    if gun__owner != human_eid || (is_dedicated()  && tnt_exploder__inProgress)
      return

    let zeroTntBlocks = length(tnt_exploder__tntBlocks) <= 0
    let requestTimeIsTooOld = (get_sync_time() - evt.atTime) > 0.4 
    let requestTimeIsFuture = get_sync_time() < evt.atTime 

    if requestTimeIsTooOld || requestTimeIsFuture || zeroTntBlocks || throwable_launcher__inProgress
      tnt_exploder_server_report_fail_explode(evt.tntExploderEid)
      return

    tnt_exploder__inProgress = true
    tnt_exploder__explodeAtTime = evt.atTime + tnt_exploder__explodeTime
    tnt_exploder__explodeStatus = false

    tnt_exploder_anim__state = int(TntExploderAnimState.TEAS_DETONATING)
    tnt_exploder_anim__stateStart = evt.atTime
    tnt_exploder_anim__stateEnd = evt.atTime + tnt_exploder_anim__detonationTime

[es(tag=server, after=tnt_exploder_start_explode)]
def tnt_exploder_exploding_server(info : UpdateStageInfoAct;
                                  tnt_exploder__explodeAtTime : float;
                                  var tnt_exploder__tntBlocks : EidList&;
                                  var tnt_exploder__explodeStatus : bool&)
  if tnt_exploder__explodeStatus
    return

  if tnt_exploder__explodeAtTime <= info.curTime
    for tntBlock in tnt_exploder__tntBlocks
      detonate_tnt_block(tntBlock)
    clear(tnt_exploder__tntBlocks)
    tnt_exploder__explodeStatus = true

[es(tag=server, track=tnt_exploder_anim__state)]
def tnt_exploder_ready_to_explode_on_anim_end(evt : Event;
                                              tnt_exploder_anim__state : int;
                                              var tnt_exploder__inProgress : bool&)
  if !tnt_exploder__inProgress || tnt_exploder_anim__state != int(TntExploderAnimState.TEAS_NONE)
    return

  tnt_exploder__inProgress = false

[es(REQUIRE=(tnt_exploder, tnt_launcher, multiple_guns_slot_gun), track=(tnt_exploder__tntBlocks, throwable_launcher__itemsCount))]
def tnt_exploer_hide_on_zero_tnt(evt : Event;
                                 eid : EntityId;
                                 tnt_exploder__tntBlocks : EidList;
                                 throwable_launcher__itemsCount : int;
                                 multiple_guns_slot_gun_hidden : Tag const?)
  let hideExploder = length(tnt_exploder__tntBlocks) <= 0 && throwable_launcher__itemsCount <= 0
  if multiple_guns_slot_gun_hidden != null && !hideExploder
    removeSubTemplate(eid, "multiple_guns_slot_gun_hidden")
  elif multiple_guns_slot_gun_hidden == null && hideExploder
    addSubTemplate(eid, "multiple_guns_slot_gun_hidden")

[es(tag=gameClient, REQUIRE=(tnt_exploder, tnt_launcher), track=(tnt_exploder__inProgress, tnt_exploder__tntBlocks, throwable_launcher__itemsCount))]
def tnt_exploer_switch_to_other_weapon_on_zero_tnt(evt : Event;
                                                   eid : EntityId;
                                                   gun__owner : EntityId;
                                                   tnt_exploder__tntBlocks : EidList;
                                                   tnt_exploder__inProgress : bool;
                                                   throwable_launcher__itemsCount : int)
  if tnt_exploder__inProgress || throwable_launcher__itemsCount > 0 || length(tnt_exploder__tntBlocks) > 0
    return

  query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId;
                               human_weap__gunEids : EidList;
                               var human_net_phys : HumanActor&)
    if human_weap__currentGunEid != eid
      return
    switch_to_first_weap_with_ammo(human_weap__gunEids, human_net_phys.phys)

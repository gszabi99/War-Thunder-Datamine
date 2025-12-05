require ecs
require DngWalkerai
require %appGame.infantry.es.walker_common
require %appGame.infantry.es.squad_order_common
require HumanPhys
require CollRes
require DagorMath
require DagorMathUtils
require AnimV20
require DngHuman
require Grid
require GridCollision
require DagorDataBlock
require DagorRandom
require vehicle
require BehNodes
require human_net_speech.modules.human_net_speech_request_common
require %appGame.infantry.es.squad_common


def is_timer_hit(var timer : float&; dt : float) : bool
  if (timer > 0.f)
    timer -= dt
    return timer <= 0.f ? true : false
  return false

[es(tag=server, no_order)]
def squad_member_response_es(info : UpdateStageInfoAct;
                             eid : EntityId;
                             var squad_member__responseTimer : float&;
                             squad_member__response : string;
                             squad_member__squad : EntityId;
                             isAlive : bool)
  if !isAlive || squad_member__squad == INVALID_ENTITY_ID
    return
  let leaderEid = get_Eid(squad_member__squad, "squad__leader") ?? INVALID_ENTITY_ID

  if (eid == leaderEid)
    return
  let isResponseRequired = is_timer_hit(squad_member__responseTimer, info.dt)
  if isResponseRequired
    request_net_speech(eid, squad_member__response)

[es(no_order, tag=server)]
def squad_member_crawl_with_leader(info : UpdateStageInfoAct; eid : EntityId; squad__leader : EntityId;
                                   squad__ownerPlayer : EntityId;
                                   var squad__membersCrawlNextCheckTime : float&;
                                   squad__membersCrawlCheckDelta : float;
                                   squad__membersCrawlDistance : float2;
                                   squad__membersCrawlOrderTime : float2)
  if has(squad__ownerPlayer, "playerIsBot") || (squad__membersCrawlNextCheckTime > info.curTime)
    return
  squad__membersCrawlNextCheckTime = info.curTime + squad__membersCrawlCheckDelta

  var leaderTm : float3x4
  var leaderStance = STANCE_STAND
  query(squad__leader) <| $ [es] (transform : float3x4;
                                  human_net_phys : HumanActor)
    leaderTm = transform
    leaderStance = determinate_stance(human_net_phys.phys.currentState)
  if leaderStance != STANCE_CRAWL
    return

  for_each_entity_in_grid(ecs_hash("humans"), BSphere3(leaderTm[3], squad__membersCrawlDistance.x), GridEntCheck.BOUNDING) <| $(smEid : EntityId; smPos : float3)
    if (abs(smPos.y - leaderTm[3].y) > squad__membersCrawlDistance.y)
      return
    query(smEid) <| $ [es(REQUIRE_NOT=deadEntity)] (squad_member__squad : EntityId;
                                                    squad_member__isPersonalOrder : bool;
                                                    squad_member__orderType : int;
                                                    var beh_tree : BehaviourTree&)
      if squad_member__squad != eid
        return
      if squad_member__isPersonalOrder && is_squad_mate_order_ignore_leader_stance(squad_member__orderType)
        return
      beh_tree.blackBoard |> set("maxStanceOrder", STANCE_CRAWL)
      beh_tree.blackBoard |> set("maxStanceOrderForce", true)
      let orderTime = rnd_float(squad__membersCrawlOrderTime.x, squad__membersCrawlOrderTime.y)
      beh_tree.blackBoard |> set("maxStanceOrderEndTime", info.curTime + orderTime)

[es(tag=server, track=isInVehicle)]
def squad_member_can_be_leader_set(evt : Event; isInVehicle : bool; var squad_member__canBeLeader : bool&)
  if (!isInVehicle)
    
    squad_member__canBeLeader = true









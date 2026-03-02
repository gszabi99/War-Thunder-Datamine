require ecs
require DngHuman
require math
require DagorMath
require %game.events

def interpolate_table(x : float; tbl : Point2List)
  let pointCount = length(tbl)
  if pointCount <= 0
    return 0.0
  if x < tbl[0].x
    return tbl[0].y
  for i in range(0, pointCount - 1)
    let pMax = tbl[i + 1]
    if x < pMax.x
      let pMin = tbl[i]
      return cvt(x, pMin.x, pMax.x, pMin.y, pMax.y)
  return tbl[pointCount - 1].y


def human_weight_influence_update(var human_net_phys : HumanActor;
                                  human_weight_influence__weightWalkSpeedMult;
                                  human_weight_influence__weightWalkSpeedMultCrawlCrouch;
                                  human_weight_influence__weightAccelerationMult;
                                  human_weight_influence__weightRunSpeedMult;
                                  human_weight_influence__weightSprintSpeedMult;
                                  human_weight_influence__weightAimingMoveSpeedMult)
  let standState = human_net_phys.phys.currentState.standState
  human_net_phys.phys.currentState.accelerationMult *= human_weight_influence__weightAccelerationMult
  human_net_phys.phys.currentState.runSpeedMult *= human_weight_influence__weightRunSpeedMult
  human_net_phys.phys.currentState.sprintSpeedMult *= human_weight_influence__weightSprintSpeedMult
  human_net_phys.phys.currentState.speedInAimStateMult *= human_weight_influence__weightAimingMoveSpeedMult
  if standState == HUStandState.ESS_CROUCH || standState == HUStandState.ESS_CRAWL || standState == HUStandState.ESS_DOWNED
    human_net_phys.phys.currentState.walkSpeedMult *= human_weight_influence__weightWalkSpeedMultCrawlCrouch
  else
    human_net_phys.phys.currentState.walkSpeedMult *= human_weight_influence__weightWalkSpeedMult


[es(tag=server, REQUIRE_NOT=deadEntity, after=entity_mods_appliers_server_es)]
def human_weight_influence_server_es(info : ParallelUpdateFrameDelayed;
                                     var human_net_phys : HumanActor;
                                     human_weight_influence__weightWalkSpeedMult : float = 1.f;
                                     human_weight_influence__weightWalkSpeedMultCrawlCrouch : float = 1.f;
                                     human_weight_influence__weightAccelerationMult : float = 1.f;
                                     human_weight_influence__weightRunSpeedMult : float = 1.f;
                                     human_weight_influence__weightSprintSpeedMult : float = 1.f;
                                     human_weight_influence__weightAimingMoveSpeedMult : float = 1.f)
  human_weight_influence_update(human_net_phys, human_weight_influence__weightWalkSpeedMult,
                                human_weight_influence__weightWalkSpeedMultCrawlCrouch, human_weight_influence__weightAccelerationMult,
                                human_weight_influence__weightRunSpeedMult, human_weight_influence__weightSprintSpeedMult,
                                human_weight_influence__weightAimingMoveSpeedMult)


[es(tag=netClient, REQUIRE=watchedByPlr, after=entity_mods_appliers_client_es)]
def human_weight_influence_client_es(info : ParallelUpdateFrameDelayed;
                                     var human_net_phys : HumanActor;
                                     human_weight_influence__weightWalkSpeedMult : float = 1.f;
                                     human_weight_influence__weightWalkSpeedMultCrawlCrouch : float = 1.f;
                                     human_weight_influence__weightAccelerationMult : float = 1.f;
                                     human_weight_influence__weightRunSpeedMult : float = 1.f;
                                     human_weight_influence__weightSprintSpeedMult : float = 1.f;
                                     human_weight_influence__weightAimingMoveSpeedMult : float = 1.f)
  human_weight_influence_update(human_net_phys, human_weight_influence__weightWalkSpeedMult,
                                human_weight_influence__weightWalkSpeedMultCrawlCrouch, human_weight_influence__weightAccelerationMult,
                                human_weight_influence__weightRunSpeedMult, human_weight_influence__weightSprintSpeedMult,
                                human_weight_influence__weightAimingMoveSpeedMult)


def update_human_phys_coefs_by_weight(eid : EntityId;
                                      human_inventory__currentWeight : float)
  query(eid) <| $ [es] (human_weight_influence__weightWalkSpeedMultTable : Point2List;
                        human_weight_influence__weightWalkSpeedMultTableCrawlCrouch : Point2List;
                        human_weight_influence__weightAccelerationMultTable : Point2List;
                        human_weight_influence__weightRunSpeedMultTable : Point2List;
                        human_weight_influence__weightSprintSpeedMultTable : Point2List;
                        human_weight_influence__weightAimingMoveSpeedMultTable : Point2List;
                        var human_weight_influence__weightWalkSpeedMult : float&;
                        var human_weight_influence__weightWalkSpeedMultCrawlCrouch : float&;
                        var human_weight_influence__weightAccelerationMult : float&;
                        var human_weight_influence__weightRunSpeedMult : float&;
                        var human_weight_influence__weightSprintSpeedMult : float&;
                        var human_weight_influence__weightAimingMoveSpeedMult : float&)
    human_weight_influence__weightWalkSpeedMult = interpolate_table(human_inventory__currentWeight, human_weight_influence__weightWalkSpeedMultTable)
    human_weight_influence__weightWalkSpeedMultCrawlCrouch = interpolate_table(human_inventory__currentWeight, human_weight_influence__weightWalkSpeedMultTableCrawlCrouch)
    human_weight_influence__weightAccelerationMult = interpolate_table(human_inventory__currentWeight, human_weight_influence__weightAccelerationMultTable)
    human_weight_influence__weightRunSpeedMult = interpolate_table(human_inventory__currentWeight, human_weight_influence__weightRunSpeedMultTable)
    human_weight_influence__weightSprintSpeedMult = interpolate_table(human_inventory__currentWeight, human_weight_influence__weightSprintSpeedMultTable)
    human_weight_influence__weightAimingMoveSpeedMult = interpolate_table(human_inventory__currentWeight, human_weight_influence__weightAimingMoveSpeedMultTable)


[es(tag=server, on_appear, track=human_inventory__currentWeight)]
def human_weight_non_human_phys_params_influence_server_es(evt : Event;
                                                           eid : EntityId;
                                                           human_inventory__currentWeight : float)
  update_human_phys_coefs_by_weight(eid, human_inventory__currentWeight)


[es(tag=gameClient, REQUIRE=watchedByPlr, on_appear, track=human_inventory__currentWeight)]
def human_weight_non_human_phys_params_influence_client_es(evt : Event;
                                                           eid : EntityId;
                                                           human_inventory__currentWeight : float)
  update_human_phys_coefs_by_weight(eid, human_inventory__currentWeight)

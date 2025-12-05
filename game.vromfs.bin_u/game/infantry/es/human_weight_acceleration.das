require ecs
require DngHuman
require math
require DagorMath
require %game.events

def human_weight_influence_update(var human_net_phys : HumanActor;
                                  human_inventory__currentWeight;
                                  human_weight_influence__minWeight;
                                  human_weight_influence__maxWeight;
                                  human_weight_influence__maxWeightAccelerationMult;
                                  human_weight_influence__maxWeightJumpMult;
                                  human_weight_influence__maxWeightSpeedMult;
                                  human_weight_influence__staminaDrainMult;
                                  human_weight_influence__maxWeightRestoreStaminaMult;
                                  human_weight_influence__maxWeightCrawlCrouchSpeedMult;
                                  human_weight_influence__maxWeightClimbingSpeedMult;
                                  human_weight_influence__maxWeightSprintMult;
                                  entity_mods__weightRunSpeedMult)
  let curLerpFactor = cvt(human_inventory__currentWeight * entity_mods__weightRunSpeedMult,
                              human_weight_influence__minWeight, human_weight_influence__maxWeight,
                              0.f, 1.f)
  human_net_phys.phys.currentState.accelerationMult *= lerp(1.f, human_weight_influence__maxWeightAccelerationMult, curLerpFactor)
  human_net_phys.phys.currentState.jumpSpeedMult *= lerp(1.f, human_weight_influence__maxWeightJumpMult, curLerpFactor)
  human_net_phys.phys.currentState.moveSpeedMult *= lerp(1.f, human_weight_influence__maxWeightSpeedMult, curLerpFactor)
  human_net_phys.phys.currentState.staminaDrainMult *= lerp(1.f, human_weight_influence__staminaDrainMult, curLerpFactor)
  human_net_phys.phys.currentState.restoreStaminaMult *= lerp(1.f, human_weight_influence__maxWeightRestoreStaminaMult, curLerpFactor)
  human_net_phys.phys.currentState.climbingSpeedMult *= lerp(1.f, human_weight_influence__maxWeightClimbingSpeedMult, curLerpFactor)
  human_net_phys.phys.currentState.crawlCrouchSpeedMult *= lerp(1.f, human_weight_influence__maxWeightCrawlCrouchSpeedMult, curLerpFactor)
  human_net_phys.phys.currentState.sprintSpeedMult *= lerp(1.f, human_weight_influence__maxWeightSprintMult, curLerpFactor)

[es(tag=server, REQUIRE_NOT=deadEntity, after=entity_mods_appliers_server_es)]
def human_weight_influence_server_es(info : ParallelUpdateFrameDelayed;
                                     var human_net_phys : HumanActor;
                                     human_inventory__currentWeight : float;
                                     human_weight_influence__minWeight : float = 4.f;
                                     human_weight_influence__maxWeight : float  = 15.f;
                                     human_weight_influence__maxWeightAccelerationMult : float = 0.5f;
                                     human_weight_influence__maxWeightJumpMult : float = 0.5f;
                                     human_weight_influence__maxWeightSpeedMult : float = 1.f;
                                     human_weight_influence__staminaDrainMult : float = 1.f;
                                     human_weight_influence__maxWeightRestoreStaminaMult : float = 1.f;
                                     human_weight_influence__maxWeightCrawlCrouchSpeedMult : float = 1.f;
                                     human_weight_influence__maxWeightClimbingSpeedMult : float = 1.f;
                                     human_weight_influence__maxWeightSprintMult : float = 1.f;
                                     entity_mods__weightRunSpeedMult : float = 1.f)
  human_weight_influence_update(human_net_phys, human_inventory__currentWeight, human_weight_influence__minWeight,
                                  human_weight_influence__maxWeight, human_weight_influence__maxWeightAccelerationMult,
                                  human_weight_influence__maxWeightJumpMult, human_weight_influence__maxWeightSpeedMult,
                                  human_weight_influence__staminaDrainMult, human_weight_influence__maxWeightRestoreStaminaMult,
                                  human_weight_influence__maxWeightCrawlCrouchSpeedMult, human_weight_influence__maxWeightClimbingSpeedMult,
                                  human_weight_influence__maxWeightSprintMult, entity_mods__weightRunSpeedMult)

[es(tag=netClient, REQUIRE=watchedByPlr, after=entity_mods_appliers_client_es)]
def human_weight_influence_client_es(info : ParallelUpdateFrameDelayed;
                                     var human_net_phys : HumanActor;
                                     human_inventory__currentWeight : float;
                                     human_weight_influence__minWeight : float = 4.f;
                                     human_weight_influence__maxWeight : float  = 15.f;
                                     human_weight_influence__maxWeightAccelerationMult : float = 0.5f;
                                     human_weight_influence__maxWeightJumpMult : float = 0.5f;
                                     human_weight_influence__maxWeightSpeedMult : float = 1.f;
                                     human_weight_influence__staminaDrainMult : float = 1.f;
                                     human_weight_influence__maxWeightRestoreStaminaMult : float = 1.f;
                                     human_weight_influence__maxWeightCrawlCrouchSpeedMult : float = 1.f;
                                     human_weight_influence__maxWeightClimbingSpeedMult : float = 1.f;
                                     human_weight_influence__maxWeightSprintMult : float = 1.f;
                                     entity_mods__weightRunSpeedMult : float = 1.f)
  human_weight_influence_update(human_net_phys, human_inventory__currentWeight, human_weight_influence__minWeight,
                                  human_weight_influence__maxWeight, human_weight_influence__maxWeightAccelerationMult,
                                  human_weight_influence__maxWeightJumpMult, human_weight_influence__maxWeightSpeedMult,
                                  human_weight_influence__staminaDrainMult, human_weight_influence__maxWeightRestoreStaminaMult,
                                  human_weight_influence__maxWeightCrawlCrouchSpeedMult, human_weight_influence__maxWeightClimbingSpeedMult,
                                  human_weight_influence__maxWeightSprintMult, entity_mods__weightRunSpeedMult)

def update_human_phys_coefs_by_weight(eid : EntityId;
                                      human_inventory__currentWeight : float;
                                      human_weight_influence__minWeight : float;
                                      human_weight_influence__maxWeight : float)
  let weightFactor = cvt(human_inventory__currentWeight,
                        human_weight_influence__minWeight, human_weight_influence__maxWeight,
                        0.f, 1.f)
  query(eid) <| $ [es] (human_weight_influence__maxWeightDoubleSprintMult : float;
                        human_weight_influence__maxWeightShakeStability : float;
                        human_weight_influence__maxWeightPunchStability = 1.f;
                        human_weight_influence__maxWeight_changePoseSpeed : float;
                        human_weight_influence__maxWeight_changePoseSpeedCrawl : float;
                        human_weight_influence__maxWeight_afterJumpDampingPoseDown : float;
                        human_weight_influence__maxWeight_afterJumpDampingPoseUp : float;
                        human_weight_influence__maxWeight_fasterChangeSpeed : float;
                        human_weight_influence__maxWeight_leapDampingFallDown : float;
                        human_weight_influence__maxWeight_leapDampingStandUp : float;
                        double_sprint__speedMultBase : float;
                        human_phys__changePoseSpeedBase : float;
                        human_phys__changePoseSpeedCrawlBase : float;
                        human_phys__afterJumpDampingChangePoseDown_speedBase : float;
                        human_phys__afterJumpDampingChangePoseUp_speedBase : float;
                        human_fast_prone__fasterChangePose_speedBase : float;
                        human_sprint_leap__leapDampingFallDown_speedBase : float;
                        human_sprint_leap__leapDampingStandUp_speedBase : float;
                        var double_sprint__speedMult : float&;
                        var human_shake__stability : float&;
                        var human_aim_punch__stability : float&;
                        var human_phys__changePoseSpeed : float&;
                        var human_phys__changePoseSpeedCrawl : float&;
                        var human_phys__afterJumpDampingChangePoseDown_speed : float&;
                        var human_phys__afterJumpDampingChangePoseUp_speed : float&;
                        var human_fast_prone__fasterChangePose_speed : float&;
                        var human_sprint_leap__leapDampingFallDown_speed : float&;
                        var human_sprint_leap__leapDampingStandUp_speed : float&)
    double_sprint__speedMult = double_sprint__speedMultBase * lerp(1.f, human_weight_influence__maxWeightDoubleSprintMult, weightFactor)
    human_shake__stability = lerp(0.0, human_weight_influence__maxWeightShakeStability, weightFactor)
    human_aim_punch__stability = lerp(0.0, human_weight_influence__maxWeightPunchStability, weightFactor)
    human_phys__changePoseSpeed = human_phys__changePoseSpeedBase * lerp(1.f, human_weight_influence__maxWeight_changePoseSpeed, weightFactor)
    human_phys__changePoseSpeedCrawl = human_phys__changePoseSpeedCrawlBase * lerp(1.f, human_weight_influence__maxWeight_changePoseSpeedCrawl, weightFactor)
    human_phys__afterJumpDampingChangePoseDown_speed = human_phys__afterJumpDampingChangePoseDown_speedBase * lerp(1.f, human_weight_influence__maxWeight_afterJumpDampingPoseDown, weightFactor)
    human_phys__afterJumpDampingChangePoseUp_speed = human_phys__afterJumpDampingChangePoseUp_speedBase * lerp(1.f, human_weight_influence__maxWeight_afterJumpDampingPoseUp, weightFactor)
    human_fast_prone__fasterChangePose_speed = human_fast_prone__fasterChangePose_speedBase * lerp(1.f, human_weight_influence__maxWeight_fasterChangeSpeed, weightFactor)
    human_sprint_leap__leapDampingFallDown_speed = human_sprint_leap__leapDampingFallDown_speedBase * lerp(1.f, human_weight_influence__maxWeight_leapDampingFallDown, weightFactor)
    human_sprint_leap__leapDampingStandUp_speed = human_sprint_leap__leapDampingStandUp_speedBase * lerp(1.f, human_weight_influence__maxWeight_leapDampingStandUp, weightFactor)

[es(tag=server, on_appear, track=human_inventory__currentWeight)]
def human_weight_non_human_phys_params_influence_server_es(evt : Event;
                                                           eid : EntityId;
                                                           human_inventory__currentWeight : float;
                                                           human_weight_influence__minWeight : float = 4.f;
                                                           human_weight_influence__maxWeight : float  = 15.f)
  update_human_phys_coefs_by_weight(eid, human_inventory__currentWeight, human_weight_influence__minWeight, human_weight_influence__maxWeight)

[es(tag=gameClient, REQUIRE=watchedByPlr, on_appear, track=human_inventory__currentWeight)]
def human_weight_non_human_phys_params_influence_client_es(evt : Event;
                                                           eid : EntityId;
                                                           human_inventory__currentWeight : float;
                                                           human_weight_influence__minWeight : float = 4.f;
                                                           human_weight_influence__maxWeight : float  = 15.f)
  update_human_phys_coefs_by_weight(eid, human_inventory__currentWeight, human_weight_influence__minWeight, human_weight_influence__maxWeight)

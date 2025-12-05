require ecs
require math
require math.base
require DngHuman
require HumanPhys
require %game.events

def private apply_entity_mods(curTime : float;
                              entity_mods__speedMult : float;
                              entity_mods__staminaDrain : float;
                              entity_mods__jumpMult : float;
                              entity_mods__climbingSpeedMult : float;
                              entity_mods__restoreStaminaMult : float;
                              entity_mods__sprintStaminaDrain : float;
                              entity_mods__sprintSpeedMult : float;
                              entity_mods__accelerationMult : float;
                              entity_mods__fasterChangeWeaponMult : float;
                              entity_mods__fasterChangePoseMult : float;
                              entity_mods__crawlCrouchSpeedMult : float;
                              entity_mods__weaponTurningSpeedMult : float;
                              entity_mods__aimingAfterFireMult : float;
                              human_phys__crawlThreshold : float;
                              human_phys__crawlTransitionMoveSpeedMult : float;
                              human_phys__changePoseSpeed : float;
                              human_phys__changePoseSpeedCrawl : float;
                              human_phys__afterJumpDampingChangePoseDown_speed : float;
                              human_phys__afterJumpDampingChangePoseUp_speed : float;
                              human_phys__afterJumpDampingTime : float;
                              human_sprint_leap__dampingStartTime : float;
                              human_sprint_leap__dampingTime : float;
                              human_sprint_leap__leapDampingFallDown_speed : float;
                              human_sprint_leap__leapDampingStandUp_speed : float;
                              human_fast_prone__startTime : float;
                              human_fast_prone__fasterChangePoseDuration : float;
                              human_fast_prone__fasterChangePose_speed : float;
                              human_sprint_leap__isLeaping : bool;
                              var human_stamina_regen_affect__mult : float&;
                              var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState

  currentState.staminaDrainMult = entity_mods__staminaDrain
  currentState.jumpSpeedMult = entity_mods__jumpMult
  currentState.climbingSpeedMult = entity_mods__climbingSpeedMult
  currentState.restoreStaminaMult = entity_mods__restoreStaminaMult
  currentState.staminaSprintDrainMult = entity_mods__sprintStaminaDrain
  currentState.sprintSpeedMult = currentState.height < 1.0 ? 1.0 : entity_mods__sprintSpeedMult
  currentState.accelerationMult = entity_mods__accelerationMult
  currentState.fasterChangeWeaponMult = entity_mods__fasterChangeWeaponMult
  currentState.weaponTurningSpeedMult = entity_mods__weaponTurningSpeedMult
  currentState.aimingAfterFireMult = entity_mods__aimingAfterFireMult
  human_stamina_regen_affect__mult = 1.0

  if currentState.height < human_phys__crawlThreshold && currentState.height > -1.
    currentState.moveSpeedMult = human_phys__crawlTransitionMoveSpeedMult
    currentState.crawlCrouchSpeedMult = human_phys__crawlTransitionMoveSpeedMult
  else
    currentState.moveSpeedMult = entity_mods__speedMult
    currentState.crawlCrouchSpeedMult = entity_mods__crawlCrouchSpeedMult

  if curTime < currentState.afterJumpDampingEndTime
    currentState.fasterChangePoseMult = human_phys__afterJumpDampingChangePoseDown_speed
  elif curTime < currentState.afterJumpDampingEndTime + human_phys__afterJumpDampingTime
    currentState.fasterChangePoseMult = human_phys__afterJumpDampingChangePoseUp_speed
  elif curTime < human_sprint_leap__dampingStartTime + human_sprint_leap__dampingTime
    let speed = human_sprint_leap__isLeaping ? human_phys__changePoseSpeed * human_sprint_leap__leapDampingFallDown_speed : human_phys__changePoseSpeedCrawl * human_sprint_leap__leapDampingStandUp_speed
    currentState.fasterChangePoseMult = speed
  elif curTime < human_fast_prone__startTime + human_fast_prone__fasterChangePoseDuration
    currentState.fasterChangePoseMult = human_phys__changePoseSpeedCrawl * human_fast_prone__fasterChangePose_speed
  else
    let isCrawlCrouch = currentState.height < 0.9
    let speed = isCrawlCrouch ? human_phys__changePoseSpeedCrawl : human_phys__changePoseSpeed
    currentState.fasterChangePoseMult = speed * entity_mods__fasterChangePoseMult

[es(tag=server)]
def player_squad_bots_sprint_set_apply_mult_es(info : ParallelUpdateFrameDelayed;
                                               squad__leader : EntityId;
                                               squad__allMembers : EidList;
                                               squad__ownerPlayer : EntityId;
                                               playerSquadBotsSprintDistanceThreshold : float;
                                               var playerSquadBotsApplySprintSpeedMult : bool&)
  playerSquadBotsApplySprintSpeedMult = false
  let isBot = has(squad__ownerPlayer, "playerIsBot")
  if isBot
    return

  let leaderTransform = get_TMatrix(squad__leader, "transform")
  if leaderTransform != null
    playerSquadBotsApplySprintSpeedMult = true
    for memberEid in squad__allMembers
      query(memberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (transform aka member_transform : float3x4)
        if memberEid != squad__leader
          let distanceSq = distance_sq(member_transform[3], (*leaderTransform)[3])
          if distanceSq < square(playerSquadBotsSprintDistanceThreshold)
            playerSquadBotsApplySprintSpeedMult = false
      if !playerSquadBotsApplySprintSpeedMult
        break

[es(tag=server, REQUIRE_NOT=deadEntity)]
def entity_mods_appliers_server_es(info : ParallelUpdateFrameDelayed;
                                   entity_mods__speedMult : float;
                                   entity_mods__staminaDrain : float;
                                   entity_mods__jumpMult : float;
                                   entity_mods__climbingSpeedMult : float;
                                   entity_mods__restoreStaminaMult : float;
                                   entity_mods__sprintStaminaDrain : float;
                                   entity_mods__sprintSpeedMult : float;
                                   entity_mods__playerSquadBotsSprintSpeedMult : float;
                                   entity_mods__accelerationMult : float;
                                   entity_mods__fasterChangeWeaponMult : float;
                                   entity_mods__fasterChangePoseMult : float;
                                   entity_mods__crawlCrouchSpeedMult : float;
                                   entity_mods__weaponTurningSpeedMult : float;
                                   entity_mods__aimingAfterFireMult : float;
                                   human_phys__crawlThreshold : float;
                                   human_phys__crawlTransitionMoveSpeedMult : float;
                                   human_phys__changePoseSpeed : float;
                                   human_phys__changePoseSpeedCrawl : float;
                                   human_phys__afterJumpDampingChangePoseDown_speed : float;
                                   human_phys__afterJumpDampingChangePoseUp_speed : float;
                                   human_phys__afterJumpDampingTime : float;
                                   human_sprint_leap__dampingStartTime : float;
                                   human_sprint_leap__dampingTime : float;
                                   human_sprint_leap__leapDampingFallDown_speed : float;
                                   human_sprint_leap__leapDampingStandUp_speed : float;
                                   human_fast_prone__startTime : float;
                                   human_fast_prone__fasterChangePoseDuration : float;
                                   human_fast_prone__fasterChangePose_speed : float;
                                   human_sprint_leap__isLeaping : bool;
                                   beh_tree__enabled : bool;
                                   squad_member__squad : EntityId;
                                   var human_stamina_regen_affect__mult : float&;
                                   var human_net_phys : HumanActor&)
  var entityModSprintSpeedMult = entity_mods__sprintSpeedMult
  if beh_tree__enabled && get_bool(squad_member__squad, "playerSquadBotsApplySprintSpeedMult") ?? false
    entityModSprintSpeedMult *= entity_mods__playerSquadBotsSprintSpeedMult

  apply_entity_mods(info.curTime, entity_mods__speedMult, entity_mods__staminaDrain, entity_mods__jumpMult,
                    entity_mods__climbingSpeedMult, entity_mods__restoreStaminaMult, entity_mods__sprintStaminaDrain,
                    entityModSprintSpeedMult, entity_mods__accelerationMult, entity_mods__fasterChangeWeaponMult,
                    entity_mods__fasterChangePoseMult, entity_mods__crawlCrouchSpeedMult, entity_mods__weaponTurningSpeedMult,
                    entity_mods__aimingAfterFireMult, human_phys__crawlThreshold, human_phys__crawlTransitionMoveSpeedMult,
                    human_phys__changePoseSpeed, human_phys__changePoseSpeedCrawl, human_phys__afterJumpDampingChangePoseDown_speed,
                    human_phys__afterJumpDampingChangePoseUp_speed, human_phys__afterJumpDampingTime, human_sprint_leap__dampingStartTime,
                    human_sprint_leap__dampingTime, human_sprint_leap__leapDampingFallDown_speed, human_sprint_leap__leapDampingStandUp_speed,
                    human_fast_prone__startTime, human_fast_prone__fasterChangePoseDuration, human_fast_prone__fasterChangePose_speed,
                    human_sprint_leap__isLeaping, human_stamina_regen_affect__mult, human_net_phys)

[es(tag=netClient, REQUIRE=watchedByPlr)]
def entity_mods_appliers_client_es(info : ParallelUpdateFrameDelayed;
                                   entity_mods__speedMult : float;
                                   entity_mods__staminaDrain : float;
                                   entity_mods__jumpMult : float;
                                   entity_mods__climbingSpeedMult : float;
                                   entity_mods__restoreStaminaMult : float;
                                   entity_mods__sprintStaminaDrain : float;
                                   entity_mods__sprintSpeedMult : float;
                                   entity_mods__accelerationMult : float;
                                   entity_mods__fasterChangeWeaponMult : float;
                                   entity_mods__fasterChangePoseMult : float;
                                   entity_mods__crawlCrouchSpeedMult : float;
                                   entity_mods__weaponTurningSpeedMult : float;
                                   entity_mods__aimingAfterFireMult : float;
                                   human_phys__crawlThreshold : float;
                                   human_phys__crawlTransitionMoveSpeedMult : float;
                                   human_phys__changePoseSpeed : float;
                                   human_phys__changePoseSpeedCrawl : float;
                                   human_phys__afterJumpDampingChangePoseDown_speed : float;
                                   human_phys__afterJumpDampingChangePoseUp_speed : float;
                                   human_phys__afterJumpDampingTime : float;
                                   human_sprint_leap__dampingStartTime : float;
                                   human_sprint_leap__dampingTime : float;
                                   human_sprint_leap__leapDampingFallDown_speed : float;
                                   human_sprint_leap__leapDampingStandUp_speed : float;
                                   human_fast_prone__startTime : float;
                                   human_fast_prone__fasterChangePoseDuration : float;
                                   human_fast_prone__fasterChangePose_speed : float;
                                   human_sprint_leap__isLeaping : bool;
                                   var human_stamina_regen_affect__mult : float&;
                                   var human_net_phys : HumanActor&)

  apply_entity_mods(info.curTime, entity_mods__speedMult, entity_mods__staminaDrain, entity_mods__jumpMult,
                    entity_mods__climbingSpeedMult, entity_mods__restoreStaminaMult, entity_mods__sprintStaminaDrain,
                    entity_mods__sprintSpeedMult, entity_mods__accelerationMult, entity_mods__fasterChangeWeaponMult,
                    entity_mods__fasterChangePoseMult, entity_mods__crawlCrouchSpeedMult, entity_mods__weaponTurningSpeedMult,
                    entity_mods__aimingAfterFireMult, human_phys__crawlThreshold, human_phys__crawlTransitionMoveSpeedMult,
                    human_phys__changePoseSpeed, human_phys__changePoseSpeedCrawl, human_phys__afterJumpDampingChangePoseDown_speed,
                    human_phys__afterJumpDampingChangePoseUp_speed, human_phys__afterJumpDampingTime, human_sprint_leap__dampingStartTime,
                    human_sprint_leap__dampingTime, human_sprint_leap__leapDampingFallDown_speed, human_sprint_leap__leapDampingStandUp_speed,
                    human_fast_prone__startTime, human_fast_prone__fasterChangePoseDuration, human_fast_prone__fasterChangePose_speed,
                    human_sprint_leap__isLeaping, human_stamina_regen_affect__mult, human_net_phys)

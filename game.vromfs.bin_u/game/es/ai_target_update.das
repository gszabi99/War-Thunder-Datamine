require ecs
require walkerai
require HumanPhys
require math
require DngHuman


[es(tag=server, no_order)]
def ai_target_update_last_actions(act : UpdateStageInfoAct; human_weap__lastShotGunEid : EntityId;
                                  ai_target__handleGrenadesAsShoot : bool = true;
                                  human_weap__lastShotAtTime : float; var ai_target : Target&)
  let lastShootTime = act.curTime - human_weap__lastShotAtTime
  if lastShootTime < ai_target.lastShootTimer && (ai_target__handleGrenadesAsShoot || !has(human_weap__lastShotGunEid, "grenade_thrower"))
    ai_target.lastShootTimer = lastShootTime
  ai_target.lastShootTimer += act.dt


[es(tag=server, no_order)]
def ai_target_noise_level(act : UpdateStageInfoAct; human_net_phys : HumanActor; human_anim__vehicleSelected : EntityId;
                          ai_target__standNoiseLevel : float = 0f;
                          ai_target__standRunNoiseLevel : float = 0.25;
                          ai_target__sprintNoiseLevel : float = 0.5;
                          ai_target__vehicleNoiseLevel : float = 0.25;
                          ai_target__movingVehicleHornNoiseLevel : float = 1f;
                          ai_target__movingVehicleNoiseLevel : float = 0.75f;
                          ai_target__vehicleSpeedThreshold : float = 0.1;
                          var ai_target__noiseLevel : float&;
                          var ai_target : Target)
  ai_target.useVehicle = uint(human_anim__vehicleSelected)
  ai_target__noiseLevel = ai_target__standNoiseLevel
  if human_anim__vehicleSelected != INVALID_ENTITY_ID
    ai_target__noiseLevel = ai_target__vehicleNoiseLevel
    query(human_anim__vehicleSelected) <| $ [es] (net_phys__currentStateVelocity : float3; vehicle_horn__endTime : float)
      if vehicle_horn__endTime > act.curTime
        ai_target__noiseLevel = ai_target__movingVehicleHornNoiseLevel
      elif length_sq(net_phys__currentStateVelocity) > ai_target__vehicleSpeedThreshold
        ai_target__noiseLevel = ai_target__movingVehicleNoiseLevel

  elif human_net_phys.phys.currentState.moveState == HUMoveState.EMS_SPRINT
    ai_target__noiseLevel = ai_target__sprintNoiseLevel

  elif human_net_phys.phys.currentState.moveState == HUMoveState.EMS_RUN && human_net_phys.phys.currentState.standState == HUStandState.ESS_STAND
    ai_target__noiseLevel = ai_target__standRunNoiseLevel


[es(tag=server, no_order)]
def ai_target_phys_velocity(act : UpdateStageInfoAct; net_phys__currentStateVelocity : float3; var ai_target : Target)
  ai_target.velocity = net_phys__currentStateVelocity

[es(tag=server, no_order)]
def ai_target_human_velocity(act : UpdateStageInfoAct; human_net_phys__velocity : float3; human_anim__vehicleSelected : EntityId; var ai_target : Target)
  ai_target.velocity = get_Point3(human_anim__vehicleSelected, "net_phys__currentStateVelocity") ?? human_net_phys__velocity

[es(tag=server, no_order)]
def ai_target_mindset(act : UpdateStageInfoAct; beh_tree__enabled : bool; var ai_target : Target)
  ai_target.isAi = beh_tree__enabled

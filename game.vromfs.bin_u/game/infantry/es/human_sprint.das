require ecs
require DagorMath
require DngHuman
require %game.player_events
require %game.events
require math.base


def calc_stamina_speed_mult(human__totalMaxStamina : float;
                            human_sprint__staminaStages : float2;
                            human_sprint__staminaSpeedMult : float2;
                            human_net_phys : HumanActor)
  let stamina = saturate(human_net_phys.phys.currentState.stamina * safeinv(human__totalMaxStamina))
  return (stamina > human_sprint__staminaStages[1] ? 1.0
        : stamina > human_sprint__staminaStages[0] ? human_sprint__staminaSpeedMult[1]
        : human_sprint__staminaSpeedMult[0])


def update_human_sprint_stage(human__totalMaxStamina : float;
                              human_sprint__staminaStages : float2;
                              human_sprint__staminaSpeedMult : float2;
                              var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState
  
  currentState.sprintSpeedMult *= calc_stamina_speed_mult(human__totalMaxStamina,
                                                          human_sprint__staminaStages,
                                                          human_sprint__staminaSpeedMult,
                                                          human_net_phys)

[es(tag=server, REQUIRE_NOT=deadEntity, after=(human_weight_influence_server_es))]
def human_sprint_stages_server(info : ParallelUpdateFrameDelayed;
                               human__totalMaxStamina : float;
                               human_sprint__staminaStages : float2;
                               human_sprint__staminaSpeedMult : float2;
                               var human_net_phys : HumanActor&)
  update_human_sprint_stage(human__totalMaxStamina, human_sprint__staminaStages, human_sprint__staminaSpeedMult, human_net_phys)

[es(tag=netClient, REQUIRE=controlledHero, after=(human_weight_influence_client_es))]
def human_sprint_stages(info : ParallelUpdateFrameDelayed;
                        human__totalMaxStamina : float;
                        human_sprint__staminaStages : float2;
                        human_sprint__staminaSpeedMult : float2;
                        var human_net_phys : HumanActor&)
  update_human_sprint_stage(human__totalMaxStamina, human_sprint__staminaStages, human_sprint__staminaSpeedMult, human_net_phys)

[es]
def human_double_sprint(evt : CmdPostPhysUpdate;
                        human_net_phys : HumanActor;
                        human__totalMaxStamina : float;
                        double_sprint__minStamina : float;
                        var double_sprint__isActive : bool&)
  assume phys = human_net_phys.phys
  let stamina = saturate(phys.currentState.stamina * safeinv(human__totalMaxStamina))

  double_sprint__isActive = (stamina > double_sprint__minStamina
    && phys.currentState.moveState == HUMoveState.EMS_SPRINT
    && phys.appliedCT.isAltAttackState)

def double_sprint_speed(double_sprint__isActive : bool;
                        double_sprint__speedMult : float;
                        double_sprint__accelerationMult : float;
                        var human_net_phys : HumanActor&)
  if double_sprint__isActive
    human_net_phys.phys.currentState.moveSpeedMult *= double_sprint__speedMult
    human_net_phys.phys.currentState.accelerationMult *= double_sprint__accelerationMult

def double_sprint_stamina_drain(double_sprint__isActive : bool;
                                double_sprint__staminaDrainMult : float;
                                double_sprint__staminaRegenMult : float;
                                var human_stamina_regen_affect__mult : float&;
                                var human_net_phys : HumanActor&)
  if double_sprint__isActive
    human_stamina_regen_affect__mult *= double_sprint__staminaRegenMult
    human_net_phys.phys.currentState.staminaSprintDrainMult *= double_sprint__staminaDrainMult

[es(tag=netClient, REQUIRE=watchedByPlr, after=(human_weight_influence_client_es))]
def double_sprint_update_local(info : ParallelUpdateFrameDelayed;
                               double_sprint__isActive : bool;
                               double_sprint__speedMult : float;
                               double_sprint__accelerationMult : float;
                               double_sprint__staminaDrainMult : float;
                               double_sprint__staminaRegenMult : float;
                               var human_net_phys : HumanActor&;
                               var human_stamina_regen_affect__mult : float&)
  double_sprint_stamina_drain(double_sprint__isActive, double_sprint__staminaDrainMult, double_sprint__staminaRegenMult, human_stamina_regen_affect__mult, human_net_phys)
  double_sprint_speed(double_sprint__isActive, double_sprint__speedMult, double_sprint__accelerationMult, human_net_phys)

[es(tag=server, REQUIRE_NOT=deadEntity, after=(human_weight_influence_server_es))]
def double_sprint_update_server(info : ParallelUpdateFrameDelayed;
                                double_sprint__isActive : bool;
                                double_sprint__speedMult : float;
                                double_sprint__accelerationMult : float;
                                double_sprint__staminaDrainMult : float;
                                double_sprint__staminaRegenMult : float;
                                var human_net_phys : HumanActor&;
                                var human_stamina_regen_affect__mult : float&)
  double_sprint_stamina_drain(double_sprint__isActive, double_sprint__staminaDrainMult, double_sprint__staminaRegenMult, human_stamina_regen_affect__mult, human_net_phys)
  double_sprint_speed(double_sprint__isActive, double_sprint__speedMult, double_sprint__accelerationMult, human_net_phys)

def human_sprint_jump_height(human_sprint__staminaStages : float2;
                             human__totalMaxStamina : float;
                             human__sprintJumpHeightMultBySprintStage : float3;
                             human__sprintJumpSpeedThreshold : float;
                             var human_net_phys : HumanActor)
  assume currentState = human_net_phys.phys.currentState
  let stamina = saturate(currentState.stamina * safeinv(human__totalMaxStamina))
  let jumpHeightMult = (stamina > human_sprint__staminaStages[1] ? human__sprintJumpHeightMultBySprintStage[2]
    : stamina > human_sprint__staminaStages[0] ? human__sprintJumpHeightMultBySprintStage[1]
    : human__sprintJumpHeightMultBySprintStage[0])

  let runSpeed = human_net_phys.phys |> human_phys_getWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_RUN) * currentState.moveSpeedMult
  let sprintSpeed = human_net_phys.phys |> human_phys_getWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_SPRINT) * currentState.moveSpeedMult * currentState.sprintSpeedMult

  let speed = cvt(length(currentState.velocity.xz), runSpeed, sprintSpeed, 0., 1.)
  if speed > human__sprintJumpSpeedThreshold
    currentState.jumpSpeedMult *= jumpHeightMult

[es(tag=server, REQUIRE_NOT=deadEntity, after=human_sprint_stages_server)]
def human_sprint_jump_height_server(info : ParallelUpdateFrameDelayed;
                                    human_sprint__staminaStages : float2;
                                    human__totalMaxStamina : float;
                                    human__sprintJumpHeightMultBySprintStage : float3;
                                    human__sprintJumpSpeedThreshold : float;
                                    var human_net_phys : HumanActor)
  human_sprint_jump_height(human_sprint__staminaStages, human__totalMaxStamina, human__sprintJumpHeightMultBySprintStage, human__sprintJumpSpeedThreshold, human_net_phys)

[es(tag=netClient, REQUIRE=hero, after=human_sprint_stages)]
def human_sprint_jump_height_client(info : ParallelUpdateFrameDelayed;
                                    human_sprint__staminaStages : float2;
                                    human__totalMaxStamina : float;
                                    human__sprintJumpHeightMultBySprintStage : float3;
                                    human__sprintJumpSpeedThreshold : float;
                                    var human_net_phys : HumanActor)
  human_sprint_jump_height(human_sprint__staminaStages, human__totalMaxStamina, human__sprintJumpHeightMultBySprintStage, human__sprintJumpSpeedThreshold, human_net_phys)

def human_sprint_gradual_acceleration(human_sprint__accelerationLimitSpeed : float;
                                      human_sprint__accelerationMultMin : float;
                                      human_sprint__accelerationMultMax : float;
                                      var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState
  let speed = length(currentState.velocity.xz)
  let maxSpeed = human_net_phys.phys |> human_phys_getWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_SPRINT) * currentState.moveSpeedMult * currentState.sprintSpeedMult
  let accMult = cvt(speed, human_sprint__accelerationLimitSpeed, maxSpeed, human_sprint__accelerationMultMax, human_sprint__accelerationMultMin)
  currentState.accelerationMult *= accMult

[es(tag=server, REQUIRE_NOT=deadEntity, after=human_weight_influence_server_es, before=(human_sprint_stages_server, double_sprint_update_server))]
def human_sprint_gradual_acceleration_server(info : ParallelUpdateFrameDelayed;
                                             human_sprint__accelerationLimitSpeed : float;
                                             human_sprint__accelerationMultMin : float;
                                             human_sprint__accelerationMultMax : float;
                                             var human_net_phys : HumanActor&)
  human_sprint_gradual_acceleration(human_sprint__accelerationLimitSpeed, human_sprint__accelerationMultMin, human_sprint__accelerationMultMax, human_net_phys)

[es(tag=netClient, REQUIRE=hero, after=human_weight_influence_client_es, before=(human_sprint_stages, double_sprint_update_local))]
def human_sprint_gradual_acceleration_client(info : ParallelUpdateFrameDelayed;
                                             human_sprint__accelerationLimitSpeed : float;
                                             human_sprint__accelerationMultMin : float;
                                             human_sprint__accelerationMultMax : float;
                                             var human_net_phys : HumanActor&)
  human_sprint_gradual_acceleration(human_sprint__accelerationLimitSpeed, human_sprint__accelerationMultMin, human_sprint__accelerationMultMax, human_net_phys)

[es(tag=gameClient, REQUIRE=hero, after=human_weight_influence_client_es, before=(human_sprint_stages, double_sprint_update_local))]
def human_sprint_stop_camera_shake(info : ParallelUpdateFrameDelayed;
                                   human_net_phys : HumanActor;
                                   sprint_stop_camera_shake__startSpeedFactor : float;
                                   sprint_stop_camera_shake__stopSpeed : float;
                                   sprint_stop_camera_shake__timeLimit : float;
                                   sprint_stop_camera_shake__distance : float;
                                   sprint_stop_camera_shake__time : float;
                                   sprint_stop_camera_shake__wait : float;
                                   var sprint_stop_camera_shake__virtualCameraPos : float&;
                                   var sprint_stop_camera_shake__timer : float&;
                                   var sprint_stop_camera_shake__active : bool&;
                                   var human_cam__sprintOffset : float&)
  assume currentState = human_net_phys.phys.currentState
  let maxSpeed = human_net_phys.phys |> human_phys_getWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_SPRINT) * currentState.moveSpeedMult * currentState.sprintSpeedMult
  let startSpeedSq = square(sprint_stop_camera_shake__startSpeedFactor * maxSpeed)
  let stopSpeedSq = square(sprint_stop_camera_shake__stopSpeed)
  let speedSq = length_sq(currentState.velocity.xz)

  
  if speedSq > startSpeedSq
    sprint_stop_camera_shake__timer = sprint_stop_camera_shake__timeLimit
  elif sprint_stop_camera_shake__timer > 0.
    
    sprint_stop_camera_shake__timer -= info.dt
    
    if sprint_stop_camera_shake__timer > 0. && speedSq < stopSpeedSq
      sprint_stop_camera_shake__timer = 0.
      sprint_stop_camera_shake__active = true

  let cameraSpeed = safediv(sprint_stop_camera_shake__distance, sprint_stop_camera_shake__time)
  
  if sprint_stop_camera_shake__active
    let waitDist = (sprint_stop_camera_shake__wait * 0.5) * cameraSpeed
    let stopValue = sprint_stop_camera_shake__distance + waitDist
    sprint_stop_camera_shake__virtualCameraPos = move_to(sprint_stop_camera_shake__virtualCameraPos, stopValue, info.dt, cameraSpeed)
    if sprint_stop_camera_shake__virtualCameraPos >= stopValue
      sprint_stop_camera_shake__active = false
  else
    sprint_stop_camera_shake__virtualCameraPos = move_to(sprint_stop_camera_shake__virtualCameraPos, 0., info.dt, cameraSpeed)

  human_cam__sprintOffset = clamp(sprint_stop_camera_shake__virtualCameraPos, 0., sprint_stop_camera_shake__distance)

[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=deadEntity, after=(human_sprint_stages, double_sprint_update_local, human_optics_camera_es), before=before_camera_sync)]
def human_sprint_change_fov(info : ParallelUpdateFrameDelayed;
                            human_net_phys : HumanActor;
                            double_sprint__isActive : bool;
                            human_sprint_fov__minSpeed : float;
                            human_sprint_fov__sprintZoomMult : float;
                            human_sprint_fov__doubleSprintZoomMult : float;
                            human_sprint_fov__zoomVisc : float;
                            var human_sprint_fov__zoom : float&;
                            var camera__magnification : float&)
  assume phys = human_net_phys.phys
  assume curState = phys.currentState
  assume prevState = phys.previousState

  let posDiff = float3(curState.location.P - prevState.location.P)
  let speed = safediv(length(posDiff.xz), phys.timeStep)
  let isSprint = curState.moveState == HUMoveState.EMS_SPRINT && speed > human_sprint_fov__minSpeed
  let targetZoom = (isSprint && double_sprint__isActive ? human_sprint_fov__doubleSprintZoomMult
                 :  isSprint && !double_sprint__isActive ? human_sprint_fov__sprintZoomMult
                 :  1.0)

  human_sprint_fov__zoom = approach(human_sprint_fov__zoom, targetZoom, info.dt, human_sprint_fov__zoomVisc)
  camera__magnification *= human_sprint_fov__zoom

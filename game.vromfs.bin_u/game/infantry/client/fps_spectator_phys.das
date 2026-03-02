require ecs
require HumanPhys
require DngHuman
require math.base
require %game.events

def setup_phys(info : ParallelUpdateFrameDelayed;
               var human_net_phys : HumanActor&;
               isDowned : bool;
               human_net_phys__isClimbing : bool;
               human_weap__opticsAttached : bool;
               gun__vertOffsetRestoreVisc)
  assume phys = human_net_phys.phys
  assume currentState = phys.currentState
  assume appliedCT = phys.appliedCT

  let isAiming = (is_control_bit_set(appliedCT, HumanPhysControlType.HCT_AIM) &&
                  human_phys_state_can_aim(currentState) &&
                  !isDowned && !human_net_phys__isClimbing &&
                  currentState.weapEquipState.curState != HUWeaponEquipState.EES_DOWN)
  let isZooming = (isAiming &&
                   human_weap__opticsAttached &&
                   human_phys_state_can_zoom(currentState) &&
                   currentState.moveState != HUMoveState.EMS_SPRINT)

  currentState.aimForZoomProgress = (isAiming ? max(currentState.aimPosition, currentState.aimForZoomProgress) : currentState.aimPosition)

  currentState.aimPosition = move_to(currentState.aimPosition, isAiming ? 1.f : 0.f, info.dt, human_net_phys.phys.aimSpeed * currentState.aimSpeedMult)
  currentState.zoomPosition = move_to(currentState.zoomPosition, (isZooming ? 1.f : 0.f) * currentState.aimForZoomProgress, info.dt,
    phys.zoomSpeed * currentState.aimSpeedMult)

  let viscosity = gun__vertOffsetRestoreVisc * currentState.aimingAfterFireMult
  currentState.gunAimOffset = approach(currentState.gunAimOffset, float2(), info.dt, viscosity)


[es(before=human_look_dir_camera_es, REQUIRE=watchedByPlr, REQUIRE_NOT=hero)]
def spectator_simulate_net_phys_update_es(info : ParallelUpdateFrameDelayed;
                                          var human_net_phys : HumanActor&;
                                          isDowned : bool;
                                          human_net_phys__isClimbing : bool;
                                          human_weap__opticsAttached : bool;
                                          spectator_gun__vertOffsetRestoreVisc : float = 0.4)
  setup_phys(info,
             human_net_phys,
             isDowned,
             human_net_phys__isClimbing,
             human_weap__opticsAttached,
             spectator_gun__vertOffsetRestoreVisc)

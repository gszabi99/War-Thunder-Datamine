require ecs
require HumanPhys
require DngHuman
require math
require math.easing


[es(after=human_optics_camera_es, tag=gameClient)]
def camera_magnification_es(
                            info : UpdateStageInfoAct;
                            human_net_phys : HumanActor;
                            human_weap__currentGunEid : EntityId;
                            var camera__magnification : float&;
                            human__cameraMagnificationOnHoldBreath : float;
                            camera__breathMagnificationSpeed : float;
                            var camera__breathMagnificationProgress : float&;
                            isAlive : bool)

  if isAlive && (human_net_phys.phys.currentState.aimPosition > 0.f) && !has(human_weap__currentGunEid, "disableZoomOnHoldBreath")
    let dir = is_hold_breath(human_net_phys.phys.currentState) ? 1.0 : -1.0
    camera__breathMagnificationProgress = clamp(camera__breathMagnificationProgress + info.dt * camera__breathMagnificationSpeed * dir, 0.f, 1.f)
    camera__magnification *= lerp(1.0, human__cameraMagnificationOnHoldBreath, inOutQuad(camera__breathMagnificationProgress))

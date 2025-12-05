require ecs
require math
require math.base
require DagorSystem


[es(before=before_camera_sync)]
def shooter_camera_offset_modifier_es(info : UpdateStageInfoAct; var shooter_cam__additionalOffset : float3&;
                                      shooter_cam__wishAdditionalOffset : float3; shooter_cam__additionalOffsetTau : float)
  shooter_cam__additionalOffset = approach_move(shooter_cam__additionalOffset, shooter_cam__wishAdditionalOffset, info.dt, shooter_cam__additionalOffsetTau, 1.0)

[es(before=before_camera_sync)]
def shooter_camera_magnification_modifier_es(info : UpdateStageInfoAct; var shooter_cam__magnificationMult : float&;
                                             shooter_cam__wishMagnificationMult : float; shooter_cam__magnificationTau : float)
  shooter_cam__magnificationMult = approach(shooter_cam__magnificationMult, shooter_cam__wishMagnificationMult, info.dt, shooter_cam__magnificationTau)


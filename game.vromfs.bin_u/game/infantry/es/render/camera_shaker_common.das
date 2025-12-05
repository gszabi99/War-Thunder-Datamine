module camera_shaker_common shared
require ecs
require %game.events

[event(broadcast)]
struct CameraShakeOnShot
  impulse : float3
  viscocity : float3
  stiffness : float3
  dt : float

[event(broadcast)]
struct CmdAddCameraTrauma
  addTrauma : float
  maxTrauma : float

[event(broadcast)]
struct CmdAddCameraTraumaByDistance
  position : float3
  maxDistance : float
  addTrauma : float
  maxTrauma : float

[event(broadcast)]
struct CmdCameraPunch
  angles : float3

[event(broadcast)]
struct CmdCameraPunchByDir
  localDir : float3


def add_trauma(addTrauma, maxTrauma : float; position : float3; maxDistance : float)
  broadcastEvent(CmdAddCameraTraumaByDistance(position = position, maxDistance = maxDistance, addTrauma = addTrauma, maxTrauma = maxTrauma))

def add_trauma(addTrauma : float; maxTrauma : float = 1.f)
  broadcastEvent(CmdAddCameraTrauma(addTrauma = addTrauma, maxTrauma = maxTrauma))

def add_punch(angles : float3)
  broadcastEvent(CmdCameraPunch(angles = angles))

def add_punch_by_dir(localDir : float3)
  broadcastEvent(CmdCameraPunchByDir(localDir = localDir))
let interopGen = require("%rGui/interopGen.nut")

let OpticAtgmSightVisible = Watched(false)
let LaserAtgmSightVisible = Watched(false)
let TargetingPodSightVisible = Watched(false)
let LaserAtgmSightColor = Watched(Color(255, 255, 0, 240))
let AtgmTrackerVisible = Watched(false)
let TurretYaw = Watched(0.0)
let TurretPitch = Watched(0.0)
let HaveLaserPoint = Watched(false)
let IsWeaponHudVisible = Watched(false)
let LaserPoint = [0, 0]
let LaserAgmName = Watched("")
let LaserAgmCnt = Watched(0)
let LaserAgmSelectedCnt = Watched(-1)
let ShellCnt = Watched(0)
let AdlPoint = [0, 0]
let CurWeaponName = Watched("")

let planeState = {
  OpticAtgmSightVisible,
  LaserAtgmSightVisible,
  TargetingPodSightVisible,
  LaserAtgmSightColor,
  AtgmTrackerVisible,
  TurretYaw,
  TurretPitch,
  HaveLaserPoint,
  IsWeaponHudVisible,
  LaserPoint,
  LaserAgmName,
  LaserAgmCnt,
  LaserAgmSelectedCnt,
  ShellCnt,
  AdlPoint,
  CurWeaponName
}

::interop.updateLaserPoint <- function(x, y) {
  LaserPoint[0] = x
  LaserPoint[1] = y
}

::interop.updateAdlPoint <- function(x, y) {
  AdlPoint[0] = x
  AdlPoint[1] = y
}

interopGen({
  stateTable = planeState
  prefix = "plane"
  postfix = "Update"
})

return planeState
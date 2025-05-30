from "%rGui/globals/ui_library.nut" import *

let { interop } = require("%rGui/globals/interop.nut")
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
let FwdPoint = [0, 0]
let HasPrimaryGun = Watched(false)
let CurWeaponName = Watched("")
let CurWeaponGidanceType = Watched(-1)
let GunBullets0 = Watched(0)
let GunBullets1 = Watched(0)
let BulletImpactPoints = Watched([])
let BulletImpactPoints1 = Watched([])
let BulletImpactPoints2 = Watched([])
let BulletImpactLineEnable = Watched(false)
let WeaponSlots = Watched([])
let WeaponSlotActive = Watched([])
let WeaponSlotsTrigger = Watched([])
let WeaponSlotsCnt = Watched([])
let WeaponSlotsTotalCnt = Watched([])
let WeaponSlotsName = Watched([])
let WeaponSlotsJettisoned = Watched([])
let SelectedWeapSlot = Watched(-1)
let SelectedTrigger = Watched(-1)
let HasOperatedShell = Watched(false)
let TriggerPulled = Watched(false)
let LaunchImpossible = Watched(false)
let SlotCount = Watched(0)

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
  FwdPoint,
  AdlPoint,
  HasPrimaryGun,
  CurWeaponName,
  CurWeaponGidanceType,
  GunBullets0,
  GunBullets1,
  BulletImpactPoints,
  BulletImpactPoints1,
  BulletImpactPoints2,
  BulletImpactLineEnable,
  WeaponSlots,
  WeaponSlotActive,
  WeaponSlotsTrigger,
  WeaponSlotsCnt,
  WeaponSlotsTotalCnt,
  WeaponSlotsName,
  WeaponSlotsJettisoned,
  SelectedTrigger,
  HasOperatedShell,
  SelectedWeapSlot,
  TriggerPulled,
  LaunchImpossible,
  SlotCount
}

interop.updateLaserPoint <- function(x, y) {
  LaserPoint[0] = x
  LaserPoint[1] = y
}

interop.updateFwdPoint <- function(x, y) {
  FwdPoint[0] = x
  FwdPoint[1] = y
}

interop.updateAdlPoint <- function(x, y) {
  AdlPoint[0] = x
  AdlPoint[1] = y
}

interopGen({
  stateTable = planeState
  prefix = "plane"
  postfix = "Update"
})

return planeState
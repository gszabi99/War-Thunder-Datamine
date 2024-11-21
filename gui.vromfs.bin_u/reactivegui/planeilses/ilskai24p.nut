from "%rGui/globals/ui_library.nut" import *

let string = require("string")
let { IlsColor, IlsLineScale, TargetPos, BombCCIPMode, RocketMode, CannonMode,
 TargetPosValid, DistToTarget, IlsPosSize, BombingMode, TimeBeforeBombRelease,
 AimLockValid, AimLockPos } = require("%rGui/planeState/planeToolsState.nut")
let { Speed, BarAltitude, Tangage, Accel, Roll, ClimbSpeed, Altitude, FuelTotal } = require("%rGui/planeState/planeFlyState.nut")
let { round } = require("%sqstd/math.nut")
let { mpsToKmh, baseLineWidth } = require("ilsConstants.nut")
let { compassWrap, generateCompassMarkASP } = require("ilsCompasses.nut")
let { cvt } = require("dagor.math")
let { WeaponSlots, WeaponSlotActive } = require("%rGui/planeState/planeWeaponState.nut")
let { IlsTrackerVisible, IlsTrackerX, IlsTrackerY } = require("%rGui/rocketAamAimState.nut")

let CCIPMode = Computed(@() CannonMode.value || RocketMode.value || BombCCIPMode.value)

let SpeedValue = Computed(@() round(Speed.value * mpsToKmh * 0.2).tointeger())
let speed = @() {
  watch = [SpeedValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(15)]
  color = IlsColor.value
  fontSize = 50
  font = Fonts.ils31
  text = (SpeedValue.value * 5).tostring()
}

let AccelWatch = Computed(@() Accel.value > 0 ? true : false)
let acceleration = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
  size = [pw(10), ph(3.5)]
  pos = [pw(8), ph(21)]
  color = IlsColor.value
  commands = [
    [VECTOR_LINE, 10, 50, 92, 50],
    [VECTOR_LINE, 92, 50, 100, 0],
    [VECTOR_LINE, 0, 100, 10, 50],
    [VECTOR_LINE, 50, 50, 50, 20]
  ]
  children = @() {
    watch = AccelWatch
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
    size = [pw(24), ph(66)]
    pos = AccelWatch.value ? [pw(98), ph(5)] : [0, ph(100)]
    color = IlsColor.value
    commands = [
      [VECTOR_LINE, 0, 100, 50, 0],
      [VECTOR_LINE, 100, 100, 50, 0],
      [VECTOR_LINE, 0, 100, 100, 100]
    ]
  }
}

let compassMark = @() {
  watch = IlsColor
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * 0.8 * IlsLineScale.value
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  commands = [
    [VECTOR_LINE, 32, 15.5, 68, 15.5],
    [VECTOR_POLY, 49, 13.5, 50, 15.5, 51, 13.5]
  ]
}

let barAltValue = Computed(@() (BarAltitude.value * 0.1).tointeger())
let barAltitude = @() {
  watch = [barAltValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(15)]
  color = IlsColor.value
  fontSize = 50
  font = Fonts.ils31
  text = (barAltValue.value * 10).tostring()
}

let altValue = Computed(@() Altitude.value.tointeger())
let altitude = @() {
  watch = [altValue, IlsColor]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(80), ph(40)]
  color = IlsColor.value
  fontSize = 35
  font = Fonts.ils31
  text = string.format("%dр", altValue.value)
}

let airSymbol = @() {
  watch = IlsColor
  size = [pw(70), ph(70)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value
  color = IlsColor.value
  commands = [
    [VECTOR_LINE, -100, 0, -70, 0],
    [VECTOR_LINE, -50, 0, -30, 0],
    [VECTOR_LINE, -50, 0, -60, 20],
    [VECTOR_LINE, -70, 0, -60, 20],
    [VECTOR_LINE, 100, 0, 70, 0],
    [VECTOR_LINE, 50, 0, 30, 0],
    [VECTOR_LINE, 50, 0, 60, 20],
    [VECTOR_LINE, 70, 0, 60, 20],
    [VECTOR_LINE, 0, -35, 0, -70],
  ]
}

let rollIndicator = @() {
  watch = IlsColor
  size = [pw(18), ph(18)]
  pos = [pw(50), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = baseLineWidth * IlsLineScale.value
  color = IlsColor.value
  commands = [
    [VECTOR_LINE, -100, 0, -80, 0],
    [VECTOR_LINE, 100, 0, 80, 0],
    [VECTOR_LINE, -77.9, 45, -69.3, 40],
    [VECTOR_LINE, -45, 77.9, -40, 69.3],
    [VECTOR_LINE, 45, 77.9, 40, 69.3],
    [VECTOR_LINE, 77.9, 45, 69.3, 40]
  ]
  children = {
    size = flex()
    children = airSymbol
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = Roll.value
        pivot = [0, 0]
      }
    }
  }
}

let climbSpeedVal = Computed(@() ClimbSpeed.value.tointeger())
let climb = @(){
  watch = IlsColor
  size = [ph(20), ph(20)]
  rendObj = ROBJ_VECTOR_CANVAS
  pos = [pw(75), ph(20)]
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value * 0.5
  commands = [
    [VECTOR_SECTOR, 50, 50, 50, 50, 120, 240],
    [VECTOR_LINE, -5, 50, 5, 50],
    [VECTOR_LINE, 6.7, 25, 11, 27.5],
    [VECTOR_LINE, 25, 6.7, 27.5, 11],
    [VECTOR_LINE, 6.7, 75, 11, 72.5],
    [VECTOR_LINE, 25, 93.3, 27.5, 89],
    [VECTOR_LINE, 1.7, 37.1, 4.1, 37.7],
    [VECTOR_LINE, 1.7, 62.9, 4.1, 62.3],
    [VECTOR_LINE, 14.6, 14.6, 16.4, 16.4],
    [VECTOR_LINE, 14.6, 85.4, 16.4, 83.6],
    [VECTOR_SECTOR, 50, 50, 10, 10, 90, 270],
    [VECTOR_LINE, 50, 40, 90, 40],
    [VECTOR_LINE, 50, 60, 90, 60],
    [VECTOR_LINE, 90, 40, 90, 60]
  ]
  children = [
    {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = IlsColor.value
      lineWidth = baseLineWidth * IlsLineScale.value * 0.8
      commands = [
        [VECTOR_POLY, 50, 10, 47, 17, 53, 17],
        [VECTOR_LINE, 50, 17, 50, 35]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = cvt(ClimbSpeed.value, -30, 30, -180, 0)
          pivot = [0.5, 0.5]
        }
      }
    },
    @(){
      watch = climbSpeedVal
      size = [pw(40), ph(20)]
      pos = [pw(50), ph(40)]
      rendObj = ROBJ_TEXT
      color = IlsColor.value
      halign = ALIGN_RIGHT
      valign = ALIGN_CENTER
      padding = [0, 10]
      fontSize = 35
      font = Fonts.ils31
      text = climbSpeedVal.value.tostring()
    }
  ]
}

function generatePitchLine(num) {
  let sign = num < 0 ? -1 : 1
  return {
    size = [pw(12), ph(30)]
    pos = [pw(12), 0]
    children = [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.value * 0.5
        color = IlsColor.value
        commands = [
          (num < 0 ? [VECTOR_LINE, num % 10 == 0 ? -15 : 25, 0, 100, 0] : [VECTOR_LINE_DASHED,  num % 10 == 0 ? -15 : 25, 0, 100, 0, 5, 8]),
          (num != 0 && num % 10 == 0 ? [VECTOR_LINE, -15, 0, -15, 10 * sign] : [])
        ]
      },
      @() {
        size = [flex(), SIZE_TO_CONTENT]
        pos = [0, ph(-40)]
        watch = IlsColor
        rendObj = ROBJ_TEXT
        halign = ALIGN_RIGHT
        padding = [0, 2]
        color = IlsColor.value
        fontSize = 35
        font = Fonts.ils31
        text = num.tostring()
      }
    ]
  }
}

function pitch(width, height, generateFunc) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generateFunc(num))
  }

  return {
    size = [width, height]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.value - 6.7) * 0.06]
      }
    }
  }
}

function pitchWrap(width, height) {
  return @() {
    size = [pw(60), ph(30)]
    pos = [pw(20), ph(18)]
    clipChildren  = true
    children = [
      pitch(width * 0.5, height * 0.3, generatePitchLine)
      {
        rendObj = ROBJ_SOLID
        size = [baseLineWidth * IlsLineScale.value, ph(100)]
        color = IlsColor.value
        pos = [pw(20), 0]
      }
    ]
  }
}

function basicInfo(width, height) {
  return {
    size = flex()
    children = [
      speed
      acceleration
      compassWrap(width, height, 0.08, generateCompassMarkASP, 0.6, 5.0, false, -1, Fonts.ils31)
      compassMark
      barAltitude
      rollIndicator
      climb
      altitude
      pitchWrap(width, height)
    ]
  }
}

let drawAdvancedReticle = Computed(@() CCIPMode.value || BombingMode.value)
let distSectorAng = Computed(@() cvt(DistToTarget.value >= 10000.0 ? 5000.0 : DistToTarget.value, 0.0, 8000.0, -90.0, 270.0).tointeger())
let distValue = Computed(@() (DistToTarget.value >= 10000.0 ? 50.0 : DistToTarget.value * 0.01).tointeger())
let CVisible = Computed(@() DistToTarget.value < 2000.0 )
let reticle = @(){
  watch = IlsTrackerVisible
  size = flex()
  children = !IlsTrackerVisible.value ? @(){
    watch = IlsColor
    size = [ph(5), ph(5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, 0, 0, 0, 0],
      [VECTOR_LINE, -100, 0, -70, 0],
      [VECTOR_LINE, 130, 0, 70, 0],
      [VECTOR_LINE, 0, 100, 0, 70],
      [VECTOR_LINE, 0, -100, 0, -70],
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = TargetPosValid.value ? TargetPos.value : [IlsPosSize[2] * 0.5, IlsPosSize[3] * 0.5]
      }
    }
    children = @(){
      watch = [CVisible, drawAdvancedReticle]
      size = flex()
      children = drawAdvancedReticle.value ? [
        @(){
          watch = distSectorAng
          rendObj = ROBJ_VECTOR_CANVAS
          size = flex()
          color = IlsColor.value
          fillColor = Color(0, 0, 0, 0)
          lineWidth = baseLineWidth * IlsLineScale.value
          commands = [
            [VECTOR_SECTOR, 0, 0, 110, 110, -90, distSectorAng.value],
            [VECTOR_LINE, 49.9, -98, 59, -115.8],
            [VECTOR_LINE, -28.5, 106.3, -33.6, 125.6]
          ]
        },
        @(){
          watch = distValue
          size = [pw(200), SIZE_TO_CONTENT]
          pos = [pw(-100), ph(-180)]
          rendObj = ROBJ_TEXT
          color = IlsColor.value
          halign = ALIGN_CENTER
          font = Fonts.ils31
          fontSize = 35
          text = string.format("%.1f", distValue.value * 0.1)
        },
        (CVisible.value ? {
          rendObj = ROBJ_VECTOR_CANVAS
          size = flex()
          color = IlsColor.value
          lineWidth = baseLineWidth * IlsLineScale.value
          commands = [
            [VECTOR_LINE, 150, -50, 150, 50],
            [VECTOR_LINE, 150, -50, 190, -50],
            [VECTOR_LINE, 150, 50, 190, 50]
          ]
        } : null)
      ] : []
    }
  } : null
}

let cancelVisible = Computed(@() CCIPMode.value && DistToTarget.value <= 600.0)
let cancel = @(){
  watch = cancelVisible
  size = flex()
  children = cancelVisible.value ? {
    rendObj = ROBJ_VECTOR_CANVAS
    pos = [pw(35), ph(45)]
    size = [pw(30), ph(30)]
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, 0, 0, 100, 100],
      [VECTOR_LINE, 0, 100, 100, 0]
    ]
  } : null
}

let distToTargetMarkPos = Computed(@() BombingMode.value ? clamp(100.0 - TimeBeforeBombRelease.value * 10.0, 0.0, 100.0).tointeger() :
 cvt(DistToTarget.value, 8000.0, 0.0, 0.0, 100.0).tointeger())
let distToTargetMark = @(){
  watch = distToTargetMarkPos
  rendObj = ROBJ_VECTOR_CANVAS
  size = [pw(70), ph(3)]
  pos = [pw(30), ph(distToTargetMarkPos.value)]
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.value * 0.5
  commands = [
    [VECTOR_POLY, 0, 0, 30, -100, 30, -60, 100, -60, 100, 60, 30, 60, 30, 100]
  ]
}

let distGrid = @(){
  watch = [CCIPMode, BombingMode, IlsTrackerVisible]
  size = flex()
  children = !IlsTrackerVisible.value && (CCIPMode.value || BombingMode.value) ? @(){
    watch = BombingMode
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(5), ph(30)]
    pos = [pw(20), ph(50)]
    color = IlsColor.value
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_LINE, 10, 0, 10, 100],
      [VECTOR_LINE, 10, 0, 30, 0],
      [VECTOR_LINE, 10, 12.5, 20, 12.5],
      [VECTOR_LINE, 10, 25, 20, 25],
      [VECTOR_LINE, 10, 37.5, 20, 37.5],
      [VECTOR_LINE, 10, 50, 20, 50],
      [VECTOR_LINE, 10, 62.5, 20, 62.5],
      [VECTOR_LINE, 10, 75, 20, 75],
      [VECTOR_LINE, 10, 87.5, 20, 87.5],
      [VECTOR_LINE, 10, 100, 30, 100]
    ]
    children = !BombingMode.value ? [
      {
        rendObj = ROBJ_TEXT
        pos = [-25, -17]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        font = Fonts.ils31
        fontSize = 35
        text = "8"
      }
      {
        rendObj = ROBJ_TEXT
        pos = [-25, ph(20)]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        font = Fonts.ils31
        fontSize = 35
        text = "6"
      }
      {
        rendObj = ROBJ_TEXT
        pos = [-25, ph(45)]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        font = Fonts.ils31
        fontSize = 35
        text = "4"
      }
      {
        rendObj = ROBJ_TEXT
        pos = [-25, ph(70)]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        font = Fonts.ils31
        fontSize = 35
        text = "2"
      }
      {
        rendObj = ROBJ_TEXT
        pos = [-25, ph(95)]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        font = Fonts.ils31
        fontSize = 35
        text = "0"
      }
      distToTargetMark
    ] : [
      {
        rendObj = ROBJ_TEXT
        pos = [-40, -17]
        size = SIZE_TO_CONTENT
        color = IlsColor.value
        font = Fonts.ils31
        fontSize = 35
        text = "10"
      }
      distToTargetMark
    ]
  } : null
}

let mode = @(){
  watch = [IlsColor, IlsTrackerVisible]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(8), ph(75)]
  color = IlsColor.value
  font = Fonts.ils31
  fontSize = 50
  text = IlsTrackerVisible.value ? "ФИ0" : "ОЦ"
}

let fuel = @(){
  watch = IlsColor
  size = [pw(9), ph(4)]
  pos = [pw(8), ph(86)]
  color = IlsColor.value
  fillColor = Color(0, 0, 0, 0)
  borderWidth = baseLineWidth * IlsLineScale.value * 0.5
  rendObj = ROBJ_FRAME
  children = @(){
    watch = FuelTotal
    size = flex()
    rendObj = ROBJ_TEXT
    halign = ALIGN_RIGHT
    valign = ALIGN_CENTER
    padding = [0, 5]
    color = IlsColor.value
    font = Fonts.ils31
    fontSize = 35
    text = FuelTotal.value.tostring()
  }
}

let fuelAlertVisible = Computed(@() FuelTotal.value <= 600)
let fuelAlert = @(){
  watch = fuelAlertVisible
  size = flex()
  children = fuelAlertVisible.value ? {
    rendObj = ROBJ_TEXT
    pos = [pw(8), ph(82)]
    size = SIZE_TO_CONTENT
    color = IlsColor.value
    font = Fonts.ils31
    fontSize = 35
    text = "ОСТАТОК МЕНЕЕ 600"
  } : null
}

let aimLock = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.value ? {
    size = [pw(5), ph(5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_RECTANGLE, -50, -50, 100, 100],
      [VECTOR_LINE, 0, 0, 0, 0]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = AimLockPos
      }
    }
  } : null
}

let aimLockX = @(){
  watch = BombingMode
  size = flex()
  children = BombingMode.value ? {
    size = [pw(2), ph(2)]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100],
      [VECTOR_LINE, 0, 100, 0, 200]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [AimLockPos[0], IlsPosSize[3] * 0.18]
      }
    }
  } : null
}

function getWeaponSlotCnt(weaponSlotsV) {
  local cnt = 0
  foreach (weaponCnt in weaponSlotsV)
    if (weaponCnt != null && weaponCnt > cnt)
      cnt = weaponCnt
  return cnt
}

function getWeaponSlotCommands(weaponSlotsV) {
  let commands = []
  foreach (weaponCnt in weaponSlotsV)
    if (weaponCnt != null)
      commands.append([VECTOR_LINE, 15 * (weaponCnt - 1), 100, 15 * (weaponCnt - 1) + 8, 100])
  return commands
}

function getWeaponSlotNumber(weaponSlotsV, weaponSlotActiveV) {
  let numbers = []
  foreach (i, weaponCnt in weaponSlotsV) {
    if (weaponCnt == null || !weaponSlotActiveV?[i])
      continue

    let pos = 15 * (weaponCnt - 1)
    let text = (i + 1).tostring()
    numbers.append(
      @() {
        watch = IlsColor
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        pos = [pw(pos), 0]
        color = IlsColor.value
        fontSize = 30
        font = Fonts.ils31
        text
      }
    )
  }
  return numbers
}

let connectors = @() {
  watch = [WeaponSlots, IlsColor, IlsLineScale]
  size = [pw(24), ph(3)]
  pos = [pw(50 - 12 * getWeaponSlotCnt(WeaponSlots.get()) / 7), ph(86)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.value
  lineWidth = baseLineWidth * IlsLineScale.value
  commands = getWeaponSlotCommands(WeaponSlots.get())
  children = [
    @() {
      watch = [WeaponSlots, WeaponSlotActive]
      size = flex()
      children = getWeaponSlotNumber(WeaponSlots.get(), WeaponSlotActive.get())
    }
  ]
}

let rangefinderVisible = Computed(@() CCIPMode.value || AimLockValid.value || BombingMode.value)
let rangefinder = @(){
  watch = rangefinderVisible
  size = flex()
  children = rangefinderVisible.value ? {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [ph(5), ph(5)]
    pos = [pw(8), ph(45)]
    color = IlsColor.value
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.value
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 100, 100],
      [VECTOR_LINE, -100, 0, -80, 0],
      [VECTOR_LINE, -92.4, -38.3, -73.9, -30.6],
      [VECTOR_LINE, -70.8, -70.8, -56.6, -56.6],
      [VECTOR_LINE, -38.3, -92.4, -30.6, -73.9],
      [VECTOR_LINE, 0, -100, 0, -80],
      [VECTOR_LINE, 38.3, -92.4, 30.6, -73.9],
      [VECTOR_LINE, 70.8, -70.8, 56.6, -56.6],
      [VECTOR_LINE, 92.4, -38.3, 73.9, -30.6],
      [VECTOR_LINE, 100, 0, 80, 0],
      [VECTOR_LINE, 92.4, 38.3, 73.9, 30.6],
      [VECTOR_LINE, 70.8, 70.8, 56.6, 56.6],
      [VECTOR_LINE, 38.3, 92.4, 30.6, 73.9],
      [VECTOR_LINE, 0, 100, 0, 80],
      [VECTOR_LINE, -92.4, 38.3, -73.9, 30.6],
      [VECTOR_LINE, -70.8, 70.8, -56.6, 56.6],
      [VECTOR_LINE, -38.3, 92.4, -30.6, 73.9],
    ]
    children = {
      rendObj = ROBJ_TEXT
      pos = [pw(-50), ph(-50)]
      size = flex()
      color = IlsColor.value
      font = Fonts.ils31
      fontSize = 50
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      text = "ЛД"
    }
  } : null
}

let aamReticle = @() {
  watch = IlsTrackerVisible
  size = flex()
  children = IlsTrackerVisible.value ?
  [
    @() {
      watch = IlsColor
      size = [pw(10), ph(10)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.value
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * IlsLineScale.value
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          translate = [IlsTrackerX.value, IlsTrackerY.value]
        }
      }
    }
  ] : null
}

function ilsKai24p(width, height) {
  return {
    size = [width, height]
    children = [
      basicInfo(width, height)
      reticle
      cancel
      distGrid
      fuel
      mode
      fuelAlert
      aimLock
      connectors
      aimLockX
      rangefinder
      aamReticle
    ]
  }
}

return ilsKai24p
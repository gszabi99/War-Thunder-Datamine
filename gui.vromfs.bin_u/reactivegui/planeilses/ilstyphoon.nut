from "%rGui/globals/ui_library.nut" import *
from "%globalScripts/loc_helpers.nut" import loc_checked
let { Speed, BarAltitude, Tangage, Altitude, Mach, Roll, CompassValue,
 Overload } = require("%rGui/planeState/planeFlyState.nut")
let { sin, cos, round, abs, floor, PI } = require("math")
let { cvt } = require("dagor.math")
let { degToRad } = require("%sqstd/math_ex.nut")
let { mpsToKnots, baseLineWidth, metrToFeet, metrToNavMile, radToDeg } = require("ilsConstants.nut")
let { IlsColor, IlsLineScale, RadarTargetDist, BombCCIPMode, RocketMode, CannonMode, TargetPosValid,
 TargetPos, IlsPosSize, AirCannonMode, AimLockPos, AimLockValid, BombingMode,
 RadarTargetDistRate, TvvMark, RadarTargetAngle } = require("%rGui/planeState/planeToolsState.nut")
let { IsAamLaunchZoneVisible, AamLaunchZoneDistMaxVal, DistanceMax,
  AamLaunchZoneDistMax, AamLaunchZoneDist, AamTimeOfFlightMax, AamLaunchZoneDistMinVal } = require("%rGui/radarState.nut")
let { format } = require("string")
let { GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let { GuidanceLockResult } = require("guidanceConstants")
let { GunBullets0, WeaponSlotsCnt, WeaponSlotsName, WeaponSlots, SelectedWeapSlot, BulletImpactLineEnable,
 BulletImpactPoints, AdlPoint } = require("%rGui/planeState/planeWeaponState.nut")
let dasRadarMarks = load_das("%rGui/planeIlses/ilsTyphoonUtil.das")

let hasRadarTarget = Computed(@() RadarTargetDist.get() > 0.0)

let AltThousandAngle = Computed(@() (BarAltitude.get() * metrToFeet % 1000 / 2.7777 - 90.0).tointeger())
let BarAltValue = Computed(@() (BarAltitude.get() * metrToFeet * 0.1).tointeger())
function altCircle(lineWidth, color, fontSize) {
  return @(){
    watch = IlsColor
    size = [ph(16), ph(16)]
    pos = [pw(65), ph(18.5)]
    rendObj = ROBJ_VECTOR_CANVAS
    color
    fillColor = Color(0, 0, 0, 0)
    lineWidth
    commands = [
      [VECTOR_LINE, 50, 0, 50, 0],
      [VECTOR_LINE, 50, 100, 50, 100],
      [VECTOR_LINE, 20.6, 9.5, 20.6, 9.5],
      [VECTOR_LINE, 2.4, 34.5, 2.4, 34.5],
      [VECTOR_LINE, 2.4, 65.5, 2.4, 65.5],
      [VECTOR_LINE, 20.6, 90.5, 20.6, 90.5],
      [VECTOR_LINE, 80.6, 90.5, 80.6, 90.5],
      [VECTOR_LINE, 97.6, 65.5, 97.6, 65.5],
      [VECTOR_LINE, 97.6, 34.5, 97.6, 34.5],
      [VECTOR_LINE, 80.6, 9.5, 80.6, 9.5]
    ]
    children = [
      @() {
        watch = [AltThousandAngle, IlsColor]
        rendObj = ROBJ_VECTOR_CANVAS
        size = [pw(50), ph(50)]
        pos = [pw(50), ph(50)]
        color = IlsColor.get()
        fillColor = Color(0, 0, 0, 0)
        lineWidth = lineWidth * 0.5
        commands = [
          [VECTOR_LINE, 100 * cos(degToRad(AltThousandAngle.get())), 100 * sin(degToRad(AltThousandAngle.get())),
            70 * cos(degToRad(AltThousandAngle.get())), 70 * sin(degToRad(AltThousandAngle.get()))]
        ]
      }
      @(){
        watch = BarAltValue
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        size = SIZE_TO_CONTENT
        font = Fonts.hud
        fontSize
        text = (BarAltValue.get() * 10).tostring()
        hplace = ALIGN_CENTER
        vplace = ALIGN_CENTER
      }
    ]
  }
}

let AltitudeValue = Computed(@() (Altitude.get() * metrToFeet).tointeger())
function altitude(fontSize) {
  return {
    size = [pw(10), ph(5)]
    pos = [pw(78), ph(22.5)]
    flow = FLOW_VERTICAL
    children = [
      @(){
        watch = IlsColor
        rendObj = ROBJ_TEXT
        size = [flex(), SIZE_TO_CONTENT]
        color = IlsColor.get()
        font = Fonts.hud
        fontSize
        text = "R"
        halign = ALIGN_CENTER
      }
      @(){
        watch = AltitudeValue
        rendObj = ROBJ_TEXT
        size = [flex(), SIZE_TO_CONTENT]
        color = IlsColor.get()
        font = Fonts.hud
        fontSize
        text = AltitudeValue.get().tostring()
        halign = ALIGN_CENTER
      }
    ]
  }
}

let airSymbol = @(){
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  pos = [pw(50), ph(50)]
  size = [ph(5), ph(5)]
  color = IlsColor.get()
  fillColor = 0
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  commands = [
    [VECTOR_ELLIPSE, 0, 0, 20, 20],
    [VECTOR_LINE, -100, 0, -20, 0],
    [VECTOR_LINE, 100, 0, 20, 0]
  ]
}

let tvvLinked = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = [ph(1), ph(1)]
  color = IlsColor.get()
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
  commands = [
    [VECTOR_LINE, 0, -100, 100, 0],
    [VECTOR_LINE, 100, 0, 0, 100],
    [VECTOR_LINE, 0, 100, -100, 0],
    [VECTOR_LINE, -100, 0, 0, -100]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [TvvMark[0], TvvMark[1]]
    }
  }
}

let MachValue = Computed(@() (Mach.get() * 100.0).tointeger())
function mach(fontSize) {
  return {
    size = [pw(10), ph(5)]
    pos = [pw(5), ph(22.5)]
    flow = FLOW_VERTICAL
    children = [
      @(){
        watch = IlsColor
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        size = SIZE_TO_CONTENT
        font = Fonts.hud
        fontSize
        text = "M"
        hplace = ALIGN_CENTER
      }
      @(){
        watch = MachValue
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        size = SIZE_TO_CONTENT
        font = Fonts.hud
        fontSize
        text = format("%.2f", MachValue.get() * 0.01)
        hplace = ALIGN_CENTER
      }
    ]
  }
}

let SpeedVal = Computed(@() (Speed.get() * mpsToKnots).tointeger())
function speed(fontSize) {
  return @(){
    watch = SpeedVal
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    pos = [pw(17), ph(24.5)]
    color = IlsColor.get()
    font = Fonts.hud
    fontSize
    text = SpeedVal.get().tostring()
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
    size = [width * 0.5, height * 0.5]
    pos = [width * 0.25, height * 0.5]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * 0.05]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * 0.1]
      }
    }
  }
}

function angleTxt(num, isLeft, x = 0, y = 0) {
  return @() {
    watch = IlsColor
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = num < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = IlsColor.get()
    fontSize = 40
    font = Fonts.hud
    text = num.tostring()
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  return {
    size = [pw(70), ph(50)]
    pos = [pw(15), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        color = IlsColor.get()
        padding = [0, 10]
        commands = [
          [VECTOR_LINE, -100, 0, 35, 0],
          [VECTOR_LINE, 65, 0, 200, 0],
          [VECTOR_LINE, 65, 0, 65, 8],
          [VECTOR_LINE, 35, 0, 35, 8]
        ]
        children = [angleTxt(-5, true, 0), angleTxt(-5, false, 0)]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, 0, 5 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, num > 0 ? 35 : 7, 0],
          (num < 0 ? [VECTOR_LINE, 13, 0, 21, 0] : []),
          (num < 0 ? [VECTOR_LINE, 24, -8, 21, 0] : []),
          (num < 0 ? [VECTOR_LINE, 24, -8, 27, 0] : []),
          (num < 0 ? [VECTOR_LINE, 27, 0, 35, 0] : []),
          [VECTOR_LINE, 100, 5 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, num > 0 ? 65 : 93, 0],
          (num < 0 ? [VECTOR_LINE, 87, 0, 79, 0] : []),
          (num < 0 ? [VECTOR_LINE, 76, -8, 79, 0] : []),
          (num < 0 ? [VECTOR_LINE, 76, -8, 73, 0] : []),
          (num < 0 ? [VECTOR_LINE, 73, 0, 65, 0] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, newNum < 0 ? 0 : 5, newNum < 0 ? 0 : 5), angleTxt(newNum, false, newNum < 0 ? 0 : -5, newNum < 0 ? 0 : 5)] : null
      }
    ]
  }
}

let generateCompassMark = function(num) {
  return {
    size = [pw(15), ph(100)]
    flow = FLOW_VERTICAL
    children = [
      @() {
        watch = IlsColor
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        hplace = ALIGN_CENTER
        fontSize = 40
        font = Fonts.hud
        text = num % 10 == 0 ? (num / 10).tostring() : ""
      }
      @() {
        watch = IlsColor
        size = [flex(), baseLineWidth * 1.5 * IlsLineScale.get()]
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 1.5
        commands = [
          [VECTOR_LINE, 50, 0, 50, 0]
        ]
      }
    ]
  }
}


function compass(width, generateFunc) {
  let children = []
  let step = 5.0

  for (local i = 0; i <= 2.0 * 360.0 / step; ++i) {

    let num = (i * step) % 360

    children.append(generateFunc(num))
  }

  let getOffset = @() (360.0 + CompassValue.get()) * 0.03 * width
  return {
    size = flex()
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [-getOffset() + width * 0.4, 0]
      }
    }
    flow = FLOW_HORIZONTAL
    children = children
  }
}

function compassWrap(width, height, generateFunc) {
  return {
    size = [width * 0.5, height * 0.1]
    pos = [width * 0.25, height * 0.1]
    clipChildren = true
    children = [
      compass(width * 0.5, generateFunc)
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_LINE, 50, 40, 50, 70]
        ]
      }
    ]
  }
}

function getWeaponsElem(weaponSlotsV, fontSize) {
  let weapons = []
  let added = {}
  local selected = ""
  foreach (i, weaponName in WeaponSlotsName.get()) {
    if (weaponName == null)
      continue
    if (SelectedWeapSlot.get() == weaponSlotsV[i])
      selected = weaponName
    if (weaponName not in added)
      added[weaponName] <- WeaponSlotsCnt.get()?[i] ?? 0
    else
      added[weaponName] += WeaponSlotsCnt.get()?[i] ?? 0
  }
  foreach (k, v in added) {
    let isSelected = selected == k
    let text = format("%s %d", loc_checked(isSelected ? $"{k}/typhoon" : $"{k}/typhoon/short"), v)
    weapons.append(
      @() {
        watch = IlsColor
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        color = IlsColor.get()
        fontSize
        font = Fonts.hud
        text
        children = (isSelected ? @(){
          watch = IlsColor
          rendObj = ROBJ_VECTOR_CANVAS
          size = flex()
          color = IlsColor.get()
          lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
          commands = [
            [VECTOR_LINE, 0, 0, 100, 0],
            [VECTOR_LINE, 0, 100, 100, 100],
            [VECTOR_LINE, 0, 0, 0, 30],
            [VECTOR_LINE, 0, 100, 0, 70],
            [VECTOR_LINE, 100, 0, 100, 30],
            [VECTOR_LINE, 100, 100, 100, 70]
          ]
        } : null)
      }
    )
  }
  weapons.append(
    @() {
      watch = [IlsColor, GunBullets0]
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      color = IlsColor.get()
      fontSize
      font = Fonts.hud
      text = format("G %d", GunBullets0.get())
    }
  )
  return weapons
}

function weapons(font_size) {
  return @(){
    watch = [WeaponSlots, WeaponSlotsName, SelectedWeapSlot]
    size = flex()
    flow = FLOW_VERTICAL
    pos = [pw(83), ph(80)]
    children = getWeaponsElem(WeaponSlots.get(), font_size)
  }
}

let distRate = Computed(@() (RadarTargetDistRate.get() * mpsToKnots).tointeger())
let aspect = Computed(@() format("% 2.0f%s", abs(RadarTargetAngle.get() * radToDeg * 0.1), RadarTargetAngle.get() > 0.0 ? "L" : "R"))
let launchDistMaxPos = Computed(@() ((1.0 - AamLaunchZoneDistMax.get()) * 100.0).tointeger())
let currentLaunchDistLen = Computed(@() ((1.0 - AamLaunchZoneDist.get()) * 100.0).tointeger())
let targetDist = Computed(@() (RadarTargetDist.get() * metrToNavMile * 10.0).tointeger())
function aamScale(fontSize) {
  return @(){
    watch = hasRadarTarget
    size = [pw(10), ph(30)]
    pos = [pw(83), ph(20)]
    children = hasRadarTarget.get() ? [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_LINE, 50, 0, 50, 100],
          [VECTOR_LINE, 40, 0, 60, 0],
          [VECTOR_LINE, 40, 100, 60, 100]
        ]
      }
      @(){
        watch = DistanceMax
        size = [flex(), SIZE_TO_CONTENT]
        pos = [0, -fontSize]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        font = Fonts.hud
        fontSize
        text = (DistanceMax.get() * metrToNavMile * 1000.0).tointeger().tostring()
        halign = ALIGN_CENTER
      }
      @(){
        watch = distRate
        size = [flex(), SIZE_TO_CONTENT]
        pos = [0, ph(102)]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        font = Fonts.hud
        fontSize
        text = format("%dkt", distRate.get())
        halign = ALIGN_CENTER
      }
      @(){
        watch = aspect
        pos = [0, ph(110)]
        size = [flex(), SIZE_TO_CONTENT]
        rendObj = ROBJ_TEXT
        color = IlsColor.get()
        fontSize
        text = aspect.get()
        halign = ALIGN_CENTER
      }
      @(){
        watch = launchDistMaxPos
        rendObj = ROBJ_SOLID
        size = [pw(20), baseLineWidth * IlsLineScale.get() * 0.5]
        pos = [pw(40), ph(launchDistMaxPos.get())]
        color = IlsColor.get()
      }
      @(){
        watch = currentLaunchDistLen
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color = IlsColor.get()
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_LINE, 60, currentLaunchDistLen.get(), 75, currentLaunchDistLen.get() - 2],
          [VECTOR_LINE, 60, currentLaunchDistLen.get(), 75, currentLaunchDistLen.get() + 2]
        ]
        children = @(){
          watch = targetDist
          pos = [pw(77), ph(currentLaunchDistLen.get() - 3)]
          rendObj = ROBJ_TEXT
          color = IlsColor.get()
          size = SIZE_TO_CONTENT
          font = Fonts.hud
          fontSize
          text = format("%.1fnm", targetDist.get() * 0.1)
        }
      }
    ] : null
  }
}

function canShoot(fontSize, color) {
  return @() {
    watch = GuidanceLockState
    size = [pw(12), fontSize]
    pos = [pw(83), ph(70)]
    children = (GuidanceLockState.get() >= GuidanceLockResult.RESULT_TRACKING ? [
      @() {
        watch = IlsColor
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color
        fontSize
        font = Fonts.hud
        text = "SHOOT"
        padding = [3, 0]
        hplace = ALIGN_CENTER
        animations = [
          { prop = AnimProp.opacity, from = -1, to = 1, duration = 0.75, play = true, loop = true }
        ]
      }
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color
        lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
        commands = [
          [VECTOR_LINE, 0, 0, 100, 0],
          [VECTOR_LINE, 0, 100, 100, 100],
          [VECTOR_LINE, 0, 0, 0, 30],
          [VECTOR_LINE, 0, 100, 0, 70],
          [VECTOR_LINE, 100, 0, 100, 30],
          [VECTOR_LINE, 100, 100, 100, 70]
        ]
      }
    ]
    : null)
  }
}

let radarMarks = @(){
  watch = IlsColor
  rendObj = ROBJ_DAS_CANVAS
  script = dasRadarMarks
  drawFunc = "draw_ils_radar_mark"
  setupFunc = "setup_data"
  size = flex()
  color = IlsColor.get()
  font = Fonts.hud
  fontSize = 30
  lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
}

let CalcFlightTime = Computed(@() AamLaunchZoneDistMaxVal.get() == 0 ? 0
  : round(AamTimeOfFlightMax.get() * (RadarTargetDist.get() / AamLaunchZoneDistMaxVal.get())).tointeger())
let timeVisible = Computed(@() IsAamLaunchZoneVisible.get() && AamTimeOfFlightMax.get() > 0.0)
function flightTime(fontSize) {
  return @() {
    watch = timeVisible
    pos = [pw(86), ph(66)]
    size = [pw(5), ph(5)]
    children = timeVisible.get() ?
      @() {
        watch = [CalcFlightTime, IlsColor]
        rendObj = ROBJ_TEXT
        halign = ALIGN_CENTER
        size = flex()
        color = IlsColor.get()
        fontSize
        font = Fonts.hud
        text = CalcFlightTime.get().tostring()
      }
    : null
  }
}

let aimPos = @(){
  watch = AimLockValid
  size = flex()
  children = AimLockValid.get() ? {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [pw(3), ph(3)]
    color = IlsColor.get()
    fillColor = 0
    lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
    commands = [
      [VECTOR_POLY, 0, -100, 100, 100, -100, 100]
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = AimLockPos
      }
    }
  } : null
}

function getBulletImpactLineCommand() {
  let commands = []
  for (local i = 0; i < BulletImpactPoints.get().len() - 2; ++i) {
    let point1 = BulletImpactPoints.get()[i]
    let point2 = BulletImpactPoints.get()[i + 1]
    if (point1.x == -1 && point1.y == -1)
      continue
    if (point2.x == -1 && point2.y == -1)
      continue
    commands.append([VECTOR_LINE, point1.x, point1.y, point2.x, point2.y])
  }
  return commands
}

let bulletsImpactLine = @() {
  watch = BulletImpactLineEnable
  size = flex()
  children = BulletImpactLineEnable.get() ? [
    @() {
      watch = [BulletImpactPoints, IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = flex()
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      commands = getBulletImpactLineCommand()
    }
  ] : null
}

let gunImpactLine = @(){
  watch = AirCannonMode
  size = flex()
  children = AirCannonMode.get() ? [
    bulletsImpactLine,
    {
      rendObj = ROBJ_VECTOR_CANVAS
      color = IlsColor.get()
      lineWidth = baseLineWidth * IlsLineScale.get()
      size = [ph(2), ph(2)]
      pos = AdlPoint
      commands = [
        [VECTOR_LINE, 30, 0, 100, 0],
        [VECTOR_LINE, -30, 0, -100, 0],
        [VECTOR_LINE, 0, 30, 0, 100],
        [VECTOR_LINE, 0, -30, 0, -100]
      ]
    }
   ] : null
}

function intScale(height, watchV) {
  let children = []
  for (local i = 0; i <= 10; ++i) {
    children.append(
      {
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        color = IlsColor.get()
        font = Fonts.hud
        fontSize = 30
        text = (i % 10).tostring()
      }
    )
  }

  return {
    size = [SIZE_TO_CONTENT, height]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, (-watchV.get()) * height]
      }
    }
  }
}

let overloadDec = Computed(@() (Overload.get() % 1.0) * 10.0)
let overloadInt = Computed(@() Overload.get() % 1.0 > 0.0 && Overload.get() % 1.0 < 0.9 ? Overload.get().tointeger() : (floor(Overload.get()) + Overload.get() % 0.05 * 20.0))
function overload(height) {
  return {
    pos = [pw(20), ph(47.5)]
    size = [pw(7), ph(2.5)]
    clipChildren = true
    flow = FLOW_HORIZONTAL
    children = [
      intScale(height * 0.025, overloadInt)
      {
        rendObj = ROBJ_TEXT
        size = SIZE_TO_CONTENT
        color = IlsColor.get()
        font = Fonts.hud
        fontSize = 30
        text = "."
      }
      intScale(height * 0.025, overloadDec)
    ]
  }
}


let isCCIPMode = Computed(@() CannonMode.get() || BombCCIPMode.get() || BombingMode.get() || RocketMode.get())
function ccipImpactLine(height) {
  return @(){
    watch = [isCCIPMode, TargetPosValid]
    size = flex()
    children = isCCIPMode.get() && TargetPosValid.get() ? [
      @() {
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = [ph(2), ph(2)]
        lineWidth = baseLineWidth * 0.5 * IlsLineScale.get()
        color = IlsColor.get()
        commands = [
          [VECTOR_LINE, -100, 0, 100, 0],
          [VECTOR_LINE, 0, -100, 0, 100]
        ]
        behavior = Behaviors.RtPropUpdate
        update = @() {
          transform = {
            translate = [TargetPos.get()[0], clamp(TargetPos.get()[1], 0, height)]
          }
        }
      }
      @(){
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        lineWidth = baseLineWidth * 0.5 * IlsLineScale.get()
        color = IlsColor.get()
        behavior = Behaviors.RtPropUpdate
        update = @() {
          commands = [
            [VECTOR_LINE, TargetPos.get()[0] / IlsPosSize[2] * 100, TargetPos.get()[1] / IlsPosSize[3] * 100, 50, 50]
          ]
        }
      }
    ]: null
  }
}

let isSraamReticle = Computed(@() GuidanceLockState.value > GuidanceLockResult.RESULT_STANDBY)
let retSize = Computed(@() hasRadarTarget.get() ? cvt(RadarTargetDist.get(), 0, 3657.6, 0.0, 0.15) : 0.15)
let distAngle = Computed(@() hasRadarTarget.get() ? cvt(RadarTargetDist.get(), 0, 3657.6, -90.0, 269.0).tointeger() : 269)
let hasSector = Computed(@() hasRadarTarget.get() && RadarTargetDist.get() > 0.0 && RadarTargetDist.get() < 3657.6)
let midDist = Computed(@() cvt(AamLaunchZoneDistMinVal.get(), 0, 3657.6, PI, -PI))
let aamReticle = @(){
  watch = [isSraamReticle, hasSector]
  size = flex()
  children = isSraamReticle.get() ? [
    @(){
      watch = [IlsColor]
      rendObj = ROBJ_VECTOR_CANVAS
      size = [ph(30), ph(30)]
      pos = [pw(50), ph(50)]
      color = IlsColor.get()
      fillColor = 0
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_ELLIPSE, 0, 0, 100, 100]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        size = [retSize.get() * IlsPosSize[3], retSize.get() * IlsPosSize[3]]
      }
    },
    (hasSector.get() ? @(){
      watch = distAngle
      rendObj = ROBJ_VECTOR_CANVAS
      size = [ph(13), ph(13)]
      pos = [pw(50), ph(50)]
      color = IlsColor.get()
      fillColor = 0
      lineWidth = baseLineWidth * IlsLineScale.get() * 0.5
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, -90, distAngle.get()],
        [VECTOR_ELLIPSE, 100 * sin(midDist.get()), 100 * cos(midDist.get()), 5, 5],
        [VECTOR_LINE, 0, -100, 0, -105],
        [VECTOR_LINE, 100 * cos(degToRad(distAngle.get())), 100 * sin(degToRad(distAngle.get())),
         105 * cos(degToRad(distAngle.get())), 105 * sin(degToRad(distAngle.get()))]
      ]
    } : null)
  ] : null
}

function IlsTyphoon(width, height) {
  return {
    size = [width, height]
    children = [
      altCircle(baseLineWidth * IlsLineScale.get() * 2.0, IlsColor.get(), 40)
      altitude(40)
      airSymbol
      tvvLinked
      mach(40)
      speed(40)
      pitch(width, height, generatePitchLine)
      compassWrap(width, height, generateCompassMark)
      weapons(40)
      aamScale(30)
      canShoot(40, IlsColor.get())
      radarMarks
      flightTime(40)
      aimPos
      gunImpactLine
      overload(height)
      ccipImpactLine(height)
      aamReticle
    ]
  }
}

return {
  IlsTyphoon
  altCircle
  altitude
  weapons
  mach
  speed
  aamScale
  canShoot
  flightTime
}
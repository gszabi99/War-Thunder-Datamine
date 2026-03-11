from "%rGui/globals/ui_library.nut" import *

let { TvvMark, RadarTargetPosValid, RadarTargetDist,
  RocketMode, CannonMode, BombCCIPMode, BombingMode, DistToTarget } = require("%rGui/planeState/planeToolsState.nut")
let { baseLineWidth, mpsToKnots, metrToFeet, feetToNavMile } = require("%rGui/planeIlses/ilsConstants.nut")
let mfdWhite = Color(255, 255, 255, 240)
let mfdLineWidth = 0.5
let { GuidanceLockResult } = require("guidanceConstants")
let { AdlPoint, CurWeaponName, ShellCnt } = require("%rGui/planeState/planeWeaponState.nut")
let { Tangage, Overload, BarAltitude, Altitude, Speed, Roll, Mach, MaxOverload } = require("%rGui/planeState/planeFlyState.nut")
let { GuidanceLockState } = require("%rGui/rocketAamAimState.nut")
let string = require("string")
let { floor, round } = require("%sqstd/math.nut")
let { sin, cos, abs } = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")
let { cvt } = require("dagor.math")


let isAAMMode = Computed(@() GuidanceLockState.get() > GuidanceLockResult.RESULT_STANDBY)
let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
let isDGFTMode = Computed(@() isAAMMode.get() && RadarTargetPosValid.get())

let generateSpdMark = function(num) {
  let ofs = num < 10 ? pw(-15) : pw(-30)
  return {
    size = const [pw(100), ph(7.5)]
    pos = [pw(30), 0]
    children = [
      (num % 5 > 0 ? null :
        @() {
          size = flex()
          pos = [ofs, 0]
          rendObj = ROBJ_TEXT
          color = mfdWhite
          vplace = ALIGN_CENTER
          fontsize = 20
          font = Fonts.hud
          text = num.tostring()
        }
      ),
      @() {
        pos = [baseLineWidth * (num % 5 > 0 ? 3 : 0), ph(25)]
        size = [baseLineWidth * (num % 5 > 0 ? 4 : 7), baseLineWidth * mfdLineWidth]
        rendObj = ROBJ_SOLID
        color = mfdWhite
        lineWidth = baseLineWidth * mfdLineWidth
      }
    ]
  }
}

function speed(height, generateFunc) {
  let children = []

  for (local i = 1000; i >= 0; i -= 10) {
    children.append(generateFunc(i / 10))
  }

  let getOffset = @() ((1000.0 - Speed.get() * mpsToKnots) * 0.00745 - 0.5) * height
  return {
    size = const [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -getOffset()]
      }
    }
    flow = FLOW_VERTICAL
    children = children
  }
}

let SpeedValue = Computed(@() round(Speed.get() * mpsToKnots).tointeger())
function speedWrap(width, height, generateFunc) {
  return @(){
    watch = isDGFTMode
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.1, height * 0.2]
    clipChildren = true
    children = [
      (!isDGFTMode.get() ? speed(height * 0.5, generateFunc) : null),
      @() {
        size = [pw(25), baseLineWidth * mfdLineWidth]
        pos = [pw(70), ph(50)]
        rendObj = ROBJ_SOLID
        color = mfdWhite
      },
      @() {
        size = SIZE_TO_CONTENT
        pos = [pw(75), ph(42)]
        rendObj = ROBJ_TEXT
        color = mfdWhite
        fontsize = 20
        font = Fonts.hud
        text = "C"
      }
    ]
  }
}

let speedVal = @() {
  size = const [pw(10), ph(4.4)]
  pos = [pw(5), ph(43)]
  halign = ALIGN_CENTER
  children = [
    @() {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = mfdWhite
      fillColor = Color(0, 0, 0, 255)
      lineWidth = baseLineWidth * mfdLineWidth
      commands = [
        [VECTOR_POLY, 0, 0, 80, 0, 100, 50, 80, 100, 0, 100]
      ]
    },
    @() {
      watch = SpeedValue
      size = SIZE_TO_CONTENT
      padding = const [0, 20]
      rendObj = ROBJ_TEXT
      color = mfdWhite
      fontsize = 20
      font = Fonts.hud
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      text = SpeedValue.get().tostring()
    }
  ]
}

let BarAltitudeValue = Computed(@() (BarAltitude.get() * metrToFeet).tointeger())
let AltVal = @() {
  size = const [pw(15), ph(4.2)]
  pos = [pw(82), ph(43)]
  halign = ALIGN_RIGHT
  children = [
    @() {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = mfdWhite
      fillColor = Color(0, 0, 0, 255)
      lineWidth = baseLineWidth * mfdLineWidth
      commands = [
        [VECTOR_POLY, 0, 50, 15, 0, 100, 0, 100, 100, 15, 100]
      ]
    },
    @() {
      watch = BarAltitudeValue
      size = SIZE_TO_CONTENT
      padding = const [0, 5]
      rendObj = ROBJ_TEXT
      color = mfdWhite
      fontsize = 18
      font = Fonts.hud
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      text = BarAltitudeValue.get() < 1000 ? string.format(",%03d", BarAltitudeValue.get() % 1000) : string.format("%d,%03d", BarAltitudeValue.get() / 1000, BarAltitudeValue.get() % 1000)
    }
  ]
}

let generateAltMark = function(num) {
  return {
    size = const [pw(100), ph(7.5)]
    pos = [pw(15), 0]
    flow = FLOW_HORIZONTAL
    children = [
      @() {
        size = [baseLineWidth * (num % 5 > 0 ? 3 : 5), baseLineWidth * mfdLineWidth]
        rendObj = ROBJ_SOLID
        color = mfdWhite
        lineWidth = baseLineWidth * mfdLineWidth
        vplace = ALIGN_CENTER
      },
      (num % 5 > 0 ? null :
        @() {
          size = flex()
          rendObj = ROBJ_TEXT
          color = mfdWhite
          vplace = ALIGN_CENTER
          fontsize = 20
          font = Fonts.hud
          text = string.format("%02d.%d", num / 10.0, num % 10)
        }
      )
    ]
  }
}

function altitude(height, generateFunc) {
  let children = []

  for (local i = 650; i >= 0; i -= 1) {
    children.append(generateFunc(i))
  }

  let getOffset = @() ((65000 - BarAltitude.get() * metrToFeet) * 0.0007425 - 0.48) * height
  return {
    size = const [pw(100), ph(100)]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -getOffset()]
      }
    }
    flow = FLOW_VERTICAL
    children = children
  }
}

function altWrap(width, height, generateFunc) {
  return @(){
    watch = isDGFTMode
    size = [width * 0.17, height * 0.5]
    pos = [width * 0.75, height * 0.2]
    clipChildren = true
    children = !isDGFTMode.get() ? [
      altitude(height * 0.5, generateFunc)
    ] : null
  }
}

let OverloadWatch = Computed(@() (floor(Overload.get() * 10)).tointeger())
let overload = @() {
  watch = OverloadWatch
  size = flex()
  pos = [pw(20), ph(17)]
  rendObj = ROBJ_TEXT
  color = mfdWhite
  fontsize = 20
  font = Fonts.hud
  text = string.format("%.1f", OverloadWatch.get() / 10.0)
}

let MaxOverloadWatch = Computed(@() (floor(MaxOverload.get() * 10)).tointeger())
let maxOverload = @() {
  watch = MaxOverloadWatch
  size = flex()
  pos = [pw(10), ph(78)]
  rendObj = ROBJ_TEXT
  color = mfdWhite
  fontsize = 20
  font = Fonts.hud
  text = string.format("%.1f", MaxOverloadWatch.get() / 10.0)
}

let MachWatch = Computed(@() (floor(Mach.get() * 100)).tointeger())
let mach = @() {
  watch = MachWatch
  size = flex()
  pos = [pw(20), ph(74)]
  rendObj = ROBJ_TEXT
  color = mfdWhite
  fontsize = 20
  font = Fonts.hud
  text = string.format("%.2f", MachWatch.get() / 100.0)
}

let AltitudeValue = Computed(@() (Altitude.get() * metrToFeet / 10).tointeger())
let radioAlt = @() {
  size = const [pw(12), ph(4)]
  pos = [pw(87), ph(87)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = mfdWhite
  fillColor = Color(0, 0, 0, 0)
  lineWidth = baseLineWidth * mfdLineWidth
  commands = [
    [VECTOR_POLY, 0, 0, 100, 0, 100, 100, 0, 100]
  ]
  halign = ALIGN_RIGHT
  children = [
    @() {
      size = SIZE_TO_CONTENT
      pos = [pw(-105), 0]
      rendObj = ROBJ_TEXT
      color = mfdWhite
      fontsize = 20
      font = Fonts.hud
      text = "R"
    },
    @() {
      watch = AltitudeValue
      size = SIZE_TO_CONTENT
      padding = const [0, 5]
      rendObj = ROBJ_TEXT
      color = mfdWhite
      fontsize = 20
      font = Fonts.hud
      text = AltitudeValue.get() < 100 ? string.format(",%02d0", AltitudeValue.get() % 100) : string.format("%d,%02d0", AltitudeValue.get() / 100, AltitudeValue.get() % 100)
    }
  ]
}

let adlMarker = @() {
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(3), ph(3)]
  color = mfdWhite
  lineWidth = baseLineWidth * mfdLineWidth
  commands = [
    [VECTOR_LINE, -100, 0, -40, 0],
    [VECTOR_LINE, 0, -100, 0, -40],
    [VECTOR_LINE, 100, 0, 40, 0],
    [VECTOR_LINE, 0, 100, 0, 40]
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [AdlPoint[0], AdlPoint[1]]
    }
  }
}

let roll = @() {
  size = const [pw(70), ph(70)]
  pos = [pw(15), ph(30)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = mfdWhite
  lineWidth = baseLineWidth * mfdLineWidth
  commands = [
    [VECTOR_LINE, 50, 89, 50, 86],
    [VECTOR_LINE, 30.5, 83.775, 32, 81.18],
    [VECTOR_LINE, 69.5, 83.775, 68, 81.18],
    [VECTOR_LINE, 22.42, 77.58, 24.54, 75.46],
    [VECTOR_LINE, 77.58, 77.58, 75.46, 75.46],
    [VECTOR_LINE, 36.66, 86.65, 37.69, 83.83],
    [VECTOR_LINE, 43.23, 88.41, 43.75, 85.45],
    [VECTOR_LINE, 56.77, 88.41, 56.25, 85.45],
    [VECTOR_LINE, 63.34, 86.65, 62.31, 83.83]
  ]
  children = [
    @() {
      size = flex()
      rendObj = ROBJ_VECTOR_CANVAS
      color = mfdWhite
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * mfdLineWidth * 0.7
      commands = [
        [VECTOR_POLY, 50, 90, 48.5, 93, 51.5, 93]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = clamp(Roll.get(), -45, 45)
        }
      }
    }
  ]
}

let ilsMode = @() {
  watch = [isAAMMode, CCIPMode, BombingMode, ShellCnt, CurWeaponName, isDGFTMode]
  size = SIZE_TO_CONTENT
  rendObj = ROBJ_TEXT
  pos = [pw(10), ph(82)]
  color = mfdWhite
  fontsize = 20
  font = Fonts.hud
  text = isDGFTMode.get() ? "DGFT" : isAAMMode.get() ? string.format("%d SRM", ShellCnt.get()) : (BombingMode.get() ? "CCRP" : (CannonMode.get() ? "STRF" : (CCIPMode.get() ? "CCIP" : "EEGS")))
}

let TargetDist = Computed(@() ((CCIPMode.get() || BombingMode.get() ? DistToTarget.get() : (RadarTargetDist.get() > 0 ? RadarTargetDist.get() : -1)) * metrToFeet * 0.1).tointeger())
let dist = @() {
  watch = [TargetDist, isAAMMode]
  size = SIZE_TO_CONTENT
  pos = [pw(90), ph(92)]
  rendObj = ROBJ_TEXT
  color = mfdWhite
  fontsize = 20
  font = Fonts.hud
  text = isAAMMode.get() && TargetDist.get() <= 0 ? "XXX" : string.format("F%03d.%d", TargetDist.get() <= 607 ? (TargetDist.get() / 10) : (TargetDist.get() * 10.0 * feetToNavMile), TargetDist.get() <= 607 ? (TargetDist.get() % 10) : (TargetDist.get() * feetToNavMile * 100.0 % 10.0))
}

let HasRadarTarget = Computed(@() RadarTargetDist.get() > 0)
let OrientationSector = Computed(@() cvt(Tangage.get(), -45.0, 45.0, 160, 20).tointeger())
let orientation = @() {
  watch = [HasRadarTarget, CCIPMode, BombingMode]
  size = flex()
  children = HasRadarTarget.get() && !CCIPMode.get() && !BombingMode.get() ? [
    @() {
      watch = OrientationSector
      rendObj = ROBJ_VECTOR_CANVAS
      size = const [pw(20), ph(20)]
      pos = [pw(50), ph(50)]
      color = mfdWhite
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * mfdLineWidth
      commands = [
        [VECTOR_SECTOR, 0, 0, 100, 100, 90 - OrientationSector.get(), 90 + OrientationSector.get()],
        [VECTOR_LINE, 100 * cos(degToRad(90 - OrientationSector.get())), 100 * sin(degToRad(90 - OrientationSector.get())),
         110 * cos(degToRad(90 - OrientationSector.get())), 110 * sin(degToRad(90 - OrientationSector.get()))],
        [VECTOR_LINE, 100 * cos(degToRad(90 + OrientationSector.get())), 100 * sin(degToRad(90 + OrientationSector.get())),
         110 * cos(degToRad(90 + OrientationSector.get())), 110 * sin(degToRad(90 + OrientationSector.get()))]
      ]
      behavior = Behaviors.RtPropUpdate
      update = @() {
        transform = {
          rotate = -Roll.get()
          pivot = [0, 0]
        }
      }
    }
  ] : null
}


let verticalPitchScale = 0.05

function angleTxt(num, isLeft, invVPlace = 1, x = 0, y = 0) {
  return @() {
    pos = [x, y]
    rendObj = ROBJ_TEXT
    vplace = (num * invVPlace) < 0 ? ALIGN_BOTTOM : ALIGN_TOP
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    color = mfdWhite
    fontsize = 20
    font = Fonts.hud
    text = abs(num).tostring()
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  let lineAngle =  num > 0 ? 0 : degToRad(min(20, newNum / 4))
  let offset = num > 0 ? 0 : (30.0 * sin(degToRad(min(20, newNum / 4))))
  return {
    size = const [pw(60), ph(50)]
    pos = [pw(20), 0]
    flow = FLOW_VERTICAL
    children = num == 0 ? [] :
    [
      @() {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * mfdLineWidth
        color = mfdWhite
        commands = [
          [VECTOR_LINE, 30, 10 * sign + offset, 30, offset],
          [VECTOR_LINE, 0, 0, num > 0 ? 30 : 5, sin(lineAngle) * (num > 0 ? 30 : 5) ],
          (num < 0 ? [VECTOR_LINE, 10, sin(lineAngle) * 10, 17, sin(lineAngle) * 17 ] : []),
          (num < 0 ? [VECTOR_LINE, 23, sin(lineAngle) * 23, 30, sin(lineAngle) * 30 ] : []),
          [VECTOR_LINE, 70, 10 * sign + offset, 70, offset],
          [VECTOR_LINE, 100, 0, num > 0 ? 70 : 95, sin(lineAngle) * (num > 0 ? 30 : 5)],
          (num < 0 ? [VECTOR_LINE, 90, sin(lineAngle) * 10, 83, sin(lineAngle) * 17] : []),
          (num < 0 ? [VECTOR_LINE, 77, sin(lineAngle) * 23, 70, sin(lineAngle) * 30] : [])
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, 1, pw(-15)), angleTxt(newNum, false, 1, pw(15))] : null
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
    size = [width * 0.6, height * 0.5]
    pos = [width * -0.3, 0]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get()) * verticalPitchScale]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get()) * verticalPitchScale * 2.0]
      }
    }
  }
}

function pitchHorizon(width, height){
  let groundColor = Color(143, 62, 0)
  let skyColor = Color(0, 13, 201)

  let minVisibleFraction = 0.01

  let horizonX = Watched(clamp(floor(TvvMark[0] / width * 100.0) / 100.0 - 0.5, minVisibleFraction, 1.0 - minVisibleFraction))
  let horizonY = Computed(@() clamp(floor((TvvMark[1] / height + Tangage.get() * verticalPitchScale) * 100.0) / 100.0 - 0.5,
    minVisibleFraction, 1.0 - minVisibleFraction))
  return @() {
    size = [width, height]
    pos = [0, 0]
    behavior = Behaviors.RtPropUpdate
    update = function() {
      horizonX.set(clamp(floor(TvvMark[0] / width * 100.0) / 100.0 - 0.5, minVisibleFraction, 1.0 - minVisibleFraction))
      return {
        transform = {
          rotate = -Roll.get()
          pivot = [horizonX.get(), horizonY.get()]
        }
      }
    }
    children = [
      @() {
        watch = [horizonX, horizonY]
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = Color(255, 255, 255)
        fillColor = skyColor
        commands = [[VECTOR_SECTOR, horizonX.get() * 100.0, horizonY.get() * 100.0, 150, 150, -180, 0]]
      }
      @() {
        watch = [horizonX, horizonY]
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = Color(255, 255, 255)
        fillColor = groundColor
        commands = [[VECTOR_SECTOR, horizonX.get() * 100.0, horizonY.get() * 100.0, 150, 150, 0, 180]]
      }
      @() {
        watch = [horizonY]
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS
        color = mfdWhite
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * mfdLineWidth
        commands = [[VECTOR_LINE, -500, horizonY.get() * 100.0 - 50.0, 500, horizonY.get() * 100.0 - 50.0]]
      }

    ]
  }
}

function TvvLinked(width, height) {
  let pitchElem = pitch(width, height, generatePitchLine)
  let hasPitchElem = Computed(@() !HasRadarTarget.get() || isAAMMode.get() || CCIPMode.get() || BombingMode.get())
  return @() {
    watch = [hasPitchElem, isDGFTMode]
    size = flex()
    children = !isDGFTMode.get() ? [
      (hasPitchElem.get() ? pitchElem : null)
      @() {
        rendObj = ROBJ_VECTOR_CANVAS
        size = const [pw(6), ph(6)]
        color = mfdWhite
        fillColor = Color(0, 0, 0, 0)
        lineWidth = baseLineWidth * mfdLineWidth
        commands = [
          [VECTOR_LINE, -100, -40, -50, 50],
          [VECTOR_LINE, -50, 50, 0, -10],
          [VECTOR_LINE, 0, -10, 50, 50],
          [VECTOR_LINE, 50, 50, 100, -40],
          [VECTOR_LINE, -100, -40, -160, -40],
          [VECTOR_LINE, 100, -40, 140, -40]
        ]
      }
    ] : null
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TvvMark[0], TvvMark[1]]
      }
    }
  }
}

let baroLabel = {
  size = const [pw(4), ph(20)]
  pos = [pw(5), ph(65)]
  children = [
    @() {
      size = const [pw(100), ph(20)]
      pos = [-15, ph(15)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = mfdWhite
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * mfdLineWidth
      commands = [
        [VECTOR_LINE, 50, 100, 50, 10],
        [VECTOR_LINE, 10, 50, 50, 10],
        [VECTOR_LINE, 90, 50, 50, 10]
      ]
    },
    {
      size = const [pw(100), ph(60)]
      pos = [-15, ph(50)]
      flow = FLOW_VERTICAL
      children = ["B", "A", "R", "O"].map(@(ch) @() {
        size = SIZE_TO_CONTENT
        rendObj = ROBJ_TEXT
        color = mfdWhite
        fontsize = 20
        font = Fonts.hud
        hplace = ALIGN_CENTER
        text = ch
      })
    },
    @() {
      size = const [pw(100), ph(20)]
      pos = [-15, ph(140)]
      rendObj = ROBJ_VECTOR_CANVAS
      color = mfdWhite
      fillColor = Color(0, 0, 0, 0)
      lineWidth = baseLineWidth * mfdLineWidth
      commands = [
        [VECTOR_LINE, 50, 0, 50, 90],
        [VECTOR_LINE, 10, 50, 50, 90],
        [VECTOR_LINE, 90, 50, 50, 90]
      ]
    }
  ]
}

function ElbitMfd(pos, size) {
  let width = size[0]
  let height = size[1]
  return {
    pos
    size = [width, height]
    clipChildren  = true
    children = [
      pitchHorizon(width, height),
      {
        size = flex()
        pos = [pw(-50), ph(-50)]
        children = [
          TvvLinked(width, height),
        ]
      },
      speedWrap(width, height, generateSpdMark),
      altWrap(width, height, generateAltMark),
      speedVal,
      AltVal,
      overload,
      maxOverload,
      mach,
      radioAlt,
      adlMarker,
      roll,
      ilsMode,
      dist,
      baroLabel,
      @() {
        rendObj = ROBJ_SOLID
        size = [baseLineWidth * mfdLineWidth, ph(5)]
        pos = [pw(50), 0]
        color = mfdWhite
      },
      orientation,
    ]
  }
}

return ElbitMfd

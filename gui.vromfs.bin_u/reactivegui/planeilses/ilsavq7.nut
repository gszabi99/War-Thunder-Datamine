from "%rGui/globals/ui_library.nut" import *

let { Speed, Altitude, ClimbSpeed, Tangage, Roll, Aoa } = require("%rGui/planeState/planeFlyState.nut");
let { compassWrap, generateCompassMark } = require("%rGui/planeIlses/ilsCompasses.nut")
let { angleTxt, yawIndicator, cancelBombing,
      lowerSolutionCue, bombFallingLine, aimMark } = require("%rGui/planeIlses/commonElements.nut")
let { IlsColor, TargetPos, DistToSafety, IlsLineScale, BombingMode, RocketMode, CannonMode,
      BombCCIPMode, IlsAtgmTrackerVisible, IlsAtgmTargetPos, IlsAtgmLocked } = require("%rGui/planeState/planeToolsState.nut")
let { mpsToKnots, metrToFeet, mpsToFpm, baseLineWidth } = require("%rGui/planeIlses/ilsConstants.nut")
let { floor } = require("%sqstd/math.nut")
let { AdlPoint } = require("%rGui/planeState/planeWeaponState.nut")

function flyDirectionAVQ7(width, height) {
  return @() {
    watch = IlsColor
    size = [width * 0.1, height * 0.1]
    pos = [width * 0.5, height * 0.3]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    fillColor = Color(0, 0, 0, 0)
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_ELLIPSE, 0, 0, 20, 20],
      [VECTOR_LINE, -50, 0, -20, 0],
      [VECTOR_LINE, 20, 0, 50, 0]
    ]
  }
}

function speedometer(width, height) {
  let grid = @() {
    watch = IlsColor
    pos = [width * 0.5, height * 0.5]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = baseLineWidth * IlsLineScale.get()
    color = IlsColor.get()
    commands = [
      [VECTOR_LINE, -35, -20, -33, -20],
      [VECTOR_LINE, -35, -16, -35, -16],
      [VECTOR_LINE, -35, -12, -35, -12],
      [VECTOR_LINE, -35, -8, -35, -8],
      [VECTOR_LINE, -35, -4, -35, -4],
      [VECTOR_LINE, -35, 0, -33, 0],
      [VECTOR_LINE, -35, 4, -35, 4],
      [VECTOR_LINE, -35, 8, -35, 8],
      [VECTOR_LINE, -35, 12, -35, 12],
      [VECTOR_LINE, -35, 16, -35, 16],
      [VECTOR_LINE, -35, 20, -33, 20]
    ]
  }

  let hundreds = @() {
    watch = [Speed, IlsColor]
    rendObj = ROBJ_TEXT
    pos = [width * 0.15, height * 0.72]
    size = flex()
    color = IlsColor.get()
    fontSize = 70
    font = Fonts.usa_ils
    text = (floor((Speed.get() * mpsToKnots) / 100)).tostring()
  }

  let speedMarkLen = Computed(@() (height * ((Speed.get() * mpsToKnots) % 100 / 100) * 0.4).tointeger())
  let speedColumn = @() {
    watch = [speedMarkLen, IlsColor]
    pos = [width * 0.17, height * 0.7 - speedMarkLen.get()]
    size = [baseLineWidth * IlsLineScale.get(), speedMarkLen.get()]
    rendObj = ROBJ_SOLID
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
  }

  return {
    size = [width, height]
    children = [ grid, hundreds, speedColumn ]
  }
}

let altmeterGrid = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = flex()
  lineWidth = baseLineWidth * IlsLineScale.get()
  color = IlsColor.get()
  commands = [
    [VECTOR_LINE, 0, 0, 100, 0],
    [VECTOR_LINE, 40, 10, 40, 10],
    [VECTOR_LINE, 40, 20, 40, 20],
    [VECTOR_LINE, 60, 25, 100, 25],
    [VECTOR_LINE, 40, 30, 40, 30],
    [VECTOR_LINE, 40, 40, 40, 40],
    [VECTOR_LINE, 0, 50, 100, 50],
    [VECTOR_LINE, 40, 60, 40, 60],
    [VECTOR_LINE, 40, 70, 40, 70],
    [VECTOR_LINE, 60, 75, 100, 75],
    [VECTOR_LINE, 40, 80, 40, 80],
    [VECTOR_LINE, 40, 90, 40, 90],
    [VECTOR_LINE, 0, 100, 100, 100]
  ]
}

let altThousand = Computed(@() (floor((Altitude.get() * metrToFeet) / 1000)).tointeger())
let thousands = @() {
  watch = [altThousand, IlsColor]
  rendObj = ROBJ_TEXT
  color = IlsColor.get()
  fontSize = 70
  font = Fonts.usa_ils
  text = altThousand.get().tostring()
}

let altMarkLen = Computed(@() ((Altitude.get() * metrToFeet) % 1000 / 10).tointeger())
let altColumn = @() {
  watch = [altMarkLen, IlsColor]
  pos = [0, ph(100 - altMarkLen.get())]
  hplace = ALIGN_RIGHT
  size = [baseLineWidth * IlsLineScale.get(), ph(altMarkLen.get())]
  rendObj = ROBJ_SOLID
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
}

let climbMarkPos = Computed(@() (clamp(ClimbSpeed.get() * mpsToFpm, -999, 999) % 1000 / 10).tointeger())
let climbMark = @() {
  watch = [climbMarkPos, IlsColor]
  pos = [0, ph(50 - climbMarkPos.get() * 0.5)]
  size = hdpx(30)
  rendObj = ROBJ_VECTOR_CANVAS
  color = IlsColor.get()
  lineWidth = baseLineWidth * 0.5 * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, 100, 50, 100, -50],
    [VECTOR_LINE, 100, 50, 0, 0],
    [VECTOR_LINE, 100, -50, 0, 0]
  ]
}

function altmeter(width, height) {
  return {
    size = [width * 0.08, height * 0.5]
    pos = [width * 0.8, height * 0.3]
    flow = FLOW_VERTICAL
    children = [
      {
        size = flex()
        flow = FLOW_HORIZONTAL
        children = [altColumn, altmeterGrid, climbMark]
      },
      {
        size = const [pw(100), ph(20)]
        flow = FLOW_VERTICAL
        padding = const [10, 0]
        children = [
          @() {
            size = flex()
            watch = IlsColor
            rendObj = ROBJ_VECTOR_CANVAS
            lineWidth = baseLineWidth * IlsLineScale.get()
            color = IlsColor.get()
            commands = [
              [VECTOR_LINE, 0, 100, 100, 100],
              [VECTOR_LINE, 100, 100, 100, 50]
            ]
            children = [thousands]
          }
        ]
      }
    ]
  }
}

function generatePitchLine(num) {
  let sign = num > 0 ? 1 : -1
  let newNum = num >= 0 ? num : (num - 5)
  return {
    size = const [pw(100), ph(100)]
    flow = FLOW_VERTICAL
    children = num == 0 ? [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = const [0, 10]
        commands = [
          [VECTOR_LINE, 0, 0, 34, 0],
          [VECTOR_LINE, 66, 0, 100, 0]
        ]
        children = [angleTxt(-5, true, Fonts.usa_ils), angleTxt(-5, false, Fonts.usa_ils)]
      }
    ] :
    [
      @() {
        size = flex()
        watch = IlsColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * IlsLineScale.get()
        color = IlsColor.get()
        padding = 10
        commands = [
          [VECTOR_LINE, 0, 5 * sign, 0, 0],
          [VECTOR_LINE, 0, 0, 7, 0],
          [VECTOR_LINE, 15, 0, 21, 0],
          [VECTOR_LINE, 28, 0, 34, 0],
          [VECTOR_LINE, 100, 5 * sign, 100, 0],
          [VECTOR_LINE, 100, 0, 93, 0],
          [VECTOR_LINE, 85, 0, 79, 0],
          [VECTOR_LINE, 72, 0, 66, 0]
        ]
        children = newNum <= 90 ? [angleTxt(newNum, true, Fonts.usa_ils), angleTxt(newNum, false, Fonts.usa_ils)] : null
      }
    ]
  }
}

let AoaForTang = Computed(@() Speed.get() > 30.0 ? Aoa.get() : 0.0)
function pitch(width, height) {
  const step = 5.0
  let children = []

  for (local i = 90.0 / step; i >= -90.0 / step; --i) {
    let num = (i * step).tointeger()

    children.append(generatePitchLine(num))
  }

  return {
    size = [width * 0.4, height * 0.5]
    pos = [width * 0.3, height * 0.3]
    flow = FLOW_VERTICAL
    children = children
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [0, -height * (90.0 - Tangage.get() + AoaForTang.get()) * 0.1]
        rotate = -Roll.get()
        pivot = [0.5, (90.0 - Tangage.get() + AoaForTang.get()) * 0.2]
      }
    }
  }
}

let maverickAimMark = @() {
  watch = [IlsAtgmLocked, IlsColor]
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(2), ph(2)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
  commands = [
    [VECTOR_LINE, -100, -100, 100, -100],
    [VECTOR_LINE, -100, -100, -100, 100],
    [VECTOR_LINE, 100, 100, -100, 100],
    [VECTOR_LINE, 100, 100, 100, -100],
    (!IlsAtgmLocked.get() ? [VECTOR_LINE, 0, 0, 0, 0] : [VECTOR_LINE, -90, -90, 90, 90]),
    (IlsAtgmLocked.get() ? [VECTOR_LINE, -90, 90, 90, -90] : [])
  ]
  behavior = Behaviors.RtPropUpdate
  update = @() {
    transform = {
      translate = [IlsAtgmTargetPos[0], IlsAtgmTargetPos[1]]
    }
  }
}

let maverickAim = @() {
  watch = IlsAtgmTrackerVisible
  size = flex()
  children = IlsAtgmTrackerVisible.get() ? [maverickAimMark] : []
}

let adlMarker = @() {
  watch = IlsColor
  rendObj = ROBJ_VECTOR_CANVAS
  size = const [pw(3), ph(3)]
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
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

function basicInformation(width, height) {
  let toGroundMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get() || BombingMode.get())
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = SIZE_TO_CONTENT
    children = [
      speedometer(width, height),
      altmeter(width, height),
      flyDirectionAVQ7(width, height),
      pitch(width, height),
      aimMark,
      maverickAim,
      @(){
        watch = toGroundMode
        size = flex()
        children = !toGroundMode.get() ? compassWrap(width, height, 0.1, generateCompassMark) : null
      }
    ]
  }
}

let pullupAnticipPos = Computed(@() clamp(0.35 + DistToSafety.get() * 0.001, 0.1, 0.5))
function pullupAnticipation(height) {
  return @() {
    watch = [IlsColor, pullupAnticipPos]
    size = const [pw(10), ph(5)]
    pos = [pw(10), height * pullupAnticipPos.get()]
    rendObj = ROBJ_VECTOR_CANVAS
    color = IlsColor.get()
    lineWidth = baseLineWidth * IlsLineScale.get()
    commands = [
      [VECTOR_LINE, -100, 100, 100, 100],
      [VECTOR_LINE, -100, 100, -100, 0],
      [VECTOR_LINE, 100, 100, 100, 0]
    ]
  }
}

let solutionCue = @() {
  watch = IlsColor
  size = [pw(100), baseLineWidth * IlsLineScale.get()]
  rendObj = ROBJ_SOLID
  color = IlsColor.get()
  lineWidth = baseLineWidth * IlsLineScale.get()
}

function rotatedBombReleaseReticle(width, height) {
  return {
    size = flex()
    children = [
      pullupAnticipation(height),
      lowerSolutionCue(height, 5),
      {
        size = const [pw(20), flex()]
        flow = FLOW_VERTICAL
        halign = ALIGN_CENTER
        children = [solutionCue, bombFallingLine()]
      }
    ]
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        translate = [TargetPos.get()[0] - width * 0.1, height * 0.1]
        rotate = -Roll.get()
        pivot = [0.1, TargetPos.get()[1] / height - 0.1]
      }
    }
  }
}

function CCIP(width, height) {
  let CCIPMode = Computed(@() RocketMode.get() || CannonMode.get() || BombCCIPMode.get())
  return @(){
    watch = CCIPMode
    size = [width, height]
    children = CCIPMode.get() ? [
      compassWrap(width, height, 0.85, generateCompassMark),
      cancelBombing(20, 20),
      yawIndicator
    ] : null
  }
}

function bombingMode(width, height) {
  return @(){
    watch = BombingMode
    size = [width, height]
    children = BombingMode.get() ? [
      rotatedBombReleaseReticle(width, height),
      compassWrap(width, height, 0.85, generateCompassMark),
      cancelBombing(20, 20),
      yawIndicator
    ] : null
  }
}

function ilsAVQ7(width, height, have_bombing_mode, have_ccip_mode) {
  return {
    size = [width, height]
    children = [
      basicInformation(width, height),
      (have_bombing_mode ? bombingMode(width, height) : null),
      (have_ccip_mode ? CCIP(width, height) : adlMarker)
    ]
  }
}

return {
  ilsAVQ7
  AVQ7CCRP = rotatedBombReleaseReticle
}
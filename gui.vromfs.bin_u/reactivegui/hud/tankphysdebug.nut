from "%rGui/globals/ui_library.nut" import *
let { Visible, Rpm, Omega, MaxRpm, CurrentGear, NeutralGearIdx, GearCount,
  GearMaxSpeed, GearRatio, Speed, DDGearRatio, LTrackSpeed, RTrackSpeed,
  HillClimbKx, HillClimbKy, LeftTrackSlide, RightTrackSlide, WorldForceVal,
  TrackForceVal, WorldForceDirUp, TrackForceDirUp, WorldForceDirForward,
  TrackForceDirForward, Throttle, LeftBrake, RightBrake, ClutchLeft, ClutchRight,
  Steering, TrackFricFront, TrackFricFrontSlide, TrackFricSideX, TrackFricSideY,
  TrackFricSideZ, TrackFricSideW, TrackFricSideProjLerp, TorqArray, MaxTorq, MinRpm } = require("tankDebugState.nut")
let string = require("string")
let { cos, sin } = require("%sqstd/math.nut")
let { fabs } = require("math")

let baseColor = Color(0, 255, 0, 200)
let warningColor = Color(255, 255, 0, 200)
let critColor = Color(255, 0, 0, 200)
let baseFontSize = 20

let iconWidth = 80
let iconHeight = 80
let engineIcon = Picture($"!ui/gameuiskin#engine_state_indicator.svg:{iconWidth}:{iconHeight}")
let transmissionIcon = Picture($"!ui/gameuiskin#new_tank_transmission.avif:{iconWidth}:{iconHeight}")
let trackIcon = Picture($"!ui/gameuiskin#track_state_indicator.svg:{iconWidth}:{iconHeight}")

let engineRpmVal = @() {
  watch = [Rpm, MaxRpm]
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = Rpm.value > MaxRpm.value * 0.9 ? critColor : Rpm.value > MaxRpm.value * 0.8 ? warningColor : baseColor
  fontSize = baseFontSize
  text = Rpm.value.tostring()
}

let engineRpm = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    {
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "RPM"
    }
    engineRpmVal
  ]
}

let engineOmegaVal = @() {
  watch = Omega
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = Omega.value.tostring()
}

let engineOmega = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Omega"
    }
    engineOmegaVal
  ]
}

let engineMaxRpmVal = @() {
  watch = MaxRpm
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = MaxRpm.value.tostring()
}

let engineMaxRpm = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "MaxRPM"
    }
    engineMaxRpmVal
  ]
}

let speedVal = @() {
  watch = Speed
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = string.format("%.1f km/h", Speed.value)
}

let speed = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Speed"
    }
    speedVal
  ]
}

let engine = {
  size = const [pw(10), ph(20)]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    {
      size = [iconWidth, iconHeight]
      rendObj = ROBJ_IMAGE
      image = engineIcon
      color = baseColor
    }
    engineRpm
    engineMaxRpm
    engineOmega
    speed
  ]
}

let transCurGearVal = @() {
  watch = CurrentGear
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize * 1.5
  text = NeutralGearIdx.value == CurrentGear.value ? "N" : CurrentGear.value < NeutralGearIdx.value ? string.format("R%d", NeutralGearIdx.value - CurrentGear.value) : (CurrentGear.value - NeutralGearIdx.value).tostring()
}

let transCurretGear = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Gear"
      valign = ALIGN_BOTTOM
    }
    transCurGearVal
  ]
}

function getTransmissionTable() {
  let childrens = []
  for (local i = 0; i < GearCount.value; ++i) {
    childrens.append({
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      children = [
        {
          size = const [pw(20), SIZE_TO_CONTENT]
          rendObj = ROBJ_TEXT
          color = baseColor
          fontSize = baseFontSize
          text = NeutralGearIdx.value == i ? "N" : i < NeutralGearIdx.value ? string.format("R%d", NeutralGearIdx.value - i) : (i - NeutralGearIdx.value).tostring()
        }
        {
          size = const [pw(30), SIZE_TO_CONTENT]
          halign = ALIGN_RIGHT
          rendObj = ROBJ_TEXT
          color = baseColor
          fontSize = baseFontSize
          text = string.format("%.2f", GearRatio.value[i])
        }
        {
          size = const [pw(40), SIZE_TO_CONTENT]
          halign = ALIGN_RIGHT
          rendObj = ROBJ_TEXT
          color = baseColor
          fontSize = baseFontSize
          text = GearMaxSpeed.value[i].tostring()
        }
      ]
    })
  }
  return childrens
}

let doubleDiffRatioVal = @() {
  watch = DDGearRatio
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = DDGearRatio.value.tostring()
}

let doubleDiffRatio = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "DoubleDiffRatio"
    }
    doubleDiffRatioVal
  ]
}

let transmission = {
  size = const [pw(15), ph(20)]
  pos = [0, ph(20)]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    {
      size = [iconWidth, iconHeight]
      rendObj = ROBJ_IMAGE
      image = transmissionIcon
      
    }
    transCurretGear
    {
      size = FLEX_H
      flow = FLOW_HORIZONTAL
      children = [
        {
          size = const [pw(20), SIZE_TO_CONTENT]
          rendObj = ROBJ_TEXT
          color = baseColor
          fontSize = baseFontSize
          text = "Gear:"
        }
        {
          size = const [pw(30), SIZE_TO_CONTENT]
          halign = ALIGN_RIGHT
          rendObj = ROBJ_TEXT
          color = baseColor
          fontSize = baseFontSize
          text = "Ratio:"
        }
        {
          size = const [pw(40), SIZE_TO_CONTENT]
          halign = ALIGN_RIGHT
          rendObj = ROBJ_TEXT
          color = baseColor
          fontSize = baseFontSize
          text = "MaxSpd:"
        }
      ]
    }
    @(){
      watch = GearCount
      size = FLEX_H
      flow = FLOW_VERTICAL
      children = getTransmissionTable()
    }
    doubleDiffRatio
  ]
}


let trackSpeedVal = @(watched_val) function() {
  return {
    watch = watched_val
    size = FLEX_H
    halign = ALIGN_RIGHT
    rendObj = ROBJ_TEXT
    color = baseColor
    fontSize = baseFontSize
    text = string.format("%.2f", watched_val.value)
  }
}

let trackSpeed = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "TrackSpd:"
      valign = ALIGN_BOTTOM
    }
    trackSpeedVal(LTrackSpeed)
    trackSpeedVal(RTrackSpeed)
  ]
}

let HillClimbVal = @() {
  watch = [HillClimbKx, HillClimbKy]
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = string.format("F: %.2f  -  L: %.2f", HillClimbKx.value, HillClimbKy.value)
}

let hillClimbK = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "HillClimbK:"
      valign = ALIGN_BOTTOM
    }
    HillClimbVal
  ]
}

let trackSideFricVal = @() {
  watch = [TrackFricSideX, TrackFricSideY, TrackFricSideZ, TrackFricSideW]
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = string.format("%.1f  %.1f  %.1f  %.1f", TrackFricSideX.value, TrackFricSideY.value, TrackFricSideZ.value, TrackFricSideW.value)
}

let trackSideFric = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "fricSideRot:"
      valign = ALIGN_BOTTOM
    }
    trackSideFricVal
  ]
}

let trackFrontalFricVal = @() {
  watch = [TrackFricFront, TrackFricFrontSlide]
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = string.format("Norm:%.1f slide:%.1f", TrackFricFront.value, TrackFricFrontSlide.value)
}

let trackFrontalFric = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "fricFrontal:"
      valign = ALIGN_BOTTOM
    }
    trackFrontalFricVal
  ]
}

let sideProjLerpVal = @() {
  watch = TrackFricSideProjLerp
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = string.format("%.2f", TrackFricSideProjLerp.value)
}

let sideProjLerp = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "sideFrictionProjLerp:"
      valign = ALIGN_BOTTOM
    }
    sideProjLerpVal
  ]
}

let slidingVal = @(watched_val) function() {
  return {
    size = const [pw(28), ph(100)]
    children = [
      @(){
        pos = [pw(15), 0]
        size = const [pw(70), ph(100)]
        watch = watched_val
        rendObj = ROBJ_SOLID
        color = watched_val.value ? critColor : baseColor
      }
      @(){
          watch = watched_val
          size = FLEX_H
          halign = ALIGN_CENTER
          rendObj = ROBJ_TEXT
          color = watched_val.value ? Color(255, 255, 255) : Color(0, 0, 0)
          fontSize = baseFontSize
          text = watched_val.value.tostring()
        }
    ]
  }
}

let sliding = {
  size = const [flex(), ph(10)]
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = const [pw(47), flex()]
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Sliding:"
      valign = ALIGN_BOTTOM
    }
    slidingVal(LeftTrackSlide)
    slidingVal(RightTrackSlide)
  ]
}


let worldForceVal = @() {
  watch = WorldForceVal
  size = FLEX_H
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = baseColor
  fontSize = baseFontSize
  text = string.format("%d", WorldForceVal.value)
}

let worldForce = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "World Force:"
      valign = ALIGN_BOTTOM
    }
    worldForceVal
  ]
}

let fricForceVal = @() {
  watch = [TrackForceVal, WorldForceVal]
  size = SIZE_TO_CONTENT
  halign = ALIGN_RIGHT
  rendObj = ROBJ_TEXT
  color = TrackForceVal.value > WorldForceVal.value ? baseColor : critColor
  fontSize = baseFontSize
  text = string.format("%d", TrackForceVal.value)
}

let frictionForce = {
  size = FLEX_H
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Friction(+Engine) Force:"
      valign = ALIGN_BOTTOM
    }
    fricForceVal
  ]
}

let tracks = {
  size = const [pw(18), ph(20)]
  pos = [pw(80), 0]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  children = [
    {
      size = [iconWidth, iconHeight]
      rendObj = ROBJ_IMAGE
      image = trackIcon
      color = baseColor
    }
    trackSpeed
    hillClimbK
    trackFrontalFric
    trackSideFric
    sideProjLerp
    sliding
    worldForce
    frictionForce
  ]
}

let forceOrientUp = @(){
  watch = [WorldForceDirUp, TrackForceDirUp]
  size = const [pw(7.5), ph(10)]
  pos = [pw(92.5), ph(40)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = warningColor
  commands = [
    [VECTOR_LINE, sin(TrackForceDirUp.value) * 20, -cos(TrackForceDirUp.value) * 20, sin(TrackForceDirUp.value) * 100, -cos(TrackForceDirUp.value) * 100],
    [VECTOR_COLOR, critColor],
    [VECTOR_LINE, sin(WorldForceDirUp.value) * 20, -cos(WorldForceDirUp.value) * 20, sin(WorldForceDirUp.value) * 100, -cos(WorldForceDirUp.value) * 100]
  ]
  children = [
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(-120), ph(-120)]
      color = baseColor
      fontSize = baseFontSize
      text = "view from above:"
    }
    {
      size = const [pw(10), ph(20)]
      rendObj = ROBJ_SOLID
      pos = [pw(-5), ph(-10)]
      color = baseColor
    }
  ]
}

let forceOrientFwd = @(){
  watch = [WorldForceDirForward, TrackForceDirForward]
  size = const [pw(7.5), ph(10)]
  pos = [pw(92.5), ph(60)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = warningColor
  commands = [
    [VECTOR_LINE, sin(TrackForceDirForward.value) * 20, -cos(TrackForceDirForward.value) * 20, sin(TrackForceDirForward.value) * 100, -cos(TrackForceDirForward.value) * 100],
    [VECTOR_COLOR, critColor],
    [VECTOR_LINE, sin(WorldForceDirForward.value) * 20, -cos(WorldForceDirForward.value) * 20, sin(WorldForceDirForward.value) * 100, -cos(WorldForceDirForward.value) * 100]
  ]
  children = [
    {
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [pw(-100), ph(-120)]
      color = baseColor
      fontSize = baseFontSize
      text = "Front view:"
    }
    {
      size = const [pw(30), ph(20)]
      rendObj = ROBJ_SOLID
      pos = [pw(-15), ph(-10)]
      color = baseColor
    }
  ]
}

function axisVal(axis, main_color) {
  return {
    size = const [pw(50), ph(100)]
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        color = main_color
        size = flex()
        fillColor = Color(0, 0, 0, 0)
        commands = [
          [VECTOR_RECTANGLE, 0, 0, 100, 100]
        ]
      }
      @(){
        watch = axis
        rendObj = ROBJ_SOLID
        color = main_color
        size = [pw(axis.value * 100.0), flex()]
      }
      @(){
        watch = axis
        size = FLEX_H
        halign = ALIGN_CENTER
        rendObj = ROBJ_TEXT
        color = axis.value > 0.7 ? Color(0, 0, 0) : Color(255, 255, 255)
        fontSize = baseFontSize
        text = string.format("%.2f", axis.value * 100.0)
      }
    ]
  }
}

let throttle = {
  size = const [pw(50), ph(12)]
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Throttle:"
    }
    axisVal(Throttle, baseColor)
  ]
}

let leftBrake = {
  size = const [pw(50), ph(12)]
  flow = FLOW_HORIZONTAL
  padding = 0
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Left Brake:"
    }
    axisVal(LeftBrake, critColor)
  ]
}

let rightBrake = {
  size = const [pw(50), ph(12)]
  flow = FLOW_HORIZONTAL
  padding = 0
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Right Brake:"
    }
    axisVal(RightBrake, critColor)
  ]
}

let leftClutch = {
  size = const [pw(50), ph(12)]
  flow = FLOW_HORIZONTAL
  padding = 0
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Left Clutch:"
    }
    axisVal(ClutchLeft, warningColor)
  ]
}

let rightClutch = {
  size = const [pw(50), ph(12)]
  flow = FLOW_HORIZONTAL
  padding = 0
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Right Clutch:"
    }
    axisVal(ClutchRight, warningColor)
  ]
}

let SteerLinePos = Computed(@() 50.0 + min(0, -Steering.value) * 50.0)
let steeringVal = {
  size = const [pw(50), ph(100)]
  children = [
    {
      rendObj = ROBJ_VECTOR_CANVAS
      color = baseColor
      size = flex()
      fillColor = Color(0, 0, 0, 0)
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 100, 100]
      ]
    }
    @(){
      watch = Steering
      rendObj = ROBJ_SOLID
      color = baseColor
      pos = [pw(SteerLinePos.value), 0]
      size = [pw(fabs(Steering.value) * 50.0), flex()]
    }
    @(){
      watch = Steering
      size = FLEX_H
      halign = ALIGN_CENTER
      rendObj = ROBJ_TEXT
      color = Color(255, 255, 255)
      fontSize = baseFontSize
      text = string.format("%.2f", Steering.value)
    }
  ]
}

let steering = {
  size = const [pw(50), ph(12)]
  flow = FLOW_HORIZONTAL
  children = [
    @(){
      size = flex()
      rendObj = ROBJ_TEXT
      color = baseColor
      fontSize = baseFontSize
      text = "Steering:"
    }
    steeringVal
  ]
}

let axis = {
  size = const [pw(30), ph(20)]
  pos = [pw(35), ph(75)]
  flow = FLOW_VERTICAL
  halign = ALIGN_CENTER
  gap = 5
  children = [
    throttle
    steering
    leftBrake
    rightBrake
    leftClutch
    rightClutch
  ]
}

function getTorqGraphCommands() {
  let commands = [
    [VECTOR_LINE, 0, -10, 0, 100],
    [VECTOR_LINE, -2, 0, 0, 0],
    [VECTOR_LINE, 0, 100, 110, 100],
    [VECTOR_LINE, 0, -10, -2, -5],
    [VECTOR_LINE, 0, -10, 2, -5],
    [VECTOR_LINE, 110, 100, 105, 98],
    [VECTOR_LINE, 110, 100, 105, 102]
  ]
  if (MaxTorq.value == 0.0)
    return null
  for (local i = 0; i < TorqArray.value.len() - 1; ++i) {
    let t1 = (1.0 - TorqArray.value[i] / MaxTorq.value) * 100.0
    let t2 = (1.0 - TorqArray.value[i + 1] / MaxTorq.value) * 100.0
    let r1 = i * 100.0 / TorqArray.value.len()
    let r2 = (i+1) * 100.0 / TorqArray.value.len()
    let rRpm = (Rpm.value - MinRpm.value) / (MaxRpm.value - MinRpm.value) * 100.0
    commands.append([VECTOR_LINE, r1, t1, r2, t2])
    commands.append([VECTOR_LINE, r2, 100, r2, 102])
    commands.append([VECTOR_LINE, rRpm, 100, rRpm, -10])
  }
  return commands
}

let torq = @(){
  watch = [TorqArray, MaxTorq]
  size = const [pw(15), ph(20)]
  pos = [pw(16), ph(10)]
  rendObj = ROBJ_VECTOR_CANVAS
  color = warningColor
  commands = getTorqGraphCommands()
  children = [
    {
      rendObj = ROBJ_TEXT
      pos = [pw(100), ph(105)]
      color = warningColor
      fontSize = baseFontSize
      text = MaxRpm.value.tostring()
    }
    {
      rendObj = ROBJ_TEXT
      pos = [pw(100), ph(88)]
      color = warningColor
      fontSize = baseFontSize
      text = "RPM"
    }
    {
      rendObj = ROBJ_TEXT
      pos = [pw(2), ph(-20)]
      color = warningColor
      fontSize = 30
      text = "M"
    }
    @(){
      watch = MaxTorq
      rendObj = ROBJ_TEXT
      pos = [pw(-19), ph(-5)]
      color = warningColor
      fontSize = baseFontSize
      text = MaxTorq.value.tointeger().tostring()
    }
    @(){
      watch = MinRpm
      rendObj = ROBJ_TEXT
      pos = [pw(-5), ph(103)]
      color = warningColor
      fontSize = baseFontSize
      text = MinRpm.value.tointeger().tostring()
    }
  ]
}

let Root = @(){
  watch = Visible
  size = flex()
  children = Visible.value ? [
    engine
    transmission
    tracks
    forceOrientUp
    forceOrientFwd
    axis
    torq
  ] : null
}

return Root
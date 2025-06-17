from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")

let { format } = require("string")
let { fabs } = require("math")
let compass = require("compass.nut")
let { greenColor } = require("style/airHudStyle.nut")
let { IsRadarVisible } = require("radarState.nut")
let { OpticsWidth, StaticFov, CalcProgress, IsVisible, IsTargetSelected, IsTargetDataAvailable,
  IsForestallVisible, IsForestallCalculating, TargetSpeed, TargetAzimuth, TargetType, TargetLength,
  TargetHeight, TargetDistance, TorpedoDistToLive, BearingAngle, HeroAzimuthAngle, IsBinocular
} = require("%rGui/fcsState.nut")
let { drawArrow } = require("fcsComponent.nut")


let compassSize = [hdpx(500), hdpx(32)]
let compassPos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
let progressBarWidth = hdpx(192)
let fcsBarColor1 = 0x7F007F00
let fcsBarColor2 = 0x19323232
let textColor = Color(0, 0, 0, 255)
let textPadding = hdpx(5)
let greyColor = Color(15, 25, 25, 255)
let highlightColor = Color(255, 255, 255, 180)
let highlightScale = 2.5

let compassComponent = {
  pos = compassPos
  children = compass(compassSize, greenColor)
}

let mkText = @(ovr) {
  padding = [0, textPadding]
  color = textColor
  rendObj = ROBJ_TEXT
  font = Fonts.tiny_text_hud
  fontFx = FFT_GLOW
  fontFxFactor = hdpx(64)
  fontFxColor = 0xFFFFFFFF
}.__update(ovr)

let processingText = mkText({
  text = loc("fcs_processing")
})

let calculatingText = mkText({
  text = loc("fcs_calculating")
})

let targetDistanceText = mkText({
  text = loc("fcs_target_distance")
})

let attackBearingText = mkText({
  text = loc("fcs_attack_bearing")
})

let processingHint = {
  pos = [sw(61), sh(37)]
  children = mkText({ text = loc("fcs_keep_sight_on_target_hint") })
}

let processingBlock = @() {
  watch = [OpticsWidth, StaticFov]
  pos = [sw(52) + OpticsWidth.get(), StaticFov.get() > 6. ? sh(56.5) : sh(55)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = CalcProgress
      size = [progressBarWidth, SIZE_TO_CONTENT]
      margin = [0, 0, textPadding, 0]
      fValue = CalcProgress.get()
      rendObj = ROBJ_PROGRESS_LINEAR
      fgColor = fcsBarColor1
      bgColor = fcsBarColor2
      children = processingText
    }
    @() {
      watch = [TargetType, CalcProgress]
      children = CalcProgress.get() < 0.15 ? null
        : mkText({ text = "".concat(loc("fcs_target_type"), loc($"{TargetType.get()}_0", TargetType.get())) })
    }
    @() {
      watch = [TargetLength, CalcProgress]
      children = CalcProgress.get() < 0.3 ? null
        : mkText({ text = "".concat(loc("fcs_target_length"), cross_call.measureTypes.ALTITUDE.getMeasureUnitsText(TargetLength.get())) })
    }
    @() {
      watch = [TargetHeight, CalcProgress]
      children = CalcProgress.get() < 0.45 ? null
        : mkText({
          text = "".concat(loc("fcs_target_height"), cross_call.measureTypes.ALTITUDE.getMeasureUnitsText(TargetHeight.get()))
        })
    }
    @() {
      watch = [TargetSpeed, CalcProgress]
      children = CalcProgress.get() < 0.60 ? null
        : mkText({
          text = "".concat(loc("fcs_target_speed"), cross_call.measureTypes.SPEED.getMeasureUnitsText(TargetSpeed.get()))
        })
    }
    @() {
      watch = [TargetAzimuth, CalcProgress]
      children = CalcProgress.get() < 0.75 ? null
        : mkText({ text = format("%s%d", loc("fcs_target_course"), TargetAzimuth.get()) })
    }
  ]
}

let redColor = Color(210, 20, 20, 250)
let yellowColor = Color(210,210,0)
let orangeColor = Color(210,120,20)

function bearingAngleColor(delta) {
  return delta > 5.0 ? redColor
    : delta > 3.5 ? orangeColor
    : delta > 1.0 ? yellowColor
    : greenColor
}

function distanceColor(current, total) {
  return current > total ? redColor
    :  current > total * 0.9 ? orangeColor
    :  current > total * 0.8 ? yellowColor
    :  greenColor
}

let calculatingBlock = @() {
  watch = [OpticsWidth, StaticFov]
  pos = [sw(52) + OpticsWidth.get(), StaticFov.get() > 6. ? sh(56.5) : sh(55)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = CalcProgress
      size = [progressBarWidth, SIZE_TO_CONTENT]
      margin = [0, 0, textPadding, 0]
      fValue = CalcProgress.get()
      rendObj = ROBJ_PROGRESS_LINEAR
      fgColor = fcsBarColor1
      bgColor = fcsBarColor2
      children = calculatingText
    }
    @() {
      watch = CalcProgress
      flow = FLOW_HORIZONTAL
      children = CalcProgress.get() == 1.0 || TargetDistance.get() != 0.0
        ? [
          targetDistanceText
          @() {
            watch = [TargetDistance, TorpedoDistToLive]
            children = mkText({
              text = cross_call.measureTypes.DISTANCE.getMeasureUnitsText(TargetDistance.get())
              color = distanceColor(TargetDistance.get(), TorpedoDistToLive.get())
            })
          }
        ] : null
    }
    @() {
      watch = CalcProgress
      flow = FLOW_HORIZONTAL
      children = CalcProgress.get() == 1.0 || BearingAngle.get() != 0.0
        ? [
          attackBearingText
          @() {
            watch = [ BearingAngle, HeroAzimuthAngle ]
            children = mkText({
              text = format("%d", BearingAngle.get())
              color = bearingAngleColor(fabs(BearingAngle.get() - HeroAzimuthAngle.get()))
            })
          }
        ] : null
    }
  ]
}

let crosshairZeroMark = {
  children = [
    drawArrow(sw(50), sh(50), 0, 1.6, highlightColor, false, highlightScale)
    drawArrow(sw(50), sh(50), 0, 1.6, greyColor)
  ]
}

let isProcessing = Computed(@() !IsForestallCalculating.get() && IsTargetSelected.get() && IsTargetDataAvailable.get() && !IsForestallVisible.get())

return @() {
  watch = [ IsVisible, isProcessing, IsForestallCalculating, IsBinocular ]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = const [sw(100), sh(100)]
  children = IsVisible.get() ? [
      !IsRadarVisible.value ? compassComponent : null
      isProcessing.get() ? processingHint : null
      IsForestallCalculating.get() ? calculatingBlock
        : isProcessing.get() ? processingBlock : null
    ]
    : IsBinocular.value ? crosshairZeroMark
    : null
}
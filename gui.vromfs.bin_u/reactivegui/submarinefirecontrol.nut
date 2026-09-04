import "%rGui/compass.nut" as compass
from "%rGui/options/measureUnits.nut" import ALTITUDE, SPEED, DISTANCE
from "%rGui/style/airHudStyle.nut" import greenColor
from "%rGui/radarState.nut" import IsRadarVisible
from "%rGui/fcsState.nut" import OpticsWidth, StaticFov, CalcProgress, IsVisible, IsTargetSelected, IsTargetDataAvailable, IsForestallVisible
  , IsForestallCalculating, TargetSpeed, TargetAzimuth, TargetType, TargetLength, TargetHeight, TargetDistance
  , TorpedoDistToLive, BearingAngle, HeroAzimuthAngle, IsBinocular, isHydrophoneMode
from "%rGui/fcsComponent.nut" import drawArrow
from "string" import format
from "math" import fabs, floor
from "%sqstd/string.nut" import cutPrefix
from "%rGui/globals/ui_library.nut" import *

let compassSize = [hdpx(500), hdpx(32)]
let compassPos = [sw(50) - 0.5 * compassSize[0], sh(0.5)]
const progressBarWidth = hdpx(192)
const fcsBarColor1 = 0x7F007F00
const fcsBarColor2 = 0x19323232
const textColor = Color(0, 0, 0, 255)
const textPadding = hdpx(5)
const greyColor = Color(15, 25, 25, 255)
const highlightColor = Color(255, 255, 255, 180)
const highlightScale = 2.5

let hydrophoneDistance = Computed(@() floor(TargetDistance.get() / 100) * 100)

let compassComponent = {
  pos = compassPos
  children = compass(compassSize, greenColor)
}

let mkText = @(ovr) {
  padding = const [0, textPadding]
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
  pos = const [sw(61), sh(37)]
  children = mkText({ text = loc("fcs_keep_sight_on_target_hint") })
}

let processingBlock = @() {
  watch = [OpticsWidth, StaticFov]
  pos = [sw(52) + OpticsWidth.get(), StaticFov.get() > 6. ? sh(56.5) : sh(55)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = CalcProgress
      size = const [progressBarWidth, SIZE_TO_CONTENT]
      margin = const [0, 0, textPadding, 0]
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
        : mkText({ text = "".concat(loc("fcs_target_length"), ALTITUDE.getMeasureUnitsText(TargetLength.get())) })
    }
    @() {
      watch = [TargetHeight, CalcProgress]
      children = CalcProgress.get() < 0.45 ? null
        : mkText({
          text = "".concat(loc("fcs_target_height"), ALTITUDE.getMeasureUnitsText(TargetHeight.get()))
        })
    }
    @() {
      watch = [TargetSpeed, CalcProgress]
      children = CalcProgress.get() < 0.60 ? null
        : mkText({
          text = "".concat(loc("fcs_target_speed"), SPEED.getMeasureUnitsText(TargetSpeed.get()))
        })
    }
    @() {
      watch = [TargetAzimuth, CalcProgress]
      children = CalcProgress.get() < 0.75 ? null
        : mkText({ text = format("%s%d", loc("fcs_target_course"), TargetAzimuth.get()) })
    }
  ]
}

let hydrophoneProcessingBlock = @() {
  watch = [OpticsWidth, StaticFov]
  pos = [sw(52) + OpticsWidth.get(), StaticFov.get() > 6. ? sh(56.5) : sh(55)]
  flow = FLOW_VERTICAL
  children = [
    function() {
      let res = { watch = [TargetType, CalcProgress] }
      if (CalcProgress.get() < 0.10)
        return res
      let expClassName = cutPrefix(TargetType.get(), "exp_")
      if (expClassName == null)
        return res
      return res.__update({
        children = mkText({
          text = "".concat(loc("fcs_target_class"), loc($"mainmenu/type_{expClassName}"))
        })
      })
    }
    @() {
      watch = [TargetAzimuth, CalcProgress]
      children = CalcProgress.get() < 0.3 ? null
        : mkText({ text = format("%s%d", loc("fcs_target_course"), TargetAzimuth.get()) })
    }
    @() {
      watch = [hydrophoneDistance, CalcProgress]
      children = CalcProgress.get() < 0.6 ? null
        : mkText({ text = "".concat(loc("fcs_target_distance"),
          ALTITUDE.getMeasureUnitsText(hydrophoneDistance.get())) })
    }
  ]
}

const redColor = Color(210, 20, 20, 250)
const yellowColor = Color(210,210,0)
const orangeColor = Color(210,120,20)

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

function isReadyToLaunch(current, total) {
  return current < total
}

let calculatingBlock = @() {
  watch = [OpticsWidth, StaticFov]
  pos = [sw(52) + OpticsWidth.get(), StaticFov.get() > 6. ? sh(56.5) : sh(55)]
  flow = FLOW_VERTICAL
  children = [
    @() {
      watch = CalcProgress
      size = const [progressBarWidth, SIZE_TO_CONTENT]
      margin = const [0, 0, textPadding, 0]
      fValue = CalcProgress.get()
      rendObj = ROBJ_PROGRESS_LINEAR
      fgColor = fcsBarColor1
      bgColor = fcsBarColor2
      children = calculatingText
    }
    @() {
      watch = [CalcProgress, TargetDistance]
      flow = FLOW_HORIZONTAL
      children = CalcProgress.get() == 1.0 || TargetDistance.get() != 0.0
        ? [
          targetDistanceText
          @() {
            watch = [TargetDistance, TorpedoDistToLive]
            children = mkText({
              text = DISTANCE.getMeasureUnitsText(TargetDistance.get())
              color = distanceColor(TargetDistance.get(), TorpedoDistToLive.get())
            })
          }
        ] : null
    }
    @() {
      watch = [CalcProgress, BearingAngle]
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
    @() {
      watch = [CalcProgress, TargetDistance, TorpedoDistToLive]
      children = CalcProgress.get() == 1.0
        ? mkText({
          text = isReadyToLaunch(TargetDistance.get(), TorpedoDistToLive.get())
            ? loc("fcs_torpedo_ready_to_launch")
            : loc("fcs_torpedo_too_far_to_launch")
          color = isReadyToLaunch(TargetDistance.get(), TorpedoDistToLive.get()) ? greenColor : redColor
        })
        : null
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
  watch = [ IsVisible, isProcessing, IsForestallCalculating, IsBinocular, isHydrophoneMode ]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = const [sw(100), sh(100)]
  children = IsVisible.get() ? [
      !IsRadarVisible.get() ? compassComponent : null
      isProcessing.get() ? processingHint : null
      IsForestallCalculating.get() ? calculatingBlock
        : !isProcessing.get() ? null
        : isHydrophoneMode.get() ? processingBlock : hydrophoneProcessingBlock
    ]
    : IsBinocular.get() ? crosshairZeroMark
    : null
}
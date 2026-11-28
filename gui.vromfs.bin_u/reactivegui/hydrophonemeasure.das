require darg
require DagorStdGuiRender
require DagorMath
require DagorRandom
require math
require strings
require %gameLibs.das.math.base
require SonarHud
require Localization
require hud


let GAIN_ARC_START = -110.0f
let GAIN_ARC_SWEEP = 220.0f
let SIGNAL_DETAILS = 51
let SIGNAL_RADIUS = 115.0
let SIGNAL_MIN_AMP = 1.0f
let SIGNAL_MAX_AMP = 10.0f
let TEXT_GAP = 26.0
let TEXT_X_OFFSET = 4.0

let SEARCH_NOISE = 0
let GAIN_ADJUSTMENT = 1
let RECEIVE_PARAMS = 2


struct CanvasParams
  lineWidthPx : float = 2.0f
  fontId : int = -1
  coneRadius : float
  gainRadius : float
  bearingArrWidth : float
  bearingArrHeight : float
  hpBearingPicture : Picture?
  hpAimPicture : Picture?
  hpGainPicture : Picture?
  hpGainCenterPicture : Picture?
  hpBearingArrPicture : Picture?


[export]
def setup_data(props : Properties&; var data : CanvasParams&)
  data.lineWidthPx = props |> getFloat("lineWidthPx", 2.0f)
  data.fontId = props |> getFontId()
  data.coneRadius = props |> getFloat("coneRadius", 0.0f)
  data.gainRadius = props |> getFloat("gainRadius", 0.0f)
  data.bearingArrWidth = props |> getFloat("bearingArrWidth", 0.0f)
  data.bearingArrHeight = props |> getFloat("bearingArrHeight", 0.0f)
  data.hpBearingPicture = props |> getPicture("hpBearingPicture")
  data.hpAimPicture = props |> getPicture("hpAimPicture")
  data.hpGainPicture = props |> getPicture("hpGainPicture")
  data.hpGainCenterPicture = props |> getPicture("hpGainCenterPicture")
  data.hpBearingArrPicture = props |> getPicture("hpBearingArrPicture")


def draw_segment(var ctx : GuiContext&; var seg : array<float2>&; a, b : float2; width : float; color : E3DCOLOR)
  seg[0] = a
  seg[1] = b
  ctx |> render_line_aa(seg, false, width, float2(0.), color)


def mk_text(var ctx : GuiContext&; fctx : StdGuiFontContext&; text : string; pos : float2; color : E3DCOLOR)
  let box = get_str_bbox(text, text |> length(), fctx)
  ctx |> set_color(color)
  ctx |> goto_xy(float2(pos.x, pos.y + box.width.y * 0.5f))
  ctx |> draw_str_scaled(1.0, text, text |> length())


def append_text(var ctx : GuiContext&; text : string; color : E3DCOLOR)
  ctx |> set_color(color)
  ctx |> draw_str_scaled(1.0, text, text |> length())


def mk_bearing_dial(var ctx : GuiContext&; data : CanvasParams&; center : float2; radius, bearing : float; color : E3DCOLOR)
  setRotViewTm(ctx, center.x, center.y, bearing * DEG_TO_RAD * -1.0, 0.0, false)
  render_picture(ctx, data.hpBearingPicture, center - float2(radius), float2(radius) * 2.0, color)
  resetViewTm(ctx)

  let arrSize = float2(ctx |> hdpx(data.bearingArrWidth), ctx |> hdpx(data.bearingArrHeight))
  let arrPos : float2 = center - float2(arrSize.x / 2.0, radius * 1.02)
  render_picture(ctx, data.hpBearingArrPicture, arrPos, arrSize, color)

  let aimSize : float = radius * 0.34
  render_picture(ctx, data.hpAimPicture, center - float2(aimSize), float2(aimSize) * 2.0, color)


def mk_gain_dial(var ctx : GuiContext&; data : CanvasParams&; gainCenter : float2; gainRadius, gain, maxGain : float; color : E3DCOLOR)
  let gainPos : float2 = gainCenter - float2(gainRadius)
  render_picture(ctx, data.hpGainPicture, gainPos, float2(gainRadius) * 2.0, color)

  let gArrDir = GAIN_ARC_START + gain * (GAIN_ARC_SWEEP / maxGain)
  let gArrPos : float2 = gainCenter - float2(gainRadius * 0.5)
  setRotViewTm(ctx, gainCenter.x, gainCenter.y, gArrDir * DEG_TO_RAD, 0.0, false)
  render_picture(ctx, data.hpGainCenterPicture, gArrPos, float2(gainRadius), color)
  resetViewTm(ctx)


def mk_gain_signal(var ctx : GuiContext&; var seg : array<float2>&; center : float2; gainMatch, curWidth : float; color : E3DCOLOR)
  var prevPoint : float2
  let radius = ctx |> hdpx(SIGNAL_RADIUS)
  let amp = lerp(SIGNAL_MIN_AMP, SIGNAL_MAX_AMP, gainMatch)
  let xOffset = ctx |> hdpx(amp)
  let yOffset = ctx |> hdpx(1.5f * amp)
  for i in range(SIGNAL_DETAILS)
    let deg : float = float((i - SIGNAL_DETAILS / 2) * 3 - 90)
    let rad : float = deg * DEG_TO_RAD

    if i == 0
      prevPoint = center + float2(
        radius * cos(rad) + rnd_float(0.0f, xOffset),
        radius * sin(rad) + rnd_float(0.0f, yOffset)
      )
      continue

    let width : float = curWidth + curWidth / 2 * gainMatch
    let edgeFade : float = sin(float(i) / float(SIGNAL_DETAILS - 1) * PI)
    let lineColor : E3DCOLOR = fade_color(color, edgeFade)
    let nextPoint : float2 = center + float2(
      radius * cos(rad) + rnd_float(0.0f, xOffset),
      radius * sin(rad) + rnd_float(0.0f, yOffset)
    )

    draw_segment(ctx, seg, prevPoint, nextPoint, width, lineColor)

    prevPoint.x = nextPoint.x
    prevPoint.y = nextPoint.y


struct MeasureLock
  isMeasured : bool
  isReadyToLaunch : bool
  isOutOfRange : bool
  isResultAlly : bool
  gainMatch : float
  distance : float
  timeLeft : float
  color : E3DCOLOR


def get_measure_lock(hud : HydrophoneMeasureHud) : MeasureLock
  var measureLock : MeasureLock
  static_if typeinfo(has_field<lockRange> type<HydrophoneMeasureHud>)
    measureLock.isMeasured = hud.isTargetMeasured
    measureLock.isReadyToLaunch = hud.isReadyToLaunch
    measureLock.gainMatch = hud.gainMatch
    measureLock.distance = hud.lockRange
    measureLock.timeLeft = hud.lockTimeLeft
    measureLock.color = hud.lockedColor
  static_if typeinfo(has_field<isOutOfRange> type<HydrophoneMeasureHud>)
    measureLock.isOutOfRange = hud.isOutOfRange
  static_if typeinfo(has_field<isResultAlly> type<HydrophoneMeasureHud>)
    measureLock.isResultAlly = hud.isResultAlly
  return measureLock


def mk_text_info(var ctx : GuiContext&; fctx : StdGuiFontContext&; center : float2; textGap : float; hud : HydrophoneMeasureHud; measureLock : MeasureLock)
  let hasNoise : bool = hud.isBearingCaught
  let hasConfirmed : bool = hud.showResult && hud.isResultConfirmed
  let isMeasured : bool = measureLock.isMeasured && !hud.isGainMode
  let isAlly : bool = hasConfirmed && measureLock.isResultAlly
  let isFailed : bool = hud.showResult && !hud.isResultConfirmed && !isMeasured
  let stepFadeColor : E3DCOLOR = fade_color(hud.bearingColor, 0.5f)
  let passFadeColor : E3DCOLOR = fade_color(hud.gainCorrectColor, 0.5f)
  let noiseLocKey = hasNoise || hasConfirmed || isMeasured ? "noiseDetect" : "noiseSearch"

  let offset = ctx |> hdpx(TEXT_X_OFFSET)
  let step = (hud.showResult || isMeasured ? RECEIVE_PARAMS
    : hud.isGainMode ? GAIN_ADJUSTMENT
    : SEARCH_NOISE)

  let noiseTxtColor = (isMeasured ? hud.gainCorrectColor
    : step > SEARCH_NOISE ? passFadeColor
    : hasNoise ? hud.gainCorrectColor
    : hud.confirmedColor)

  let signalTxtColor = (isMeasured ? hud.gainCorrectColor
    : step > GAIN_ADJUSTMENT ? passFadeColor
    : hud.isGainCorrect ? hud.gainCorrectColor
    : hud.isGainMode ? hud.confirmedColor
    : hasNoise ? hud.bearingColor
    : stepFadeColor)

  mk_text(ctx, fctx, loc("hud/hydrophone/{noiseLocKey}"),
    center + float2(-abs(float(step) * offset), -textGap * float(step)), noiseTxtColor)
  mk_text(ctx, fctx, loc("hud/hydrophone/signalAmplification"),
    center + float2(-abs((float(step) - 1) * offset), textGap * (1 - float(step))), signalTxtColor)

  let launchColor = (isFailed ? hud.failColor
    : isAlly ? hud.gainCorrectColor
    : measureLock.isMeasured ? measureLock.color
    : hasConfirmed ? hud.gainCorrectColor
    : stepFadeColor)

  let launchPos = center + float2(-abs((float(step) - 2) * offset), textGap * (2 - float(step)))
  if measureLock.isMeasured && !isFailed && !isAlly
    let distColor = measureLock.isOutOfRange ? hud.failColor : launchColor
    mk_text(ctx, fctx, "{loc("hud/hydrophone/targetLocked")}: ", launchPos, launchColor)
    append_text(ctx, get_measure_units_text(MeasureUnitsTypes.MEASURE_UNIT_DIST, measureLock.distance, true, 0.1), distColor)
    append_text(ctx, " ({int(ceil(measureLock.timeLeft))} {loc("measureUnits/seconds")})", launchColor)
  else
    let resultLocKey = isFailed ? "signalFailed" : isAlly ? "targetAlly" : "launchPermitted"
    mk_text(ctx, fctx, loc("hud/hydrophone/{resultLocKey}"), launchPos, launchColor)

  let isOutOfRange = isMeasured && measureLock.isOutOfRange
  let rechargeColor = (isOutOfRange ? hud.failColor
    : isMeasured && measureLock.isReadyToLaunch ? hud.gainCorrectColor
    : stepFadeColor)
  mk_text(ctx, fctx, isOutOfRange ? loc("fcs_torpedo_too_far_to_launch") : loc("hud/hydrophone/recharge"),
    center + float2(-abs((float(step) - 3) * offset), textGap * (3 - float(step))), rechargeColor)


def fade_color(color : E3DCOLOR; alpha : float) : E3DCOLOR
  return E3DCOLOR(Color4(float4(Color4(color)) * clamp(alpha, 0.0f, 1.0f)))


[export, unused_argument(rdata, rstate)]
def draw_hydrophone_measure(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let hud = get_hydrophone_measure_hud()
  if !hud.isActive
    return

  var seg : array<float2>
  seg |> resize(2)
  var fctx : StdGuiFontContext
  get_font_context(fctx, data.fontId, 0, 0, 0)
  ctx |> set_font(data.fontId, 0, 0)

  let center = get_passive_sonar_hud_fov_center()
  let width = ctx |> hdpx(data.lineWidthPx)

  let coneRadius = ctx |> hdpx(data.coneRadius)
  let gainRadius = ctx |> hdpx(data.gainRadius)
  let gainCenter : float2 = center + float2(0.0, coneRadius * 0.65)

  let measureLock = get_measure_lock(hud)
  let coneColor : E3DCOLOR = (measureLock.isMeasured && !hud.isGainMode ? measureLock.color
    : hud.isGainCorrect ? hud.gainCorrectColor
    : hud.isGainMode ? hud.gainCorrectColor
    : hud.bearingColor)

  let gainColor : E3DCOLOR = (hud.isGainCorrect ? hud.gainCorrectColor
    : hud.isGainMode ? hud.bearingColor
    : fade_color(hud.bearingColor, 0.5f))

  mk_bearing_dial(ctx, data, center, coneRadius, hud.bearing, coneColor)
  mk_gain_dial(ctx, data, gainCenter, gainRadius, hud.gain, hud.maxGain, gainColor)

  if (hud.isGainMode)
    let signalColor : E3DCOLOR = hud.isGainCorrect ? hud.gainCorrectColor : hud.confirmedColor
    mk_gain_signal(ctx, seg, gainCenter, measureLock.gainMatch, width, signalColor)

  let textGap = ctx |> hdpx(TEXT_GAP)
  mk_text_info(ctx, fctx, center + float2(coneRadius * 1.07, 0.0), textGap, hud, measureLock)

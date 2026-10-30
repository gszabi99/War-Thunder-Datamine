require darg
require DagorStdGuiRender
require DagorMath
require DagorRandom
require math
require strings
require %gameLibs.das.math.base
require SonarHud
require Localization


let GAIN_ARC_START = -110.0f
let GAIN_ARC_SWEEP = 220.0f
let SIGNAL_DETAILS = 51
let SIGNAL_RADIUS = 115.0
let CONE_RADIUS = 350.0
let GAIN_RADIUS = 160.0
let TEXT_GAP = 26.0


struct CanvasParams
  lineWidthPx : float = 2.0f
  fontId : int = -1
  hpBearingPicture : Picture?
  hpAimPicture : Picture?
  hpGainPicture : Picture?
  hpGainCenterPicture : Picture?
  hpBearingArrPicture : Picture?


[export]
def setup_data(props : Properties&; var data : CanvasParams&)
  data.lineWidthPx = props |> getFloat("lineWidthPx", 2.0f)
  data.fontId = props |> getFontId()
  data.hpBearingPicture = props |> getPicture("hpBearingPicture")
  data.hpAimPicture = props |> getPicture("hpAimPicture")
  data.hpGainPicture = props |> getPicture("hpGainPicture")
  data.hpGainCenterPicture = props |> getPicture("hpGainCenterPicture")
  data.hpBearingArrPicture = props |> getPicture("hpBearingArrPicture")


def draw_segment(var ctx : GuiContext&; var seg : array<float2>&; a, b : float2; width : float; color : E3DCOLOR)
  seg[0] = a
  seg[1] = b
  ctx |> render_line_aa(seg, false, width, float2(0.), color)


def mk_right_align_text(var ctx : GuiContext&; fctx : StdGuiFontContext&; text : string; pos : float2; color : E3DCOLOR)
  let box = get_str_bbox(text, text |> length(), fctx)
  ctx |> set_color(color)
  ctx |> goto_xy(float2(pos.x - box.width.x, pos.y + box.width.y * 0.5f))
  ctx |> draw_str_scaled(1.0, text, text |> length())


def mk_bearing_dial(var ctx : GuiContext&; data : CanvasParams&; center : float2; radius, bearing : float; color : E3DCOLOR)
  setRotViewTm(ctx, center.x, center.y, bearing * DEG_TO_RAD * -1.0, 0.0, false)
  render_picture(ctx, data.hpBearingPicture, center - float2(radius), float2(radius) * 2.0, color)
  resetViewTm(ctx)

  let arrWidth : float = radius / 32.0
  let arrPos : float2 = center - float2(arrWidth / 2.0, radius * 1.02)
  let arrSize : float2 = float2(arrWidth, arrWidth * 5.0)
  render_picture(ctx, data.hpBearingArrPicture, arrPos, arrSize, color)

  let aimSize : float = radius * 0.34
  render_picture(ctx, data.hpAimPicture, center - float2(aimSize), float2(aimSize) * 2.0, color)


def mk_gain_dial(var ctx : GuiContext&; data : CanvasParams&; gainCenter : float2; radius, gain, maxGain : float; color : E3DCOLOR)
  let gainPos : float2 = gainCenter - float2(radius * 0.5)
  render_picture(ctx, data.hpGainPicture, gainPos, float2(radius), color)

  let gArrDir = GAIN_ARC_START + gain * (GAIN_ARC_SWEEP / maxGain)
  let gArrWidth : float = radius * 0.5
  let gArrPos : float2 = gainCenter - float2(gArrWidth * 0.5)
  setRotViewTm(ctx, gainCenter.x, gainCenter.y, gArrDir * DEG_TO_RAD, 0.0, false)
  render_picture(ctx, data.hpGainCenterPicture, gArrPos, float2(gArrWidth), color)
  resetViewTm(ctx)


def mk_gain_signal(var ctx : GuiContext&; var seg : array<float2>&; center : float2; power, maxPower, curWidth : float; color : E3DCOLOR)
  var prevPoint : float2
  for i in range(SIGNAL_DETAILS)
    let deg : float = float((i - SIGNAL_DETAILS / 2) * 3 - 90)
    let rad : float = deg * DEG_TO_RAD

    if i == 0
      prevPoint = center + float2(120 * cos(rad), 120 * sin(rad))
      continue

    let width : float = curWidth + curWidth / 2 * power / maxPower
    let edgeFade : float = sin(float(i) / float(SIGNAL_DETAILS - 1) * PI)
    let lineColor : E3DCOLOR = fade_color(color, edgeFade)
    let nextPoint : float2 = center + float2(
      SIGNAL_RADIUS * cos(rad) + rnd_float(0.0f, power * 1.0f),
      SIGNAL_RADIUS * sin(rad) + rnd_float(0.0f, power * 1.5f)
    )

    draw_segment(ctx, seg, prevPoint, nextPoint, width, lineColor)

    prevPoint.x = nextPoint.x
    prevPoint.y = nextPoint.y


def mk_text_info(var ctx : GuiContext&; fctx : StdGuiFontContext&; center : float2; textGap : float; hud : HydrophoneMeasureHud)
  let hasNoise : bool = hud.isBearingCaught
  let hasConfirmed : bool = hud.showResult && hud.isResultConfirmed
  let fadeColor : E3DCOLOR = fade_color(hud.bearingColor, 0.5f)
  let noiseLocKey = hasNoise || hasConfirmed ? "noiseDetect" : "noiseSearch"
  let noiseTxtColor = hasNoise || hasConfirmed ? hud.gainCorrectColor : hud.bearingColor

  let signalTxtColor = (hud.isGainCorrect || hasConfirmed ? hud.gainCorrectColor
    : hud.isGainMode ? hud.confirmedColor
    : hasNoise ? hud.bearingColor
    : fadeColor)

  mk_right_align_text(ctx, fctx, loc("hud/hydrophone/{noiseLocKey}"), center, noiseTxtColor)
  mk_right_align_text(ctx, fctx, loc("hud/hydrophone/signalAmplification"), center + float2(0.0, textGap), signalTxtColor)

  let launchColor = (hud.showResult && hud.isResultConfirmed ? hud.confirmedColor
    : !hud.showResult ? fadeColor
    : hud.failColor)
  let launchLocId = (!hud.showResult || hud.showResult && hud.isResultConfirmed
    ? "hud/hydrophone/launchPermitted"
    : "hud/hydrophone/signalFailed")

  mk_right_align_text(ctx, fctx, loc(launchLocId), center + float2(0.0, textGap * 2), launchColor)
  mk_right_align_text(ctx, fctx, loc("hud/hydrophone/recharge"), center + float2(0.0, textGap * 3), fadeColor)


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

  let coneRadius = ctx |> hdpx(CONE_RADIUS)
  let gainRadius = ctx |> hdpx(GAIN_RADIUS)
  let gainCenter : float2 = center + float2(0.0, coneRadius * 0.65)

  let coneColor : E3DCOLOR = (hud.isGainCorrect ? hud.gainCorrectColor
    : hud.isGainMode ? hud.gainCorrectColor
    : hud.bearingColor)

  let gainColor : E3DCOLOR = (hud.isGainCorrect ? hud.gainCorrectColor
    : hud.isGainMode ? hud.bearingColor
    : fade_color(hud.bearingColor, 0.5f))

  mk_bearing_dial(ctx, data, center, coneRadius, hud.bearing, coneColor)
  mk_gain_dial(ctx, data, gainCenter, gainRadius, hud.gain, hud.maxGain, gainColor)

  if (hud.isGainMode)
    let signalColor : E3DCOLOR = hud.isGainCorrect ? hud.gainCorrectColor : hud.confirmedColor
    mk_gain_signal(ctx, seg, gainCenter, hud.gain, hud.maxGain, width, signalColor)

  let textGap = ctx |> hdpx(TEXT_GAP)
  mk_text_info(ctx, fctx, center - float2(coneRadius * 1.1, textGap * 2.0), textGap, hud)

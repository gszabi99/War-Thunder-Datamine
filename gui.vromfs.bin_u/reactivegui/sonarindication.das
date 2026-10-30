require darg
require DagorStdGuiRender
require DagorMath
require math
require strings
require Localization
require %gameLibs.das.math.base
require Mission
require SonarHud

let LEFT_ARC = float2(135.0f, 225.0f)
let RIGHT_ARC = float2(-45.0f, 45.0f)

let transparent = E3DCOLOR(0x0)

struct CanvasParams
  disabledTicksColor : E3DCOLOR = E3DCOLOR(0xFFC0C0C0)
  activeTicksColor : E3DCOLOR = E3DCOLOR(0xFF267F00)
  minorTickLenPx : float = 3.0f
  majorTickLenPx : float = 9.0f
  ticksPerArc : int = 25
  majorTickEvery : int = 4
  tickLineWidth : float = 1.5f
  cooldownBarColor : E3DCOLOR = E3DCOLOR(0xFF267F00)
  cooldownBarOffset : float = 5.0f
  cooldownBarWidth : float = 3.0f
  pulseRingColor : E3DCOLOR = E3DCOLOR(0x55267F00)
  pulseRingAlpha : float = 0.33f
  pulseRingMinSaturation : float = 0.0f
  pulseAnimationTime : float = 2.0f
  pulseRingWidth : float = 40.0f
  pulseFadeTime : float = 0.6f
  fontId : int = -1
  rangeTextColor : E3DCOLOR = E3DCOLOR(0xFA0ACA0A) // airHudStyle green (as the FCS "ready to launch" string), 10,202,10,250
  trackedPulseStartTime : float = -1.0f
  secondAnimationStartTime : float = -1.0f

[export]
def setup_data(props : Properties&; var data : CanvasParams&)
  data.disabledTicksColor = props |> getColor("disabledTicksColor", E3DCOLOR(0xFFC0C0C0))
  data.activeTicksColor = props |> getColor("activeTicksColor", E3DCOLOR(0xFF267F00))
  data.minorTickLenPx = props |> getFloat("minorTickLenPx", 3.0f)
  data.majorTickLenPx = props |> getFloat("majorTickLenPx", 9.0f)
  data.ticksPerArc = props |> getInt("ticksPerArc", 25)
  data.majorTickEvery = props |> getInt("majorTickEvery", 4)
  data.tickLineWidth = props |> getFloat("tickLineWidth", 1.5f)
  data.cooldownBarColor = props |> getColor("cooldownBarColor", E3DCOLOR(0xFF267F00))
  data.cooldownBarOffset = props |> getFloat("cooldownBarOffset", 5.0f)
  data.cooldownBarWidth = props |> getFloat("cooldownBarWidth", 3.0f)
  data.pulseRingColor = props |> getColor("pulseRingColor", E3DCOLOR(0xFF267F00))
  data.pulseRingAlpha = props |> getFloat("pulseRingAlpha", 0.33f)
  data.pulseRingMinSaturation = props |> getFloat("pulseRingMinSaturation", 0.0f)
  data.pulseAnimationTime = props |> getFloat("pulseAnimationTime", 2.0f)
  data.pulseFadeTime = props |> getFloat("pulseFadeTime", 0.6f)
  data.pulseRingWidth = props |> getFloat("pulseRingWidth", 40.0f)
  data.fontId = props |> getFontId()
  data.rangeTextColor = props |> getColor("rangeTextColor", E3DCOLOR(0xFA0ACA0A))
  data.trackedPulseStartTime = -1.0f
  data.secondAnimationStartTime = -1.0f

def draw_arc_ticks(var ctx : GuiContext&; center : float2; radius : float; startDeg, endDeg : float; lineWidth : float; minorTickLen, majorTickLen : float; ticksPerArc, majorTickEvery : int; color : E3DCOLOR)
  let minorLen = ctx |> hdpx(minorTickLen)
  let majorLen = ctx |> hdpx(majorTickLen)
  let baseRadius = radius - majorLen
  for i in range(ticksPerArc)
    let angle = (startDeg + float(i) / float(ticksPerArc - 1) * (endDeg - startDeg)) * DEG_TO_RAD
    let dir = float2(cos(angle), sin(angle))
    let tickLen = i % majorTickEvery == 0 ? majorLen : minorLen
    let segment <- to_array_move(fixed_array<float2>(center + dir * baseRadius, center + dir * (baseRadius + tickLen)))
    ctx |> render_line_aa(segment, false, lineWidth, float2(0.), color)

def draw_progress_arc(var ctx : GuiContext&; center : float2; radius, lineWidth, percent : float, color : E3DCOLOR)
  let angles = float2(-PI * 0.5f, -PI * 0.5f + percent * 2.0f * PI)
  ctx |> render_sector_aa(center, float2(radius, radius), angles, lineWidth, color, transparent)

def draw_ring(var ctx : GuiContext&; center : float2; radius, ringWidth : float; color : E3DCOLOR)
  let outerRadius = radius
  let innerRadius = outerRadius - ringWidth
  ctx |> render_ellipse_aa(center, float2(outerRadius, outerRadius), ringWidth, transparent, color, transparent)
  ctx |> render_ellipse_aa(center, float2(innerRadius, innerRadius), ringWidth, color, transparent, transparent)

def saturate_color(color : E3DCOLOR; saturation : float) : float4
  let baseColor = float4(Color4(color))
  let luma = baseColor.x * 0.299f + baseColor.y * 0.587f + baseColor.z * 0.114f
  return float4(
    cvt(saturation, 0.0f, 1.0f, luma, baseColor.x),
    cvt(saturation, 0.0f, 1.0f, luma, baseColor.y),
    cvt(saturation, 0.0f, 1.0f, luma, baseColor.z),
    baseColor.w
  )

[export, unused_argument(rdata, rstate)]
def draw_active_sonar_indication(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; var data : CanvasParams&)
  let activeSonarHud = get_active_sonar_hud()
  if !activeSonarHud.isEnabled
    return

  let time = float(get_total_time())
  let center = activeSonarHud.fovCenterScreenPos
  let radius = activeSonarHud.fovRadius
  let cooldown = activeSonarHud.pulseCooldown
  let pulseStartTime = activeSonarHud.pulseStartTime
  let lastDetectionTime = activeSonarHud.lastDetectedTime

  if data.trackedPulseStartTime != pulseStartTime
    data.trackedPulseStartTime = pulseStartTime
    data.secondAnimationStartTime = -1.0f

  let isActive = time - pulseStartTime >= cooldown
  if !isActive
    let lineWidth = ctx |> hdpx(data.cooldownBarWidth)
    let ringRadius = radius - (ctx |> hdpx(data.majorTickLenPx)) - (ctx |> hdpx(data.cooldownBarOffset)) - lineWidth * 0.5f
    draw_progress_arc(ctx, center, ringRadius, lineWidth, (time - pulseStartTime) / cooldown, data.cooldownBarColor)
    if activeSonarHud.targetReturnTime < cooldown
      let targetReturnTimeRel = activeSonarHud.targetReturnTime / cooldown
      draw_progress_arc(ctx, center, ringRadius * 0.9, lineWidth * 2.0, targetReturnTimeRel, data.cooldownBarColor)

  let tickLineWidth = ctx |> hdpx(data.tickLineWidth)
  let ticksColor = isActive ? data.activeTicksColor : data.disabledTicksColor
  draw_arc_ticks(ctx, center, radius, RIGHT_ARC.x, RIGHT_ARC.y, tickLineWidth, data.minorTickLenPx, data.majorTickLenPx, data.ticksPerArc, data.majorTickEvery, ticksColor)
  draw_arc_ticks(ctx, center, radius, LEFT_ARC.x, LEFT_ARC.y, tickLineWidth, data.minorTickLenPx, data.majorTickLenPx, data.ticksPerArc, data.majorTickEvery, ticksColor)

  let rangeMax = activeSonarHud.rangeMax
  if rangeMax > 0.0f
    var fctx : StdGuiFontContext
    get_font_context(fctx, data.fontId, 0, 0, 0)
    ctx |> set_font(data.fontId, 0, 0)
    let rangeText = "{loc("hud/sonarMaxRange")}: {int(rangeMax + 0.5f)} {loc("measureUnits/meters_dist")}"
    let textBox = get_str_bbox(rangeText, rangeText |> length(), fctx)
    // along the bottom border of the sonar working-zone circle (fovCenterScreenPos + fovRadius), lowered by 20px
    let textPos = float2(center.x - textBox.width.x * 0.5f, center.y + radius - textBox.width.y + (ctx |> hdpx(20.0f)))
    ctx |> set_color(data.rangeTextColor)
    ctx |> goto_xy(textPos)
    ctx |> draw_str_scaled(1.0, rangeText, rangeText |> length())

  let pulseAnimationTime = data.pulseAnimationTime
  let firstAnimationEndTime = pulseStartTime + pulseAnimationTime
  let elapsed = time - pulseStartTime

  if data.secondAnimationStartTime < 0.0f && lastDetectionTime > 0.0f
    data.secondAnimationStartTime = max(firstAnimationEndTime, lastDetectionTime)

  if elapsed >= pulseAnimationTime && (data.secondAnimationStartTime < 0.0f || time >= data.secondAnimationStartTime + pulseAnimationTime)
    return

  let isSecondPhase = data.secondAnimationStartTime >= 0.0f && time >= data.secondAnimationStartTime
  let pulseRingWidth = ctx |> hdpx(data.pulseRingWidth)
  let pulseFadeTime = data.pulseFadeTime
  let phaseElapsed = isSecondPhase ? time - data.secondAnimationStartTime : elapsed

  let animationT = cvt(phaseElapsed, 0.0f, pulseAnimationTime, 1.0f, 0.0f)
  let ringRadiusForward = (radius - pulseRingWidth * 2.0f) * animationT + pulseRingWidth * 2.0f
  let ringRadius = isSecondPhase ? cvt(phaseElapsed, 0.0f, pulseAnimationTime, pulseRingWidth * 2.0f, radius) : ringRadiusForward

  let fadeInAlpha = cvt(phaseElapsed, 0.0f, pulseFadeTime, 0.0f, 1.0f)
  let fadeOutAlpha = cvt(phaseElapsed, pulseAnimationTime - pulseFadeTime, pulseAnimationTime, 1.0f, 0.0f)
  let alpha = min(fadeInAlpha, fadeOutAlpha)
  let saturation = isSecondPhase ? cvt(phaseElapsed, 0.0f, pulseAnimationTime, data.pulseRingMinSaturation, 1.0f) : cvt(phaseElapsed, 0.0f, pulseAnimationTime, 1.0f, data.pulseRingMinSaturation)

  let ringColor = saturate_color(data.pulseRingColor, saturation) * data.pulseRingAlpha * alpha
  let color = E3DCOLOR(Color4(ringColor))
  draw_ring(ctx, center, ringRadius, pulseRingWidth, color)

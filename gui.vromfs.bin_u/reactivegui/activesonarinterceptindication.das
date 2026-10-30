require darg
require DagorStdGuiRender
require DagorMath
require math
require %gameLibs.das.math.base
require Mission
require SonarHud

struct CanvasParams
  pulseArcColor : E3DCOLOR = E3DCOLOR(Color4(float4(1.0, 0.0, 0.0, 0.5)))
  pulseSectorColor : E3DCOLOR = E3DCOLOR(0x0)
  pulseArcRadius : float = 0.25f
  pulseArcWidth : float = 0.5f
  pulseArcLineWidth : float = 20.0f
  pulseArrowSize : float = 0.025f
  pulseFadeTime : float = 1.0f

[export]
def setup_data(props : Properties&; var data : CanvasParams&)
  data.pulseArcColor = props |> getColor("pulseArcColor", E3DCOLOR(Color4(float4(1.0, 0.0, 0.0, 0.5))))
  data.pulseSectorColor = props |> getColor("pulseSectorColor", E3DCOLOR(0x0))
  data.pulseArcRadius = props |> getFloat("pulseArcRadius", 0.25f)
  data.pulseArcWidth = props |> getFloat("pulseArcWidth", 0.5f)
  data.pulseArcLineWidth = props |> getFloat("pulseArcLineWidth", 20.0f)
  data.pulseArrowSize = props |> getFloat("pulseArrowSize", 0.025f)
  data.pulseFadeTime = props |> getFloat("pulseFadeTime", 1.0f)

[export, unused_argument(rstate)]
def draw_active_sonar_intercept_indication(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  let activeSonarInterceptHud = get_active_sonar_intercept_hud()

  let time = float(get_total_time())
  let phaseElapsed = time - activeSonarInterceptHud.lastDetectedTime
  if phaseElapsed > data.pulseFadeTime
    return

  let fadeOutAlpha = cvt(phaseElapsed, 0.0f, data.pulseFadeTime, 1.0f, 0.0f)
  var pulseArcColor4 = float4(Color4(data.pulseArcColor))
  pulseArcColor4 *= fadeOutAlpha
  let pulseArcColor = E3DCOLOR(Color4(pulseArcColor4))
  var pulseSectorColor4 = float4(Color4(data.pulseSectorColor))
  pulseSectorColor4 *= fadeOutAlpha
  let pulseSectorColor = E3DCOLOR(Color4(pulseSectorColor4))

  let size = min(rdata.size.x, rdata.size.y)

  let radius = size * data.pulseArcRadius
  let angle = atan2(-activeSonarInterceptHud.dirToLastContact.x, -activeSonarInterceptHud.dirToLastContact.y)
  let center = rdata.pos + rdata.size * 0.5
  ctx |> render_sector_aa(center, float2(radius), float2(angle - data.pulseArcWidth * 0.5f, angle + data.pulseArcWidth * 0.5f), ctx |> hdpx(data.pulseArcLineWidth), pulseArcColor, pulseSectorColor)

  let arrowSize = size * data.pulseArrowSize
  var sina, cosa = 0.0
  sincos(angle, sina, cosa)
  let arrowDir = float2(cosa, sina)
  let arrowSide = float2(-sina, cosa)
  let arrowPos = center + arrowDir * (radius + arrowSize)
  let arrowLines <- to_array_move(fixed_array(
    arrowPos,
    arrowPos + (arrowDir + arrowSide) * -arrowSize * 0.707f,
    arrowPos + (arrowDir - arrowSide) * -arrowSize * 0.707f))
  ctx |> render_poly(arrowLines, pulseArcColor)
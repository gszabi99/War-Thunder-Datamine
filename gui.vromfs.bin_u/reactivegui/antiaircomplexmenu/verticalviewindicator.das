require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require darg
require DagorStdGuiRender
require DagorMath
require math
require DagorSystem
require RadarHud
require app


struct CanvasParams
  fontId : int = -1
  fontSize : int = 20
  maxHeight : float = 20.0


def foreach_targets(blk : block<(target : RadarTarget const const#; i : int) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    for i, t in iter_range(targets), targets
      invoke(blk, t, i)


class VerticalViewIndicator : Canvas
  params : CanvasParams = CanvasParams()

  lineColor : E3DCOLOR = E3DCOLOR(0xAA00FF00)


  def VerticalViewIndicator(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    setFont(data.fontId)
    setFontSize(data.fontSize)
    params = data

  def azRelToX(azimuthRel : float)
    let azimuthMin = get_radar_hud_azimuth_min() * radToDeg
    let azimuthMax = get_radar_hud_azimuth_max() * radToDeg

    let angle = lerp(azimuthMin, azimuthMax, azimuthRel)
    let normed = norm_ang_deg(angle)
    return cvt(normed, 0.0, 360.0, 0.0, 1.0)

  def hieghtToY(height : float)
    let y = height / params.maxHeight * 0.001
    return clamp(y, 0.0, 1.0)

  def drawBackGround() // TODO replace with map
    setFillColor(E3DCOLOR(0xFF000000))
    setColor(E3DCOLOR(0xAA000000))
    drawBox(float2(-0.5), float2(0.5))

  def drawMesh()
    setColor(lineColor)
    setFillColor(E3DCOLOR(0x00000000))
    let azimuthMarkingsNum = 6
    for i in range(1, azimuthMarkingsNum)
      let x = float(i) / float(azimuthMarkingsNum)
      drawLine(float2(x, 0.0), float2(x, 1.0))

      let ang = floori(360.0 * x)
      drawStrAnchored(float2(x, -0.03), "{ang}", AnchorHorz.Center, AnchorVert.Top)

    let elevationMarkingsNum = 4
    for i in range(1, elevationMarkingsNum)
      let y = float(i) / float(elevationMarkingsNum)
      drawLine(float2(0.0, y), float2(1.0, y))
      let el = params.maxHeight * y
      drawStrAnchored(float2(-0.02, y), "{el}", AnchorHorz.Right, AnchorVert.Center)

    drawStrAnchored(float2(-0.02, -0.03), "0", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(-0.02, 0.99), "km", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(1.0, 0.0) - float2(0.01, 0.03), loc("hud/AAComplexMenu/azimuth"), AnchorHorz.Right, AnchorVert.Top)

  def drawScanAzimuth()
    let turretRel = get_radar_hud_turret_azimuth()
    let turretX = azRelToX(turretRel)
    drawLine(float2(turretX, 0.0), float2(turretX, 1.0))

    setFillColor(E3DCOLOR(0x0100AA00))
    let halfWidth = get_radar_hud_target_azimuth_width()
    if halfWidth > 0.

      let azMin = turretX - halfWidth / PI * 0.5
      let azMax = turretX + halfWidth / PI * 0.5
      if azMin >= 0.0 && azMax <= 1.0
        drawBox(float2(azMin, 0.0), float2(azMax, 1.0))
      elif azMin < 0.0
        drawBox(float2(1.0 + azMin, 0.0), float2(1.0, 1.0))
        drawBox(float2(0.0, 0.0), float2(azMax, 1.0))
      elif azMax > 1.0
        drawBox(float2(azMin, 0.0), float2(1.0, 1.0))
        drawBox(float2(0.0, 0.0), float2(azMax - 1.0, 1.0))

  def drawTargets()
    setFillColor(E3DCOLOR(0x00000000))
    setViewport(float2(0.0), float2(1.0))
    foreach_targets() <| $(var target; i)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        let x = azRelToX(target.azimuthRel)
        let y = hieghtToY(target.height)
        let pos = float2(x, y)

        let signalRel = target.signalRel < 0.01 ? 0.0 : cvt(target.signalRel, 0.3, 1.0, 0.5, 1.)
        let alphaColor = (1. - target.ageRel) * signalRel
        let col4 = float4(Color4(lineColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setColor(col)

        drawCircle(pos, -0.02)

        setColor(lineColor)

        let h = 0.025
        if target.isDetected
          let offset = 0.017
          drawLine(pos - float2(offset, h), pos + float2(-offset, h))
          drawLine(pos + float2(offset, h), pos + float2(offset, -h))

        // TODO ADD TARGET TYPE
        let targetAnnotation = "{i}"
        let isAnnotationOnTop = y > 0.5
        let annotationOffset = float2(0.0, h + 0.003) * (y > 0.5 ? -1.0 : 1.0)
        let annotationAnchorVert = isAnnotationOnTop ? AnchorVert.Top : AnchorVert.Bottom
        drawStrAnchored(pos + annotationOffset, targetAnnotation, AnchorHorz.Center, annotationAnchorVert)


    restoreViewport()

  def drawEdges(padding : float2)
    drawLine(float2(-0.5, 0.5 + padding.y), float2(0.5, 0.5 + padding.y))
    drawLine(float2(-0.5 + padding.x, -0.5), float2(-0.5 + padding.x, 0.5))

  def draw()
    drawBackGround()

    let padding = float2(0.05, -0.1)

    setColor(lineColor)
    setFillColor(E3DCOLOR(0x00000000))

    drawEdges(padding)


    let size = toAbsXY(float2(1.0, -1.0) - padding)
    let pos = toAbsPos(float2(-0.5, 0.5) + padding)
    pushAxes(pos, size) // [-1, 1]

    drawMesh()
    drawScanAzimuth()
    drawTargets()

    popAxes()




[export]
def draw(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  new VerticalViewIndicator(ctx, rdata, rstate, data).draw()

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.maxHeight = props |> getFloat("maxHeight", 20.0)

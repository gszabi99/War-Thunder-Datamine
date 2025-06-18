require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require darg
require DagorStdGuiRender
require DagorMath
require math
require DagorSystem
require RadarHud
require app
require %rGui.utils.radar_common
require strings
require WTInput

struct CanvasParams
  fontId : int = -1
  fontSize : int = 20
  maxHeight : float = 20.0
  planeTargetPicture : Picture? = null
  helicopterTargetPicture : Picture? = null
  rocketTargetPicture : Picture? = null

def foreach_targets(blk : block<(target : RadarTarget const const#) : void>)
  get_radar_hud_targets() <| $(targets : array<RadarTarget> const#)
    for t in targets
      invoke(blk, t)


class VerticalViewIndicator : Canvas
  lineColor : E3DCOLOR = E3DCOLOR(0xFF37454D)
  textColor : E3DCOLOR = E3DCOLOR(0x99999999)
  targetColor : E3DCOLOR = E3DCOLOR(0xFF00FF07)

  def VerticalViewIndicator(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    setFont(data.fontId)
    setFontSize(data.fontSize)

  def azRelToX(azimuthRel : float)
    let azimuthMin = get_radar_hud_azimuth_min() * radToDeg
    let azimuthMax = get_radar_hud_azimuth_max() * radToDeg

    let angle = lerp(azimuthMin, azimuthMax, azimuthRel)
    let normed = norm_ang_deg(angle)
    return cvt(normed, 0.0, 360.0, 0.0, 1.0)

  def hieghtToY(height : float; params : CanvasParams&)
    let y = height / params.maxHeight * 0.001
    return clamp(y, 0.0, 1.0)

  def drawMesh(params : CanvasParams&)
    setColor(lineColor)
    setFillColor(E3DCOLOR(0x00000000))
    let azimuthMarkingsNum = 6
    for i in range(1, azimuthMarkingsNum)
      let x = float(i) / float(azimuthMarkingsNum)
      setColor(lineColor)
      drawLine(float2(x, 0.0), float2(x, 1.0))

      let ang = floori(360.0 * x)
      setColor(textColor)
      drawStrAnchored(float2(x, -0.03), "{ang}", AnchorHorz.Center, AnchorVert.Top)

    let elevationMarkingsNum = 4
    for i in range(1, elevationMarkingsNum)
      let y = float(i) / float(elevationMarkingsNum)
      setColor(lineColor)
      drawLine(float2(0.0, y), float2(1.0, y))
      let el = params.maxHeight * y
      setColor(textColor)
      drawStrAnchored(float2(-0.03, y), "{el}", AnchorHorz.Center, AnchorVert.Center)

    setColor(textColor)
    drawStrAnchored(float2(-0.03, -0.03), "0", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(-0.03, 0.99), "km", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(1.0, 0.0) - float2(0.005, 0.03), loc("hud/AAComplexMenu/azimuth"), AnchorHorz.Right, AnchorVert.Top)

  def drawScanAzimuth()
    let turretRel = get_radar_hud_turret_azimuth()
    let turretX = azRelToX(turretRel)
    setColor(lineColor)
    drawLine(float2(turretX, 0.0), float2(turretX, 1.0))

    let halfWidth = get_radar_hud_target_azimuth_width()
    if halfWidth > 0.0 && halfWidth < PI

      setFillColor(E3DCOLOR(0x00000000))
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

  def drawTargets(params : CanvasParams&)
    setFillColor(E3DCOLOR(0x00000000))
    setViewport(float2(0.0), float2(1.0))

    let mousePos = get_mouse_pos()
    let lt = toAbsPos(float2(0, 1.0))
    let rb = toAbsPos(float2(1.0, 0.0))
    let isMouseOnEllement = lt.x <= mousePos.x && mousePos.x <= rb.x && lt.y <= mousePos.y && mousePos.y <= rb.y
    var needToHandleMouseClick = is_mouse_btn_down(0) && isMouseOnEllement

    let targetCircleRadius = -0.02
    let absTargetCircleRadius = toAbsXY(float2(targetCircleRadius))
    let absTargetCircleRadiusSq = absTargetCircleRadius * absTargetCircleRadius
    let absTargetCircleDistanceSq = absTargetCircleRadiusSq.x + absTargetCircleRadiusSq.y

    foreach_targets() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        let x = azRelToX(target.azimuthRel)
        let y = hieghtToY(target.height, params)
        let pos = float2(x, y)

        let signalRel = target.signalRel < 0.01 ? 0.0 : cvt(target.signalRel, 0.3, 1.0, 0.5, 1.)
        let alphaColor = (1. - target.ageRel) * signalRel
        let col4 = float4(Color4(targetColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setColor(col)

        drawCircle(pos, -0.02)

        setColor(targetColor)

        let h = 0.025
        if target.isDetected
          let offset = 0.017
          drawLine(pos - float2(offset, h), pos + float2(-offset, h))
          drawLine(pos + float2(offset, h), pos + float2(offset, -h))

        let drawAbove = y < 0.5
        let anchorVert = drawAbove ? AnchorVert.Bottom : AnchorVert.Top
        let annotationOffset = float2(0.0, h + 0.01) * (drawAbove ? 1.0 : -1.0)
        let annotationPos = pos + annotationOffset

        var fctx : StdGuiFontContext
        get_font_context(fctx, font.id, 0, 0, font.size)

        let annotation = "{int(target.persistentIndex)}"

        let picture = Radar`getImageForTarget(target, params.planeTargetPicture, params.helicopterTargetPicture, params.rocketTargetPicture)
        if picture != null
          let annotationBox = get_str_bbox(annotation, annotation |> length(), fctx).width
          let pictureSize = float2(annotationBox.y * 1.5)
          drawStrAnchored(annotationPos, annotation, AnchorHorz.Left, anchorVert)

          let picturePos = toAbsPos(annotationPos) - pictureSize
          render_picture(*ctx, picture, picturePos, pictureSize, targetColor)
        else
          let offsetY = 0.0 // toRelY(drawAbove ? float(get_font_descent(fctx)) : float(get_font_ascent(fctx)))
          let targetIndexPos = annotationPos + float2(0.0, offsetY)
          drawStrAnchored(targetIndexPos, annotation, AnchorHorz.Center, anchorVert)

        if needToHandleMouseClick
          let absPos = toAbsPos(pos)
          let mouseToTargetSq = (absPos - mousePos) * (absPos - mousePos)
          let distSq = mouseToTargetSq.x + mouseToTargetSq.y
          let isPressed = distSq < absTargetCircleDistanceSq
          if isPressed
            radar_switch_to_target(target.sourceObjectId)
            needToHandleMouseClick = false

    restoreViewport()

  def drawEdges(padding : float2)
    drawLine(float2(-0.5, 0.5 + padding.y), float2(0.5, 0.5 + padding.y))
    drawLine(float2(-0.5 + padding.x, -0.5), float2(-0.5 + padding.x, 0.5))

  def draw(params : CanvasParams&)
    let padding = float2(0.05, -0.1)

    setColor(lineColor)
    setFillColor(E3DCOLOR(0x00000000))

    drawEdges(padding)


    let size = toAbsXY(float2(1.0, -1.0) - padding)
    let pos = toAbsPos(float2(-0.5, 0.5) + padding)
    pushAxes(pos, size) // [-1, 1]

    drawMesh(params)
    drawScanAzimuth()
    drawTargets(params)

    popAxes()


[export]
def draw(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; data : CanvasParams&)
  new VerticalViewIndicator(ctx, rdata, rstate, data).draw(data)

[export]
def setup(props : Properties&; var storage : CanvasParams&)
  storage.fontId = props |> getFontId()
  storage.fontSize = props |> getInt("fontSize", 20)
  storage.maxHeight = props |> getFloat("maxAltitude", 12.0)
  storage.planeTargetPicture = props |> getPicture("planeTargetPicture")
  storage.helicopterTargetPicture = props |> getPicture("helicopterTargetPicture")
  storage.rocketTargetPicture = props |> getPicture("rocketTargetPicture")
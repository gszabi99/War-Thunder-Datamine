require %rGui.utils.canvas_common
require %rGui.utils.radar_common
require DagorStdGuiRender
require DagorMath
require math
require hud
require darg
require RadarHud
require HeroManager
require FlightModelWrap
require Unit
require strings
require Sensors


def rgb(r, g, b : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0)))

def rgb(r, g, b, a : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, float(a) / 255.0)))


struct PropStorage
  fontId : int = 0
  screenRatio : float = 0.9

struct Props
  bgColor : E3DCOLOR = rgb(5, 5, 2)
  elementColor : E3DCOLOR = rgb(175, 25, 0)
  markingsColor : E3DCOLOR = rgb(175, 25, 0)

  elementsLineWidth : float = 3.0
  markingsLineWidth : float = 3.0

  radarBoxHalfSize : float2 = float2(0.34, 0.40)
  radarBoxPos : float2 = float2(0.0, -0.025)

  maxRangeKm : float = 30.0
  scaleMaxDistance : float = 15.0
  scaleY : float = 0.5

  columnOuterMarginFrac : float = 0.7
  columnInnerMarginFrac : float = 0.4

  anchorDistKm1 : float = 5.0
  anchorDistKm2 : float = 10.0
  distanceScaleRangeMin : float = 3.0
  distanceScaleRangeMax : float = 12.0
  scaleLineStartDistKm : float = 0.3

  markingsFontSize : int = 30


class Mig21Radar : Canvas
  params : PropStorage = PropStorage()
  props : Props = Props()

  hero : Unit?
  fmw : FlightModelWrap?

  hasLockedTarget : bool = false
  hasLockedDistance : bool = false
  lockedDistRel : float = 0.0

  leftColumn1x : float = 0.0
  leftColumn2x : float = 0.0
  rightColumn2x : float = 0.0
  rightColumn1x : float = 0.0

  def Mig21Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&; in_props : Props = Props())
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    params.fontId = in_params.fontId
    params.screenRatio = in_params.screenRatio
    props = in_props
    setFont(params.fontId)

    hero = get_watched_not_delayed_hero()
    fmw = as_fmw(hero)
    return if fmw == null

  def drawBackground()
    setFillColor(props.bgColor)
    setColor(props.bgColor)
    drawBox(leftTop(), rightBottom())

  def drawGround()
    let pos = toAbsPos(float2(0.0, 1.0))
    let size = toAbsXY(float2(1.0, -1.0))
    render_ground_reflection(*ctx, size, pos, props.elementColor, int2(20, 10), true)

  def drawRangeScale()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    let y20 = 20.0 / props.maxRangeKm
    let y10 = 10.0 / props.maxRangeKm

    let tickH = 0.1
    let gap = 0.01

    let lx = 0.0
    let rx = 1.0

    drawLine(float2(lx, y10), float2(lx - tickH, y10))
    drawStrAnchored(float2(lx - tickH - gap, y10), "10", AnchorHorz.Right, AnchorVert.Center)

    drawLine(float2(lx, y20), float2(lx - tickH, y20))
    drawStrAnchored(float2(lx - tickH - gap, y20), "20", AnchorHorz.Right, AnchorVert.Center)


    drawLine(float2(rx + tickH, y20), float2(rx, y20))
    drawStrAnchored(float2(rx + tickH + gap, y20), "20", AnchorHorz.Left, AnchorVert.Center)

    drawLine(float2(rx + tickH, y10), float2(rx, y10))
    drawStrAnchored(float2(rx + tickH + gap, y10), "10", AnchorHorz.Left, AnchorVert.Center)

    let maxRangePos = float2(0.5, 1.0)
    let maxRangeStr = "{roundi(props.maxRangeKm)}"
    let maxRangeBbox = getStrBbox(maxRangePos, maxRangeStr, AnchorHorz.Center, AnchorVert.Center)
    let bboxLeft = toRelPos(maxRangeBbox.leftTop).x
    let bboxRight = toRelPos(maxRangeBbox.rightBottom).x
    drawLine(float2(bboxLeft - gap - tickH, maxRangePos.y), float2(bboxLeft - gap, maxRangePos.y))
    drawLine(float2(bboxRight + gap, maxRangePos.y), float2(bboxRight + gap + tickH, maxRangePos.y))
    drawStrAnchored(maxRangePos, maxRangeStr, AnchorHorz.Center, AnchorVert.Center)

  def drawTargetSector()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFillColor(E3DCOLOR(0x00000000))

    let azimuthRange = max(0.0, get_radar_hud_azimuth_max() - get_radar_hud_azimuth_min())
    let rectHalfW = min(azimuthRange > 0.0 ? get_radar_hud_target_azimuth_width() / azimuthRange : 0.0, 0.5)
    let rectCx = get_radar_hud_turret_azimuth()
    let rectTop = get_radar_hud_target_distance()
    let rectBot = 0.0

    let halfGap = rectHalfW * 0.5
    drawLine(float2(rectCx - rectHalfW, rectTop), float2(rectCx - halfGap, rectTop))
    drawLine(float2(rectCx + halfGap, rectTop), float2(rectCx + rectHalfW, rectTop))
    drawLine(float2(rectCx - rectHalfW, rectBot), float2(rectCx - halfGap, rectBot))
    drawLine(float2(rectCx + halfGap, rectBot), float2(rectCx + rectHalfW, rectBot))
    drawLine(float2(rectCx - rectHalfW, rectTop), float2(rectCx - rectHalfW, rectBot))
    drawLine(float2(rectCx + rectHalfW, rectTop), float2(rectCx + rectHalfW, rectBot))

    drawStrAnchored(float2(0.5, rectBot), "0", AnchorHorz.Center, AnchorVert.Center)


  def drawCentralIndicator()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFillColor(E3DCOLOR(0x00000000))

    let cx = 0.5
    let circleR = 0.08

    let circleY = 0.5
    drawEllipse(float2(cx, circleY), float2(circleR, circleR * params.screenRatio))

    if hasLockedTarget
      let crossExt = circleR * 1.44
      setLineWidth(props.markingsLineWidth * 2.0)
      drawLine(float2(cx - crossExt, circleY), float2(cx + crossExt, circleY))
      setLineWidth(props.markingsLineWidth)
    else
      let crossS = circleR * 0.63
      drawLine(float2(cx - crossS, circleY), float2(cx + crossS, circleY))
    let crossV = circleR * 0.63 * params.screenRatio
    drawLine(float2(cx, circleY - crossV), float2(cx, circleY + crossV))

  def distScalePos(distKm : float; mirror : bool) : float2
    let clampedDistKm = clamp(distKm, props.distanceScaleRangeMin, props.distanceScaleRangeMax)
    let x = leftColumn1x + (leftColumn2x - leftColumn1x) * (clampedDistKm - props.anchorDistKm1) / (props.anchorDistKm2 - props.anchorDistKm1)
    return float2(mirror ? 1.0 - x : x, props.scaleY)

  def drawDistanceScaleSide(mirror : bool)
    let vtH = 0.045
    let p0 = distScalePos(props.scaleLineStartDistKm, mirror) + float2(0.01 * (mirror ? -1.0 : 1.0), 0.0)
    let pEnd = distScalePos(props.scaleMaxDistance, mirror) + float2(0.01 * (mirror ? 1.0 : -1.0), 0.0)

    let p5 = distScalePos(props.anchorDistKm1, mirror)
    let p10 = distScalePos(props.anchorDistKm2, mirror)
    drawLine(float2(p5.x, p5.y - vtH), float2(p5.x, p5.y + vtH))
    drawLine(float2(p10.x, p10.y - vtH), float2(p10.x, p10.y + vtH))
    drawStrAnchored(float2(p5.x, p5.y - vtH - 0.02), "5", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(p10.x, p10.y - vtH - 0.02), "10", AnchorHorz.Center, AnchorVert.Top)

    if hasLockedDistance
      setLineWidth(props.markingsLineWidth * 2.0)
      drawLine(p0, pEnd)
      setLineWidth(props.markingsLineWidth)

      setColor(props.elementColor)
      setFillColor(props.elementColor)
      let distKm = lockedDistRel * props.maxRangeKm
      drawPointerTriangle(distScalePos(distKm, mirror))
      setColor(props.markingsColor)

  def drawDistanceScale()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)
    drawDistanceScaleSide(false)
    drawDistanceScaleSide(true)

  def drawPointerTriangle(pos : float2)
    let triH = 0.04
    let triHalfW = 0.017
    let tip = float2(pos.x, pos.y + triH)
    drawFilledPoly([tip, float2(pos.x - triHalfW, pos.y), float2(pos.x + triHalfW, pos.y)])

  def drawBottomTriangles()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)

    let triHalfW = 0.04
    let triH = -toRelY(toAbsX(triHalfW) * 1.73 * params.screenRatio)

    let outerY = 0.1 - triH * 2.0 / 3.0
    let innerY = 0.0 - triH * 2.0 / 3.0
    let centers = fixed_array(
      float2(leftColumn1x, outerY),
      float2(leftColumn2x, innerY),
      float2(rightColumn2x, innerY),
      float2(rightColumn1x, outerY))
    for center in centers
      let apexY = center.y + triH * 2.0 / 3.0
      let baseY = center.y - triH / 3.0
      drawLine(float2(center.x, apexY), float2(center.x - triHalfW, baseY))
      drawLine(float2(center.x, apexY), float2(center.x + triHalfW, baseY))
      drawLine(float2(center.x - triHalfW, baseY), float2(center.x + triHalfW, baseY))


  def drawLevelSymbol(pos : float2)
    let s = 0.024
    drawLine(pos - float2(s, 0.0), pos + float2(s, 0.0))
    drawLine(pos - float2(0.0, s), pos + float2(0.0, s))

  def drawAboveSymbol(pos : float2)
    let hw = 0.024
    let hh = 0.02
    drawLine(pos - float2(0.0, hh), pos + float2(0.0, hh))
    drawLine(pos + float2(-hw, hh), pos + float2(hw, hh))

  def drawBelowSymbol(pos : float2)
    let hw = 0.024
    let hh = 0.02
    drawLine(pos - float2(0.0, hh), pos + float2(0.0, hh))
    drawLine(pos + float2(-hw, -hh), pos + float2(hw, -hh))


  def drawTargets()
    Radar`foreach_visible_target() <| $(var target)
      if target.targetType == int(RadarTargetType.TYPE_TARGET)
        let hasDist = get_radar_hud_has_distance_scale() && target.distanceRel >= 0.
        var distanceRel = 0.0
        if hasDist
          distanceRel = target.distanceRel

        var azimuthRel = 0.0
        if get_radar_hud_has_azimuth_scale()
          azimuthRel = target.azimuthRel

        let signalRel = target.signalRel < 0.01 ? 0. : cvt(target.signalRel, 0.05, 1., 0.3, 1.)
        let alphaColor = (1. - target.ageRel) * signalRel

        let elev = target.elevationRel

        let targetPos = float2(azimuthRel, target.isSelected ? elev : distanceRel)

        let col4 = float4(Color4(props.elementColor)) * alphaColor
        let col = E3DCOLOR(Color4(col4))
        setColor(col)
        setLineWidth(props.markingsLineWidth)

        if elev > 0.6 && !target.isSelected
          drawBelowSymbol(targetPos)
        elif elev < 0.4 && !target.isSelected
          drawAboveSymbol(targetPos)
        else
          drawLevelSymbol(targetPos)

        if target.isSelected
          hasLockedTarget = true
          hasLockedDistance = hasDist
          lockedDistRel = distanceRel



  def drawMarkings()
    setColor(props.markingsColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWidth)

    drawRangeScale()
    drawCentralIndicator()
    drawTargetSector()
    drawDistanceScale()
    drawBottomTriangles()


  def drawHud()
    drawGround()
    setLineWidth(props.elementsLineWidth)
    drawTargets()


  def draw()
    return if hero == null
    setFullCanvasViewport()
    drawBackground()

    let lt = props.radarBoxPos - props.radarBoxHalfSize
    let rb = props.radarBoxPos + props.radarBoxHalfSize
    pushLocalAxes(float2(lt.x, rb.y), (rb - lt) * float2(1.0, -1.0))

    let halfCanvasPx = canvasSize.x * 0.5
    leftColumn1x = 0.5 - toRelX(halfCanvasPx * props.columnOuterMarginFrac)
    leftColumn2x = 0.5 - toRelX(halfCanvasPx * props.columnInnerMarginFrac)
    rightColumn2x = 0.5 + toRelX(halfCanvasPx * props.columnInnerMarginFrac)
    rightColumn1x = 0.5 + toRelX(halfCanvasPx * props.columnOuterMarginFrac)

    drawHud()
    drawMarkings()
    popAxes()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Mig21Radar(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
  propStorage.screenRatio = props |> getFloat("screenRatio", 0.9)

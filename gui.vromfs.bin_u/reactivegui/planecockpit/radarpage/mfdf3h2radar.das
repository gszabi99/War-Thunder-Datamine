require %rGui.planeCockpit.radarPage.F101RadarBase_common
require %rGui.utils.canvas_common
require DagorStdGuiRender
require DagorMath
require darg
require strings


def make_f3h2_props()
  var p = Props()
  p.elementsLineWidth = 3.5
  p.markingsLineWidth = 2.0
  p.radarBoxHalfSize = float2(0.335, 0.335)
  p.radarBoxPos = float2(0.0, 0.0)
  p.displayRadius = 0.5
  return p


class F3H2Radar : F101RadarBase

  def F3H2Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&)
    F101RadarBase`F101RadarBase(self, guiCtx, rdata, rstate, in_params, make_f3h2_props())

  def drawOuterRing()
    let r = props.displayRadius
    let tickLen = r * 0.125
    let lblR = r - 0.020
    let tickOuterR = r - 0.038

    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth + 0.5)
    drawArc(r, 0.0, 360.0, 64)

    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    var angle = 0.0
    for _ in range(12)
      if angle != 90.0
        let pOuter = circlePoint(angle, tickOuterR)
        let pInner = circlePoint(angle, tickOuterR - tickLen)
        drawLine(pOuter, pInner)
      angle += 30.0

    drawStrAnchored(circlePoint(270.0, lblR), "9", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(circlePoint(180.0, lblR), "6", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(circlePoint(90.0,  lblR), "3", AnchorHorz.Center, AnchorVert.Center)

  def drawOpeningClosing()
    let r = props.displayRadius
    let baseR = r * 0.88
    let charDeg = 4.2
    let halfSpan = 3.0 * charDeg
    setColor(props.markingsColor)
    setFontSize(props.smallFontSize)

    let opening = fixed_array<string>("O", "P", "E", "N", "I", "N", "G")
    for idx in range(7)
      let charAngle = 345.0 - halfSpan + float(idx) * charDeg
      drawStrAnchored(circlePoint(charAngle, baseR), opening[idx], AnchorHorz.Center, AnchorVert.Center)

    let closing = fixed_array<string>("C", "L", "O", "S", "I", "N", "G")
    for idx in range(7)
      let charAngle = 15.0 - halfSpan + float(idx) * charDeg
      drawStrAnchored(circlePoint(charAngle, baseR), closing[idx], AnchorHorz.Center, AnchorVert.Center)

  def drawCenterGroup()
    let r = props.displayRadius
    let innerR = r * 0.24
    let dotR = r * 0.04
    let vUp = r * 0.34
    let vDown = r * 0.29
    let hLen = r * 0.30

    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)

    setFillColor(E3DCOLOR(0x00000000))
    drawArc(innerR, 0.0, 360.0, 48)
    drawArc(dotR, 0.0, 360.0, 24)

    drawLine(float2(-hLen, 0.0), float2(-dotR, 0.0))
    drawLine(float2(dotR, 0.0),  float2(hLen, 0.0))

    drawLine(float2(0.0, -vUp), float2(0.0, -dotR))
    drawLine(float2(0.0, dotR), float2(0.0, vDown))

    setFontSize(props.markingsFontSize)
    let lbl2pos = circlePoint(57.0, r * 0.16)
    drawStrAnchored(lbl2pos, "2", AnchorHorz.Center, AnchorVert.Center)

  def drawCenterVerticalScale()
    let r = props.displayRadius

    let majorTickW = 0.022
    let minorTickW = 0.014
    let lblOfsX = majorTickW + 0.006

    let y20 = -(r * 0.67)
    let y15 = -(r * 0.53)
    let y10 = -(r * 0.34)

    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    drawLine(float2(0.0, y20), float2(majorTickW, y20))
    drawStrAnchored(float2(lblOfsX, y20), "20", AnchorHorz.Left, AnchorVert.Center)

    drawLine(float2(0.0, y15), float2(minorTickW, y15))

    drawLine(float2(0.0, y10), float2(majorTickW, y10))
    drawStrAnchored(float2(lblOfsX, y10), "10", AnchorHorz.Left, AnchorVert.Center)

  def drawRightVerticalScale()
    let r = props.displayRadius

    let colX = r * 0.77
    let majorTickLen = 0.025
    let minorTickLen = 0.014
    let lblOfsX = majorTickLen + 0.008

    let topY = -(r * 0.34)
    let botY =  r * 0.34
    let step = (botY - topY) / 4.0

    let labels = fixed_array<int>(10, 5, 0, 5, 10)

    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    for lIdx in range(5)
      let y = topY + float(lIdx) * step

      drawLine(float2(colX, y), float2(colX - majorTickLen, y))
      drawStrAnchored(float2(colX + lblOfsX, y), fmt(":d", labels[lIdx]), AnchorHorz.Left, AnchorVert.Center)

      if lIdx < 4
        let nextY = topY + float(lIdx + 1) * step
        let minorStep = (nextY - y) / 5.0
        for mIdx in range(1, 5)
          let my = y + float(mIdx) * minorStep
          drawLine(float2(colX, my), float2(colX - minorTickLen, my))

  def override drawMarkings()
    setColor(props.markingsColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWidth)

    drawOuterRing()
    drawOpeningClosing()
    drawCenterGroup()
    drawCenterVerticalScale()
    drawRightVerticalScale()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new F3H2Radar(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)

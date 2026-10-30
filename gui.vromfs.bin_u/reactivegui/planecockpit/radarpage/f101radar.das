require %rGui.planeCockpit.radarPage.F101RadarBase_common
require %rGui.utils.canvas_common
require DagorStdGuiRender
require DagorMath
require math
require darg
require strings


class F101Radar : F101RadarBase

  def F101Radar(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_params : PropStorage&)
    F101RadarBase`F101RadarBase(self, guiCtx, rdata, rstate, in_params)

  def drawDisplayCircle()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth + 0.5)
    let r1 = props.displayRadius
    let r2 = 0.398
    let r3 = 0.428
    drawArc(r1, 0.0, 360.0, 64)
    drawArc(r2, 0.0, 360.0, 64)
    drawArc(r3, 0.0, 360.0, 64)

  def draw2000YardScale()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.smallFontSize)

    let r = props.displayRadius

    setFontSize(props.markingsFontSize)
    drawStrAnchored(float2(0.0, -r + 0.015), "0", AnchorHorz.Center, AnchorVert.Center)

    let tickLen0 = 0.0255
    let tickTop0 = -r + 0.03
    drawLine(float2(0.0, tickTop0), float2(0.0, tickTop0 + tickLen0))

    let lineX = -0.008
    let tickW = 0.012
    let y20 = -0.252
    let y10 = -0.125
    let y2  = -0.042

    drawLine(float2(lineX, y20), float2(lineX, y2))

    drawLine(float2(lineX, y20), float2(lineX + tickW, y20))
    drawLine(float2(lineX, y10), float2(lineX + tickW, y10))
    drawLine(float2(lineX, y2),  float2(lineX + tickW, y2))

    drawStrAnchored(float2(lineX + tickW + 0.005, y20), "20", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(lineX + tickW + 0.005, y10), "10", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(lineX + tickW + 0.005, y2),  "2",  AnchorHorz.Left, AnchorVert.Center)

  def draw6MileScale()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    let r = props.displayRadius
    let horizLen = 0.03

    let tickDist = 0.081
    let p4y = -tickDist
    let p4x = -sqrt(r * r - p4y * p4y)
    let p4 = float2(p4x, p4y)
    drawLine(p4, p4 - float2(horizLen, 0.0))
    drawStrAnchored(p4 - float2(horizLen + 0.015, 0.0), "4", AnchorHorz.Center, AnchorVert.Center)

    let p2y = tickDist
    let p2x = -sqrt(r * r - p2y * p2y)
    let p2 = float2(p2x, p2y)
    drawLine(p2, p2 - float2(horizLen, 0.0))
    drawStrAnchored(p2 - float2(horizLen + 0.015, 0.0), "2", AnchorHorz.Center, AnchorVert.Center)

    let pExTy = -tickDist * 2.4
    let pExTx = -sqrt(r * r - pExTy * pExTy)
    let pExT = float2(pExTx, pExTy)
    drawLine(pExT, pExT - float2(horizLen, 0.0))

    let pExBy = tickDist * 2.4
    let pExBx = -sqrt(r * r - pExBy * pExBy)
    let pExB = float2(pExBx, pExBy)
    drawLine(pExB, pExB - float2(horizLen, 0.0))

    let milesX = min(p4.x, p2.x) - horizLen - 0.015
    let milesMid = 0.0
    let sp = 0.025
    drawStrAnchored(float2(milesX, milesMid - sp * 2.0), "M", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(milesX, milesMid - sp),        "I", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(milesX, milesMid),              "L", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(milesX, milesMid + sp),         "E", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(milesX, milesMid + sp * 2.0),   "S", AnchorHorz.Center, AnchorVert.Center)

    let chevronHalf = 4.0
    let chevronDepth = 0.04
    let pTop = circlePoint(270.0 - chevronHalf, r)
    let pBot = circlePoint(270.0 + chevronHalf, r)
    let pTip = circlePoint(270.0, r - chevronDepth)
    drawLine(pTop, pTip)
    drawLine(pBot, pTip)

  def drawUpperAzimuthScale()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    let r = props.displayRadius
    let tickLen = 0.025

    let angles = fixed_array<float>(-20.0, -10.0, 0.0, 10.0, 20.0)
    for a in angles
      let pOn = circlePoint(a, r)
      drawLine(pOn, pOn - float2(0.0, tickLen))

    let leftTickBase = circlePoint(-20.0, r)
    let horizLen = 0.042
    drawLine(leftTickBase, leftTickBase - float2(horizLen, 0.0))
    drawStrAnchored(leftTickBase - float2(horizLen + 0.02016, 0.0), "6", AnchorHorz.Center, AnchorVert.Center)

  def drawLowerAzimuthScale()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    let r = props.displayRadius
    let tickLen = 0.025 * 0.7

    let angles = fixed_array<float>(160.0, 170.0, 190.0, 200.0)
    for a in angles
      let pOn = circlePoint(a, r)
      drawLine(pOn, pOn + float2(0.0, tickLen))

    let labels = fixed_array<int>(60, 30, 30, 60)
    for idx in range(0, 4)
      let pOn = circlePoint(angles[idx], r)
      drawStrAnchored(pOn + float2(0.0, tickLen + 0.012), fmt(":d", labels[idx]), AnchorHorz.Center, AnchorVert.Center)

    let azPos = circlePoint(180.0, r)
    drawStrAnchored(azPos + float2(0.0, 0.015), "AZ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(azPos + float2(0.0, 0.035), "0", AnchorHorz.Center, AnchorVert.Center)

  def drawRangeRateTicks()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.smallFontSize)

    let r = props.displayRadius - 0.01
    let tickLen = 0.0255

    let clockAngles = fixed_array<float>(315.0, 45.0, 135.0, 180.0, 225.0)
    let clockLabels = fixed_array<int>(-100, 100, 300, 400, 500)

    let shortTickLen = tickLen * 0.5

    for idx in range(0, 5)
      let a = clockAngles[idx]
      let val = clockLabels[idx]
      let valStr = fmt(":d", val)

      if val == 300 || val == 500
        let tickStart = circlePoint(a, r)
        let tickEnd = circlePoint(a, r - shortTickLen)
        drawLine(tickStart, tickEnd)
        let textPos = circlePoint(a, r - shortTickLen - 0.015)
        drawStrAnchored(textPos, valStr, AnchorHorz.Center, AnchorVert.Center)
      else
        let textPos = circlePoint(a, r - 0.015)
        drawStrAnchored(textPos, valStr, AnchorHorz.Center, AnchorVert.Center)
        let tickOuter = circlePoint(a, r - 0.03)
        let tickInner = circlePoint(a, r - 0.03 - tickLen)
        drawLine(tickOuter, tickInner)

    let rOuter = props.displayRadius
    let p500base = circlePoint(225.0, rOuter)
    let p500y = p500base.y * 1.15
    let p500x = -sqrt(rOuter * rOuter - p500y * p500y)
    let p500 = float2(p500x, p500y)
    let horizLen500 = 0.03
    drawLine(p500, p500 - float2(horizLen500, 0.0))
    drawStrAnchored(p500 - float2(horizLen500 + 0.012, 0.0), "0", AnchorHorz.Center, AnchorVert.Center)

  def draw200_30Scale()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    let r = props.displayRadius
    let a100 = 45.0

    let pBase = circlePoint(a100, r)
    let vertLen = 0.05
    let pTop = pBase - float2(0.0, vertLen)
    drawLine(pBase, pTop)

    let horizLen = 0.04
    let horizY = pTop.y + 0.036
    drawLine(float2(pTop.x, horizY), float2(pTop.x + horizLen, horizY))

    drawStrAnchored(float2(pTop.x + horizLen * 0.5, horizY - 0.015), "200", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(pTop.x + horizLen * 0.5 + 0.015, horizY + 0.015), "30", AnchorHorz.Center, AnchorVert.Center)

  def drawRightScale()
    setColor(props.markingsColor)
    setLineWidth(props.markingsLineWidth)
    setFontSize(props.markingsFontSize)

    let r = props.displayRadius
    let horizLen = 0.03

    let tickDist = 0.081
    let p20y = -tickDist
    let p20x = sqrt(r * r - p20y * p20y)
    let p20 = float2(p20x, p20y)
    drawLine(p20, p20 + float2(horizLen, 0.0))
    drawStrAnchored(p20 + float2(horizLen + 0.015, 0.0), "20", AnchorHorz.Center, AnchorVert.Center)

    let p50ty = -tickDist * 1.68
    let p50tx = sqrt(r * r - p50ty * p50ty)
    let p50t = float2(p50tx, p50ty)
    drawLine(p50t, p50t + float2(horizLen, 0.0))
    let sp50 = 0.018
    drawStrAnchored(p50t + float2(horizLen + 0.012, -sp50 * 0.5), "5", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(p50t + float2(horizLen + 0.012,  sp50 * 0.5), "0", AnchorHorz.Center, AnchorVert.Center)

    let pExTy = -tickDist * 2.36
    let pExTx = sqrt(r * r - pExTy * pExTy)
    let pExT = float2(pExTx, pExTy)
    drawLine(pExT, pExT + float2(horizLen, 0.0))

    let p10y = tickDist
    let p10x = sqrt(r * r - p10y * p10y)
    let p10 = float2(p10x, p10y)
    drawLine(p10, p10 + float2(horizLen, 0.0))
    drawStrAnchored(p10 + float2(horizLen + 0.015, 0.0), "10", AnchorHorz.Center, AnchorVert.Center)

    let p50by = tickDist * 1.68
    let p50bx = sqrt(r * r - p50by * p50by)
    let p50b = float2(p50bx, p50by)
    drawLine(p50b, p50b + float2(horizLen, 0.0))
    drawStrAnchored(p50b + float2(horizLen + 0.015, 0.0), "50", AnchorHorz.Center, AnchorVert.Center)

    let pExBy = rb.y
    let pExBx = sqrt(r * r - pExBy * pExBy)
    let pExB = float2(pExBx, pExBy)
    drawLine(pExB, pExB + float2(horizLen, 0.0))
    drawStrAnchored(pExB + float2(horizLen + 0.015, 0.0), "0", AnchorHorz.Center, AnchorVert.Center)

    let milesX = max(p20.x, p10.x) + horizLen + 0.015
    let milesMid = 0.0
    let sp = 0.025
    drawStrAnchored(float2(milesX, milesMid - sp * 2.0), "M", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(milesX, milesMid - sp),        "I", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(milesX, milesMid),              "L", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(milesX, milesMid + sp),         "E", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(milesX, milesMid + sp * 2.0),   "S", AnchorHorz.Center, AnchorVert.Center)

    let chevronHalf = 4.0
    let chevronDepth = 0.04
    let pTop = circlePoint(90.0 - chevronHalf, r)
    let pBot = circlePoint(90.0 + chevronHalf, r)
    let pTip = circlePoint(90.0, r - chevronDepth)
    drawLine(pTop, pTip)
    drawLine(pBot, pTip)

  def drawCenterDots()
    setColor(props.markingsColor)
    setFillColor(props.markingsColor)
    let dotR = 0.005
    drawCircle(float2(0.0, 0.042), dotR)
    drawCircle(float2(0.0, 0.125), dotR)
    drawCircle(float2(0.0, 0.252), dotR)

  def override drawMarkings()
    setColor(props.markingsColor)
    setFontSize(props.markingsFontSize)
    setLineWidth(props.markingsLineWidth)

    drawDisplayCircle()
    draw2000YardScale()
    draw6MileScale()
    drawUpperAzimuthScale()
    drawLowerAzimuthScale()
    drawRangeRateTicks()
    drawRightScale()
    draw200_30Scale()
    drawCenterDots()

    let centralOffset = 0.03
    let lineLength = 0.06
    drawLine(props.radarBoxPos - float2(lineLength + centralOffset, 0), props.radarBoxPos - float2(centralOffset, 0))
    drawLine(props.radarBoxPos + float2(lineLength + centralOffset, 0), props.radarBoxPos + float2(centralOffset, 0))


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new F101Radar(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)

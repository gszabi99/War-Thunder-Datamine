module canvas_common
require darg
require DagorStdGuiRender
require DagorMath
require DagorSystem
require math
require strings
require %rGui.utils.helpers_common

def draw_horizontal_label(var ctx : GuiContext&; pos : float2; text : string)
  ctx |> goto_xy(pos.x, pos.y)
  ctx |> draw_str_scaled(1.0, text, text |> length())

def draw_vertical_label(var ctx : GuiContext&; pos : float2; text : string; ht : float)
  ctx |> goto_xy(pos.x, pos.y)
  for c, i in text, range(0, length(text))
    ctx |> draw_char_u(uint16(c))
    ctx |> goto_xy(pos.x, pos.y + ht * float(i + 1))

enum AnchorHorz
  Left
  Center
  Right

enum AnchorVert
  Top
  Center
  Bottom

struct AxesState
  origin : float2
  scale : float2

struct Font
  id : int
  size : int

class Canvas
  ctx : GuiContext?
  rdata : ElemRenderData const?
  rstate : RenderState const?
  color : E3DCOLOR
  fillColor : E3DCOLOR
  lineWidth : float
  lineWidthHdpx : float
  font : Font
  lineSpacing : float
  canvasPos : float2
  canvasSize : float2
  axesOrigin : float2
  axesScale : float2
  axesStates : array<AxesState>
  textAnchorHorz : AnchorHorz

  def Canvas(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const)
    self.ctx = unsafe(addr(ctx))
    self.rdata = unsafe(addr(rdata))
    self.rstate = unsafe(addr(rstate))
    color = E3DCOLOR(0xFFFFFFFF)
    fillColor = E3DCOLOR(0x0)
    lineWidth = 1.0
    lineWidthHdpx = hdpx(ctx, 1.0)
    font.id = 0
    font.size = 16
    lineSpacing = 1.0
    canvasPos = rdata.pos
    canvasSize = rdata.size
    resetAxes()


// ****************************************************************************
// ***   Relative Axes Methods   **********************************************
// ****************************************************************************

  /*
    Set the origin and scale of the axes. The origin is the position of the axes
    in the canvas space. The scale is the size of the axes in the canvas space.
    Examples:

    // Sets (0.0, 1.0) axes in the top-left of the canvas where 1.0 - is the canvas size by corresponding axis
      setAxes(canvasPos, canvasSize)
      drawLine(float2(0.0, 0.0), float2(1.0, 1.0))

    // Sets (-0.5, +0.5) axes in the center of the canvas where 1.0 - is the canvas height (isotropic scale)
      setAxes(canvasPos + 0.5 * canvasSize, float2(canvasSize.y))
      drawLine(float2(-0.5, -0.5), float2(0.5, 0.5))

    // Sets (0.0, 100.0) axes in the top-left of the canvas where 100.0 - is the canvas size by corresponding axis
    setAxes(canvasPos, 0.01 * canvasSize)
    drawLine(float2(0.0, 0.0), float2(100.0, 100.0))
  */
  def setAxes(origin : float2; scale : float2)
    axesOrigin = origin
    axesScale = scale


  def setOrigin(origin : float2)
    axesOrigin = origin


  def setScale(scale : float2)
    axesScale = scale


  def pushAxes(origin : float2; scale : float2)
    axesStates.push([[AxesState origin = axesOrigin, scale = axesScale]])
    setAxes(origin, scale)


  def popAxes()
    if axesStates.empty()
      return

    let state = axesStates.back()
    axesStates.pop()
    setAxes(state.origin, state.scale)


  def resetAxes()
    axesOrigin = canvasPos + 0.5 * canvasSize
    axesScale = canvasSize
    axesStates.clear()


  def toAbsX(rel : float) : float
    return axesScale.x * rel


  def toAbsY(rel : float) : float
    return axesScale.y * rel


  def toAbsXY(relXY : float2) : float2
    return axesScale * relXY


  def toAbsPos(relPos : float2) : float2
    return axesOrigin + toAbsXY(relPos)


  def toRelX(abs : float) : float
    return abs / axesScale.x


  def toRelY(abs : float) : float
    return abs / axesScale.y


  def toRelXY(absXY : float2) : float2
    return absXY / axesScale


  def toRelPos(absPos : float2) : float2
    return (absPos - axesOrigin) / axesScale


  def leftTop()
    return toRelPos(canvasPos)

  def rightBottom()
    return toRelPos(canvasPos + canvasSize)

// ****************************************************************************
// ***   Common Methods   *****************************************************
// ****************************************************************************


  def setColor(color : E3DCOLOR)
    set_color(*ctx, color)
    self.color = color


  def setFullCanvasViewport()
    set_viewport(*ctx, canvasPos.x, canvasPos.y, canvasPos.x + canvasSize.x, canvasPos.y + canvasSize.y)


  def setViewport(lt : float2; rb : float2)
    let ltAbs = toAbsPos(lt)
    let rbAbs = toAbsPos(rb)
    set_viewport(*ctx, ltAbs.x, ltAbs.y, rbAbs.x, rbAbs.y)


  def restoreViewport()
    restore_viewport(*ctx)


  def setRotation(pos : float2; angle : float)
    var sina, cosa : float
    sincos(angle, sina, cosa)
    let ax = rotate(float2(1.0, 0.0), sina, cosa)
    let ay = float2(-ax.y, ax.x)
    let absPos = toAbsPos(pos)
    setRotViewTm(*ctx, absPos.x, absPos.y, angle, 0.0, false)


  def resetViewTm()
    resetViewTm(*ctx)


  def isOutOfCanvas(pos : float2; margin : float2 = float2(0.0))
    let lt = leftTop() + margin
    let rb = rightBottom() - margin
    return pos.x < lt.x || pos.x > rb.x || pos.y < lt.y || pos.y > rb.y


  def traceRayToCanvasEdges(pos : float2; dir : float2; margin : float2 = float2(0.0))
    let lt = leftTop() + margin
    let rb = rightBottom() - margin

    var tx : float
    if dir.x > 0.0
      tx = (rb.x - pos.x) / dir.x
    elif dir.x < 0.0
      tx = (lt.x - pos.x) / dir.x
    else
      tx = 1e10

    var ty : float
    if dir.y > 0.0
      ty = (rb.y - pos.y) / dir.y
    elif dir.y < 0.0
      ty = (lt.y - pos.y) / dir.y
    else
      ty = 1e10

    return min(tx, ty);


// ****************************************************************************
// ***   Graphics Methods   ***************************************************
// ****************************************************************************

  def setFillColor(color : E3DCOLOR)
    fillColor = color


  def setLineWidth(width : float)
    lineWidth = width
    lineWidthHdpx = hdpx(*ctx, width)


  def drawDot(pos : float2)
    let absPos = toAbsPos(pos)
    let halfSize = float2(0.75 * lineWidthHdpx)
    let lt = absPos - halfSize
    let rb = absPos + halfSize
    render_box(*ctx, lt.x, lt.y, rb.x, rb.y)


  def drawLine(from : float2; to : float2)
    let line <- to_array_move([[float2[2] toAbsPos(from); toAbsPos(to)]])
    render_line_aa(*ctx, line, false, lineWidthHdpx, float2(0.0), color)


  def drawDashedLine(from : float2; to : float2; dash : float; space : float)
    render_line_dashed(*ctx, toAbsPos(from), toAbsPos(to), toAbsY(dash), toAbsY(space), lineWidthHdpx, color)


  def drawPolyLine(verts : array<float2>)
    for i in range(0..length(verts) - 1)
      drawLine(verts[i], verts[i + 1])


  def drawClosedPolyLine(verts : array<float2>)
    var len = length(verts)
    for i0 in range(0..len)
      let i1 = (i0 + 1) % len
      drawLine(verts[i0], verts[i1])


  def drawDashedPolyLine(verts : array<float2>; dash : float; space : float)
    for i in range(0..length(verts) - 1)
      drawDashedLine(verts[i], verts[i + 1], dash, space)


  def drawDashedClosedPolyLine(verts : array<float2>; dash : float; space : float)
    var len = length(verts)
    for i0 in range(0..len)
      let i1 = (i0 + 1) % len
      drawDashedLine(verts[i0], verts[i1], dash, space)


  def drawFilledPoly(verts : array<float2>)
    var finalVerts <- [{for v in verts; toAbsPos(v)}]
    render_poly(*ctx, finalVerts, color)


  def drawBox(lt : float2; rb : float2)
    render_rectangle_aa(*ctx, toAbsPos(lt), toAbsPos(rb), lineWidthHdpx, color, fillColor)


  def drawRoundedBox(lt : float2; rb : float2; rounding : float4)
    render_rounded_box(*ctx, toAbsPos(lt), toAbsPos(rb), fillColor, color, axesScale.y * rounding, lineWidthHdpx)


  def drawEllipse(pos : float2; radius : float2)
    render_ellipse_aa(*ctx, toAbsPos(pos), toAbsXY(radius), lineWidthHdpx, color, fillColor)


  def drawCircle(pos : float2; radius : float)
    render_ellipse_aa(*ctx, toAbsPos(pos), float2(toAbsY(radius)), lineWidthHdpx, color, fillColor)


  def drawSector(pos : float2; radius : float2; angles : float2)
    render_sector_aa(*ctx, toAbsPos(pos), toAbsXY(radius), angles, lineWidthHdpx, color, fillColor)


  def drawDashedRect(pos : float2; sizeRel : float2; dashRel : float2; spaceRel : float2; rotation : float = 0.0)
    var sina, cosa : float
    sincos(rotation, sina, cosa)
    let halfSize = 0.5 * sizeRel
    let lt = pos + rotate(float2(-halfSize.x, -halfSize.y), sina, cosa)
    let rt = pos + rotate(float2(halfSize.x, -halfSize.y), sina, cosa)
    let lb = pos + rotate(float2(-halfSize.x, halfSize.y), sina, cosa)
    let rb = pos + rotate(float2(halfSize.x, halfSize.y), sina, cosa)
    drawDashedLine(lt, rt, dashRel.x, spaceRel.x)
    drawDashedLine(rt, rb, dashRel.y, spaceRel.y)
    drawDashedLine(rb, lb, dashRel.x, spaceRel.x)
    drawDashedLine(lb, lt, dashRel.y, spaceRel.y)


  def drawDashedEllipse(pos : float2; radiusRel : float2; dashAngle : float; spaceAngle : float; firstDashAngle : float = 0.0)
    var angles = float2(firstDashAngle, firstDashAngle + dashAngle)
    while angles.y < firstDashAngle + 2.0 * PI
      drawSector(pos, float2(radiusRel), angles)
      angles += float2(dashAngle + spaceAngle)


  def drawCrossReticle(pos : float2; outerSize : float2; innerSize : float2)
    let outerHalfSize = 0.5 * outerSize
    let innerHalfSize = 0.5 * innerSize
    drawLine(pos + float2(innerHalfSize.x, 0.0), pos + float2(outerHalfSize.x, 0.0))
    drawLine(pos - float2(innerHalfSize.x, 0.0), pos - float2(outerHalfSize.x, 0.0))
    drawLine(pos + float2(0.0, innerHalfSize.y), pos + float2(0.0, outerHalfSize.y))
    drawLine(pos - float2(0.0, innerHalfSize.y), pos - float2(0.0, outerHalfSize.y))


  def drawArrowHead(pos : float2; dir : float2; size : float2)
    let right = float2(-dir.y, dir.x)
    let halfSize = 0.5 * size
    let rightWing = right * halfSize.x - dir * halfSize.y
    let leftWing = -right * halfSize.x - dir * halfSize.y
    drawLine(pos, pos + rightWing)
    drawLine(pos, pos + leftWing)


  def drawCross(pos : float2; size : float2)
    let halfSize = 0.5 * size
    drawLine(pos + halfSize, pos - halfSize)
    drawLine(float2(pos.x - halfSize.x, pos.y + halfSize.y), float2(pos.x + halfSize.x, pos.y - halfSize.y))


// ****************************************************************************
// ***   Text Methods   *******************************************************
// ****************************************************************************

  // TODO: move current font params into the Font struct to avoid name collisions
  def setFont(fontId : int)
    set_font(*ctx, fontId, 0, 0)
    font.id = fontId


/*
  Can adjust caret position to keep the correct line spacing for the next line after println
  Example:
    setFontSize(32)
    println("Big characters") // The caret position goes 32 pixels down
    setFontSize(22, true) // Will adjust caret position by 10 pixels up
    print("Small characters") // Text will be printed with correct line spacing

  Can be used as well to have top aligned strings of different font sizes printed in line
  Example:
    setFontSize(32)
    print("Big characters")
    setFontSize(22, true) // Will adjust caret position by 10 pixels up
    println("Smal characters") // Text will be top aligned with the previous one
*/
  def setFontSize(fontSize : int; adjustCaretPosition : bool = false)
    if adjustCaretPosition
      var fctx : StdGuiFontContext
      get_font_context(fctx, font.id, 0, 0, font.size)
      let lastLineSpasing = get_font_line_spacing(fctx)
      get_font_context(fctx, font.id, 0, 0, fontSize)
      let nextLineSpasing = get_font_line_spacing(fctx)
      let pos = get_text_pos(*ctx)
      goto_xy(*ctx, float2(pos.x, pos.y - lastLineSpasing + nextLineSpasing))

    set_font_ht(*ctx, fontSize)
    font.size = fontSize


  def getFontAscent() : float
    var fctx : StdGuiFontContext
    get_font_context(fctx, font.id, 0, 0, font.size)
    return toRelY(float(get_font_ascent(fctx)))


  def getFontDescent() : float
    var fctx : StdGuiFontContext
    get_font_context(fctx, font.id, 0, 0, font.size)
    return toRelY(float(get_font_descent(fctx)))


  def getStringSize(str : string; var len : int = 0) : float2
    len = len > 0 ? len : length(str)
    var fctx : StdGuiFontContext
    get_font_context(fctx, font.id, 0, 0, font.size)
    return toRelXY(get_str_bbox(str, len, fctx).width)


  def setLineSpacing(lineSpacing : float)
    self.lineSpacing = lineSpacing


  def setTextAnchorHorz(anchor : AnchorHorz)
    textAnchorHorz = anchor


// TODO: find better names because print is std function in DAS
  def setCaretPosition(pos : float2)
    goto_xy(*ctx, toAbsPos(pos))


  def printStr(str : string; var len : int = 0)
    len = len > 0 ? len : length(str)
    draw_str_scaled(*ctx, 1.0, str, len)


  def printStrLn(str : string; var len : int = 0)
    len = len > 0 ? len : length(str)
    let pos = get_text_pos(*ctx)
    draw_str_scaled(*ctx, 1.0, str, length(str))
    var fctx : StdGuiFontContext
    get_font_context(fctx, font.id, 0, 0, font.size)
    goto_xy(*ctx, float2(pos.x, pos.y + lineSpacing * get_font_line_spacing(fctx)))


  def drawStr(var pos : float2; str : string; var len : int = 0)
    pos = toAbsPos(pos)
    len = len > 0 ? len : length(str)
    var fctx : StdGuiFontContext
    get_font_context(fctx, font.id, 0, 0, font.size)

    if textAnchorHorz == AnchorHorz.Right
      let size = get_str_bbox(str, len, fctx).width
      pos.x -= size.x
    elif textAnchorHorz == AnchorHorz.Center
      let size = get_str_bbox(str, len, fctx).width
      pos.x -= 0.5 * size.x

    goto_xy(*ctx, pos)
    draw_str_scaled(*ctx, 1.0, str, len)

  def drawStrAnchored(var pos : float2; str : string; anchorHorz : AnchorHorz; anchorVert : AnchorVert)
    pos = toAbsPos(pos)
    let len = length(str)

    var fctx : StdGuiFontContext
    get_font_context(fctx, font.id, 0, 0, font.size)
    let size = get_str_bbox(str, len, fctx).width

    if anchorHorz == AnchorHorz.Right
      pos.x -= size.x
    elif anchorHorz == AnchorHorz.Center
      pos.x -= 0.5 * size.x

    if anchorVert == AnchorVert.Top
      pos.y += size.y
    elif anchorVert == AnchorVert.Center
      pos.y += 0.5 * size.y

    goto_xy(*ctx, pos)
    draw_str_scaled(*ctx, 1.0, str, len)

  def drawIntWithBiggerThousands(pos : float2; value : int; fontSizeMul : float; drawFrame : bool; thousandDigits : int)
    var fctx : StdGuiFontContext
    let thousandsFontSize = roundi(fontSizeMul * float(font.size))
    get_font_context(fctx, font.id, 0, 0, font.size)
    let lowCharSize = get_str_bbox("8", 1, fctx).width
    get_font_context(fctx, font.id, 0, 0, thousandsFontSize)
    let highCharSize = get_str_bbox("8", 1, fctx).width
    let absPos = toAbsPos(pos)

    let high = value / 1000
    var low = value - high * 1000
    let hasHigh = high != 0
    if hasHigh
      low = abs(low)
    let highStr = hasHigh ? string(high) : "";
    let lowStr = fmt(hasHigh ? ":0>3" : ":>3", low);
    let lowLen = length(lowStr)
    let highLen = length(highStr)
    var lowPos = absPos
    var highPos = absPos

    if textAnchorHorz == AnchorHorz.Right
      lowPos.x -= lowCharSize.x * float(lowLen)
    else
      lowPos.x += highCharSize.x * float(thousandDigits) + lowCharSize.x * float(3 - lowLen)

    if high != 0
      if textAnchorHorz == AnchorHorz.Right
        highPos.x = lowPos.x - highCharSize.x * float(highLen)
      else
        highPos.x = absPos.x + highCharSize.x * float(thousandDigits - highLen)

    lowPos.y -= 0.5 * (highCharSize.y - lowCharSize.y)

    goto_xy(*ctx, lowPos);
    draw_str_scaled(*ctx, 1.0, lowStr, lowLen)

    if hasHigh
      set_font_ht(*ctx, thousandsFontSize);
      goto_xy(*ctx, highPos);
      draw_str_scaled(*ctx, 1.0, highStr, highLen)
      set_font_ht(*ctx, font.size);

    if drawFrame
      let maxWidth = lowCharSize.x * 3.0 + highCharSize.x * float(thousandDigits)
      let maxHeight = max(lowCharSize.y, highCharSize.y)
      let padding = float2(0.25, 0.1) * highCharSize
      var left = absPos.x - lineWidthHdpx - padding.x
      var right = absPos.x + lineWidthHdpx + padding.x

      if textAnchorHorz == AnchorHorz.Right
        left -= maxWidth
      else
        right += maxWidth

      let top = absPos.y - maxHeight - lineWidthHdpx - padding.y
      let bottom = absPos.y + lineWidthHdpx + padding.y
      render_frame(*ctx, left, top, right, bottom, lineWidthHdpx)

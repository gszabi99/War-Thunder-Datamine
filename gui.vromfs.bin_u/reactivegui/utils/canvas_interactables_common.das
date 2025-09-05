module canvas_interactables_common
require darg
require DagorStdGuiRender
require DagorMath
require DagorSystem
require math
require strings
require %rGui.utils.helpers_common
require app
require WTInput
require %rGui.utils.canvas_common

struct InteractableVisitor
  [unused_argument(obj)] def interact(var obj : InteractableCanvasEll&)
    pass

  [unused_argument(btn)] def interactButton(var btn : InteractableButton&)
    pass


struct DrawVisitor : InteractableVisitor
  ctx : GuiContext?
  rdata : ElemRenderData const?
  rstate : RenderState const?

  def DrawVisitor(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const)
    self.ctx = unsafe(addr(ctx))
    self.rdata = unsafe(addr(rdata))
    self.rstate = unsafe(addr(rstate))

  def override interact(var obj : InteractableCanvasEll&)
    if self.ctx != null && self.rdata != null && self.rstate != null
      obj.draw(*self.ctx, *self.rdata, *self.rstate)
      if is_interactable_canvas_debug_enabled()
        obj.drawDebug(*self.ctx, *self.rdata, *self.rstate)


struct ClickVisitor : InteractableVisitor
  pos : float2 = float2(0.0)

  def ClickVisitor(pos : float2)
    self.pos = pos

  def override interactButton(var btn : InteractableButton&)
    let relPos = btn.toRelativePos(self.pos)
    return if !btn.isPointInside(relPos)
    btn.onClick(relPos)

struct DoubleClickVisitor : ClickVisitor
  def DoubleClickVisitor(pos : float2)
    ClickVisitor`ClickVisitor(self, pos)

  def override interactButton(var btn : InteractableButton&)
    let relPos = btn.toRelativePos(self.pos)
    return if !btn.isPointInside(relPos)
    btn.onDoubleClick(relPos)

struct PressVisitor : InteractableVisitor
  startPos : float2 = float2(0.0)
  currPos : float2 = float2(0.0)

  def PressVisitor(start_pos, curr_pos : float2)
    self.startPos = start_pos
    self.currPos = curr_pos

  def override interactButton(var btn : InteractableButton&)
    let relStartPos = btn.toRelativePos(self.startPos)
    return if !btn.isPointInside(relStartPos)
    let relCurrPos = btn.toRelativePos(currPos)

    btn.onPress(relStartPos, relCurrPos)

struct InteractableCanvasEll
  pos : float2 = float2(0.0)
  size : float2 = float2(0.0)

  def InteractableCanvasEll(in_pos, in_size : float2)
    self.pos = in_pos
    self.size = in_size

  [unused_argument(ctx, rdata, rstate)] def const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    pass

  def walkLayout(var visitor : InteractableVisitor&)
    visitor->interact(self)

  def const getDebugColor()
    return E3DCOLOR(0xFF800080)

  [unused_argument(rdata, rstate)] def const drawDebug(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    let lt = self.pos
    let rb = self.pos + self.size
    ctx |> render_rectangle_aa(lt, rb, ctx |> hdpx(2.0), getDebugColor(), E3DCOLOR(0x0))


struct InteractableButton : InteractableCanvasEll
  minValueBounds : float2 = float2(0.0)
  maxValueBounds : float2 = float2(1.0)

  def InteractableButton(in_pos, in_size : float2)
    InteractableCanvasEll`InteractableCanvasEll(self, in_pos, in_size)

  def override walkLayout(var visitor : InteractableVisitor&)
    InteractableCanvasEll`walkLayout(self, visitor)
    visitor->interactButton(self)

  [unused_argument(relative_pos)] def onClick(relative_pos : float2)
    pass

  [unused_argument(relative_pos)] def onDoubleClick(relative_pos : float2)
    pass

  [unused_argument(start_pos_rel, curr_pos_rel)] def onPress(start_pos_rel : float2; curr_pos_rel : float2)
    pass

  def const toRelativePos(abs_pos : float2)
    let lt = self.pos
    let rb = self.pos + self.size
    let relPos = float2(
      cvt_ex(abs_pos.x, lt.x, rb.x, self.minValueBounds.x, self.maxValueBounds.y),
      cvt_ex(abs_pos.y, lt.y, rb.y, self.minValueBounds.x, self.maxValueBounds.y)
    )
    return relPos

  def const isPointInside(rel_pos : float2)
    return self.minValueBounds.x <= rel_pos.x && rel_pos.x <= self.maxValueBounds.x && self.minValueBounds.y <= rel_pos.y && rel_pos.y <= self.maxValueBounds.y

  def const isMouseOnEllement()
    let mousePosRel = toRelativePos(get_mouse_pos())
    return isPointInside(mousePosRel)

  def override const getDebugColor()
    return isMouseOnEllement() ? E3DCOLOR(0xFFFF0000) : InteractableCanvasEll`getDebugColor(self)

struct TextButtonStyle
  color : E3DCOLOR = E3DCOLOR(0x0)
  fontId : int = 0
  fontSize : int = 0

  anchorHorz : AnchorHorz = AnchorHorz.Left
  anchorVert : AnchorVert = AnchorVert.Bottom

  glowColor : E3DCOLOR = E3DCOLOR(0x0)
  glowFxFactor : int = 0

struct TextButton : InteractableButton
  text : string = ""
  style : TextButtonStyle = TextButtonStyle()
  textBox : BBox2 = BBox2()

  onClickCallback : lambda<() : void>

  def TextButton(var in_pos : float2; txt : string; in_style : TextButtonStyle)
    text = txt
    style = in_style

    var fctx : StdGuiFontContext
    get_font_context(fctx, style.fontId, 0, 0, style.fontSize)
    textBox = get_str_bbox(txt, txt |> length(), fctx)

    let sz = textBox.width
    if style.anchorHorz == AnchorHorz.Right
      in_pos.x -= sz.x
    elif style.anchorHorz == AnchorHorz.Center
      in_pos.x -= 0.5 * sz.x

    if style.anchorVert == AnchorVert.Top
      in_pos.y += sz.y
    elif style.anchorVert == AnchorVert.Center
      in_pos.y += 0.5 * sz.y

    textBox = make_bbox(in_pos, sz)

    InteractableButton`InteractableButton(self, in_pos, sz * float2(1.0, -1.0))

  [unused_argument(relative_pos)] def override onClick(relative_pos : float2)
    if onClickCallback != null
      onClickCallback |> invoke()

  [unused_argument(relative_pos)] def override onDoubleClick(relative_pos : float2)
    if onClickCallback != null
      onClickCallback |> invoke()

  [unused_argument(rdata, rstate)] def override const draw(var ctx : GuiContext &; rdata : ElemRenderData & const; rstate : RenderState & const)
    ctx |> set_color(style.color)
    ctx |> set_font(style.fontId, 0, 0)
    ctx |> set_font_ht(style.fontSize)
    ctx |> set_draw_str_attr(FontFxType.FFT_GLOW, 0, 0, style.glowColor, style.glowFxFactor)

    ctx |> goto_xy(pos.x, pos.y)
    ctx |> draw_str_scaled(1.0, text, text |> length())
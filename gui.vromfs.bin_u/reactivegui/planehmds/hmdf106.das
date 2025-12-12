require %rGui.utils.canvas_common

require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require math
require Unit
require WTVr

def set_color_alpha(col : E3DCOLOR)
  let col4 = is_hmd_enabled() ? float4(Color4(col)) * 0.5 : float4(Color4(col)) * 0.3
  return E3DCOLOR(Color4(col4))

class Component : Canvas
  isValid : bool

  hero : Unit?
  fmw : FlightModelWrap?


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null || fmw.cockpit == null

    setColor(set_color_alpha(*fmw.cockpit |> getPageColor(MfdPageType.MFD_PLANE_ILS)))
    setLineWidth(floor(4.0 * fmw.cockpit.ilsLineWidthScale))
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    isValid = true


  def draw()
    return if !isValid

    let size = 0.05
    let sizeInner = 0.2 * size
    let sizeOuter = 1.45 * size
    let margin = 0.1 * size
    let ladderWidth = 0.06 * size

    drawCircle(float2(0.0), size)
    drawCircle(float2(0.0), sizeInner)

    let posMax = sizeInner + margin
    let posMin = size - margin
    drawLine(float2(posMin, 0.0), float2(posMax, 0.0))
    drawLine(float2(-posMin, 0.0), float2(-posMax, 0.0))

    let count = 3
    let step = (size - sizeInner) / float(count + 1)
    for i in 0 .. count
      let offset = float(i) * step + step + sizeInner
      drawLine(float2(-ladderWidth, offset), float2(ladderWidth, offset))
      drawLine(float2(-ladderWidth, -offset), float2(ladderWidth, -offset))

    let pos = size + margin
    drawLine(float2(-pos, 0.0), float2(-sizeOuter, 0.0))
    drawLine(float2(pos, 0.0), float2(sizeOuter, 0.0))
    drawLine(float2(0.0, -pos), float2(0.0, -sizeOuter))
    drawLine(float2(0.0, pos), float2(0.0, sizeOuter))


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const)
  new Component(guiCtx, rdata, rstate).draw()

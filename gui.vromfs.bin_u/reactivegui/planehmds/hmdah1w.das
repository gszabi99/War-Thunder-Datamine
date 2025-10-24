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

let green = E3DCOLOR(0xFF10FF10)

class Component : Canvas
  isValid : bool

  hero : Unit?
  fmw : FlightModelWrap?


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null

    setColor(set_color_alpha(green))
    setLineWidth(floor(4.0 * fmw.cockpit.ilsLineWidthScale))
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    isValid = true


  def draw()
    return if !isValid

    let size = 0.05
    let sizeInner = 0.3 * size
    let margin = 0.01 * size

    drawCircle(float2(0.0), size)
    drawCircle(float2(0.0), sizeInner)

    let offset = (size - sizeInner) * 0.22
    let posMax = sizeInner - offset
    let posMin = size - margin - offset
    drawLine(float2(posMin, 0.0), float2(posMax, 0.0))
    drawLine(float2(-posMin, 0.0), float2(-posMax, 0.0))
    drawLine(float2(0.0, -posMin), float2(0.0, -posMax))
    drawLine(float2(0.0, posMin), float2(0.0, posMax))

[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const)
  new Component(guiCtx, rdata, rstate).draw()

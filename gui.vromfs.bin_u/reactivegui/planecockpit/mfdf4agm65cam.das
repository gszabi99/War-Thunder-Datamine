require darg
require DagorMath
require DagorStdGuiRender
require math
require %rGui.utils.canvas_common
require GuidanceLock
require hud


let
  CLR_GRN  = E3DCOLOR(0xFF_00CC00)
  CLR_NONE = E3DCOLOR(0x00_000000)


struct PropStorage
  fontId : int
  vignette : Picture? = null


class Component : Canvas
  isValid       : bool = false
  isTracking    : bool = false

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    isValid    = true
    isTracking = get_agm_guidance_lock_state() == GuidanceLockState.RESULT_TRACKING
    setLineWidth(2.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(min(canvasSize.x, canvasSize.y)))
    setFont(props.fontId)
    setColor(CLR_GRN)
    setFillColor(CLR_NONE)

  def drawTvCrosshair()
    let gap = 0.025
    let armLen = 0.10
    let rect = 0.012
    let rectOff = (gap + armLen) * 0.5
    let trackMul = isTracking ? 0.55 : 1.0
    let gapRect = rectOff * trackMul * 0.7071
    drawLine(float2(0.0, -armLen), float2(0.0, -gap))
    drawLine(float2(0.0, gap), float2(0.0, armLen))
    drawLine(float2(-armLen, 0.0), float2(-gap, 0.0))
    drawLine(float2(gap, 0.0), float2(armLen, 0.0))
    setFillColor(CLR_GRN)
    drawBox(float2(gapRect - rect, -gapRect - rect), float2(gapRect + rect, -gapRect + rect))
    drawBox(float2(gapRect - rect, gapRect - rect), float2(gapRect + rect, gapRect + rect))
    drawBox(float2(-gapRect - rect, gapRect - rect), float2(-gapRect + rect, gapRect + rect))
    drawBox(float2(-gapRect - rect, -gapRect - rect), float2(-gapRect + rect, -gapRect + rect))
    setFillColor(CLR_NONE)


  def drawVignette(vignette : darg::Picture?)
    return if vignette == null

    let sc = min(canvasSize.x, canvasSize.y)
    let hw = 0.5 * canvasSize.x / sc
    let hh = 0.5 * canvasSize.y / sc
    setColor(E3DCOLOR(0xFFFFFFFF))
    drawPicture(float2(-hw, -hh), float2(hw * 2.0, hh * 2.0), vignette)


  def draw(props : PropStorage&)
    return if !isValid
    setFullCanvasViewport()
    drawTvCrosshair()
    drawVignette(props.vignette)
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw(props)


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
  propStorage.vignette = props |> getPicture("vignette")

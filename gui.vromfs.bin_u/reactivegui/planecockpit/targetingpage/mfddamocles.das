require darg
require DagorMath
require DagorStdGuiRender
require WTCamera
require %rGui.utils.canvas_common

struct PropStorage
  fontId : int
  isMetricUnits : bool

class Component : Canvas
  isValid : bool = false
  isMetricUnits : bool = true
  fcm : FlightControlMode? = null

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    fcm = get_flight_control_mode()
    return if fcm == null

    isValid = true
    isMetricUnits = props.isMetricUnits
    setColor(E3DCOLOR(0xFFFFFFFF))
    setLineWidth(3.0)
    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))


  def drawBigMainReticle()
    let outerCrossSize = float2(0.6, 0.4)
    let innerCrossSize = 0.2 * outerCrossSize
    drawCrossReticle(float2(0.0), outerCrossSize, innerCrossSize)
    let outerRectHalfSize = 0.25 * (outerCrossSize + innerCrossSize)
    let innerRectHalfSize = 0.5 * outerRectHalfSize
    drawBox(-outerRectHalfSize, outerRectHalfSize)
    drawBox(-innerRectHalfSize, innerRectHalfSize)

    if fcm.ctrlMap.isLaserDesignatorEnabled
      let serifHalfSize = 0.03
      let dx = 0.5 * outerCrossSize.x
      let dy = 0.5 * outerCrossSize.y
      drawLine(float2(dx, -serifHalfSize), float2(dx, serifHalfSize))
      drawLine(float2(-dx, -serifHalfSize), float2(-dx, serifHalfSize))
      drawLine(float2(-serifHalfSize, dy), float2(serifHalfSize, dy))
      drawLine(float2(-serifHalfSize, -dy), float2(serifHalfSize, -dy))


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawBigMainReticle()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.isMetricUnits = getBool(props, "isMetricUnits", true)

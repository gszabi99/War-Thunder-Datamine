require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightControl
require FlightModelWrap
require HeroManager
require hud
require math
require Plane
require Sensors
require strings
require Unit
require WTCamera

require %rGui.utils.canvas_common
require %rGui.utils.constants_common


let
  METER_TO_FEET   = 3.28084
  RANGE_MIN_FT    = 750.0
  RANGE_MAX_FT    = 4500.0
  FIRE_RANGE_FT   = 3000.0
  CIRCLE_R_AT_MIN = 0.054
  HUD_FOV_DEG     = float2(20)
  HUD_FOV_LIMITS  = HUD_FOV_DEG * degToRad / 2.0
struct PropStorage
  fontId : int


class Component : Canvas
  isValid      : bool = false
  hero         : Unit? = null
  fmw          : FlightModelWrap? = null
  trackDist    : float = 0.0
  trackActive  : bool = false
  aimPos       : float2 = float2(0.0)
  hasAim       : bool = false
  defaultColor : E3DCOLOR = E3DCOLOR(0xFF_00FF00)

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    let app_inst = get_app()
    if app_inst == null
      return
    hero = get_watched_not_delayed_hero()
    if hero == null
      return
    fmw = hero.as_fmw()
    if fmw == null
      return
    if fmw.cockpit == null
      return
    let fcm = app_inst.flightControlMode
    if fcm == null
      return

    isValid = true

    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        trackActive = true
        trackDist = target.distance

    if fcm.isCannonFireDirectionValid
      aimPos = worldPosToHud((hero.unitTm * fcm.averageCannonPosition) + fcm.cannonAimDirection)
      hasAim = true
    elif fcm.isCannonAimValid
      aimPos = worldPosToHud(fcm.cannonAimPosition)
      hasAim = true

    defaultColor = *fmw.cockpit->getPageColor(MfdPageType.MFD_PLANE_ILS)
    setColor(defaultColor)
    setLineWidth(floor(3.0 * fmw.cockpit.ilsLineWidthScale))
    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(canvasSize)
    setFontSize(35)


  def worldPosToHud(pos : float3)
    return worldVecToHud(pos - hero.pos)

  def worldVecToHud(dirVec : float3)
    var localVec = quat_mul_vec(math::quat(inverse(hero.unitTm)), dirVec)
    if localVec.x < 0.0
      localVec.x = -localVec.x
    localVec = fast_normalize(localVec)
    let screenX = atan2(localVec.x, localVec.z) - PI_2
    let screenY = safe_asin(localVec.y)
    return float2(screenX / HUD_FOV_LIMITS.x, -screenY / HUD_FOV_LIMITS.y)


  def drawReticle(cx : float; cy : float; radius : float)
    let dotR = 0.005
    setFillColor(defaultColor)
    for i in range(0, 6)
      let angle = float(i) * 60.0 * degToRad
      var sina, cosa = 0.0
      sincos(angle, sina, cosa)
      drawCircle(float2(cx + radius * cosa, cy + radius * sina), dotR)
    drawCircle(float2(cx, cy), 0.006)
    setFillColor(E3DCOLOR(0x0))


  def drawRangeNumeral(cx : float; cy : float; rangeFt : float)
    let val = roundi(clamp(rangeFt, RANGE_MIN_FT, RANGE_MAX_FT) / 20.0) * 20
    let pos = float2(cx - 0.09, cy - 0.07)
    let txt = "{val}"
    setFontSize(30)
    let sz = getStringSize(txt)
    let circR = max(sz.x, sz.y) * 0.66
    drawCircle(pos, circR)
    drawStrAnchored(pos, txt, AnchorHorz.Center, AnchorVert.Center)
    setFontSize(35)


  def drawSpanNumeral(cx : float; cy : float; rangeFt : float)
    if rangeFt >= FIRE_RANGE_FT
      let pos = float2(cx + 0.09, cy + 0.07)
      let txt = "25"
      setFontSize(30)
      let sz = getStringSize(txt)
      let circR = max(sz.x, sz.y) * 0.66
      drawCircle(pos, circR)
      drawStrAnchored(pos, txt, AnchorHorz.Center, AnchorVert.Center)
      setFontSize(35)


  def draw()
    return if !isValid
    setFullCanvasViewport()

    let cx = hasAim ? aimPos.x : 0.0
    let cy = hasAim ? aimPos.y : 0.0

    if trackActive
      let rangeFt = trackDist * METER_TO_FEET
      let clampedFt = clamp(rangeFt, RANGE_MIN_FT, RANGE_MAX_FT)
      let radius = CIRCLE_R_AT_MIN * RANGE_MIN_FT / clampedFt
      drawReticle(cx, cy, radius)
      drawRangeNumeral(cx, cy, rangeFt)
      drawSpanNumeral(cx, cy, rangeFt)
    else
      drawReticle(cx, cy, CIRCLE_R_AT_MIN)

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)

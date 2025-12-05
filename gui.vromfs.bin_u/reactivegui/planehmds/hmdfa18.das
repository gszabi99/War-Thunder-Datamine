require %rGui.utils.canvas_common
require %rGui.utils.constants_common
require %rGui.utils.helpers_common
require %rGui.utils.radar_common
require %rGui.planeIlses.F18cockpit_common

require DagorStdGuiRender
require hud
require darg
require Unit
require app
require HeroManager
require FlightModelWrap
require FlightControl
require WTCamera
require math
require DagorMath
require strings
require RadarHud
require Sensors
require GuidanceLock
require Plane
require Weapon
require Mission

require DagorSystem

[export]
def render(var ctx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(ctx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.ilsFovDeg = getFloat(props, "ilsFovDeg", 20.0)

class Component : FA18CockpitElementBase

  isHMSMode : bool

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    FA18CockpitElementBase`FA18CockpitElementBase(self, guiCtx, rdata, rstate, props)

    isHMSMode = find(get_radar_hud_mode_name(), "HMD") >= 0

    setScale(float2(canvasSize.y))

    let fontSize = 20
    defaultFontSize = floori(float(fontSize) * rdata.size.y / 1080.0)

  def draw()
    return if !isValid

    let scale = float2(0.5, 0.5)
    pushLocalAxes(float2(0.0), scale)
    setFullCanvasViewport()

    drawIntegratedAirSpeed()
    drawAltitude()
    drawFlightParams()

    let isCombatMode = gearProgress == 0.0
    if isCombatMode
      drawSelectedAirWeapon()
      drawSelectedGroundWeapon()
      if tracking.screenPosValid
        drawRadarAirTracking(toRelPos(tracking.screenPos), float2(0.0), 0.4)
        drawAamReticle(toRelPos(tracking.screenPos), float2(0.0), 0.4)
      drawRadarAirTrackingInfo()
      if aamGuidance.screenPosValid
        drawAamGuidance(aamGuidance.screenPos, float2(0.0))

    drawHMS()
    drawAimingCross()
    drawHeading()

    restoreViewport()
    popAxes()


  def drawHeading()
    let pos = float2(0.0, -0.4)
    let size = float2(0.6, 0.06)

    let HMDForward = get_camera_orig_dir()
    let HMDHeading = atan2_est(HMDForward.x, HMDForward.z)
    drawHeadingTape(HMDHeading, pos, size)

    let HMDElevation = norm_s_ang_deg(90.0 - atan2_est(sqrt(HMDForward.x * HMDForward.x + HMDForward.y * HMDForward.y), HMDForward.y) * radToDeg)
    let HMDElevationText = "{floori(HMDElevation)}"
    drawStrAnchored(pos + float2(0.0, -0.02), HMDElevationText, AnchorHorz.Center, AnchorVert.Bottom)

    let planeHeadingText = "{floori(heading * radToDeg)}"
    drawStrAnchored(pos + float2(0, size.y), planeHeadingText, AnchorHorz.Center, AnchorVert.Top)


  def drawHMS()
    return if !isHMSMode

    let camera = get_app().flightControlMode.cameraControl.cur
    return if camera == null

    let fovRad = fov_to_deg(camera.viewData.fov) * degToRad
    let azWidth = get_radar_hud_scan_azimuth_max() - get_radar_hud_scan_azimuth_min()
    let screenWidth = azWidth / fovRad
    drawDashedEllipse(float2(0.0), float2(screenWidth), 0.1, 0.1)


  def drawAimingCross()
    let outerSize = float2(0.05)
    let innerSize = float2(0.02)
    drawCrossReticle(float2(0.0), outerSize, innerSize)

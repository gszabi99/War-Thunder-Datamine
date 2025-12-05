require %rGui.planeIlses.ilsRafale_common
require %rGui.utils.canvas_common
require %rGui.utils.helpers_common

require %dasGameLibs.math.base
require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require math
require Plane
require strings
require Unit
require Weapon
require WTVr

struct PropStorage
  fontId : int

def set_color_alpha(col : E3DCOLOR)
  let col4 = is_hmd_enabled() ? float4(Color4(col)) * 0.5 : float4(Color4(col)) * 0.3
  return E3DCOLOR(Color4(col4))

class Component : Canvas
  isValid  : bool
  limits   : Limits

  hero : Unit?
  fmw  : FlightModelWrap?
  wc   : WeaponController?
  app  : AcesApp?

  state : CommonState


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage& const)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    wc = hero.weap
    return if wc == null
    app = get_app()
    return if app == null

    setFont(props.fontId)
    setColor(E3DCOLOR(uint4(100, 100, 100, 50)))
    setLineWidth(floor(4.0 * fmw.cockpit.ilsLineWidthScale))
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y * 0.5))
    isValid = true

    state.init_hmd(self, fmw, hero, wc, app)
    limits = Limits(center = float2(0.0), radius = float2(0.55))


  def drawArcSegmentAttitudeReference()
    with state
      let size = 0.6
      let divs = 12
      let interval = TWOPI / float(divs)
      let quat = *hero |> calcQuatAtTime(double(totalTime))
      var angles : float3
      quat_to_euler(quat, angles.x, angles.y, angles.z)
      let limit = interval * 2.0 // To ensure that an arc is always drawn
      let yQuant = clamp(round(angles.y / interval) * interval, -limit, limit)
      let sector = float2(yQuant, -PI - yQuant)

      var triangle <- array(
        float2(0.0, 0.03),
        float2(-0.03, 0.00),
        float2(0.03, 0.00))
      drawFilledPoly(triangle.clone().inv_y().translate(float2(0.0, -size + 0.06)))

      setRotation(float2(0.0), angles.z)
      drawSector(float2(0.0), float2(size), sector)

      var sina, cosa : float
      for i in 0..divs
        if i == 0 || i == 6
          let end = size - 0.045
          let sign = i == 6 ? -1.0 : 1.0
          let startPos = sign * float2(size, 0.0)
          let endPos = sign * float2(end, 0.0)
          let offset = float2(0.0, toRelY(lineWidthHdpx))
          drawLine(startPos - offset, endPos - offset)
          drawLine(startPos + offset, endPos + offset)
        elif i == 3
          drawCircle(float2(0.0, size - 0.03), 0.014)
        elif i == 9
          drawClosedPolyLine(triangle.translate(float2(0.0, -size)))
        else
          let angle = float(i) * interval
          sincos(angle, sina, cosa)
          let end = size - 0.025
          let startPos = float2(size * cosa, size * sina)
          let endPos = float2(end * cosa, end * sina)
          drawLine(startPos, endPos)

      resetViewTm()


  def drawSelectedWeapon()
    with state
      let pos = float2(-0.5, 0.25)
      setFontSize(30)
      setTextAnchorHorz(AnchorHorz.Left)

      if isAirGunMode || isGroundGunMode
        drawStr(pos, "GUN")
      elif (!get_hud_cur_weapon_name().empty())
        let name = loc("{get_hud_cur_weapon_name()}/rafale")
        drawStr(pos, name)


  def drawAoa()
    with state
      var pos = float2(-0.55, -0.15)
      let aoaStr = fmt(":>5.1f", fmw.fm.aoa)
      setFontSize(30)
      drawStrAnchored(pos, " α", AnchorHorz.Left, AnchorVert.Bottom)
      pos.y += getLineSpacing() * 0.6
      setFontSize(20)
      drawStrAnchored(pos, aoaStr, AnchorHorz.Left, AnchorVert.Bottom)


  def drawHeadingPitch()
    with state
      let pos = float2(0.0, -0.5)
      setFontSize(20)
      let pitch = ceili(fmw.tangage)
      let pitchSign = pitch < 0 ? "-" : "+"
      let forward = fast_normalize(hero.unitTm[0].xz)
      let heading = floori(rad_to_deg(norm_ang(atan2_est(forward.x, forward.y))))
      let pitchStr = "{fmt(":3d", heading)}/{pitchSign}{fmt(":2d", abs(pitch))}"
      drawStrAnchored(pos, pitchStr, AnchorHorz.Center, AnchorVert.Bottom)


  def drawReticle()
    let pos = float2(0.0, -0.3)
    let size = 0.07
    let deadzone = 0.055
    drawCircle(pos, size)
    drawLine(float2(pos.x, pos.y + size), float2(pos.x, pos.y + deadzone))
    drawLine(float2(pos.x, pos.y - size), float2(pos.x, pos.y - deadzone))
    drawLine(float2(pos.x + size, pos.y), float2(pos.x + deadzone, pos.y))
    drawLine(float2(pos.x - size, pos.y), float2(pos.x - deadzone, pos.y))


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawArcSegmentAttitudeReference()
    drawSelectedWeapon()
    drawAoa()
    drawHeadingPitch()
    drawReticle()
    draw_tracking_air_target_mark(state, self, limits)
    draw_tracking_ground_target_mark(state, self, limits)
    draw_air_speed(state, self, /*pos*/ float2(-0.32, -0.32), /*ft_sz*/ 30)
    draw_radar_status(state, self, /*pos*/ float2(-0.5, -0.2), /*ft_sz*/ 30)
    draw_spi_mark(state, self, limits)
    draw_radar_target_data(state, self, /*mach*/ float2(-0.2, 0.55), /*dist*/ float2(0.0, 0.55), /*alt*/ float2(0.2, 0.55), /*ft_sz*/ 20)
    draw_load_factor(state, self, /*pos*/ float2(0.4, -0.15), /*ft_sz*/ 20)
    draw_baro_alt(state, self, /*pos*/ float2(0.28, -0.32), /*ft_sz*/ 30)
    draw_radar_alt(state, self, /*pos*/ float2(0.28, -0.26), /*ft_sz*/ 20)
    draw_dynamic_launch_zone(state, self, /*pos*/ float2(0.4, -0.05),  /*size*/ float2(0.05, 0.37), /*ft_sz*/ 20)
    draw_closure_rate(state, self, /*pos*/ float2(0.24, -0.06), /*ft_sz*/ 20)
    draw_aam_em_tracking_mark(state, self, limits)
    draw_aam_ir_tracking_mark(state, self, limits)
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage& const)
  new Component(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
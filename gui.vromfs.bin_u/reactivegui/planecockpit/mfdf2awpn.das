require %rGui.utils.canvas_common
require %rGui.utils.helpers_common
require %rGui.utils.weaponslots_common

require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightModelWrap
require HeroManager
require hud
require Plane
require strings
require Unit
require Weapon
require WTCamera

require DagorSystem


def loc_wpn(str : string, suffix : string) : string
  if str.empty()
    return ""
  return loc("mfd/f_2a_wpn/{str}/{suffix}")


def calc_box_points(pos : float2; size : float2) : tuple<lt : float2, rb : float2>
  return size * -0.5 + pos, size * 0.5 + pos


struct Shapes
  outline = fixed_array(
    float2(-0.000, -0.235),

    float2(-0.002, -0.103),
    float2(-0.005, -0.102),
    float2(-0.005, -0.085),
    float2(-0.014, -0.076),
    float2(-0.019, -0.067),
    float2(-0.022, -0.056),
    float2(-0.023, -0.046),
    float2(-0.026, -0.038),
    float2(-0.026, -0.038),
    float2(-0.031, -0.031),
    float2(-0.039, -0.023),
    float2(-0.048, -0.018),
    float2(-0.062, -0.012),
    float2(-0.077, -0.010),
    float2(-0.211, -0.000),
    float2(-0.393, -0.000),
    float2(-0.211, 0.002),
    float2(-0.077, 0.012),
    float2(-0.044, 0.017),
    float2(-0.044, 0.043),
    float2(-0.042, 0.052),
    float2(-0.035, 0.064),
    float2(-0.024, 0.072),
    float2(-0.011, 0.076),

    float2(-0.000, 0.077),

    float2(0.011, 0.076),
    float2(0.024, 0.072),
    float2(0.035, 0.064),
    float2(0.042, 0.052),
    float2(0.044, 0.043),
    float2(0.044, 0.017),
    float2(0.077, 0.012),
    float2(0.211, 0.002),
    float2(0.393, -0.000),
    float2(0.211, -0.000),
    float2(0.077, -0.010),
    float2(0.062, -0.012),
    float2(0.048, -0.018),
    float2(0.039, -0.023),
    float2(0.031, -0.031),
    float2(0.026, -0.038),
    float2(0.026, -0.038),
    float2(0.023, -0.046),
    float2(0.022, -0.056),
    float2(0.019, -0.067),
    float2(0.014, -0.076),
    float2(0.005, -0.085),
    float2(0.005, -0.102),
    float2(0.002, -0.103),
  )
  ventralFin = fixed_array(
    float2(-0.035, 0.064),
    float2(-0.041, 0.104),
    float2(-0.024, 0.072),
  )
  pylon = fixed_array(
    float2(-0.007, 0.000),
    float2(-0.006, 0.026),
    float2(0.006, 0.026),
    float2(0.007, 0.000),
  )


struct Stations
  pos = fixed_array(
    float2(-0.000, 0.000), // 00
    float2(-0.432, 0.000), // 01 Wingtip station A/A left
    float2(-0.347, 0.040), // 02 Wing station A/A left
    float2(-0.263, 0.040), // 03 Wing station A/A A/G left
    float2(-0.184, 0.040), // 04 Wing station A/A A/G left
    float2(-0.106, 0.040), // 05 Inner wing station A/G left
    float2(-0.000, 0.000), // 06
    float2(0.000, 0.000),  // 07
    float2(0.106, 0.040),  // 08 Inner wing station A/G right
    float2(0.184, 0.040),  // 09 Wing station A/A A/G right
    float2(0.263, 0.040),  // 10 Wing station A/A A/G right
    float2(0.347, 0.040),  // 11 Wing station A/A right
    float2(0.432, 0.000))  // 12 Wingtip station A/A right

  lblOffset = fixed_array(
    float2(0.000, 0.030), // 00
    float2(0.000, 0.030), // 01 Wingtip station A/A left
    float2(0.000, 0.030), // 02 Wing station A/A left
    float2(0.000, 0.030), // 03 Wing station A/A A/G left
    float2(0.000, 0.030), // 04 Wing station A/A A/G left
    float2(0.000, 0.030), // 05 Inner wing station A/G left
    float2(0.000, 0.030), // 06
    float2(0.000, 0.030), // 07
    float2(0.000, 0.030), // 08 Inner wing station A/G right
    float2(0.000, 0.030), // 09 Wing station A/A A/G right
    float2(0.000, 0.030), // 10 Wing station A/A A/G right
    float2(0.000, 0.030), // 11 Wing station A/A right
    float2(0.000, 0.030)) // 12 Wingtip station A/A right


struct Colors
  green  = E3DCOLOR(Color4(float4(0.000, 1.000, 0.000, 1.000))) //#00FF00
  white  = E3DCOLOR(Color4(float4(1.000, 1.000, 1.000, 1.000))) //#FFFFFF
  black  = E3DCOLOR(Color4(float4(0.000, 0.000, 0.000, 1.000))) //#000000
  red    = E3DCOLOR(Color4(float4(1.000, 0.000, 0.000, 1.000))) //#FF0000
  yellow = E3DCOLOR(Color4(float4(1.000, 1.000, 0.000, 1.000))) //#FFFF00


enum MasterMode
  AA
  AG


struct PropStorage
  fontId : int


class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  wc : WeaponController? = null
  app : AcesApp? = null
  ws : WeaponSlots? = null
  colors : Colors = Colors()
  shapes : Shapes = Shapes()
  stations : Stations = Stations()
  ammo : table<string, int>

  isArmed : bool = false
  isWeaponSelectorOn : bool = false

  outlinePos : float2 = float2(0.0, -0.1)


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    return if hero == null
    fmw = hero.as_fmw()
    return if fmw == null
    wc = hero.weap
    return if wc == null
    fm = fmw.fm
    return if fm == null
    app = get_app()
    return if app == null

    ws = new WeaponSlots(hero, app, fmw, wc)

    isValid = true
    setColor(colors.green)
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(18)

    isArmed = !(fmw.isOnGround || fm.currentAlt < fmw.minAltitudeForDropShells)
    isWeaponSelectorOn = app.flightControlMode.isWeaponSelectorOn

    for p in stations.pos
      p += outlinePos


  def drawOutline()
    setFillColor(colors.black)
    drawFilledPolyOutlined(shapes.outline.to_array().translate(outlinePos))
    drawFilledPolyOutlined(shapes.ventralFin.to_array().translate(outlinePos))
    drawFilledPolyOutlined(shapes.ventralFin.to_array().inv_x().translate(outlinePos))
    let size = float2(0.006, 0.012)
    let pos = float2(0.4, 0.0)
    drawBox(pos - size + outlinePos, pos + size + outlinePos)
    drawBox(-pos - size + outlinePos, -pos + size + outlinePos)


  def drawAam(slot : WeaponSlot&)
    let pos = stations.pos[slot.slot]

    if (slot.guidanceType == GuidanceType.TYPE_ARH
    || slot.guidanceType == GuidanceType.TYPE_SARH)
      drawCross(pos, float2(0.045))
      drawCircle(pos, 0.020)
    else
      drawCross(pos, float2(0.040))
      drawCircle(pos, 0.014)


  def drawBomb(slot : WeaponSlot&)
    let pos = stations.pos[slot.slot]

    let size = 0.030
    drawLine(float2(pos.x + size, pos.y), float2(pos.x - size, pos.y))
    drawCircle(pos, 0.020)


  def drawAgm(slot : WeaponSlot&)
    let pos = stations.pos[slot.slot]

    let size = 0.030
    drawLine(float2(pos.x, pos.y + size), float2(pos.x, pos.y - size))
    drawLine(float2(pos.x + size, pos.y), float2(pos.x - size, pos.y))
    drawCircle(pos, 0.020)


  def drawRocket(slot : WeaponSlot&)
    if slot.nextToShoot
      setFillColor(colors.white)
    else
      setFillColor(colors.black)
    let pos = stations.pos[slot.slot]

    let size = 0.030
    drawLine(float2(pos.x, pos.y + size), float2(pos.x, pos.y - size))
    drawLine(float2(pos.x + size, pos.y), float2(pos.x - size, pos.y))
    drawCircle(pos, 0.020)


  def drawAmmo(ammo : int, weapon : string)
    let pos = float2(0.05, 0.15)
    drawStrAnchored(pos, "{ammo} {loc_wpn(weapon, "full")}", AnchorHorz.Right, AnchorVert.Bottom)
    drawStrAnchored(float2(pos.x, pos.y + getFontDescent()), isArmed ? "RDY" : "SAFE", AnchorHorz.Right, AnchorVert.Top)


  def drawGunAmmo()
    let pos = float2(-0.07, -0.14)
    let gunAmmo = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
    drawStrAnchored(pos, fmt(":>3d", gunAmmo), AnchorHorz.Center, AnchorVert.Bottom)


  def drawWeaponLabel(slot : WeaponSlot&)
    if slot.nextToShoot
      setColor(colors.white)
    else
      setColor(colors.green)
    drawStrAnchored(stations.pos[slot.slot] + stations.lblOffset[slot.slot], loc_wpn(slot.locName, "short"), AnchorHorz.Center, AnchorVert.Top)
    setColor(colors.white)


  def getMasterMode()
    if (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET))
      return MasterMode.AA
    elif (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_ROCKET))
      return MasterMode.AG
    return MasterMode.AA


  def drawOsbLabels()
    let osbCount = 5
    let inset = 0.2
    let step = (1.0 - inset - inset) / float(osbCount - 1)
    let margin = 0.03
    let bboxMargin = 0.005
    let p0 = 0.5 - margin
    let p1 = 0.5 - inset
    setFillColor(colors.green)

    let masterMode = getMasterMode() == MasterMode.AA ? "A-A" : "A-G"
    // Left
    drawStrAnchored(float2(-p0, -p1), "SJ", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(-p0, -p1 + step * 3.0), "SPOT", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(-p0, -p1 + step * 4.0), "BORE", AnchorHorz.Left, AnchorVert.Center)
    // Bottom
    drawStrAnchored(float2(-p1, p0), "SWAP", AnchorHorz.Center, AnchorVert.Bottom)
    drawBBox(getStrBbox(float2(-p1 + step, p0), "SMS", AnchorHorz.Center, AnchorVert.Bottom), bboxMargin)
    setColor(colors.white)
    drawStrAnchored(float2(-p1 + step, p0), "SMS", AnchorHorz.Center, AnchorVert.Bottom)
    setColor(colors.green)
    drawStrAnchored(float2(-p1 + step * 3.0, p0), "FCR", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(-p1 + step * 4.0, p0), "DCLT", AnchorHorz.Center, AnchorVert.Bottom)
    // Right
    drawStrAnchored(float2(p0, -p1 - getFontAscent()), "WPN", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(p0, -p1 + getFontAscent()), "SEL", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(p0, -p1 + step * 3.0), "BP", AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(p0, -p1 + step * 4.0), "COOL", AnchorHorz.Right, AnchorVert.Center)
    // Top
    drawStrAnchored(float2(p1, -p0), "VI", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(p1 - step, -p0), "INV", AnchorHorz.Center, AnchorVert.Top)
    drawStrAnchored(float2(p1 - step * 3.0, -p0), "SBM", AnchorHorz.Center, AnchorVert.Top)
    drawBBox(getStrBbox(float2(p1 - step * 4.0, -p0), "A-A", AnchorHorz.Center, AnchorVert.Top), bboxMargin)
    setColor(colors.white)
    drawStrAnchored(float2(p1 - step * 4.0, -p0), masterMode, AnchorHorz.Center, AnchorVert.Top)
    setColor(colors.green)

    setFillColor(colors.black)


  def drawCycleWeapon()
    let triangle = fixed_array(
      float2(0.0, 0.0),
      float2(0.03, 0.016),
      float2(0.03, -0.016),
    )
    drawClosedPolyLine(triangle.to_array().translate(float2(-0.45, 0.0)))
    drawClosedPolyLine(triangle.to_array().translate(float2(-0.45, 0.0)).inv_x())


  def drawWeaponSlots()
    setColor(colors.white)
    var nts : string
    for i in 0 .. ws.length()
      continue if (hero.slotIdByWeaponId[i] <= 0)
      var slot = ws.getWeaponSlot(i)

      continue if slot.curAmmo < 1
      continue if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)
      continue if slot.trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER)
      ammo.insert(slot.locName, (ammo?[slot.locName] ?? 0) + slot.curAmmo)

      drawWeaponLabel(slot)
      if ((slot.slot > 1 && slot.slot < 6) || slot.slot > 7 && slot.slot < 12)
        drawPolyLine(shapes.pylon.to_array().translate(float2(stations.pos[slot.slot].x, 0.0) + outlinePos))
      if slot.nextToShoot
        setFillColor(colors.white)
      else
        setFillColor(colors.black)
      if (slot.trigger == int(WeaponTriggerType.AAM_TRIGGER))
        drawAam(slot)
      elif (slot.trigger == int(WeaponTriggerType.AGM_TRIGGER))
        drawAgm(slot)
      elif (slot.trigger == int(WeaponTriggerType.BOMBS_TRIGGER)
        || slot.trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
        drawBomb(slot)
      elif (slot.trigger == int(WeaponTriggerType.ROCKETS_TRIGGER))
        drawRocket(slot)
      else
        continue

      if slot.nextToShoot
        nts = slot.locName

    if !nts.empty()
      drawAmmo(ammo.get_value(nts), nts)
    setColor(colors.green)


  def draw()
    return if !isValid

    setFullCanvasViewport()
    drawOsbLabels()
    drawCycleWeapon()
    drawWeaponSlots()
    drawGunAmmo()
    drawOutline()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)

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
require math
require Plane
require Unit
require Weapon
require WTCamera


struct Colors
  green  = E3DCOLOR(Color4(float4(0.000, 1.000, 0.000, 1.000))) //#00FF00
  white  = E3DCOLOR(Color4(float4(1.000, 1.000, 1.000, 1.000))) //#FFFFFF
  black  = E3DCOLOR(Color4(float4(0.000, 0.000, 0.000, 1.000))) //#000000
  red    = E3DCOLOR(Color4(float4(1.000, 0.000, 0.000, 1.000))) //#FF0000
  yellow = E3DCOLOR(Color4(float4(1.000, 1.000, 0.000, 1.000))) //#FFFF00


def rad_to_deg(rad : float)
  return rad * 180.0 / PI


def deg_to_rad(deg : float)
  return deg * PI / 180.0

def calc_box_points(pos : float2; size : float2) : tuple<lt : float2, rb : float2>
  return size * -0.5 + pos, size * 0.5 + pos


def loc_wpn(str : string) : string
  if str.empty()
    return ""
  return loc("mfd/su_30sm_wpn/{str}")


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
  stations : array<float2>

  isArmed : bool = false
  isWeaponSelectorOn : bool = false

  outlScale : float2 = float2(1.0)
  outlTransl : float2 = float2(1.0)
  outlUnit : float = 0.1
  outlWing : float = 1.0
  outlPylon : float2 = float2(0.005, 0.1)
  slotCount : int = 6
  slotOffset : float2 = float2(0.02, 0.05)
  slotHeight : float = 0.5
  stationIds <- [[auto 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12]]


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    fmw = hero.as_fmw()
    wc = hero.weap
    fm = fmw.fm
    app = get_app()

    return if fmw == null
    return if wc == null
    return if fm == null

    ws = new WeaponSlots(hero, app, fmw, wc)

    isValid = true
    setColor(colors.white)
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(18)

    isArmed = !(fmw.isOnGround || fm.currentAlt < fmw.minAltitudeForDropShells)
    isWeaponSelectorOn = app.flightControlMode.isWeaponSelectorOn

    // Configuration
    outlScale = float2(0.6)             // Scale of aircraft outline
    outlTransl = float2(-0.15, -0.2)    // Transflate of aircraft outline
    outlUnit = 0.085 * outlScale.x              // Unit for scaling aircraft parts
    outlWing = 1.0 * outlScale.x               // Wingspan
    outlPylon = float2(0.003, 0.05)    // Pylon width & height
    stationIds <- [[auto 11; 9; 7; 5; 3; 1; 2; 4; 6; 8; 10; 12]] // Station numbering
    slotCount = stationIds.length() // Number of slots on the aircraft
    slotOffset = float2(0.02, 0.08) // Offset of the first slot from the wingtip
    slotHeight = 0.4                // Maximum length of slot connector lines


  def calcStations() : array<float2>
    let mid = 12 / 2
    let wing = outlWing * 0.5
    return <- [{
      for i in 0 .. slotCount;
      float2(
        lerp(-wing + slotOffset.x, wing - slotOffset.x, float(i) / float(slotCount - 1)),
        (i < mid)
        ? lerp(slotOffset.y, slotHeight, float(i) / float(mid - 1))
        : lerp(slotHeight, slotOffset.y, float(i - mid) / float(mid - 1))
      )
    }]


  def drawOsbLabels()
    let offset = 0.03
    let offsetInfo = 0.08
    setColor(colors.green)
    drawStrAnchored(float2(-0.3, -0.5 + offset), "ПИЛ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.3, -0.5 + offsetInfo), "РЛ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.15, -0.5 + offset), "ТО", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0, -0.5 + offset), "РЭП", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.15, -0.5 + offset), "КИСС", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.3, -0.5 + offset), "ОПС", AnchorHorz.Center, AnchorVert.Center)
    let box = calc_box_points(float2(0.3, -0.5 + offset), float2(0.14, 0.038))
    drawBox(box.lt, box.rb)

    if !fm.EI.areEnginesStarted && !isArmed
      setColor(colors.red)
      drawStrAnchored(float2(0.3, -0.5 + offsetInfo), "ОТКАЗ СУО", AnchorHorz.Center, AnchorVert.Center)
      setColor(colors.green)

    drawStrAnchored(float2(0.0, -0.5 + offset), "РЗП", AnchorHorz.Center, AnchorVert.Center)
    drawStrVert(float2(0.5 - offset, -0.3), "РДВ", AnchorHorz.Center, AnchorVert.Center)
    drawStrVert(float2(0.5 - offset, -0.15), "ОЛС", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0, 0.5 - offset), "ГРУЗ", AnchorHorz.Center, AnchorVert.Center)


  def drawFireControlState()
    setColor(colors.green)
    setFontSize(16)
    let pos = float2(0.2, 0.4)

    if !fm.EI.areEnginesStarted
      setColor(colors.yellow)
      drawStrAnchored(float2(0.4, 0.38), "ГЛАВН ОТКЛ", AnchorHorz.Center, AnchorVert.Center)
      setColor(colors.green)

    drawStrAnchored(float2(-0.1, -0.02) + pos, "ПИТ", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(-0.1, 0.02) + pos, "УР ВП", AnchorHorz.Left, AnchorVert.Center)
    drawStrAnchored(float2(0.01, -0.02) + pos, "1", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.01, 0.02) + pos, "2", AnchorHorz.Center, AnchorVert.Center)
    if !fm.EI.areEnginesStarted && !isArmed
      setColor(colors.yellow)
      drawStrAnchored(float2(0.035, -0.02) + pos, "ОТКЛ", AnchorHorz.Left, AnchorVert.Center)
      setColor(colors.green)
    else
      drawStrAnchored(float2(0.035, -0.02) + pos, "ВКЛ", AnchorHorz.Left, AnchorVert.Center)
    if !isArmed
      setColor(colors.yellow)
      drawStrAnchored(float2(0.035, 0.02) + pos, "ОТКЛ", AnchorHorz.Left, AnchorVert.Center)
      setColor(colors.green)
    else
      drawStrAnchored(float2(0.035, 0.02) + pos, "ВКЛ", AnchorHorz.Left, AnchorVert.Center)

    drawBox(float2(-0.11, -0.04) + pos, float2(0.11, 0.04) + pos)
    drawLine(float2(-0.005, -0.04) + pos, float2(-0.005, 0.04) + pos)
    drawLine(float2(-0.005, 0.0) + pos, float2(0.11, 0.0) + pos)

    setColor(colors.white)
    setFontSize(18)

  def drawGunAmmo()
    let pos = float2(0.27, -0.21)
    let ammo = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
    drawStrAnchored(pos, "ВПУ {ammo}", AnchorHorz.Center, AnchorVert.Bottom)


  def drawAamSlot(slot : WeaponSlot&; var scale : float2 = float2(1.0))
    setFillColor(colors.black)
    let pos = stations[slot.slot] + outlTransl
    var str = ""

    if (slot.guidanceType == GuidanceType.TYPE_ARH
    || slot.guidanceType == GuidanceType.TYPE_SARH)
      scale *= float2(1.3)
      if (slot.guidanceType == GuidanceType.TYPE_ARH)
        str = "A"

    drawCross(pos, float2(0.031) * scale)
    drawCross(float2(pos.x, pos.y + 0.015 * scale.x), float2(0.015) * scale)
    drawCircle(pos, 0.015 * scale.x)

    if !str.empty()
      drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Center)


  def drawAgmSlot(slot : WeaponSlot&; var scale : float2 = float2(1.0))
    setFillColor(colors.black)
    let pos = stations[slot.slot] + outlTransl
    var str = ""
    scale *= float2(1.3)
    if (slot.guidanceType == GuidanceType.TYPE_OPTICAL)
      str = "T"
    elif (slot.guidanceType == GuidanceType.TYPE_GNSS)
      str = "Г"
    elif (slot.guidanceType == GuidanceType.TYPE_LASER_ILLUMINATION)
      str = "Л"

    drawCross(pos, float2(0.031) * scale)
    drawCross(float2(pos.x, pos.y + 0.015 * scale.x), float2(0.015) * scale)
    drawCircle(pos, 0.015 * scale.x)

    if !str.empty()
      drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Center)


  def drawBombSlot(slot : WeaponSlot&; scale : float2 = float2(1.0))
    setFillColor(colors.black)
    let pos = stations[slot.slot] + outlTransl
    var str = ""
    if (slot.guidanceType == GuidanceType.TYPE_GNSS)
      str = "Г"
    elif (slot.guidanceType == GuidanceType.TYPE_OPTICAL)
      str = "T"
    elif (slot.guidanceType == GuidanceType.TYPE_LASER_ILLUMINATION)
      str = "Л"
    var triangle = [
      float2(0.0, -0.005),
      float2(0.02, -0.03),
      float2(-0.02, -0.03),
    ]
    drawFilledPoly(triangle.translate(pos).scale(scale))
    drawEllipse(pos, float2(0.015, 0.025) * scale)
    if !str.empty()
      drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Center)


  def drawRocketSlot(slot : WeaponSlot&; scale : float2 = float2(1.0))
    setFillColor(colors.black)
    let pos = stations[slot.slot] + outlTransl
    drawCircle(pos, 0.02 * scale.x)
    drawCircle(pos + float2(0.01, 0.01) * scale, 0.007 * scale.x)
    drawCircle(pos + float2(-0.01, 0.01) * scale, 0.007 * scale.x)
    drawCircle(pos - float2(0.0, 0.01) * scale, 0.007 * scale.x)


  def drawFuelTank(slot : WeaponSlot&; scale : float2 = float2(1.0))
    setFillColor(colors.black)
    let pos = stations[slot.slot] + outlTransl
    drawCircle(pos, 0.02 * scale.x)


  def drawStationLine(slot : WeaponSlot&)
    let pos = stations[slot.slot]
    setColor(colors.white)
    drawLine(float2(pos.x, outlPylon.y) + outlTransl, pos + outlTransl)


  def drawOutline()
    // Wings
    drawLine(float2(outlWing * 0.5, 0.0) + outlTransl, float2(-outlWing * 0.5, 0.0) + outlTransl)
    // Fuse
    drawSector(float2(0.0) * outlScale + outlTransl, float2(outlUnit), float2(deg_to_rad(180.0), deg_to_rad(0.0)))
    // Stations
    for f in stations
      setFillColor(colors.white)
      drawBox(float2(f.x - outlPylon.x, 0.0) + outlTransl, float2(f.x + outlPylon.x, outlPylon.y) + outlTransl)
      setFillColor(E3DCOLOR(0x0))
    // Engines
    setFillColor(colors.black)
    drawBox(float2(outlUnit, 0.0) + outlTransl, float2(outlUnit * 2.0, outlUnit * 0.5) + outlTransl)
    drawBox(float2(-outlUnit * 2.0, 0.0) + outlTransl, float2(-outlUnit, outlUnit * 0.5) + outlTransl)
    setFillColor(E3DCOLOR(0x0))
    // Vertical stabs
    let stab = [[auto
      float2(outlUnit * 2.0 + outlUnit * 0.15, 0.0);
      float2(outlUnit * 2.0 - outlUnit * 0.15, 0.0);
      float2(outlUnit * 2.0, -outlUnit * 1.6);
    ]]
    drawFilledPoly(stab.to_array().translate(outlTransl))
    drawFilledPoly(stab.to_array().inv_x().translate(outlTransl))


  def drawStationNumbering()
    let height = -0.01
    for i, pos in stationIds, stations
      drawStrAnchored(float2(pos.x, height) + outlTransl, "{i}", AnchorHorz.Center, AnchorVert.Bottom)


  def drawNtsBracket(slotIdx : int)
    setColor(colors.green)
    setLineWidth(2.0)
    let pos = float2(stations[slotIdx].x, -0.045) + outlTransl
    var bracket = [
      float2(-0.018, 0.01),
      float2(-0.018, 0.0),
      float2(0.018, 0.0),
      float2(0.018, 0.01),
    ]
    drawPolyLine(bracket.translate(pos))
    setColor(colors.white)
    setLineWidth(1.0)


  def drawWeaponLabel(slot : WeaponSlot&)
    let mid = slotCount / 2
    let idx = slot.slot % mid
    var pos = float2(0.35, stations[slot.slot].y)
    if slot.slot >= mid
      pos += float2(0.12, 0.0)
    drawStrAnchored(pos + outlTransl, loc_wpn(slot.locName), AnchorHorz.Left, AnchorVert.Center)


  def drawWeaponSlots()
    for i in 0 .. ws.length()
      continue if (hero.slotIdByWeaponId[i] <= 0)
      var slot = ws.getWeaponSlot(i)
      slot.slot -= 1

      continue if slot.curAmmo < 1
      continue if slot.slot > stations.length() - 1
      continue if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)

      if slot.nextToShoot
        drawNtsBracket(slot.slot)
      drawStationLine(slot)

      if slot.selected
        setColor(colors.green)
      else
        setColor(colors.white)

      drawWeaponLabel(slot)
      if (slot.trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER))
        drawFuelTank(slot)
      elif (slot.trigger == int(WeaponTriggerType.AAM_TRIGGER))
        drawAamSlot(slot)
      elif (slot.trigger == int(WeaponTriggerType.AGM_TRIGGER))
        drawAgmSlot(slot)
      elif (slot.trigger == int(WeaponTriggerType.BOMBS_TRIGGER)
        || slot.trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
        drawBombSlot(slot)
      elif (slot.trigger == int(WeaponTriggerType.ROCKETS_TRIGGER))
        drawRocketSlot(slot)

    setColor(colors.white)

  def draw()
    return if !isValid

    stations <- calcStations()

    setFullCanvasViewport()
    drawFireControlState()
    drawOutline()
    drawOsbLabels()
    drawWeaponSlots()
    drawStationNumbering()
    drawGunAmmo()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
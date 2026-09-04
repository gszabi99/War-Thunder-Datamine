options no_aliasing = false

require %rGui.utils.canvas_common
require %rGui.utils.constants_common
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
require strings
require Unit
require Weapon
require WTCamera
require Localization


def loc_wpn(str : string) : string
  if str.empty()
    return ""
  return loc("mfd/m346_fa_wpn/{str}")


struct Colors
  green   = E3DCOLOR(Color4(float4(0.000, 1.000, 0.000, 1.000)))
  outline = E3DCOLOR(Color4(float4(0.000, 0.369, 1.000, 1.000)))
  orange  = E3DCOLOR(Color4(float4(1.000, 0.400, 0.000, 1.000)))


struct PropStorage
  fontId : int


class Component : Canvas
  isValid    : bool = false
  hero       : Unit? = null
  fmw        : FlightModelWrap? = null
  fm         : FlightModel? = null
  wc         : WeaponController? = null
  app        : AcesApp? = null
  ws         : WeaponSlots? = null
  colors     : Colors = Colors()
  stations   : array<float2>

  isArmed    : bool = false
  flareCount : int = 0
  chaffCount : int = 0
  cmCount    : int = 0

  outlTransl : float2 = float2(0.0, -0.1)
  outlWing   : float = 0.64
  outlPylon  : float2 = float2(0.004, 0.038)
  slotCount  : int = 7

  dashSize  : float = 0.04
  dashGap   : float = 0.025
  dashWidth : float = 2.0

  selectedTrigger : int = -1
  hasTgp          : bool = false

  maskW  : float = 0.073
  maskH  : float = 0.017
  maskCY : float = -0.016


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
    setColor(WHITE)
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(18)

    isArmed = !(fmw.isOnGround || fm.input.currentAlt < fmw.minAltitudeForDropShells)
    if (int(wc.numCountermeasureGuns) > 0)
      *wc->calcNumCountermeasureBullet(flareCount, chaffCount)

  def calcStations() : array<float2>
    var r : array<float2>
    r |> push(float2(-0.36,  0.16))
    r |> push(float2(-0.25,  0.04))
    r |> push(float2(-0.11, -0.04))
    r |> push(float2(0.00,  0.18))
    r |> push(float2(0.11,  -0.04))
    r |> push(float2(0.25,  0.04))
    r |> push(float2(0.36,  0.16))
    return <- r


  def ml(a, b, T : float2; s : float)
    drawLine(a * s + T, b * s + T)
    drawLine(float2(-a.x, a.y) * s + T, float2(-b.x, b.y) * s + T)


  def drawOutline()
    let s = 1.2
    let T = outlTransl + float2(0.0, 0.1)
    setColor(colors.outline)
    ml(float2(0.0,   -0.353), float2(0.022, -0.27),  T, s)
    ml(float2(0.022, -0.27),  float2(0.033, -0.19),  T, s)
    ml(float2(0.033, -0.19),  float2(0.055, -0.15),  T, s)
    ml(float2(0.055, -0.15),  float2(0.095, -0.05),  T, s)
    ml(float2(0.095, -0.05),  float2(0.30,   0.065), T, s)
    ml(float2(0.30,   0.065), float2(0.30,   0.12),  T, s)
    ml(float2(0.30,   0.12),  float2(0.07,   0.12),  T, s)
    ml(float2(0.07,   0.12),  float2(0.039,  0.23),  T, s)
    ml(float2(0.039,  0.23),  float2(0.185,  0.278), T, s)
    ml(float2(0.185,  0.278), float2(0.185,  0.309), T, s)
    ml(float2(0.185,  0.309), float2(0.0,   0.309), T, s)


  def drawStationNumbering()
    setFontSize(14)
    for i in 0 .. slotCount
      let pos = stations[i]
      drawStrAnchored(float2(pos.x, -0.012) + outlTransl, "{i + 1}", AnchorHorz.Center, AnchorVert.Bottom)
    setFontSize(18)


  def drawAamSlot(slot : WeaponSlot&)
    setFillColor(BLACK)
    let pos = stations[slot.slot] + outlTransl
    drawCircle(pos, 0.013)
    drawLine(pos + float2(0.003, 0.003), pos + float2(0.009, 0.009))
    drawLine(pos + float2(-0.003, 0.003), pos + float2(-0.009, 0.009))
    drawLine(pos + float2(0.003, -0.003), pos + float2(0.009, -0.009))
    drawLine(pos + float2(-0.003, -0.003), pos + float2(-0.009, -0.009))


  def drawBombSlot(slot : WeaponSlot&)
    setFillColor(BLACK)
    let pos = stations[slot.slot] + outlTransl
    var tri = [
      float2(0.0, -0.005),
      float2(0.017, -0.027),
      float2(-0.017, -0.027),
    ]
    drawFilledPoly(tri.translate(pos))
    drawEllipse(pos, float2(0.013, 0.021))


  def drawRocketSlot(slot : WeaponSlot&)
    setFillColor(BLACK)
    let pos = stations[slot.slot] + outlTransl
    drawCircle(pos, 0.017)
    drawCircle(pos + float2(0.008, 0.008), 0.005)
    drawCircle(pos + float2(-0.008, 0.008), 0.005)
    drawCircle(pos + float2(0.0, -0.008), 0.005)


  def drawFuelTank(slot : WeaponSlot&)
    setFillColor(BLACK)
    let pos = stations[slot.slot] + outlTransl
    drawCircle(pos, 0.017)


  def drawTextSlot(slot : WeaponSlot&)
    let pos = stations[slot.slot] + outlTransl
    drawStrAnchored(pos, slot.locName, AnchorHorz.Center, AnchorVert.Center)


  def drawNtsBracket(slotIdx : int)
    setColor(colors.green)
    setLineWidth(2.0)
    let pos = float2(stations[slotIdx].x, -0.038) + outlTransl
    var bracket = [
      float2(-0.016, 0.008),
      float2(-0.016, 0.0),
      float2(0.016, 0.0),
      float2(0.016, 0.008),
    ]
    drawPolyLine(bracket.translate(pos))
    setColor(WHITE)
    setLineWidth(1.0)


  def drawWeaponLabel(slot : WeaponSlot&)
    let pos = stations[slot.slot]
    setColor(BLACK)
    setFillColor(BLACK)
    drawBox(float2(pos.x - maskW, pos.y + maskCY - maskH), float2(pos.x + maskW, pos.y + maskCY + maskH))
    setFillColor(E3DCOLOR(0x0))
    if slot.selected
      setFillColor(YELLOW)
      drawBox(float2(pos.x - 0.054, pos.y - 0.033), float2(pos.x + 0.054, pos.y + 0.001))
      setColor(BLACK)
    else
      setColor(WHITE)
    setFillColor(E3DCOLOR(0x0))
    drawStrAnchored(float2(pos.x, pos.y - 0.016), loc_wpn(slot.locName), AnchorHorz.Center, AnchorVert.Center)
    setColor(colors.green)
    drawStrAnchored(float2(pos.x, pos.y + 0.012), "{slot.curAmmo}", AnchorHorz.Center, AnchorVert.Top)
    setColor(WHITE)


  def drawWeaponSlots()
    selectedTrigger = -1
    hasTgp = false
    setFontSize(16)
    for i in 0 .. ws.length()
      continue if (hero.slotIdByWeaponId[i] <= 0)
      var slot = ws.getWeaponSlot(i)
      slot.slot -= 1
      continue if slot.curAmmo < 1
      continue if slot.slot > stations.length() - 1

      if slot.selected
        selectedTrigger = slot.trigger

      if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)
        hasTgp = true
        drawStrAnchored(stations[3] + outlTransl, "TGP", AnchorHorz.Center, AnchorVert.Center)
      elif slot.trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER)
        drawWeaponLabel(slot)
      elif slot.trigger == int(WeaponTriggerType.AAM_TRIGGER)
        drawWeaponLabel(slot)
      elif (slot.trigger == int(WeaponTriggerType.AGM_TRIGGER)
        || slot.trigger == int(WeaponTriggerType.BOMBS_TRIGGER)
        || slot.trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
        drawWeaponLabel(slot)
      elif slot.trigger == int(WeaponTriggerType.ROCKETS_TRIGGER)
        drawWeaponLabel(slot)

    setColor(WHITE)
    setFillColor(E3DCOLOR(0x0))
    setFontSize(18)


  def drawCountermeasures()
    setFontSize(17)
    let pos = float2(0.0, 0.36)
    setColor(WHITE)
    drawStrAnchored(pos + float2(-0.175, -0.01), "CH {chaffCount}", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(pos + float2(0.175,  -0.01), "FL {flareCount}", AnchorHorz.Center, AnchorVert.Center)
    setColor(WHITE)
    setFontSize(18)


  def dashLine(a, b : float2; dash, gap : float)
    let total = length(b - a)
    let dir = normalize(b - a)
    var t = 0.0
    while t < total
      drawLine(a + dir * t, a + dir * min(t + dash, total))
      t += dash + gap
    drawLine(a + dir * (total - dash), b)


  def drawBorder()
    let r = 0.48
    setColor(WHITE)
    setLineWidth(dashWidth)
    dashLine(float2(-r, -r), float2(r, -r), dashSize, dashGap)
    dashLine(float2(r, -r), float2(r,  r), dashSize, dashGap)
    dashLine(float2(r,  r), float2(-r,  r), dashSize, dashGap)
    dashLine(float2(-r,  r), float2(-r, -r), dashSize, dashGap)
    setLineWidth(1.0)


  def drawOsbLabels()
    setFontSize(16)
    let off = 0.04
    var modeLabel = "A-G"
    if selectedTrigger == int(WeaponTriggerType.AAM_TRIGGER)
      modeLabel = "A-A"
    drawStrAnchored(float2(-0.3, -0.5 + off), modeLabel, AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0, -0.5 + off), "PRE", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.3, -0.5 + off), "WPN SEL", AnchorHorz.Center, AnchorVert.Center)
    setColor(colors.orange)
    drawStrAnchored(float2(-0.3, 0.5 - off), "APK1", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.15, 0.5 - off), "APK2", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0, 0.5 - off), "APK3", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.15, 0.5 - off), "APK4", AnchorHorz.Center, AnchorVert.Center)
    setColor(WHITE)
    drawStrAnchored(float2(0.33, 0.475 - off), "TGP", AnchorHorz.Center, AnchorVert.Center)
    var tgpState = "OFF"
    if hasTgp
      tgpState = "ON"
    drawStrAnchored(float2(0.33, 0.5 - off), tgpState, AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.46, -0.28), "PUR",    AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(0.46, -0.24), "ON",     AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(0.46, -0.08), "BIT",    AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(0.46,  0.1),  "BARO",   AnchorHorz.Right, AnchorVert.Center)
    drawStrAnchored(float2(0.46,  0.27), "RELOAD", AnchorHorz.Right, AnchorVert.Center)
    drawStrVert(float2(-0.5 + off, -0.1), "FZ NT", AnchorHorz.Center, AnchorVert.Center)
    setFontSize(18)


  def draw()
    return if !isValid

    stations <- calcStations()

    setFullCanvasViewport()
    drawOutline()
    drawWeaponSlots()
    drawCountermeasures()
    drawOsbLabels()
    drawBorder()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)

require darg
require DagorMath
require DagorStdGuiRender
require math
require %rGui.utils.canvas_common
require GuidanceLock
require hud
require Plane
require Weapon
require HeroManager
require Unit


let
  CLR_GRN  = E3DCOLOR(0xFF_00CC00)
  CLR_RED  = E3DCOLOR(0xFF_FF2020)
  CLR_NONE = E3DCOLOR(0x00_000000)
  CLR_BG   = E3DCOLOR(0xFF_000000)
  CLR_YEL  = E3DCOLOR(0xFF_CCCC00)

  PYLON_COUNT = 5


struct PropStorage
  fontId : int
  vignette : Picture? = null


class Component : Canvas
  isTracking : bool = false
  turretYaw : float = 0.0
  turretPitch : float = 0.0
  pylonSlots : array<int>
  pylonAmmo : array<int>
  pylonMaxAmmo : array<int>
  pylonTrigger : array<int>
  selectedSlot : int = -1

  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; in_props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    isTracking = get_agm_guidance_lock_state() == GuidanceLockState.RESULT_TRACKING
    setLineWidth(1.5)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(in_props.fontId)
    setColor(CLR_GRN)
    setFillColor(CLR_NONE)

    get_weapon_slots() <| $(var tmp : array<int>#)
      pylonSlots := tmp
    get_weapon_slots_curr_ammo() <| $(var tmp : array<int>#)
      pylonAmmo := tmp
    get_weapon_slots_max_ammo() <| $(var tmp : array<int>#)
      pylonMaxAmmo := tmp
    get_weapon_slots_trigger() <| $(var tmp : array<int>#)
      pylonTrigger := tmp
    selectedSlot = get_selected_weapon_slot()

    let hero = get_watched_not_delayed_hero()
    if hero != null && hero.weap != null && length(hero.weap.turret) > 0
      turretYaw = hero.weap.turret[0].yawVisual
      turretPitch = hero.weap.turret[0].pitchVisual

  def pylonHasWeapon(pylon_idx : int) : bool
    for i in range(length(pylonSlots))
      if pylonSlots[i] == pylon_idx && i < length(pylonAmmo) && pylonAmmo[i] > 0
        return true
    return false

  def pylonIsSelected(pylon_idx : int) : bool
    for i in range(length(pylonSlots))
      if pylonSlots[i] == pylon_idx && i < length(pylonAmmo) && pylonAmmo[i] > 0
        if pylonSlots[i] == selectedSlot
          return true
    return false

  def pylonGetTrigger(pylon_idx : int) : int
    for i in range(length(pylonSlots))
      if pylonSlots[i] == pylon_idx && i < length(pylonAmmo) && pylonAmmo[i] > 0
        return pylonTrigger[i]
    return -1

  def pylonGetAmmo(pylon_idx : int) : int
    var total = 0
    for i in range(length(pylonSlots))
      if pylonSlots[i] == pylon_idx && i < length(pylonAmmo)
        total += pylonAmmo[i]
    return total

  def pylonIsContainer(pylon_idx : int) : bool
    for i in range(length(pylonSlots))
      if pylonSlots[i] == pylon_idx && i < length(pylonMaxAmmo) && pylonMaxAmmo[i] > 1
        return true
    return false

  def drawSideLabels()
    setFontSize(11)
    let y0 = -0.38
    let x = 0.628
    let dy = 0.153
    setColor(CLR_GRN)
    drawStrAnchored(float2(-x, y0),            "BAL",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy),       "MFD",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy * 2.0), "B/W",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy * 3.0), "E-O",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy * 4.0), "Corr", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-x, y0 + dy * 5.0), "Wnd",  AnchorHorz.Center, AnchorVert.Center)
    setColor(CLR_RED)
    drawStrAnchored(float2(x, y0), "FCS", AnchorHorz.Center, AnchorVert.Center)
    setColor(CLR_GRN)
    drawStrAnchored(float2(x, y0 + dy),       "PFD",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x, y0 + dy * 2.0), "NAV",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x, y0 + dy * 3.0), "STP",  AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x, y0 + dy * 4.0), "A-AE", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(x, y0 + dy * 5.0), "Exit", AnchorHorz.Center, AnchorVert.Center)

  def drawTopBar()
    setColor(CLR_GRN)
    setFontSize(10)
    let top = -0.46
    drawStrAnchored(float2(-0.575, top - 0.006), "OMGx:{fmt(":.2f", turretYaw)}", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(-0.575, top + 0.015), "OMGy:{fmt(":.2f", turretPitch)}", AnchorHorz.Left, AnchorVert.Top)

    let btnY = top + 0.015
    let brzinaX = -0.23
    let zahvatX = -0.075
    let pracenjeX = 0.075
    let crnoX = 0.23

    drawStrAnchored(float2(brzinaX, btnY), "BRZINA", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(zahvatX, btnY), "ZAHVAT", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(pracenjeX, btnY), "PRACENJE", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(crnoX, btnY), "CRNO", AnchorHorz.Center, AnchorVert.Center)

    drawStrAnchored(float2(0.44, top - 0.006), "AGx:{fmt(":.2f", turretYaw)}", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(0.44, top + 0.015), "AGy:{fmt(":.2f", turretPitch)}", AnchorHorz.Right, AnchorVert.Top)

    setColor(CLR_RED)
    drawStrAnchored(float2(0.55, top + 0.008), "FCS", AnchorHorz.Right, AnchorVert.Top)
    setColor(CLR_GRN)

  def drawPylonAtgm(pos : float2; radius : float; clr : E3DCOLOR)
    setColor(clr)
    drawCircle(pos, radius)
    let d = radius * 1.05
    drawLine(pos - float2(d, d), pos + float2(d, d))
    drawLine(float2(pos.x - d, pos.y + d), float2(pos.x + d, pos.y - d))

  def drawPylonBomb(pos : float2; radius : float; clr : E3DCOLOR)
    setColor(clr)
    drawCircle(pos, radius)
    let d = radius * 1.05
    drawLine(float2(pos.x, pos.y - d), float2(pos.x, pos.y + d))
    drawLine(float2(pos.x - d, pos.y), float2(pos.x + d, pos.y))

  def drawPylonRocket(pos : float2; radius : float; clr : E3DCOLOR; ammo : int)
    setColor(clr)
    drawCircle(pos, radius)
    let d = radius * 1.05
    let inner = radius
    drawLine(pos + float2(-d, -d), pos + float2(-inner * 0.707, -inner * 0.707))
    drawLine(pos + float2(d, -d), pos + float2(inner * 0.707, -inner * 0.707))
    drawLine(pos + float2(-d, d), pos + float2(-inner * 0.707, inner * 0.707))
    drawLine(pos + float2(d, d), pos + float2(inner * 0.707, inner * 0.707))
    if ammo > 1
      setFontSize(11)
      drawStrAnchored(pos, "{ammo}", AnchorHorz.Center, AnchorVert.Center)

  def drawBottomBar()
    setColor(CLR_GRN)
    setFontSize(11)
    let bot = 0.46
    let ry = bot + 0.015
    drawStrAnchored(float2(0.23, ry), "---", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.385, ry), "Res", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.54, ry), "+++", AnchorHorz.Center, AnchorVert.Center)

    let pylonY = bot - 0.035
    let pylonR = 0.0232
    let frameHalfW = 0.56
    let inset = frameHalfW * 2.0 * 0.1
    let gap = pylonR * 2.0 * 0.6
    let spacing = pylonR * 2.0 + gap
    let leftX = -frameHalfW + inset
    let rightX = frameHalfW - inset
    let pylonIndices = fixed_array<int>(1, 2, 3, 4, 5)
    let pylonPositions = fixed_array(
      float2(leftX, pylonY),
      float2(leftX + spacing, pylonY),
      float2(0.0, pylonY),
      float2(rightX - spacing, pylonY),
      float2(rightX, pylonY))
    for i in range(PYLON_COUNT)
      let pidx = pylonIndices[i]
      if !pylonHasWeapon(pidx)
        continue
      let clr = pylonIsSelected(pidx) ? CLR_GRN : CLR_YEL
      let trig = pylonGetTrigger(pidx)
      if trig == int(WeaponTriggerType.AGM_TRIGGER)
        drawPylonAtgm(pylonPositions[i], pylonR, clr)
      elif trig == int(WeaponTriggerType.BOMBS_TRIGGER) || trig == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
        drawPylonBomb(pylonPositions[i], pylonR, clr)
      elif trig == int(WeaponTriggerType.ROCKETS_TRIGGER)
        drawPylonRocket(pylonPositions[i], pylonR, clr, pylonGetAmmo(pidx))
      else
        drawPylonAtgm(pylonPositions[i], pylonR, clr)

  def drawTvCrosshair()
    setColor(CLR_GRN)
    setLineWidth(1.5)
    let armLen = 0.0225
    drawLine(float2(0.0, -armLen), float2(0.0, armLen))
    drawLine(float2(-armLen, 0.0), float2(armLen, 0.0))

  def drawGate()
    setColor(isTracking ? CLR_RED : CLR_GRN)
    setLineWidth(1.5)
    let gx = 0.12
    let gy = 0.07
    let cornerLen = 0.03
    drawLine(float2(-gx, -gy), float2(-gx + cornerLen, -gy))
    drawLine(float2(-gx, -gy), float2(-gx, -gy + cornerLen))
    drawLine(float2(gx, -gy), float2(gx - cornerLen, -gy))
    drawLine(float2(gx, -gy), float2(gx, -gy + cornerLen))
    drawLine(float2(-gx, gy), float2(-gx + cornerLen, gy))
    drawLine(float2(-gx, gy), float2(-gx, gy - cornerLen))
    drawLine(float2(gx, gy), float2(gx - cornerLen, gy))
    drawLine(float2(gx, gy), float2(gx, gy - cornerLen))

  def drawBlackBorder()
    let flt = float2(-0.56, -0.414)
    let frb = float2(0.56, 0.414)
    setColor(CLR_BG)
    setFillColor(CLR_BG)
    drawBox(float2(-0.7, -0.7), float2(0.7, flt.y))
    drawBox(float2(-0.7, frb.y), float2(0.7, 0.7))
    drawBox(float2(-0.7, flt.y), float2(flt.x, frb.y))
    drawBox(float2(frb.x, flt.y), float2(0.7, frb.y))
    setFillColor(CLR_NONE)

  def drawFrame()
    setColor(E3DCOLOR(0xFF_FFFFFF))
    setLineWidth(1.0)
    drawBox(float2(-0.56, -0.414), float2(0.56, 0.414))

  def drawVignette(vignette : darg::Picture?)
    return if vignette == null
    let sc = min(canvasSize.x, canvasSize.y)
    let hSize = 0.5 * canvasSize / sc
    setColor(E3DCOLOR(0xFFFFFFFF))
    drawPicture(-hSize, hSize * 2.0, vignette)

  def draw(in_props : PropStorage&)
    setFullCanvasViewport()
    drawBlackBorder()
    drawFrame()
    drawTopBar()
    drawBottomBar()
    drawTvCrosshair()
    drawGate()
    drawSideLabels()
    drawVignette(in_props.vignette)
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw(props)


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = props |> getInt("fontId", 0)
  propStorage.vignette = props |> getPicture("vignette")

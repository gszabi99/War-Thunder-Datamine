require %rGui.utils.canvas_common
require %rGui.utils.helpers_common
require %rGui.utils.weaponslots_common

require app
require DagorDataBlock
require DagorMath
require DagorStdGuiRender
require DagorSystem
require darg
require FlightModelWrap
require GuidanceLock
require HeroManager
require hud
require math
require Plane
require strings
require Unit
require Weapon


def loc_wpn(str : string) : string
  if str.empty()
    return ""
  return loc("mfd/f_5th_wpn/{str.replace("_default", "")}")


struct Shapes
  outline = fixed_array(
    float2(-0.000, -0.000),
    float2(-0.015, -0.001),
    float2(-0.029, -0.006),
    float2(-0.077, -0.014),
    float2(-0.087, -0.019),
    float2(-0.096, -0.028),
    float2(-0.405, -0.037),
    float2(-0.405, -0.046),
    float2(-0.106, -0.047),
    float2(-0.108, -0.055),
    float2(-0.107, -0.071),
    float2(-0.099, -0.085),
    float2(-0.092, -0.092),
    float2(-0.084, -0.096),
    float2(-0.077, -0.106),
    float2(-0.069, -0.113),
    float2(-0.060, -0.116),
    float2(-0.056, -0.138),
    float2(-0.052, -0.154),
    float2(-0.041, -0.170),
    float2(-0.024, -0.180),
    float2(-0.010, -0.185),
    float2(-0.004, -0.273),
    float2(-0.003, -0.280),
    float2(-0.000, -0.284),
  )


struct Colors
  green     = E3DCOLOR(Color4(float4(0.000, 1.000, 0.000, 1.000)))  //#00FF00
  red       = E3DCOLOR(Color4(float4(1.000, 0.000, 0.000, 1.000)))  //#FF0000
  nullColor = E3DCOLOR(0x0)
  black     = E3DCOLOR(Color4(float4(0.000, 0.000, 0.000, 1.000)))  //#000000


struct PropStorage
  fontId    : int
  fontSize  : int
  declutter : bool


struct Guidance
  isActive     : bool              = false
  guidanceType : GuidanceType      = GuidanceType.TYPE_INVALID
  lockState    : GuidanceLockState = GuidanceLockState.RESULT_INVALID


class Component : Canvas
  isValid         : bool              = false
  hero            : Unit?             = null
  fmw             : FlightModelWrap?  = null
  fm              : FlightModel?      = null
  wc              : WeaponController? = null
  app             : AcesApp?          = null
  ws              : WeaponSlots?      = null
  colors          : Colors            = Colors()
  shapes          : Shapes            = Shapes()
  defaultFontSize : int               = 18
  declutter       : bool              = false
  stations        : array<float2>

  isArmed  : bool     = false
  guidance : Guidance = Guidance()

  outlScale      : float2 = float2(0.7)         // Scale of aircraft outline
  outlOffset     : float2 = float2(0.0, -0.14)  // Offset of aircraft outline
  outlTransl     : float2 = float2(0.0, -0.12)  // Transflate of aircraft outline and stations
  outlWing       : float  = 0.7                 // Wingspan
  outlPylon      : float2 = float2(0.005, 0.0)  // Pylon width & height
  slotCount      : int    = 8                   // Number of slots on the aircraft
  slotOffset     : float2 = float2(0.0, 0.05)   // Offset of the first slot from the wingtip
  slotHeight     : float  = 0.52                // Maximum length of slot connector lines
  slotMarkerSize : float  = 0.02                // Size of the slot marker circle


  def initDeclutter()
    outlTransl = float2(0.0, -0.36)  // Transflate of aircraft outline and stations


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
    resetColors()
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    if props.declutter
      setScale(float2(canvasSize.y))
    else
      setScale(float2(canvasSize.y * 1.4, canvasSize.y * 1.2))
    setFont(props.fontId)
    defaultFontSize = props.fontSize
    resetFontSize()

    isArmed = !(fmw.isOnGround || fm.currentAlt < fmw.minAltitudeForDropShells)
    var secondaryWeapon : Weapon?
    get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
      secondaryWeapon := weapon

    var lockState = GuidanceLockState.RESULT_INVALID
    var guidanceType = GuidanceType.TYPE_INVALID
    if secondaryWeapon != null
      guidanceType = get_weapon_guidance_type(secondaryWeapon)
      if secondaryWeapon.trigger_no == int(WeaponTriggerType.AAM_TRIGGER)
        lockState = get_aam_guidance_lock_state()
      elif secondaryWeapon.trigger_no == int(WeaponTriggerType.AGM_TRIGGER)
        lockState = get_agm_guidance_lock_state()
      elif secondaryWeapon.trigger_no == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
        lockState = get_bomb_guidance_lock_state()
    if guidanceType != GuidanceType.TYPE_INVALID
      guidance.isActive = true
      guidance.lockState = lockState
      guidance.guidanceType = guidanceType

    declutter = props.declutter
    if declutter
      initDeclutter()


  def calcStations() : array<float2>
    let mid = slotCount / 2
    let wing = outlWing * 0.5
    return <- [
      for i in 0 .. slotCount;
      float2(
        lerp(-wing + slotOffset.x, wing - slotOffset.x, float(i) / float(slotCount)),
        (i <= mid) ?
        lerp(slotHeight, slotOffset.y, float(i) / float(mid))
        : lerp(slotOffset.y, slotHeight, float(i - mid) / float(mid))
      ) + outlTransl
    ]


  def resetColors()
    setColor(colors.green)
    setFillColor(colors.nullColor)


  def resetFontSize()
    setFontSize(defaultFontSize)


  def drawOutline()
    return if declutter

    setFillColor(colors.green)
    var outline : array<float2> <- shapes.outline.to_array()
    outline.reserve(shapes.outline.length() * 2)
    outline.pop()
    outline.emplace(shapes.outline.flip().inv_x())
    outline.pop()
    drawFilledPolyOutlined(outline.translate(outlTransl + outlOffset).scale(outlScale))
    resetColors()


  def drawGunAmmo(pos : float2)
    let gunAmmo = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
    drawStrAnchored(pos, fmt(":>3d", gunAmmo), AnchorHorz.Center, AnchorVert.Top)


  def drawOsbLabels()
    let osbCount = 5
    let inset = -0.1
    let step = (1.0 - inset - inset) / float(osbCount - 1)
    let margin = 0.03
    let bboxMargin = 0.005
    let p0 = 0.5 - margin
    let p1 = 0.5 - inset
    // Bottom
    drawStrAnchored(float2(-p1 + step, p0), "SWAP", AnchorHorz.Center, AnchorVert.Bottom)
    drawBBox(getStrBbox(float2(-p1 + step * 2.0, p0), "SMS", AnchorHorz.Center, AnchorVert.Bottom), bboxMargin)
    drawStrAnchored(float2(-p1 + step * 2.0, p0), "SMS", AnchorHorz.Center, AnchorVert.Bottom)
    drawStrAnchored(float2(-p1 + step * 3.0, p0), "FCR", AnchorHorz.Center, AnchorVert.Bottom)
    // Top
    drawGunAmmo(float2(p1 - step * 2.0, -p0))
    drawStrAnchored(float2(p1 - step * 3.0, -p0), isArmed ? "ARM" : "SAFE", AnchorHorz.Center, AnchorVert.Top)


  def drawStationMarker(slot_no : int)
    let pos = stations[slot_no]
    let posCircle = float2(pos.x, outlPylon.y - 1.5 * slotMarkerSize) + outlTransl
    drawCircle(posCircle, slotMarkerSize)
    if declutter
      let curColor = self.color
      setColor(colors.black)
      drawStrAnchored(posCircle, string(slot_no), AnchorHorz.Center, AnchorVert.Center)
      setColor(curColor)


  def drawsStationLine(slot_no : int)
    let pos = stations[slot_no]
    let width = 0.004
    drawBox(
      float2(pos.x - width, outlPylon.y) + outlTransl,
      float2(pos.x + width, pos.y))


  def drawStation(slot : WeaponSlot&)
    if slot.curAmmo > 0 || slot.maxAmmo < 1
      setColor(colors.green)
      setFillColor(colors.green)
    else
      setColor(colors.red)
      setFillColor(colors.red)

    drawStationMarker(slot.slot)
    if slot.maxAmmo > 0
      drawsStationLine(slot.slot)

    resetColors()


  def drawWeaponLabel(slot : WeaponSlot&)
    let offset = float2(0.0, 0.02)
    let pos = stations[slot.slot] + offset
    setFontSize(roundi(float(defaultFontSize) * 0.8))
    drawStrAnchored(pos, loc_wpn(slot.locName), AnchorHorz.Center, AnchorVert.Top)
    resetFontSize()


  def drawWeaponSlots()
    setFillColor(colors.green)
    for i in 1 .. slotCount
      drawStationMarker(i)
    for i in 0 .. ws.length()
      continue if (hero.slotIdByWeaponId[i] <= 0)
      let slot = ws.getWeaponSlot(i)
      continue if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)
      continue if slot.trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER)
      continue if slot.slot < 0
      if slot.slot >= slotCount
        logwarn("mfdF5ThWpn.das: WeaponSlot {slotCount} out of bounds")
        continue

      drawStation(slot)
      if slot.nextToShoot
        drawWeaponLabel(slot)


  def drawWeaponStatus()
    return if !declutter

    let pos = float2(0)
    var str = ""
    if !isArmed
      str = "SAFE"
    elif guidance.isActive && int(guidance.lockState) <= int(GuidanceLockState.RESULT_WARMING_UP)
      str = "STBY"
    elif !guidance.isActive || (guidance.isActive && int(guidance.lockState) >= int(GuidanceLockState.RESULT_LOCKING))
      str = "READY"
    if !str.empty()
      drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Center)


  def draw()
    return if !isValid

    stations <- calcStations()

    setFullCanvasViewport()
    resetColors()
    if declutter
      drawOsbLabels()
    drawWeaponSlots()
    drawWeaponStatus()
    drawOutline()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.declutter = getBool(props, "declutter", false)

  let blk = getBlk(props, "blk")
  return if blk == null

  propStorage.fontSize = *blk->datablock_getInt("fontSize", 18)

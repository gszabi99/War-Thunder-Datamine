require %rGui.planeCockpit.mfdRafaleWpnConstants
require %rGui.utils.canvas_common
require %rGui.utils.poly_shape_common

require app
require DagorMath
require DagorStdGuiRender
require DagorSystem
require darg
require Plane
require FlightModelWrap
require HeroManager
require hud
require math
require strings
require Unit
require Weapon
require WTCamera
require GuidanceLock

def radToDeg(rad : float)
  return rad * 180.0 / PI


def degToRad(rad : float)
  return rad * PI / 180.0


def boxCalcPoints(pos : float2; size : float2) : tuple<lt : float2, rb : float2>
  return size * -0.5 + pos, size * 0.5 + pos


struct PropStorage
  fontId : int

struct WeaponSlots
  slot : array<int>
  name : array<string>
  jettisoned : array<bool>
  maxAmmo : array<int>
  currAmmo : array<int>
  trigger : array<int>
  selected : int


def weaponslots_update(var self : WeaponSlots&)
  with self
    slot |> clear()
    name |> clear()
    jettisoned |> clear()
    maxAmmo |> clear()
    currAmmo |> clear()
    trigger |> clear()

    get_weapon_slots() <| $(var tmp : array<int>#)
      slot := tmp

    get_weapon_slots_names() <| $(var tmp : array<string const>#)
      for tmp_ in tmp
        name.push_clone(tmp_)

    get_weapon_slots_jettisoned() <| $(var tmp : array<bool>#)
      jettisoned := tmp

    get_weapon_slots_max_ammo() <| $(var tmp : array<int>#)
      maxAmmo := tmp

    get_weapon_slots_curr_ammo() <| $(var tmp : array<int>#)
      currAmmo := tmp

    get_weapon_slots_trigger() <| $(var tmp : array<int>#)
      trigger := tmp

    selected = get_selected_weapon_slot()


class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  wc : WeaponController? = null
  app : AcesApp? = null
  isArmed : bool = false
  isWeaponSelectorOn : bool = false
  shapes = Shapes()
  colors = Colors()
  stations = Stations()
  stationIndicators <- StationIndicators().pos
  safetyIndicators <- SafetyIndicators().y
  slots = WeaponSlots()
  defaultLineWidth = 2.0
  defaultFontSize = 42
  // Transforms for children of aircraft outline
  gPos = float2(0, 0.09)
  gScale = float2(1.0, 1.20)


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)
    hero = get_watched_not_delayed_hero()
    fmw = hero.as_fmw()
    wc = hero.weap
    app = get_app()

    if fmw == null || wc == null
      return

    isValid = true
    setColor(colors.white)
    setLineWidth(defaultLineWidth)
    setFont(props.fontId)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(42)

    fm = fmw.fm
    isArmed = !(fmw.isOnGround || fm.currentAlt < fmw.minAltitudeForDropShells)
    isWeaponSelectorOn = app.flightControlMode.isWeaponSelectorOn


  def resetLineWidth()
    setLineWidth(defaultLineWidth)


  def drawAircraftOutline()
    setColor(colors.blue)

    shapes.outline.main |> poly_draw(self, gPos, gScale)
    shapes.outline.canard |> poly_draw_symmetrical(self, true, false, gPos, gScale)


  def drawAam(pos : float2; isSelected : bool; hasSeeker : bool; isNextToShoot : bool)
    selectWeaponColor(isSelected)
    let scale = float2(0.27, 0.3)

    if (isNextToShoot)
      let lockState = get_aam_guidance_lock_state()
      if (lockState == GuidanceLockState.RESULT_WARMING_UP || lockState == GuidanceLockState.RESULT_INVALID)
        setColor(colors.purple)

    shapes.mica.body |> poly_draw(self, pos, scale)
    shapes.mica.strake |> poly_draw_symmetrical(self, true, false, pos, scale)
    shapes.mica.fin |> poly_draw_symmetrical(self, true, false, pos, scale)

    setColor(colors.red)
    if (hasSeeker)
      shapes.mica.seeker |> poly_draw(self, pos, scale)


  def drawTank(pos : float2)
    setColor(colors.yellow)
    let scale = float2(0.45, 0.56)

    shapes.tank.tank |> poly_draw(self, pos, scale)
    shapes.tank.fin |> poly_draw_symmetrical(self, true, false, pos, scale)


  def drawGun()
    setColor(colors.white)

    let pos = float2(0.190, -0.270) * gScale + gPos
    let boxBase = boxCalcPoints(pos, float2(0.03, 0.02))
    drawBox(boxBase.lt, boxBase.rb)
    let boxBarrel = boxCalcPoints(pos + float2(0, -0.04), float2(0.014, 0.06))
    drawBox(boxBarrel.lt, boxBarrel.rb)

    setLineWidth(lineWidth * 0.6)
    drawSector(pos + float2(0.0, -0.055), float2(0.07), float2(degToRad(90.0 - 30.0), degToRad(90.0 + 30.0)))
    resetLineWidth()

    setTextAnchorHorz(AnchorHorz.Center)
    setFontSize(37)
    let ammo = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))
    drawStr(pos + float2(-0.01, 0.05), "{ammo}", 3)


  def drawStationIndicators()
    setColor(colors.blue)
    for station in stationIndicators
      drawCircle(station * gScale + gPos, 0.01)


  def drawTargetingPod(pos : float2)
    setColor(colors.green)
    let scale = float2(0.2)

    shapes.targetingPod.optic |> poly_draw(self, pos, scale)
    shapes.targetingPod.base |> poly_draw(self, pos, scale)


  def drawMultipleEjector(var pos : float2)
    setColor(colors.yellow)
    pos += float2(0.0, -0.03)
    let scale = float2(0.35, 0.42)

    shapes.multipleEjector.multipleEjector |> poly_draw(self, pos, scale)


  def drawBombFill(pos : float2; scale : float2)
    setColor(colors.black)
    shapes.bomb.body.shapeType = ShapeType.PolyFilledOutlined
    shapes.bomb.fin.shapeType = ShapeType.PolyFilledOutlined
    shapes.bomb.body |> poly_draw(self, pos, scale)
    shapes.bomb.fin |> poly_draw_symmetrical(self, true, false, pos, scale)
    shapes.bomb.body.shapeType = ShapeType.Poly
    shapes.bomb.fin.shapeType = ShapeType.Poly


  def drawBomb(pos : float2; isSelected : bool; hasSeeker : bool; drawFilled : bool = false)
    let scale = float2(0.14, 0.17)
    if (drawFilled)
      drawBombFill(pos, scale)
    selectWeaponColor(isSelected)

    shapes.bomb.body |> poly_draw(self, pos, scale)
    shapes.bomb.fin |> poly_draw_symmetrical(self, true, false, pos, scale)
    setColor(colors.red)
    if (hasSeeker)
      shapes.bomb.seeker |> poly_draw(self, pos, scale)


  def drawMultipleBombs(pos : float2; isSelected : bool; ammo : int; hasSeeker : bool; drawFilled : bool = false)
    if (ammo > 2)
      drawBomb(pos + float2(0.0, -0.11), isSelected, hasSeeker)
    if (ammo > 1)
      setColor(colors.yellow)
      setFontSize(35)
      drawStrAnchored(float2(pos.x, 0.49), fmt(":02d", ammo), AnchorHorz.Center, AnchorVert.Bottom)
      drawBomb(pos + float2(-0.04, 0.14), isSelected, hasSeeker, true)
    if (ammo > 0)
      drawBomb(pos + float2(0.04, 0.14), isSelected, hasSeeker, true)


  def drawWeaponStatusIndicators(pos : float2; isNextToShoot : bool)
    setColor(colors.yellow)

    let safe = isArmed ? " " : "S"
    let nts = isNextToShoot ? "D" : " "

    setFontSize(35)
    drawStrAnchored(pos, "{safe}{nts}", AnchorHorz.Center, AnchorVert.Bottom)


  def drawWeaponSlots()
    let n = slots.slot.length() - 1
    for i in range(0, n)
      let station = slots.slot[i]
      continue if (station < 0)

      if (station >= stations.pos.length())
        logerr("mfdRafaleWpn: Attempt to access non-existent weaponslot {station}")
        return

      if (i >= slots.name.length()
        || i >= slots.currAmmo.length()
        || i >= slots.maxAmmo.length()
        || i >= slots.trigger.length()
        || i >= slots.jettisoned.length())
        logerr("mfdRafaleWpn: Attempted out-of-bounds access at index {i}")
        return

      let name = slots.name[i]
      continue if (name.empty())

      var currWeaponName : string
      get_selected_secondary_weapon(fmw) <| $(var weapon : Weapon?#)
        let shellProps = weapon?.prop?.shellProps
        currWeaponName = (shellProps != null) ? get_weapon_name(*shellProps) : ""
        currWeaponName = replace(currWeaponName, "_default", "")

      let currAmmo = slots.currAmmo[i]
      let maxAmmo = slots.maxAmmo[i]
      let trigger = slots.trigger[i]
      let jettisoned = slots.jettisoned[i]
      let isSelected = name.find(currWeaponName) != -1 ? true : false
      let pos = stations.pos[station] * gScale + gPos
      let hasAmmo = (currAmmo > 0)
      let isNextToShoot = (slots.selected == station)
      let multipleEjector = (maxAmmo > 1)

      if (isNextToShoot)
        drawStatus(hasAmmo)
      if (multipleEjector && !jettisoned)
        drawMultipleEjector(pos)

      continue if (!hasAmmo)

      assert(stations.pos.length() == stations.offsetAam.length())
      assert(stations.pos.length() == safetyIndicators.length())

      let isSmartBomb = (trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
        || trigger == int(WeaponTriggerType.AGM_TRIGGER))

      if (trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER))
        drawTargetingPod(pos)
      elif (trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER))
        drawTank(pos)
      elif (trigger == int(WeaponTriggerType.AAM_TRIGGER))
        let hasSeeker = (name.find("mica_em") != -1)
        drawAam(pos + stations.offsetAam[station], isSelected, hasSeeker, isNextToShoot)
        drawWeaponStatusIndicators(float2(pos.x, safetyIndicators[station] * gScale.y + gPos.y), isNextToShoot)
      elif (isSmartBomb || trigger == int(WeaponTriggerType.BOMBS_TRIGGER))
        if (multipleEjector)
          drawMultipleBombs(pos, isSelected, currAmmo, isSmartBomb)
        else
          drawBomb(pos, isSelected, isSmartBomb)
        drawWeaponStatusIndicators(float2(pos.x, safetyIndicators[station] * gScale.y + gPos.y), isNextToShoot)


  def drawFrame()
    setColor(colors.green)
    let real = "REAL"
    let realBbox = getStringSize(real, real.length())
    let realPos = float2(-0.39, -0.34)
    let realMargin  = 0.005
    setFontSize(42)

    let bbox = drawStrAnchored(realPos, real, AnchorHorz.Right, AnchorVert.Top)
    drawBBox(bbox, realMargin)

    setColor(colors.white)
    drawStrAnchored(float2(-0.39, -0.10), "SIM", AnchorHorz.Right, AnchorVert.Top)
    drawStrAnchored(float2(-0.46, 0.46), "SEL", AnchorHorz.Left, AnchorVert.Bottom)


  def drawStatus(hasAmmo : bool)
    let pos = float2(0.32, -0.47)
    if (hasAmmo)
      setColor(colors.yellow)
      shapes.statusIndicator.w |> poly_draw(self, pos, float2(1.1, 0.7))
    else
      setColor(colors.red)
      let scale = float2(0.5, 1.5)
      let offset = float2(0.01, 0.0)
      shapes.statusIndicator.line |> poly_draw(self, pos + offset * float2(0.5), scale)
      shapes.statusIndicator.line |> poly_draw(self, pos + offset * float2(-0.5), scale)
      shapes.statusIndicator.line |> poly_draw(self, pos + offset * float2(1.5), scale)
      shapes.statusIndicator.line |> poly_draw(self, pos + offset * float2(-1.5), scale)
      let box  = boxCalcPoints(pos, float2(0.06, 0.04))
      drawBox(box.lt, box.rb)


  def drawCf()
    setColor(colors.yellow)
    let pos = float2(0, -0.300) * gScale + gPos

    setFontSize(42)
    drawStrAnchored(pos, "CF", AnchorHorz.Center, AnchorVert.Center)


  def selectWeaponColor(isSelected : bool)
    if (!isWeaponSelectorOn)
      setColor(colors.white)
    elif (isSelected)
      setColor(colors.green)
    else
      setColor(colors.orange)


  def draw()
    return if !isValid

    slots |> weaponslots_update()

    setFullCanvasViewport()
    drawAircraftOutline()
    drawStationIndicators()
    drawWeaponSlots()
    drawGun()
    drawFrame()
    drawCf()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)

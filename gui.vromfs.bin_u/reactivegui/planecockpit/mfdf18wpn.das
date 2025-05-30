require %rGui.planeCockpit.mfdF18WpnConstants
require %rGui.utils.canvas_common
require %rGui.utils.helpers_common
require %rGui.utils.weaponslots_common
require %rGui.utils.constants_common

require app
require DagorMath
require DagorStdGuiRender
require darg
require FlightControl
require FlightModelWrap
require HeroManager
require math
require Mission
require Plane
require strings
require Unit
require Weapon
require WTCamera
require Sensors
require GamePhys

def calc_box_points(pos : float2; size : float2) : tuple<lt : float2, rb : float2>
  return size * -0.5 + pos, size * 0.5 + pos


def loc_wpn(str : string) : string
  if str.empty()
    return ""
  return loc("mfd/f_18_wpn/{str}")


struct PropStorage
  fontId : int


enum MasterMode
  AA
  AG


enum WeaponDeliveryMode
  GUN_CCIP
  AAM
  BOMBS_CCRP
  BOMBS_CCIP
  ROCKETS_CCIP


struct Tracking
  isActive : bool
  pos : float3
  distance : float
  distanceRate : float
  dirNorm : float3
  angVel : float3


class Component : Canvas
  isValid : bool = false
  hero : Unit? = null
  fmw : FlightModelWrap? = null
  fm : FlightModel? = null
  wc : WeaponController? = null
  app : AcesApp? = null
  ws : WeaponSlots? = null
  toi : Tracking = Tracking()
  shapes : Shapes = Shapes()
  colors : Colors = Colors()
  stations : Stations = Stations()

  isArmed : bool = false
  isWeaponSelectorOn : bool = false
  isSpiSet : bool = false
  masterMode : MasterMode = MasterMode.AA
  weaponDeliveryMode : WeaponDeliveryMode = WeaponDeliveryMode.GUN_CCIP
  weapons : table<string, bool>
  gunAmmo : int = 0


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


    using() <| $(var target : TargetOfInterest#)
      if hero.sensors.getSelectedTargetOfInterest(hero.detector, target)
        toi.isActive = true
        toi.pos = target.from + target.dirNorm * target.distance
        toi.distance = target.distance
        toi.distanceRate = target.distanceRate
        toi.dirNorm = target.dirNorm
        toi.angVel = target.angVel

    ws = new WeaponSlots(hero, app, fmw, wc)

    isValid = true
    setColor(colors.green)
    setLineWidth(1.0)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))
    setFont(props.fontId)
    setFontSize(15)
    setLineSpacing(0.85)

    isArmed = !(fmw.isOnGround || fm.currentAlt < fmw.minAltitudeForDropShells)
    isWeaponSelectorOn = app.flightControlMode.isWeaponSelectorOn
    var spi : float3
    if get_point_of_interest(spi)
      isSpiSet = true
    gunAmmo = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)))


  def drawWeaponLabel(slot : WeaponSlot; isNts : bool; hasAdapter : bool = false)
    var pos = stations.pos[slot.slot] + stations.lblOffset[slot.slot]
    let margin = float2(0.007)
    if hasAdapter
      pos += float2(0.0, 0.03)
    drawStrAnchored(pos, loc_wpn(slot.locName), AnchorHorz.Center, AnchorVert.Center)
    if isNts
      let box = calc_box_points(pos, float2(0.11, getStringSize(loc_wpn(slot.locName)).y + margin.y))
      drawBox(box.lt, box.rb)


  def drawSettings()
    if weaponDeliveryMode == WeaponDeliveryMode.BOMBS_CCIP || weaponDeliveryMode == WeaponDeliveryMode.BOMBS_CCRP
      drawBombSettings()
    elif masterMode == MasterMode.AA
      drawRadarSettings()


  def drawBombSettings()
    setFontSize(16)
    drawStrAnchored(float2(0.0, 0.17), "PROG 1", AnchorHorz.Center, AnchorVert.Bottom)
    let width =  0.5 * getStringSize("PROG 1").x + 0.005
    drawLine(float2(width, 0.18), float2(-width, 0.18))

    setCaretPosition(float2(-0.21, 0.24))
    printStrLn("MODE")
    printStrLn("MFUZ")
    printStrLn("EFUZ")

    setCaretPosition(float2(-0.09, 0.24))
    printStrLn((weaponDeliveryMode == WeaponDeliveryMode.BOMBS_CCRP) ? "AUTO" : "CCIP")
    printStrLn("NOSE")
    printStrLn("DLY1")


  def drawRadarSettings()
    setFontSize(16)
    return if !toi.isActive

    let tangVel = toi.angVel * toi.distance
    let relVel = tangVel + toi.distanceRate * toi.dirNorm
    let targetVel = hero.vel + relVel
    let targetSpd = length(targetVel)
    let targetBaroAlt = toi.pos.y - app.currentScene.waterLevel
    let targetMach = targetSpd / atmosphere_sonicSpeed(targetBaroAlt)
    let altDiff = hero.pos.y - toi.pos.y
    let tas = length(hero.vel) * mpsToKmh
    let horzAspect = (atan2(targetVel.x, targetVel.z) - atan2(hero.vel.x, hero.vel.z)) * radToDeg
    let vertAspect = (atan2(toi.dirNorm.x, toi.dirNorm.y) - atan2(hero.vel.x, hero.vel.y)) * radToDeg * -1.0

    setCaretPosition(float2(-0.36, 0.15))
    printStrLn("RNG      {roundi(toi.distance)}")
    printStrLn("VC        {roundi(toi.distanceRate * mpsToKnots)}")
    printStrLn("V          M  {fmt(":.1f", targetMach)}")
    printStrLn("  ALT    {roundi(altDiff)}")
    printStrLn("ASPCT  {roundi(horzAspect)}{loc("measureUnits/deg")}")

    setCaretPosition(float2(0.01, 0.15))
    printStrLn("ALT      {fmt(":<7d", roundi(targetBaroAlt))} B")
    printStrLn("TAS      {roundi(tas)}")
    printStrLn("ASPCT  {roundi(vertAspect)}{loc("measureUnits/deg")}")
    printStrLn("ROLL {fmw.roll > 0.0 ? "R" : "L"}   {fmt(":>3", abs(roundi(fmw.roll)))}{loc("measureUnits/deg")}")

    drawLine(float2(-0.4, 0.1), float2(0.4, 0.1))


  def drawAamSymbol(pos : float2)
    drawCircle(pos, 0.01)
    let point1 = float2(0.004)
    let point2 = float2(0.012)
    drawLine(point1 + pos, point2 + pos)
    drawLine(-point1 + pos, -point2 + pos)
    drawLine(point1 * float2(1, -1) + pos, point2 * float2(1, -1) + pos)
    drawLine(point1 * float2(-1, 1) + pos, point2 * float2(-1, 1) + pos)


  def drawAamSlot(slot : WeaponSlot&)
    if slot.curAmmo <= 0
      return
    let pos = stations.pos[slot.slot]
    if slot.maxAmmo > 1
      let offset = float2(0.015, 0.0)
      if slot.curAmmo > 0
        drawAamSymbol(pos + offset)
      if slot.curAmmo > 1
        drawAamSymbol(pos - offset)
        if slot.nextToShoot
          drawStrAnchored(pos + float2(0.0, 0.05), "L SEL", AnchorHorz.Center, AnchorVert.Top)
    else
      drawAamSymbol(pos)
    drawWeaponLabel(slot, slot.nextToShoot)


  def drawBombSlot(slot : WeaponSlot&)
    if slot.curAmmo <= 0
      return
    let pos = stations.pos[slot.slot]
    drawClosedPolyLine(shapes.diamond.to_array().scale(float2(0.025)).translate(pos))
    drawStrAnchored(pos + float2(0.0, 0.017), "{slot.curAmmo}", AnchorHorz.Center, AnchorVert.Top)
    drawWeaponLabel(slot, slot.nextToShoot, true)


  def drawRocketSlot(slot : WeaponSlot&)
    if slot.curAmmo <= 0
      return
    let pos = stations.pos[slot.slot]
    drawClosedPolyLine(shapes.diamond.to_array().scale(float2(0.025)).translate(pos))
    drawStrAnchored(pos + float2(0.0, 0.017), "{slot.curAmmo}", AnchorHorz.Center, AnchorVert.Top)
    drawWeaponLabel(slot, slot.nextToShoot, true)


  def drawTextSlot(slot : WeaponSlot&)
    if slot.curAmmo <= 0
      return
    let pos = stations.pos[slot.slot]
    drawStrAnchored(pos, loc_wpn(slot.locName), AnchorHorz.Center, AnchorVert.Center)


  def drawWeaponSlots()
    setFontSize(14)
    for i in 0 .. ws.length()
      continue if (hero.slotIdByWeaponId[i] <= 0)
      let slot = ws.getWeaponSlot(i)

      if (slot.trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER)
        || slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)
        || slot.trigger == int(WeaponTriggerType.AGM_TRIGGER))
        drawTextSlot(slot)
      elif (slot.trigger == int(WeaponTriggerType.AAM_TRIGGER))
        drawAamSlot(slot)
      elif (slot.trigger == int(WeaponTriggerType.BOMBS_TRIGGER)
        || slot.trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER))
        drawBombSlot(slot)
      elif (slot.trigger == int(WeaponTriggerType.ROCKETS_TRIGGER))
        drawRocketSlot(slot)

      if masterMode == MasterMode.AA
        if (slot.trigger == int(WeaponTriggerType.AAM_TRIGGER))
          if slot.curAmmo > 0
            weapons.insert(slot.locName, slot.selected)
      elif masterMode == MasterMode.AG
        if (slot.trigger == int(WeaponTriggerType.BOMBS_TRIGGER)
          || slot.trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
          || slot.trigger == int(WeaponTriggerType.AGM_TRIGGER)
          || slot.trigger == int(WeaponTriggerType.ROCKETS_TRIGGER))
          if slot.curAmmo > 0
            weapons.insert(slot.locName, slot.selected)


  def drawOsbLabelVert(pos : float2; str : string; isSelected : bool; margin : float2 = float2(0))
    drawStrVert(pos, str, AnchorHorz.Center, AnchorVert.Center)
    let size = getVertStringSize(str)
    if isSelected
      let box = calc_box_points(pos, size + margin)
      drawBox(box.rb, box.lt)

  def drawOsbLabel(pos : float2; str : string; isSelected : bool; margin : float2 = float2(0))
    drawStrAnchored(pos, str, AnchorHorz.Center, AnchorVert.Center)
    let size = getStringSize(str)
    if isSelected
      let box = calc_box_points(pos, size + margin)
      drawBox(box.rb, box.lt)

  def drawOsbLabelsBombs(offsetFrame : float)
    drawOsbLabelVert(float2(-0.5 + offsetFrame, -0.3), "MODE", false)
    drawOsbLabelVert(float2(-0.5 + offsetFrame, -0.15), "MFUZ", false)
    drawOsbLabelVert(float2(-0.5 + offsetFrame, 0.0), "EFUZ", false)
    drawOsbLabelVert(float2(-0.5 + offsetFrame, 0.15), "DRAG", false)

    drawOsbLabelVert(float2(0.5 - offsetFrame, 0.15), "UFC", false)

    drawOsbLabel(float2(-0.3, 0.5 - offsetFrame), "PROG", false)
    drawOsbLabel(float2(-0.15, 0.5 - offsetFrame), "TONE", false)
    drawOsbLabel(float2(0.15, 0.5 - offsetFrame), "DATA", false)


  def drawOsbLabelsRockets(offsetFrame : float; margin : float2)
    drawOsbLabelVert(float2(-0.5 + offsetFrame, -0.3), "CCIP", true, margin)
    drawOsbLabelVert(float2(-0.5 + offsetFrame, -0.15), "MAN", false)
    drawOsbLabelVert(float2(-0.5 + offsetFrame, 0.0), "SGL", false)
    drawOsbLabelVert(float2(-0.5 + offsetFrame, 0.15), "SAL", false)

    drawOsbLabel(float2(-0.3, 0.5 - offsetFrame), "MTR", false)
    drawOsbLabel(float2(-0.15, 0.5 - offsetFrame), "TONE", false)
    drawOsbLabel(float2(0.15, 0.5 - offsetFrame), "DATA", false)


  def drawOsbLabels()
    setFontSize(16)
    let offsetFrame = 0.04
    let margin = float2(0.01)
    let totalTime = roundi(get_total_time())
    let min = fmt(":02d", totalTime / 60)
    let sec = fmt(":02d", totalTime % 60)

    drawOsbLabelVert(float2(0.5 - offsetFrame, -0.3), "GUN", true, margin)
    drawStrAnchored(float2(0.42, -0.3), (gunAmmo > 0) ? "RDY" : "STDBY", AnchorHorz.Right, AnchorVert.Center)
    drawOsbLabelVert(float2(0.5 - offsetFrame, 0.0), "STEP", false)

    drawOsbLabel(float2(0.0, 0.5 - offsetFrame), fmw.isOnGround ? "MENU" : "{min}{sec}", false)


    var i = 0
    var pos = float2(-0.3, -0.5 + offsetFrame)
    for k, v in keys(weapons), values(weapons)
      if i > 4
        break
      drawOsbLabel(pos, loc_wpn(k), false)
      if v
        let box = calc_box_points(pos, float2(0.14, getStringSize(loc_wpn(k)).y + margin.y))
        drawBox(box.lt, box.rb)
        if isArmed
          drawStrAnchored(pos + float2(0.0, 0.05), "RDY", AnchorHorz.Center, AnchorVert.Center)
      pos += float2(0.15, 0.0)
      i++

    if weaponDeliveryMode == WeaponDeliveryMode.BOMBS_CCIP || weaponDeliveryMode == WeaponDeliveryMode.BOMBS_CCRP
      drawOsbLabelsBombs(offsetFrame)
    elif weaponDeliveryMode == WeaponDeliveryMode.ROCKETS_CCIP
      drawOsbLabelsRockets(offsetFrame, margin)


  def drawMasterArm()
    setFontSize(25)
    drawStrAnchored(float2(0.0), isArmed ? "ARM" : "SAFE", AnchorHorz.Center, AnchorVert.Bottom)


  def drawGunAmmo()
    setFontSize(16)
    drawStrAnchored(float2(0.0, -0.33), (gunAmmo > 0) ? "{gunAmmo}" : "XXXX", AnchorHorz.Center, AnchorVert.Center)


  def selectModes()
    if (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_CANNONS) ||
      fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_CANNONS))
      weaponDeliveryMode = WeaponDeliveryMode.GUN_CCIP
      masterMode = MasterMode.AA
    elif (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_AIR_TARGET))
      weaponDeliveryMode = WeaponDeliveryMode.AAM
      masterMode = MasterMode.AA
    elif (isSpiSet && fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS_AUTO))
      weaponDeliveryMode = WeaponDeliveryMode.BOMBS_CCRP
      masterMode = MasterMode.AG
    elif (!isSpiSet && fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_BOMBS))
      weaponDeliveryMode = WeaponDeliveryMode.BOMBS_CCIP
      masterMode = MasterMode.AG
    elif (fmw.sightMode == int(CockpitSightMode.HUD_SIGHT_MODE_GROUND_ROCKET))
      weaponDeliveryMode = WeaponDeliveryMode.ROCKETS_CCIP
      masterMode = MasterMode.AG


  def drawOutline()
    drawPolyLine(shapes.outline.to_array())
    drawPolyLine(shapes.outline.to_array().inv_x())
    let stationOb = lerp(shapes.outline[0], shapes.outline[1], 0.33)
    let stationIb = lerp(shapes.outline[0], shapes.outline[1], 0.66)
    drawLine(stationOb, stationOb + float2(0.0, 0.01))
    drawLine(stationIb, stationIb + float2(0.0, 0.01))
    drawLine(inv_x(stationOb), inv_x(stationOb + float2(0.0, 0.01)))
    drawLine(inv_x(stationIb), inv_x(stationIb + float2(0.0, 0.01)))


  def draw()
    return if !isValid

    setFullCanvasViewport()
    selectModes()
    drawOutline()
    drawGunAmmo()
    drawWeaponSlots()
    drawMasterArm()
    drawOsbLabels()
    drawSettings()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
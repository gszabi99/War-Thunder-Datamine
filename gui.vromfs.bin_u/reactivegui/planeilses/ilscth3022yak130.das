require %rGui.planeIlses.ilsCth3022

require DagorMath
require DagorStdGuiRender
require darg
require math
require Weapon

require %rGui.utils.canvas_common
require %rGui.utils.weaponslots_common

class ComponentYak130 : Component
  def ComponentYak130(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
    super(guiCtx, rdata, rstate, props)


  def override drawWeaponSlots()
    return if isAirGunMode || isGroundGunMode

    let pos = float2(0.0, 0.44)
    let size = float2(0.22, 0.0)
    let boxSize = 0.014

    let numbers <- fixed_array(7, 5, 3, 1, 9, 2, 4, 6, 8)
    let slotMap <- fixed_array(-1, -1, 2, 3, 5, 6, -1, -1, -1)
    let count = numbers.length()
    let centerSlot = 4

    let stations <- [
      for i in 0 .. count;
      float2(lerp(-size.x, size.x, float(i) / float(count - 1)), pos.y)
    ]
    let relLineWidth = toRelY(lineWidthHdpx)
    for i in stations
      drawDot(i + float2(0.0, relLineWidth))

    setFontSize(roundi(0.5 * float(defaultFontSize)))

    var cannonBullets = 0
    get_weapons_by_trigger_group(wc.Weapons, WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY) <| $(weapons : array<Weapon const? const> const#)
      for w in weapons
        if w != null && (w.trigger_no == int(WeaponTriggerType.CANNONS_TRIGGER) || w.trigger_no == int(WeaponTriggerType.MACHINE_GUNS_TRIGGER))
          cannonBullets += w.countBullets

    for i in 0 .. ws.length()
      continue if (hero.slotIdByWeaponId[i] <= 0)
      let slot = ws.getWeaponSlot(i)

      continue if slot.trigger == int(WeaponTriggerType.CANNONS_TRIGGER)
      let mapped = slot.slot < slotMap.length() ? slotMap[slot.slot] : -1
      continue if mapped < 0 || mapped > count - 1
      continue if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)
      continue if slot.maxAmmo < 1
      continue if slot.curAmmo < 1
      let slotPos = stations[mapped]
      drawStrAnchored(float2(slotPos.x, slotPos.y - boxSize), "{numbers[mapped]}", AnchorHorz.Center, AnchorVert.Center)

      if slot.selected
        drawBox(float2(slotPos.x - boxSize, slotPos.y - boxSize * 2.0), float2(slotPos.x + boxSize, slotPos.y))

    let centerPos = stations[centerSlot]
    drawStrAnchored(float2(centerPos.x, centerPos.y - boxSize), "{numbers[centerSlot]}", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(centerPos.x, centerPos.y + boxSize + 0.01), "{cannonBullets}", AnchorHorz.Center, AnchorVert.Top)

    setFontSize(defaultFontSize)


  def override draw()
    return if !isValid

    setFullCanvasViewport()
    drawFlightSymbology()
    drawLaserDesignatorStatus()
    drawHmd()
    drawGunMode()
    drawRocketMode()
    drawBombMode()
    drawWeaponCodeOrGunAmmo()
    drawWeaponSlots()
    drawPermanentLabels()
    drawReleasePerm()
    drawThrottle()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; props : PropStorage&)
  new ComponentYak130(guiCtx, rdata, rstate, props).draw()

[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  setup_component(props, propStorage)

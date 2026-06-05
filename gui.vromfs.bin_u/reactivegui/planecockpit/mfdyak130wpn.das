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
  return loc("mfd/yak130_wpn/" + str)


def rgb(r, g, b : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, 1.0)))

def rgb(r, g, b, a : int) : E3DCOLOR
  return E3DCOLOR(Color4(float4(float(r) / 255.0, float(g) / 255.0, float(b) / 255.0, float(a) / 255.0)))


struct Colors
  green   : E3DCOLOR = rgb(0, 255, 0)
  outline : E3DCOLOR = rgb(0, 255, 0)
  red     : E3DCOLOR = rgb(255,   0,   0)
  bg      : E3DCOLOR = rgb(0, 0, 0)


struct PropStorage
  fontId        : int
  stationFontId : int
  aamPic        : Picture? = null
  aamBgPic      : Picture? = null
  bombsPic      : Picture? = null
  bombsBgPic    : Picture? = null
  rocketsPic    : Picture? = null
  rocketsBgPic  : Picture? = null
  kabPic        : Picture? = null
  kabBgPic      : Picture? = null
  ptbPic        : Picture? = null
  yakPic        : Picture? = null


class Component : Canvas
  isValid  : bool = false
  hero     : Unit? = null
  fmw      : FlightModelWrap? = null
  fm       : FlightModel? = null
  wc       : WeaponController? = null
  app      : AcesApp? = null
  ws       : WeaponSlots? = null
  colors   : Colors = Colors()
  stations : float2[9]

  isArmed    : bool = false
  flareCount : int = 0
  chaffCount : int = 0
  cmCount    : int = 0

  cannonCur : int = 0
  cannonMax : int = 0

  outlTransl : float2 = float2(0.0, -0.1)
  slotCount  : int = 9

  dashSize  : float = 0.04
  dashGap   : float = 0.025
  dashWidth : float = 2.0

  selectedTrigger     : int = -1
  hasTgp              : bool = false
  stationNums         : int[9]
  selectedSlotIndices : array<int>

  wingBaseY          : float  = 0.05
  stationLabelOffsets : float2[9]
  aamOffset     : float2 = float2(0.0, -0.17)
  bombsOffset   : float2 = float2(0.0, -0.1)
  rocketsOffset : float2 = float2(0.0, -0.13)
  kabOffset     : float2 = float2(0.0, -0.1)
  ptbOffset     : float2 = float2(0.0, -0.162)

  labelW        : float = 0.0312
  labelH        : float = 0.008
  osbFontSize   : int = 14
  fontId        : int = 0
  stationFontId : int = 0
  aamPic        : Picture? = null
  aamBgPic      : Picture? = null
  bombsPic      : Picture? = null
  bombsBgPic    : Picture? = null
  rocketsPic    : Picture? = null
  rocketsBgPic  : Picture? = null
  kabPic        : Picture? = null
  kabBgPic      : Picture? = null
  ptbPic        : Picture? = null
  yakPic        : Picture? = null


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; var props : PropStorage&)
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
    setScale(float2(canvasSize.y * 1.2, canvasSize.y))
    fontId = props.fontId
    stationFontId = props.stationFontId
    aamPic = props.aamPic
    aamBgPic = props.aamBgPic
    bombsPic = props.bombsPic
    bombsBgPic = props.bombsBgPic
    rocketsPic = props.rocketsPic
    rocketsBgPic = props.rocketsBgPic
    kabPic = props.kabPic
    kabBgPic = props.kabBgPic
    ptbPic = props.ptbPic
    yakPic = props.yakPic
    setFont(fontId)
    setFontSize(18)

    isArmed = !(fmw.isOnGround || fm.input.currentAlt < fmw.minAltitudeForDropShells)

    get_weapons_by_trigger_group(wc.Weapons, WeaponTriggerGroups.TRIGGER_GROUP_PRIMARY) <| $(weapons : array<Weapon const? const> const#)
      for w in weapons
        if w != null && (w.trigger_no == int(WeaponTriggerType.CANNONS_TRIGGER) || w.trigger_no == int(WeaponTriggerType.MACHINE_GUNS_TRIGGER))
          cannonCur += w.countBullets
          cannonMax += w.fullBullets

    stations = fixed_array<float2>(
      float2(-0.252,  0.098), float2(-0.196,  0.035), float2(-0.133,  0.015),
      float2(-0.070, -0.014), float2(0.000,   0.063), float2(0.070,  -0.014),
      float2(0.133,   0.000), float2(0.196,   0.035), float2(0.252,   0.098)
    )
    stationNums = fixed_array<int>(7, 5, 3, 1, 9, 2, 4, 6, 8)
    stationLabelOffsets = fixed_array<float2>(
      float2(-0.03, -0.03), float2(-0.03, -0.07), float2(-0.03, -0.11),
      float2(-0.03, -0.15), float2(0.0, -0.12),   float2(0.03, -0.15),
      float2(0.03, -0.11),  float2(0.03, -0.07),  float2(0.03, -0.03)
    )

    cmCount = wc.Weapons.countBullets(int(WeaponTriggerType.COUNTERMEASURES_TRIGGER))
    get_weapons_by_trigger_group(wc.Weapons, WeaponTriggerGroups.TRIGGER_GROUP_FLARES) <| $(weapons : array<Weapon const? const> const#)
      for w in weapons
        if w != null
          flareCount += w.countBullets
    chaffCount = cmCount - flareCount


  def drawOutline()
    return if yakPic == null
    let picW = 0.50
    let picH = picW * 527.0 / 436.0
    setColor(WHITE)
    drawPicture(float2(-picW * 0.5, -picH * 0.5), float2(picW, picH), yakPic)


  def drawWeaponLabel(slot : WeaponSlot&)
    let pos = stations[slot.slot]
    if slot.selected
      setColor(colors.green)
      setFillColor(colors.green)
      drawBox(float2(pos.x - labelW, pos.y - labelH), float2(pos.x + labelW, pos.y + labelH))
      setFillColor(TRANSPARENT)
      setColor(BLACK)
    else
      setColor(colors.green)
      setFillColor(BLACK)
      drawBox(float2(pos.x - labelW, pos.y - labelH), float2(pos.x + labelW, pos.y + labelH))
      setFillColor(TRANSPARENT)
    drawStrAnchored(pos, loc_wpn(slot.locName), AnchorHorz.Center, AnchorVert.Center)
    setColor(colors.green)


  def drawMissile(c : float2; selected : bool)
    drawWpnSlotPic(c, selected, 0.04, 0.052 * 242.0 / 50.0, aamPic, aamBgPic)


  def drawWpnSlotPic(c : float2; selected : bool; picW, picH : float; normalPic, bgPic : Picture?)
    let pos = float2(c.x - picW * 0.5, c.y)
    let sz  = float2(picW, picH)
    if bgPic != null
      setColor(BLACK)
      drawPicture(pos, sz, bgPic)
    if normalPic != null
      setColor(selected ? colors.green : WHITE)
      drawPicture(pos, sz, normalPic)


  def drawPicLbl(c : float2; lbl : string; selected : bool; lblOffset : float2; lineEndY : float)
    let lx = c.x + lblOffset.x
    let ly = c.y - 0.030 - 0.0165 + lblOffset.y
    let lblHW   = 0.03
    let lblHH   = 0.0165
    var lineStartX = lx
    if lx < 0.0
      lineStartX = lx + lblHW
    elif lx > 0.0
      lineStartX = lx - lblHW
    setColor(BLACK)
    setFillColor(selected ? colors.green : WHITE)
    drawBox(float2(lx - lblHW, ly - lblHH), float2(lx + lblHW, ly + lblHH))
    setFillColor(TRANSPARENT)
    setFont(stationFontId)
    setFontSize(13)
    drawStrAnchored(float2(lx, ly), lbl, AnchorHorz.Center, AnchorVert.Center)
    setColor(WHITE)
    drawLine(float2(lineStartX, ly + lblHH), float2(c.x, lineEndY))
    setColor(colors.green)
    setFont(fontId)


  def drawStationNumbering()
    setFont(stationFontId)
    setFontSize(14)
    for i in 0 .. slotCount
      let pos = stations[i]
      var isSelected = false
      for idx in selectedSlotIndices
        if idx == i
          isSelected = true
          break
      if isSelected
        setColor(WHITE)
        setFillColor(TRANSPARENT)
        drawBox(float2(pos.x - 0.018, 0.21 - 0.013), float2(pos.x + 0.018, 0.21 + 0.013))
      setColor(WHITE)
      drawStrAnchored(float2(pos.x, 0.21), "{stationNums[i]}", AnchorHorz.Center, AnchorVert.Center)
    setFont(fontId)
    setColor(colors.green)
    setFontSize(18)


  def drawWeaponSlots()
    selectedTrigger = -1
    hasTgp = false
    selectedSlotIndices |> clear()
    setFontSize(16)
    for i in 0 .. ws.length()
      continue if (hero.slotIdByWeaponId[i] <= 0)
      var slot = ws.getWeaponSlot(i)
      // index → визуальная позиция в stations (пилоны: 2→3, 3→1, 4→2, 5→4)
      let slotMap = fixed_array(-1, -1, 2, 3, 5, 6, -1, -1, -1)
      slot.slot = slot.slot < slotMap.length() ? slotMap[slot.slot] : -1
      continue if slot.slot < 0
      continue if slot.curAmmo < 1
      continue if slot.slot > stations.length() - 1

      if slot.selected
        selectedTrigger = slot.trigger
        selectedSlotIndices |> push(slot.slot)

      let stationPos = stations[slot.slot]

      if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)
        hasTgp = true
      elif slot.trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER)
        let iconPos = float2(stationPos.x + ptbOffset.x, wingBaseY + ptbOffset.y)
        drawWpnSlotPic(iconPos, false, 0.03, 0.24, ptbPic, ptbPic)
        drawPicLbl(iconPos, "ПТБ", false, stationLabelOffsets[slot.slot], iconPos.y)
      elif slot.trigger == int(WeaponTriggerType.AAM_TRIGGER)
        let iconPos = float2(stationPos.x + aamOffset.x, wingBaseY + aamOffset.y)
        drawMissile(iconPos, slot.selected)
        drawPicLbl(float2(iconPos.x, wingBaseY + bombsOffset.y), "Р-73", slot.selected, stationLabelOffsets[slot.slot], iconPos.y)
      elif slot.trigger == int(WeaponTriggerType.AGM_TRIGGER)
        drawWeaponLabel(slot)
      elif slot.trigger == int(WeaponTriggerType.BOMBS_TRIGGER)
        let iconPos = float2(stationPos.x + bombsOffset.x, wingBaseY + bombsOffset.y)
        drawWpnSlotPic(iconPos, slot.selected, 0.038, 0.18, bombsPic, bombsBgPic)
        drawPicLbl(iconPos, "АБ", slot.selected, stationLabelOffsets[slot.slot], iconPos.y)
      elif slot.trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
        let iconPos = float2(stationPos.x + kabOffset.x, wingBaseY + kabOffset.y)
        drawWpnSlotPic(iconPos, slot.selected, 0.045, 0.18, kabPic, kabBgPic)
        drawPicLbl(iconPos, "КАБ", slot.selected, stationLabelOffsets[slot.slot], iconPos.y)
      elif slot.trigger == int(WeaponTriggerType.ROCKETS_TRIGGER)
        let iconPos = float2(stationPos.x + rocketsOffset.x, wingBaseY + rocketsOffset.y)
        drawWpnSlotPic(iconPos, slot.selected, 0.040, 0.21, rocketsPic, rocketsBgPic)
        var rktLbl = "НАР"
        if find(slot.name, "s8") >= 0
          rktLbl = "С8"
        elif find(slot.name, "s_25") >= 0
          rktLbl = "С25"
        drawPicLbl(iconPos, rktLbl, slot.selected, stationLabelOffsets[slot.slot], iconPos.y)
        let cntPos = float2(iconPos.x, iconPos.y + 0.21 * 0.3)
        let cntHW = 0.018
        let cntHH = 0.010
        setColor(BLACK)
        setFillColor(slot.selected ? colors.green : WHITE)
        drawBox(float2(cntPos.x - cntHW, cntPos.y - cntHH), float2(cntPos.x + cntHW, cntPos.y + cntHH))
        setFillColor(TRANSPARENT)
        setColor(BLACK)
        setFont(stationFontId)
        setFontSize(13)
        drawStrAnchored(cntPos, "{slot.curAmmo}", AnchorHorz.Center, AnchorVert.Center)
        setColor(colors.green)
        setFont(fontId)

    setColor(colors.green)
    setFillColor(TRANSPARENT)
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
    let rx = 0.32
    let ry = 0.44
    setColor(colors.green)
    setLineWidth(dashWidth)
    drawLine(float2(-rx, -ry), float2(rx, -ry))
    drawLine(float2(rx, -ry),  float2(rx,  ry))
    drawLine(float2(rx,  ry),  float2(-rx,  ry))
    drawLine(float2(-rx,  ry), float2(-rx, -ry))
    setLineWidth(1.0)


  def drawOsbLabels()
    setFontSize(osbFontSize)
    let off = 0.04
    setColor(colors.green)
    drawStrAnchored(float2(-0.3,  -0.5 + off), "ПИЛ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(-0.15, -0.5 + off), "НВГ", AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.0,   -0.5 + off), "ИТО", AnchorHorz.Center, AnchorVert.Center)
    setFillColor(colors.green)
    drawBox(float2(0.108, -0.5 + off - 0.013), float2(0.192, -0.5 + off + 0.013))
    setFillColor(TRANSPARENT)
    setColor(BLACK)
    drawStrAnchored(float2(0.15,  -0.5 + off), "КИСС", AnchorHorz.Center, AnchorVert.Center)
    setColor(colors.green)
    drawStrAnchored(float2(0.3,   -0.5 + off), "ТВ",  AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(-0.38 + off, -0.2),  "ОНСТ",  0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(-0.38 + off,  0.25), "ПОДВ", 0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(0.38 - off, -0.33), "ВЫЗВ", 0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(0.38 - off, -0.20), "ДВИГ", 0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(0.38 - off, -0.07), "ТОПЛ", 0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(0.38 - off, 0.06), "ГИДР", 0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(0.38 - off,  0.16), "СОС",   0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(0.38 - off,  0.26), "КСУ",   0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(0.38 - off,  0.36), "СЖО",   0.0, AnchorHorz.Center, AnchorVert.Center)
    drawStrVerticalAnchored(float2(0.38 - off,  0.47), "ФОН",   0.0, AnchorHorz.Center, AnchorVert.Center)
    setFontSize(18)


  def drawCannon()
    return if cannonMax <= 0
    let xOff = 0.0
    let bx   = 0.009
    let by1  = -0.11
    let by2  = 0.09
    let bh   = by2 - by1
    let pad  = 0.0035
    let lblHW  = 0.042
    let lblHH  = 0.013
    let lblGap = 0.03
    let lblCY  = by1 - lblGap - lblHH
    setColor(BLACK)
    setFillColor(WHITE)
    drawBox(float2(xOff - lblHW, lblCY - lblHH), float2(xOff + lblHW, lblCY + lblHH))
    setFillColor(TRANSPARENT)
    setFontSize(14)
    drawStrAnchored(float2(xOff, lblCY), "СНПУ", AnchorHorz.Center, AnchorVert.Center)
    drawLine(float2(xOff, lblCY + lblHH), float2(xOff, by1))
    setFontSize(18)

    let isEmpty = cannonCur <= 0
    setColor(BLACK)
    setFillColor(WHITE)
    drawBox(float2(xOff - bx, by1), float2(xOff + bx, by2))
    if cannonMax > 0 && cannonCur > 0
      let fillH = (bh - 2.0 * pad) * float(cannonCur) / float(cannonMax)
      setColor(BLACK)
      setFillColor(colors.green)
      drawBox(float2(xOff - bx + pad, by2 - pad - fillH), float2(xOff + bx - pad, by2 - pad))
    setFillColor(TRANSPARENT)
    let sqY = by2 + 0.03
    let sqW = 0.025
    let sqH = 0.014
    let sqColor = isEmpty ? colors.red : WHITE
    setColor(BLACK)
    setFillColor(sqColor)
    drawBox(float2(xOff - sqW, sqY - sqH), float2(xOff + sqW, sqY + sqH))
    setFillColor(TRANSPARENT)
    setColor(BLACK)
    setFontSize(14)
    drawStrAnchored(float2(xOff, sqY), "{cannonCur}", AnchorHorz.Center, AnchorVert.Center)
    setColor(colors.green)
    setFontSize(18)


  def draw()
    return if !isValid

    setFullCanvasViewport()
    setColor(colors.bg)
    setFillColor(colors.bg)
    drawBox(float2(-0.5, -0.5), float2(0.5, 0.5))
    setFillColor(TRANSPARENT)
    drawOutline()
    drawCannon()
    drawWeaponSlots()
    drawStationNumbering()
    drawOsbLabels()
    drawBorder()
    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const; rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId = getInt(props, "fontId", 0)
  propStorage.stationFontId = getInt(props, "stationFontId", 0)
  propStorage.aamPic = getPicture(props, "aamPic")
  propStorage.aamBgPic = getPicture(props, "aamBgPic")
  propStorage.bombsPic = getPicture(props, "bombsPic")
  propStorage.bombsBgPic = getPicture(props, "bombsBgPic")
  propStorage.rocketsPic = getPicture(props, "rocketsPic")
  propStorage.rocketsBgPic = getPicture(props, "rocketsBgPic")
  propStorage.kabPic = getPicture(props, "kabPic")
  propStorage.kabBgPic = getPicture(props, "kabBgPic")
  propStorage.ptbPic = getPicture(props, "ptbPic")
  propStorage.yakPic = getPicture(props, "yakPic")

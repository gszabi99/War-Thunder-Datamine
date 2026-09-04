require %rGui.utils.canvas_common
require %rGui.utils.weaponslots_common
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


struct PropStorage
  fontId   : int = 0
  fontSize : int = 18


let COL_BLACK  = E3DCOLOR(uint4(0, 0, 0, 255))
let COL_WHITE  = E3DCOLOR(uint4(255, 255, 255, 255))
let COL_GREEN  = E3DCOLOR(uint4(0, 255, 0, 255))
let COL_RED    = E3DCOLOR(uint4(255, 0, 0, 255))
let COL_YELLOW = E3DCOLOR(uint4(255, 255, 0, 255))
let COL_ORANGE = E3DCOLOR(uint4(255, 165, 0, 255))
let COL_NULL   = E3DCOLOR(0x0)

let LABEL_FONT_SIZE  = 15
let LABEL_FONT_SIZE_R = 14

let HELI_CTR     = float2(0.0, -0.06)
let FUSE_HW      = 0.060
let FUSE_HH      = 0.086
let WING_TOP_Y     = -0.030
let WING_BOT_Y     = -0.0014
let WING_TOP_SPAN  = 0.463
let WING_BOT_SPAN  = 0.463
let WING_TIP_TOP_Y = -0.017
let WING_TIP_BOT_Y = 0.00

let STATION_X <- fixed_array(-0.440, -0.280, -0.153, 0.153, 0.280, 0.440)
let MAX_STATIONS = 6


class Component : Canvas
  isValid    : bool              = false
  hero       : Unit?             = null
  fmw        : FlightModelWrap?  = null
  fm         : FlightModel?      = null
  wc         : WeaponController? = null
  appRef     : AcesApp?          = null
  ws         : WeaponSlots?      = null
  fontSize   : int               = 18
  isArmed    : bool              = false
  engStarted : bool              = false
  wingAttY   : float             = 0.0
  pylonBotY  : float             = 0.0
  stAmmoData     : array<int>
  stMaxAmmoData  : array<int>
  stTriggerData  : array<int>
  stSelectedData : array<bool>
  stHasAmmo      : array<bool>
  stWpnCountData : array<int>
  aspect     : float             = 1.0
  flareCount : int               = 0
  chaffCount : int               = 0
  cannonCur  : int               = 0
  cannonMax  : int               = 0


  def Component(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
                rstate : RenderState& const; var props : PropStorage&)
    Canvas`Canvas(self, guiCtx, rdata, rstate)

    hero = get_watched_not_delayed_hero()
    if hero == null
      return
    fmw = hero.as_fmw()
    if fmw == null
      return
    wc = hero.weap
    if wc == null
      return
    fm = fmw.fm
    if fm == null
      return
    appRef = get_app()
    if appRef == null
      return

    ws = new WeaponSlots(hero, appRef, fmw, wc)
    isValid = true
    fontSize = props.fontSize
    engStarted = fm.EI.areEnginesStarted
    isArmed = !(fmw.isOnGround || fm.input.currentAlt < fmw.minAltitudeForDropShells)
    wingAttY = HELI_CTR.y + WING_BOT_Y
    pylonBotY = wingAttY + 0.045 + 0.048
    aspect = canvasSize.x / canvasSize.y
    if int(wc.numCountermeasureGuns) > 0
      *wc->calcNumCountermeasureBullet(flareCount, chaffCount)
    cannonCur = (wc.Weapons.countBullets(int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)) +
      wc.Weapons.countBullets(int(WeaponTriggerType.CANNONS_TRIGGER)))
    for weapon in wc.Weapons.getAllWeapons()
      if weapon == null
        continue
      let trg = weapon.trigger_no
      if trg == int(WeaponTriggerType.MACHINE_GUNS_TRIGGER) || trg == int(WeaponTriggerType.CANNONS_TRIGGER) || trg >= int(WeaponTriggerConsts.FIRST_GUNNER_TRIGGER)
        cannonMax += weapon.fullBullets
      if trg >= int(WeaponTriggerConsts.FIRST_GUNNER_TRIGGER)
        cannonCur += weapon.countBullets

    setColor(COL_WHITE)
    setLineWidth(1.5)
    setFont(props.fontId)
    setFontSize(fontSize)
    setOrigin(canvasPos + 0.5 * canvasSize)
    setScale(float2(canvasSize.y))


  def drawFrame()
    setColor(COL_WHITE)
    setLineWidth(1.0)
    setFillColor(COL_NULL)
    drawBox(float2(-0.47 * aspect, -0.445), float2(0.47 * aspect, 0.445))


  def drawTopBar()
    setColor(COL_WHITE)
    setFontSize(LABEL_FONT_SIZE)
    let tabY = -0.48
    drawStrAnchored(float2(-0.38 * aspect, tabY), "ПЛТ", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(-0.26 * aspect, tabY), "НВГ", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(-0.14 * aspect, tabY), "ОВО", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(-0.02 * aspect, tabY), "БКС", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(0.10 * aspect, tabY), "БКО", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(0.22 * aspect, tabY), "РЛС", AnchorHorz.Left, AnchorVert.Top)
    drawStrAnchored(float2(0.34 * aspect, tabY), "ОПС", AnchorHorz.Left, AnchorVert.Top)

    setColor(COL_GREEN)
    setFillColor(COL_GREEN)
    drawBox(float2(0.33 * aspect, -0.48), float2(0.39 * aspect, -0.45))
    setFillColor(COL_NULL)
    setColor(COL_WHITE)


  def drawLeftLabels()
    setColor(COL_WHITE)
    setFontSize(LABEL_FONT_SIZE)
    let leftX = -0.49 * aspect
    drawStrVert(float2(leftX, -0.45), "ТВ", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(leftX, -0.35), "ТРСФ", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(leftX, -0.18), "УЛ1", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(leftX, -0.04), "РМК", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(leftX, 0.10), "КОРР", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(leftX, 0.27), "ПРЦ", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(leftX, 0.38), "2Ц", AnchorHorz.Left, AnchorVert.Top)


  def drawRightLabels()
    setColor(COL_WHITE)
    setFontSize(LABEL_FONT_SIZE_R)
    let rightX = 0.475 * aspect
    drawStrVert(float2(rightX, -0.47), "СТОП", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(rightX, -0.33), "СВР", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(rightX, -0.20), "ШРС", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(rightX, -0.08), "СЛОИ", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(rightX, 0.06), "НАЗМ", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(rightX, 0.21), "НПДВ", AnchorHorz.Left, AnchorVert.Top)
    drawStrVert(float2(rightX, 0.36), "АСП", AnchorHorz.Left, AnchorVert.Top)


  def drawCountermeasures()
    setFontSize(fontSize - 2)
    let cmY = -0.38
    let flareStr = "{flareCount}"
    let chaffStr = "{chaffCount}"
    let boxPad = float2(0.015, 0.008)

    setColor(flareCount > 0 ? COL_GREEN : COL_RED)
    drawStrAnchored(float2(-0.18, cmY), "ЛТЦ", AnchorHorz.Center, AnchorVert.Center)
    let flareNumPos = float2(-0.10, cmY)
    let flareBox = getStrBbox(flareNumPos, flareStr, AnchorHorz.Center, AnchorVert.Center)
    setFillColor(COL_NULL)
    drawBBoxPadded(flareBox, boxPad)
    drawStrAnchored(flareNumPos, flareStr, AnchorHorz.Center, AnchorVert.Center)

    setColor(chaffCount > 0 ? COL_GREEN : COL_RED)
    let chaffNumPos = float2(0.10, cmY)
    let chaffBox = getStrBbox(chaffNumPos, chaffStr, AnchorHorz.Center, AnchorVert.Center)
    setFillColor(COL_NULL)
    drawBBoxPadded(chaffBox, boxPad)
    drawStrAnchored(chaffNumPos, chaffStr, AnchorHorz.Center, AnchorVert.Center)
    drawStrAnchored(float2(0.18, cmY), "ДО", AnchorHorz.Center, AnchorVert.Center)

    setFontSize(fontSize)
    setColor(COL_WHITE)


  def drawMessages()
    setFontSize(fontSize)

    if !engStarted && !isArmed
      setColor(COL_RED)
      drawStrAnchored(float2(0.0, -0.30), "БП", AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(0.0, -0.24), "БЛОКИРОВКА СУО", AnchorHorz.Center, AnchorVert.Center)
      setColor(COL_GREEN)
      drawStrAnchored(float2(0.0, -0.17), "ВКЛЮЧИ ГЛАВНЫЙ", AnchorHorz.Center, AnchorVert.Center)
    elif !isArmed
      setColor(COL_YELLOW)
      drawStrAnchored(float2(0.0, -0.26), "ЗЕМЛЯ", AnchorHorz.Center, AnchorVert.Center)

    setColor(COL_WHITE)


  def drawHelicopterOutline()
    setColor(COL_WHITE)
    setLineWidth(1.5)
    setFillColor(COL_NULL)

    let fuseTop = HELI_CTR.y - FUSE_HH
    let fuseBot = HELI_CTR.y + FUSE_HH
    let wingTopY = HELI_CTR.y + WING_TOP_Y
    let wingBotY = HELI_CTR.y + WING_BOT_Y

    drawRoundedBox(float2(-FUSE_HW, fuseTop), float2(FUSE_HW, fuseBot), float4(0.023))

    let winHW = 0.028
    let winHH = 0.035 * 1.5
    let winCY = HELI_CTR.y + 0.005
    drawBox(float2(-winHW, winCY - winHH), float2(winHW, winCY + winHH))

    setFillColor(COL_WHITE)
    drawCircle(float2(-winHW + 0.015, winCY - winHH + 0.015), 0.004)
    setFillColor(COL_NULL)

    let tipTopY = HELI_CTR.y + WING_TIP_TOP_Y
    let tipBotY = HELI_CTR.y + WING_TIP_BOT_Y
    let pylonHW = 0.011
    let pylonDepth = 0.045

    for side in range(2)
      let sv = side == 0 ? -1.0 : 1.0

      drawLine(float2(sv * FUSE_HW, wingTopY), float2(sv * WING_TOP_SPAN, tipTopY))
      drawLine(float2(sv * WING_TOP_SPAN, tipTopY), float2(sv * WING_BOT_SPAN, tipBotY))

      var curX = sv * FUSE_HW
      for pylIdx in range(3)
        let stIdx = side == 0 ? (2 - pylIdx) : (3 + pylIdx)
        let pylCenter = STATION_X[stIdx]
        let offset = abs(pylCenter)
        let pylRoot = pylCenter - sv * pylonHW
        let pylTip = pylCenter + sv * pylonHW
        let frac = (offset - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
        let localBotY = lerp(wingBotY, tipBotY, frac)

        let curFrac = (abs(curX) - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
        let curBotY = lerp(wingBotY, tipBotY, clamp(curFrac, 0.0, 1.0))
        let rootFrac = (abs(pylRoot) - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
        let rootBotY = lerp(wingBotY, tipBotY, clamp(rootFrac, 0.0, 1.0))
        drawLine(float2(curX, curBotY), float2(pylRoot, rootBotY))

        drawLine(float2(pylRoot, rootBotY), float2(pylRoot, localBotY + pylonDepth))
        drawLine(float2(pylRoot, localBotY + pylonDepth), float2(pylTip, localBotY + pylonDepth))
        let tipFrac = (abs(pylTip) - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
        let tipEdgeBotY = lerp(wingBotY, tipBotY, clamp(tipFrac, 0.0, 1.0))
        drawLine(float2(pylTip, localBotY + pylonDepth), float2(pylTip, tipEdgeBotY))

        curX = pylTip

      let lastFrac = (abs(curX) - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
      let lastBotY = lerp(wingBotY, tipBotY, clamp(lastFrac, 0.0, 1.0))
      drawLine(float2(curX, lastBotY), float2(sv * WING_BOT_SPAN, tipBotY))

    let neckH = 0.022
    drawLine(float2(0.0, fuseBot), float2(0.0, fuseBot + neckH))
    let gunBoxHW = winHW
    let gunBoxH = 0.040 * 2.0
    let gunBoxTop = fuseBot + neckH
    let gunBoxBot = gunBoxTop + gunBoxH
    let pad = 0.003
    setFillColor(COL_BLACK)
    drawBox(float2(-gunBoxHW, gunBoxTop), float2(gunBoxHW, gunBoxBot))
    if cannonMax > 0 && cannonCur > 0
      let fillH = (gunBoxH - 2.0 * pad) * float(cannonCur) / float(cannonMax)
      setFillColor(COL_GREEN)
      drawBox(float2(-gunBoxHW + pad, gunBoxBot - pad - fillH), float2(gunBoxHW - pad, gunBoxBot - pad))
    setFillColor(COL_NULL)
    drawBox(float2(-gunBoxHW, gunBoxTop), float2(gunBoxHW, gunBoxBot))
    setFontSize(fontSize - 4)
    drawStrAnchored(float2(gunBoxHW + 0.015, gunBoxTop + gunBoxH * 0.5), "{cannonCur}", AnchorHorz.Left, AnchorVert.Center)
    setFontSize(fontSize)

    setColor(COL_WHITE)


  def drawRocketPod(center : float2; radius : float; curAmmo : int; maxAmmo : int)
    if maxAmmo <= 5
      drawRocketPod5(center, radius, curAmmo, maxAmmo)
    else
      drawRocketPod20(center, radius, curAmmo, maxAmmo)


  def drawRocketPod20(center : float2; radius : float; curAmmo : int; maxAmmo : int)
    setFillColor(COL_BLACK)
    drawCircle(center, radius)

    let dotR = radius * 0.13
    let ring1R = radius * 0.42
    let ring2R = radius * 0.87

    var remaining = clamp(curAmmo, 0, maxAmmo > 0 ? maxAmmo : 20)

    for dotIdx in range(14)
      let ang = float(dotIdx) * PI * 2.0 / 14.0 - PI / 2.0
      let pos = center + float2(cos(ang), sin(ang)) * ring2R
      remaining -= 1
      setFillColor(remaining >= 0 ? COL_GREEN : COL_BLACK)
      drawCircle(pos, dotR * 0.9)

    for dotIdx in range(6)
      let ang = float(dotIdx) * PI / 3.0 - PI / 2.0
      let pos = center + float2(cos(ang), sin(ang)) * ring1R
      remaining -= 1
      setFillColor(remaining >= 0 ? COL_GREEN : COL_BLACK)
      drawCircle(pos, dotR)

    setFillColor(COL_NULL)


  def drawRocketPod5(center : float2; radius : float; curAmmo : int; maxAmmo : int)
    setFillColor(COL_BLACK)
    drawCircle(center, radius)

    let dotR = radius * 0.24
    let ringR = radius * 0.55

    var remaining = clamp(curAmmo, 0, maxAmmo > 0 ? maxAmmo : 5)

    for dotIdx in range(5)
      let ang = float(dotIdx) * PI * 2.0 / 5.0 - PI / 2.0
      let pos = center + float2(cos(ang), sin(ang)) * ringR
      remaining -= 1
      setFillColor(remaining >= 0 ? COL_GREEN : COL_BLACK)
      drawCircle(pos, dotR)

    setFillColor(COL_NULL)


  def drawAamLauncher(center : float2; halfWidth : float; curAmmo : int; maxAmmo : int)
    let pylHW = 0.011
    let horzBarHW = pylHW * 0.70
    let rktR = halfWidth * 0.34
    let rowH = rktR * 2.6 * 1.15
    let halfSpan = halfWidth * 1.15
    let colW = (pylHW + halfSpan) * 0.5
    let numRows = 2
    let top = center.y

    var remaining = clamp(curAmmo, 0, maxAmmo > 0 ? maxAmmo : 4)
    for rowIdx in range(numRows)
      for colIdx in range(2)
        let rktPos = float2(
          colIdx == 0 ? center.x - colW : center.x + colW,
          top + rowH * (float(rowIdx) + 0.5))
        remaining -= 1
        let alive = remaining >= 0
        setFillColor(alive ? COL_GREEN : COL_BLACK)
        drawCircle(rktPos, rktR)

        if alive
          setColor(COL_WHITE)
          let arcStep = rktR * 0.28
          for arcIdx in range(3)
            let arcX = rktPos.x - rktR * 0.15 + arcStep * float(arcIdx)
            let arcHH = rktR * (0.55 - 0.10 * float(arcIdx))
            drawLine(float2(arcX, rktPos.y - arcHH), float2(arcX + arcStep * 0.3, rktPos.y - arcHH * 0.5))
            drawLine(float2(arcX + arcStep * 0.3, rktPos.y - arcHH * 0.5), float2(arcX, rktPos.y))
            drawLine(float2(arcX, rktPos.y), float2(arcX + arcStep * 0.3, rktPos.y + arcHH * 0.5))
            drawLine(float2(arcX + arcStep * 0.3, rktPos.y + arcHH * 0.5), float2(arcX, rktPos.y + arcHH))

    let frameLeft = center.x - halfSpan
    let frameRight = center.x + halfSpan
    let vl = center.x - pylHW
    let vr = center.x + pylHW
    setColor(COL_WHITE)

    for segIdx in range(numRows)
      let segTop = top + rowH * float(segIdx) + (segIdx > 0 ? horzBarHW : 0.0)
      let segBot = top + rowH * float(segIdx + 1) - horzBarHW
      drawLine(float2(vl, segTop), float2(vl, segBot))
      drawLine(float2(vr, segTop), float2(vr, segBot))

    for barIdx in range(1, numRows + 1)
      let rowY = top + rowH * float(barIdx)
      let isBottom = barIdx == numRows
      drawLine(float2(frameLeft, rowY - horzBarHW), float2(vl, rowY - horzBarHW))
      drawLine(float2(vr, rowY - horzBarHW), float2(frameRight, rowY - horzBarHW))
      if isBottom
        drawLine(float2(frameLeft, rowY + horzBarHW), float2(frameRight, rowY + horzBarHW))
      else
        drawLine(float2(frameLeft, rowY + horzBarHW), float2(vl, rowY + horzBarHW))
        drawLine(float2(vr, rowY + horzBarHW), float2(frameRight, rowY + horzBarHW))
      drawLine(float2(frameLeft, rowY - horzBarHW), float2(frameLeft, rowY + horzBarHW))
      drawLine(float2(frameRight, rowY - horzBarHW), float2(frameRight, rowY + horzBarHW))


  def drawAtgmLauncher(center : float2; halfWidth : float; curAmmo : int; maxAmmo : int)
    let pylHW = 0.011
    let horzBarHW = pylHW * 0.70
    let rktR = halfWidth * 0.34
    let rowH = rktR * 3.22
    let halfSpan = halfWidth * 1.15
    let colW = (pylHW + halfSpan) * 0.5
    let top = center.y

    let numRows = (maxAmmo + 1) / 2
    let totalSlots = numRows * 2
    let spent = clamp(totalSlots - curAmmo, 0, totalSlots)

    var spentCount = 0
    for rowIdx in range(numRows)
      for colIdx in range(2)
        let rktPos = float2(
          colIdx == 0 ? center.x - colW : center.x + colW,
          top + rowH * (float(rowIdx) + 0.5))
        spentCount += 1
        let alive = spentCount > spent

        setFillColor(alive ? COL_GREEN : COL_BLACK)
        drawCircle(rktPos, rktR)

        if alive
          setColor(COL_WHITE)
          let arcStep = rktR * 0.28
          for arcIdx in range(3)
            let arcX = rktPos.x - rktR * 0.15 + arcStep * float(arcIdx)
            let arcHH = rktR * (0.55 - 0.10 * float(arcIdx))
            drawLine(float2(arcX, rktPos.y - arcHH), float2(arcX + arcStep * 0.3, rktPos.y - arcHH * 0.5))
            drawLine(float2(arcX + arcStep * 0.3, rktPos.y - arcHH * 0.5), float2(arcX, rktPos.y))
            drawLine(float2(arcX, rktPos.y), float2(arcX + arcStep * 0.3, rktPos.y + arcHH * 0.5))
            drawLine(float2(arcX + arcStep * 0.3, rktPos.y + arcHH * 0.5), float2(arcX, rktPos.y + arcHH))

    let frameLeft = center.x - halfSpan
    let frameRight = center.x + halfSpan
    let vl = center.x - pylHW
    let vr = center.x + pylHW
    setColor(COL_WHITE)

    for segIdx in range(numRows)
      let segTop = top + rowH * float(segIdx) + (segIdx > 0 ? horzBarHW : 0.0)
      let segBot = top + rowH * float(segIdx + 1) - horzBarHW
      drawLine(float2(vl, segTop), float2(vl, segBot))
      drawLine(float2(vr, segTop), float2(vr, segBot))

    for barIdx in range(1, numRows + 1)
      let rowY = top + rowH * float(barIdx)
      let isBottom = barIdx == numRows
      drawLine(float2(frameLeft, rowY - horzBarHW), float2(vl, rowY - horzBarHW))
      drawLine(float2(vr, rowY - horzBarHW), float2(frameRight, rowY - horzBarHW))
      if isBottom
        drawLine(float2(frameLeft, rowY + horzBarHW), float2(frameRight, rowY + horzBarHW))
      else
        drawLine(float2(frameLeft, rowY + horzBarHW), float2(vl, rowY + horzBarHW))
        drawLine(float2(vr, rowY + horzBarHW), float2(frameRight, rowY + horzBarHW))
      drawLine(float2(frameLeft, rowY - horzBarHW), float2(frameLeft, rowY + horzBarHW))
      drawLine(float2(frameRight, rowY - horzBarHW), float2(frameRight, rowY + horzBarHW))


  def drawVihrLauncher(center : float2; halfWidth : float; curAmmo : int; maxAmmo : int; isLeftWing : bool)
    let pylHW = 0.011
    let horzBarHW = pylHW * 0.70
    let rktR = halfWidth * 0.30
    let rowH = rktR * 3.22
    let narrowSpan = halfWidth * 1.15
    let wideSpan = halfWidth * 1.80
    let top = center.y
    let totalH = rowH * 2.0

    let narrowColW = (pylHW + narrowSpan) * 0.5
    let wideColW = wideSpan * 0.75

    let positions <- fixed_array(
      float2(center.x - narrowColW, top + rowH * 0.5),
      float2(center.x + narrowColW, top + rowH * 0.5),
      float2(lerp(center.x - wideColW, center.x + wideColW, 0.0 / 3.0), top + rowH * 1.5),
      float2(lerp(center.x - wideColW, center.x + wideColW, 1.0 / 3.0), top + rowH * 1.5),
      float2(lerp(center.x - wideColW, center.x + wideColW, 2.0 / 3.0), top + rowH * 1.5),
      float2(lerp(center.x - wideColW, center.x + wideColW, 3.0 / 3.0), top + rowH * 1.5))

    let totalSlots = 6
    let spent = clamp(totalSlots - curAmmo, 0, totalSlots)
    var spendOrder <- fixed_array(0, 1, 2, 3, 4, 5)
    if !isLeftWing
      spendOrder = fixed_array(1, 0, 5, 4, 3, 2)

    var isAlive <- fixed_array(true, true, true, true, true, true)
    for spIdx in range(spent)
      isAlive[spendOrder[spIdx]] = false

    for rktIdx in range(totalSlots)
      let rktPos = positions[rktIdx]
      let alive = isAlive[rktIdx]
      setFillColor(alive ? COL_GREEN : COL_BLACK)
      drawCircle(rktPos, rktR)
      if alive
        setColor(COL_WHITE)
        let arcStep = rktR * 0.28
        for arcIdx in range(3)
          let arcX = rktPos.x - rktR * 0.15 + arcStep * float(arcIdx)
          let arcHH = rktR * (0.55 - 0.10 * float(arcIdx))
          drawLine(float2(arcX, rktPos.y - arcHH), float2(arcX + arcStep * 0.3, rktPos.y - arcHH * 0.5))
          drawLine(float2(arcX + arcStep * 0.3, rktPos.y - arcHH * 0.5), float2(arcX, rktPos.y))
          drawLine(float2(arcX, rktPos.y), float2(arcX + arcStep * 0.3, rktPos.y + arcHH * 0.5))
          drawLine(float2(arcX + arcStep * 0.3, rktPos.y + arcHH * 0.5), float2(arcX, rktPos.y + arcHH))

    let vl = center.x - pylHW
    let vr = center.x + pylHW
    setFillColor(COL_NULL)
    setColor(COL_WHITE)

    drawLine(float2(vl, top), float2(vl, top + rowH - horzBarHW))
    drawLine(float2(vr, top), float2(vr, top + rowH - horzBarHW))
    drawLine(float2(vl, top + rowH + horzBarHW), float2(vl, top + totalH - horzBarHW))
    drawLine(float2(vr, top + rowH + horzBarHW), float2(vr, top + totalH - horzBarHW))

    let midY = top + rowH
    let midLeft = center.x - narrowSpan
    let midRight = center.x + narrowSpan
    drawLine(float2(midLeft, midY - horzBarHW), float2(vl, midY - horzBarHW))
    drawLine(float2(midLeft, midY + horzBarHW), float2(vl, midY + horzBarHW))
    drawLine(float2(midLeft, midY - horzBarHW), float2(midLeft, midY + horzBarHW))
    drawLine(float2(vr, midY - horzBarHW), float2(midRight, midY - horzBarHW))
    drawLine(float2(vr, midY + horzBarHW), float2(midRight, midY + horzBarHW))
    drawLine(float2(midRight, midY - horzBarHW), float2(midRight, midY + horzBarHW))

    let botY = top + totalH
    let botLeft = center.x - wideSpan
    let botRight = center.x + wideSpan
    drawLine(float2(botLeft, botY - horzBarHW), float2(vl, botY - horzBarHW))
    drawLine(float2(vr, botY - horzBarHW), float2(botRight, botY - horzBarHW))
    drawLine(float2(botLeft, botY + horzBarHW), float2(botRight, botY + horzBarHW))
    drawLine(float2(botLeft, botY - horzBarHW), float2(botLeft, botY + horzBarHW))
    drawLine(float2(botRight, botY - horzBarHW), float2(botRight, botY + horzBarHW))

    setColor(COL_WHITE)


  def drawGunPodIcon(center : float2; radius : float; curAmmo : int; maxAmmo : int)
    let hw = radius * 1.7 * 0.8 * 0.8
    let hh = radius * 0.7
    let cr = hh * 0.95 * 0.85
    let pylon_hw = radius * 0.25
    let pylon_h  = radius * 0.55
    setColor(COL_WHITE)
    setFillColor(COL_NULL)
    drawRoundedBox(float2(center.x - hw, center.y - hh), float2(center.x + hw, center.y + hh), float4(hh))
    drawBox(float2(center.x - pylon_hw, center.y - hh - pylon_h), float2(center.x + pylon_hw, center.y - hh))
    let barrelOfs = hw * 0.38 * 0.85
    for side in range(2)
      let sv = side == 0 ? -1.0 : 1.0
      let bc = float2(center.x + sv * barrelOfs, center.y)
      drawCircle(bc, cr * 0.55)
    setColor(COL_WHITE)


  def drawFuelTankIcon(center : float2; radius : float)
    setFillColor(COL_BLACK)
    drawCircle(center, radius)
    setFontSize(fontSize - 4)
    drawStrAnchored(center, "ТБ", AnchorHorz.Center, AnchorVert.Center)
    setFillColor(COL_NULL)


  def collectStationData()
    var stAmmo     <- [for _i in 0 .. MAX_STATIONS; 0]
    var stMaxAmmo  <- [for _i in 0 .. MAX_STATIONS; 0]
    var stWpnCount <- [for _i in 0 .. MAX_STATIONS; 0]
    var stTrigger  <- [for _i in 0 .. MAX_STATIONS; -1]
    var stSelected <- [for _i in 0 .. MAX_STATIONS; false]

    let addGunTrg = int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)

    for weapon in wc.Weapons.getAllWeapons()
      if weapon == null
        continue
      if weapon.trigger_no != addGunTrg
        continue
      let wpnIdx = weapon.weaponIdx
      if wpnIdx < 0 || wpnIdx >= length(hero.slotIdByWeaponId)
        continue
      let st = hero.slotIdByWeaponId[wpnIdx] - 1
      if st < 0 || st >= MAX_STATIONS
        continue
      stAmmo[st] += weapon.countBullets
      stMaxAmmo[st] += weapon.fullBullets
      stWpnCount[st] += 1
      stTrigger[st] = addGunTrg

    for wpnIdx in 0 .. ws.length()
      let slot = ws.getWeaponSlot(wpnIdx)
      if slot.trigger == int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)
        continue
      if hero.slotIdByWeaponId[wpnIdx] <= 0
        continue
      var slotMut = slot
      slotMut.slot -= 1
      if slotMut.slot < 0 || slotMut.slot >= MAX_STATIONS
        continue
      if slot.trigger == int(WeaponTriggerType.TARGETING_POD_TRIGGER)
        continue
      if slot.trigger == int(WeaponTriggerType.MACHINE_GUNS_TRIGGER)
        continue
      if slot.trigger == int(WeaponTriggerType.CANNONS_TRIGGER)
        continue
      stAmmo[slotMut.slot] += slot.curAmmo
      stMaxAmmo[slotMut.slot] += slot.maxAmmo
      stWpnCount[slotMut.slot] += 1
      if stTrigger[slotMut.slot] < 0
        stTrigger[slotMut.slot] = slot.trigger
      if slot.selected
        stSelected[slotMut.slot] = true

    stHasAmmo <- [for idx in 0 .. MAX_STATIONS; stMaxAmmo[idx] > 0]
    stAmmoData <- stAmmo
    stMaxAmmoData <- stMaxAmmo
    stTriggerData <- stTrigger
    stSelectedData <- stSelected
    stWpnCountData <- stWpnCount


  def drawWingHighlight()
    let wingTopY = HELI_CTR.y + WING_TOP_Y
    let wingBotY = HELI_CTR.y + WING_BOT_Y
    let tipTopY = HELI_CTR.y + WING_TIP_TOP_Y
    let tipBotY = HELI_CTR.y + WING_TIP_BOT_Y
    let pylonHW = 0.011
    let pylonDepth = 0.045

    for stIdx in range(MAX_STATIONS)
      if !stSelectedData[stIdx]
        continue
      let side = stIdx < 3 ? -1.0 : 1.0
      let pylCenter = STATION_X[stIdx]
      let pylEdge = pylCenter + side * pylonHW
      let pylRoot = pylCenter - side * pylonHW
      let edgeFracTop = (abs(pylEdge) - FUSE_HW) / (WING_TOP_SPAN - FUSE_HW)
      let edgeFracBot = (abs(pylEdge) - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
      let edgeTopY = lerp(wingTopY, tipTopY, clamp(edgeFracTop, 0.0, 1.0))
      let edgeBotY = lerp(wingBotY, tipBotY, clamp(edgeFracBot, 0.0, 1.0))

      setFillColor(COL_ORANGE)
      setColor(COL_ORANGE)
      drawFilledPoly(to_array_move(fixed_array(
        float2(side * FUSE_HW, wingTopY),
        float2(pylEdge, edgeTopY),
        float2(pylEdge, edgeBotY),
        float2(side * FUSE_HW, wingBotY))))

      let offset = abs(pylCenter)
      let frac = (offset - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
      let localBotY = lerp(wingBotY, tipBotY, frac)
      let rootFrac = (abs(pylRoot) - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
      let rootBotY = lerp(wingBotY, tipBotY, clamp(rootFrac, 0.0, 1.0))
      let tipFrac = (abs(pylEdge) - FUSE_HW) / (WING_BOT_SPAN - FUSE_HW)
      let tipEdgeBotY = lerp(wingBotY, tipBotY, clamp(tipFrac, 0.0, 1.0))
      drawFilledPoly(to_array_move(fixed_array(
        float2(pylRoot, rootBotY),
        float2(pylRoot, localBotY + pylonDepth),
        float2(pylEdge, localBotY + pylonDepth),
        float2(pylEdge, tipEdgeBotY))))

      setFillColor(COL_NULL)
      setColor(COL_WHITE)


  def drawWeaponStations()
    let iconR = 0.048

    for stIdx in range(MAX_STATIONS)
      let stX = STATION_X[stIdx]
      let stPos = float2(stX, pylonBotY)

      if stMaxAmmoData[stIdx] <= 0
        continue

      setColor(COL_WHITE)
      let pylonAttachY = wingAttY + 0.045
      let pylonAttachPos = float2(stX, pylonAttachY)
      let trigger = stTriggerData[stIdx]
      let aamHW = 0.039
      let aamRktR = aamHW * 0.34
      let aamRowH = aamRktR * 2.6 * 1.15
      let atgmRowH = aamRktR * 3.22
      let atgmNumRows = (stMaxAmmoData[stIdx] + 1) / 2
      var formBottomY = pylonBotY + iconR

      if trigger == int(WeaponTriggerType.ROCKETS_TRIGGER)
        drawRocketPod(stPos, iconR, stAmmoData[stIdx], stMaxAmmoData[stIdx])
        formBottomY = pylonBotY + iconR
      elif trigger == int(WeaponTriggerType.AAM_TRIGGER)
        drawAamLauncher(pylonAttachPos, aamHW, stAmmoData[stIdx], stMaxAmmoData[stIdx])
        let aamBarHW = 0.011 * 0.70
        formBottomY = pylonAttachY + aamRowH * 2.0 + aamBarHW
      elif trigger == int(WeaponTriggerType.AGM_TRIGGER)
        let atgmBarHW = 0.011 * 0.70
        if stWpnCountData[stIdx] > 1
          let vihrRktR = aamHW * 0.30
          let vihrRowH = vihrRktR * 3.22
          drawVihrLauncher(pylonAttachPos, aamHW, stAmmoData[stIdx], stMaxAmmoData[stIdx], stIdx < 3)
          formBottomY = pylonAttachY + vihrRowH * 2.0 + atgmBarHW
        else
          drawAtgmLauncher(pylonAttachPos, aamHW, stAmmoData[stIdx], stMaxAmmoData[stIdx])
          formBottomY = pylonAttachY + atgmRowH * float(atgmNumRows) + atgmBarHW
      elif trigger == int(WeaponTriggerType.BOMBS_TRIGGER) || trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
        let bombR = iconR * 0.80
        setFillColor(stAmmoData[stIdx] > 0 ? COL_GREEN : COL_BLACK)
        drawCircle(stPos, bombR)
        setFontSize(fontSize - 2)
        drawStrAnchored(stPos, "АБ", AnchorHorz.Center, AnchorVert.Center)
        setFillColor(COL_NULL)
        formBottomY = pylonBotY + bombR
      elif trigger == int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)
        drawGunPodIcon(stPos, 0.040, stAmmoData[stIdx], stMaxAmmoData[stIdx])
        formBottomY = pylonBotY + 0.040
      elif trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER)
        drawFuelTankIcon(stPos, 0.040)
        formBottomY = pylonBotY + 0.040
      else
        setFillColor(COL_BLACK)
        drawBox(float2(stPos.x - 0.029, stPos.y - 0.040),
                float2(stPos.x + 0.029, stPos.y + 0.040))
        setFillColor(COL_NULL)
        formBottomY = pylonBotY + 0.040

      drawDashedLine(float2(stX, formBottomY), float2(stX, 0.445), 0.008, 0.005)

      let ammoStr = "{stAmmoData[stIdx]}"
      let ammoIconY = pylonBotY - 0.06
      setColor(stAmmoData[stIdx] > 0 ? COL_GREEN : COL_RED)
      setFontSize(fontSize - 4)
      if stIdx < 3
        drawStrAnchored(float2(stX + iconR - 0.01, ammoIconY), ammoStr, AnchorHorz.Left, AnchorVert.Center)
      else
        drawStrAnchored(float2(stX - iconR + 0.01, ammoIconY), ammoStr, AnchorHorz.Right, AnchorVert.Center)
      setFontSize(fontSize)

    setColor(COL_WHITE)


  def drawWeaponLabels()
    let labelY = 0.47
    setFontSize(fontSize - 2)

    for stIdx in range(MAX_STATIONS)
      if !stHasAmmo[stIdx]
        continue

      let stX = STATION_X[stIdx]
      let trigger = stTriggerData[stIdx]

      setColor(COL_WHITE)
      var wpnLabel = ""
      if trigger == int(WeaponTriggerType.ROCKETS_TRIGGER)
        wpnLabel = "НАР"
      elif trigger == int(WeaponTriggerType.AAM_TRIGGER)
        wpnLabel = "УР-В"
      elif trigger == int(WeaponTriggerType.AGM_TRIGGER)
        wpnLabel = stWpnCountData[stIdx] > 1 ? "УР-В" : "УР-А"
      elif trigger == int(WeaponTriggerType.BOMBS_TRIGGER) || trigger == int(WeaponTriggerType.GUIDED_BOMBS_TRIGGER)
        wpnLabel = "АБ"
      elif trigger == int(WeaponTriggerType.EXTERNAL_FUEL_TANKS_TRIGGER)
        wpnLabel = "ТБ"
      elif trigger == int(WeaponTriggerType.ADDITIONAL_GUNS_TRIGGER)
        wpnLabel = "УПК"

      let labelBox = getStrBbox(float2(stX, labelY), wpnLabel, AnchorHorz.Center, AnchorVert.Center)
      drawStrAnchored(float2(stX, labelY), wpnLabel, AnchorHorz.Center, AnchorVert.Center)

      if stSelectedData[stIdx]
        let boxW = labelBox.rightBottom.x - labelBox.leftTop.x
        let boxH = labelBox.rightBottom.y - labelBox.leftTop.y
        setFillColor(COL_NULL)
        drawBBoxPadded(labelBox, float2(boxW * 0.20, boxH * 0.10))

    setFontSize(fontSize)
    setColor(COL_WHITE)


  def draw()
    return if !isValid

    setFullCanvasViewport()

    setColor(COL_BLACK)
    setFillColor(COL_BLACK)
    drawBox(float2(-0.5), float2(0.5))
    setFillColor(COL_NULL)
    setColor(COL_WHITE)

    drawFrame()
    drawTopBar()
    drawLeftLabels()
    drawRightLabels()

    setViewport(float2(-0.47 * aspect, -0.445), float2(0.47 * aspect, 0.445))
    drawCountermeasures()
    drawMessages()
    collectStationData()
    drawWingHighlight()
    drawHelicopterOutline()
    drawWeaponStations()
    restoreViewport()

    drawWeaponLabels()

    restoreViewport()


[export]
def render(var guiCtx : GuiContext&; rdata : ElemRenderData& const;
           rstate : RenderState& const; var props : PropStorage&)
  new Component(guiCtx, rdata, rstate, props).draw()


[export]
def setup(props : Properties&; var propStorage : PropStorage&)
  propStorage.fontId   = getInt(props, "fontId", 0)
  propStorage.fontSize = getInt(props, "fontSize", 18)

import "DataBlock" as DataBlock
import "colorCorrector" as cc
import "%rGui/style/teamColors.nut" as teamColors
from "blkLoad" import tryLoadBlk
from "dagor.math" import E3DCOLOR
from "math" import ceil, abs
from "%sqstd/string.nut" import split, replace
from "%rGui/hud/mpScore/mpScoreState.nut" import MpScoreMode, mpScoreMode, playerTeam, teamBarParts, teamBarDrops, ffaLine, bases, captureZones
from "%rGui/compassState.nut" import HasCompass
from "%appGlobals/hud/hudState.nut" import isAAComplexMenuActive, mpScoreBox
from "%rGui/hudState.nut" import isUnitAlive
from "%rGui/globals/ui_library.nut" import *


let skinScale = max(min(sw(100), sh(100)) / 1080.0, 1.0)
let px = @(value) ceil(value * skinScale).tointeger()

let hudBlk = DataBlock()
tryLoadBlk(hudBlk, "config/hud.blk")
let skinPath = hudBlk?.skins.defSkin ?? "ui/gameuiskin"
let cfg = hudBlk?.multiplayer_score ?? DataBlock()
let ffaCfg = hudBlk?.multiplayer_score_digits ?? DataBlock()

let noImage = freeze({ pic = "", size = [0, 0] })


function parseImage(desc) {
  let parts = split(desc, ":")
  if (parts.len() < 3)
    return noImage
  let size = [px(parts[1].tointeger()), px(parts[2].tointeger())]
  return freeze({ pic = $"{skinPath}#{parts[0]}:{size[0]}:{size[1]}:{parts?[3] ?? "K"}", size })
}

let readImage = @(name) parseImage(cfg?[name] ?? "")

let gaugeBg = readImage("progressBarArrow")
let gaugeBar = readImage("progressBar")
let airfieldBg = readImage("iconAirfieldBgd")
let baseIcons = freeze({ [1] = readImage("iconAllies"), [2] = readImage("iconAxis") })
let baseZoneBg = readImage("iconBasezoneBgd")
let zoneCurrent = readImage("iconAirfieldCur")
let zoneScaleCurrent = cfg?.captureZoneIconBlinkingScale ?? 1.5
let basesGap = px(cfg?.respawnBasesOffset ?? 2)
let basesBottom = -px(cfg?.respawnBasesOffsetY ?? 7)
let zonesGap = px(cfg?.airfieldsOffset ?? 5)
let zonesRowPos = freeze([0, px(cfg?.airfieldsOffsetY ?? 5)])
let minBarWidth = px(5)

const ZONE_LETTERS = "abcdefghijklmnop"
function readZoneIcons(fmtName) {
  let fmt = cfg?[fmtName] ?? ""
  return freeze(array(ZONE_LETTERS.len()).map(@(_, i) parseImage(replace(fmt, "%c", ZONE_LETTERS.slice(i, i + 1)))))
}
let zoneIcons = readZoneIcons("iconCapturezoneFmt")
let baseZoneIcons = readZoneIcons("iconBasezoneFmt")

const COLOR_WHITE = 0xFFFFFFFF
const COLOR_BAR_BLINK = 0xFFE1E1E1
let readColor = @(blk, name, def) blk.getE3dcolor(name, def).u

let colorFriend = readColor(cfg, "colorFriend", E3DCOLOR(0, 0, 0, 255))
let colorEnemy = readColor(cfg, "colorEnemy", E3DCOLOR(0, 0, 0, 255))
let colorNeutral = readColor(cfg, "colorNeutral", E3DCOLOR(0, 0, 0, 255))
let colorGaugeBg = readColor(cfg, "colorProgressBgd", E3DCOLOR(0, 0, 0, 255))

let correctHues = @(_teamColors) {
  friend = cc.correctHueTarget(colorFriend, cc.TARGET_HUE_ALLY)
  enemy = cc.correctHueTarget(colorEnemy, cc.TARGET_HUE_ENEMY)
}


let scoreColors = Computed(@() correctHues(teamColors.get()))

let anchorY = Computed(@() HasCompass.get() && !isAAComplexMenuActive.get() ? fsh(6.5) : fsh(1.5))

let zoneBlinkAnim = freeze([{ prop = AnimProp.opacity, from = 1.0, to = (cfg?.captureZoneIconBlinkingAlpha ?? 170) / 255.0,
  duration = 0.5, easing = CosineFull, loop = true, play = true }])

let mkGaugeBg = @(isLeft) @() {
  size = gaugeBg.size
  pos = [isLeft ? -gaugeBg.size[0] : 0, -gaugeBg.size[1] / 2]
  rendObj = ROBJ_IMAGE
  image = Picture(gaugeBg.pic)
  flipX = !isLeft
  color = colorGaugeBg
}

let blinkTriggers = freeze({ player = {}, enemy = {} })

keepref(Computed(@() teamBarDrops.get().player)).subscribe(@(_) anim_start(blinkTriggers.player))
keepref(Computed(@() teamBarDrops.get().enemy)).subscribe(@(_) anim_start(blinkTriggers.enemy))

function mkTeamBar(side) {
  let isLeft = side == "player"
  let colorKey = isLeft ? "friend" : "enemy"
  let part = Computed(@() teamBarParts.get()?[side] ?? 0.0)
  let blinkTrigger = blinkTriggers[side]
  let image = @() {
    watch = scoreColors
    size = gaugeBar.size
    rendObj = ROBJ_IMAGE
    image = Picture(gaugeBar.pic) 
    flipX = !isLeft
    color = scoreColors.get()[colorKey]
    animations = [{ prop = AnimProp.color, from = scoreColors.get()[colorKey], to = COLOR_BAR_BLINK, duration = 1.0,
      easing = CosineFull, trigger = blinkTrigger }]
  }
  return function() {
    let width = part.get() <= 0 ? 0 : max((part.get() * gaugeBar.size[0]).tointeger(), minBarWidth)
    return {
      watch = part
      size = [width, gaugeBar.size[1]]
      pos = [isLeft ? -width : 0, -gaugeBar.size[1] / 2]
      clipChildren = true
      halign = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
      children = width == 0 ? null : image
    }
  }
}

function mkIconGauge(image, size, fValue, fgColor, bgColor) {
  return {
    size
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    rendObj = ROBJ_PROGRESS_CIRCULAR
    image = Picture(image.pic)
    fValue
    fgColor
    bgColor
  }
}

function mkBase(row, isPlayerBase, colors) {
  let { army, integrity, isEnabled } = row
  let icon = baseIcons[army]
  let teamColor = !isEnabled ? colorNeutral : isPlayerBase ? colors.friend : colors.enemy
  return {
    size = airfieldBg.size
    children = [
      { size = FLEX, rendObj = ROBJ_IMAGE, image = Picture(airfieldBg.pic) }
      mkIconGauge(icon, icon.size, (isPlayerBase ? -integrity : integrity) / 100.0, teamColor, colorNeutral)
    ]
  }
}

function mkBasesRow(rows, isPlayerBase, colors) {
  if (rows.len() == 0)
    return null
  let width = rows.len() * (airfieldBg.size[0] + basesGap) - basesGap
  return {
    pos = [isPlayerBase ? -gaugeBg.size[0] : gaugeBg.size[0] - width, basesBottom - airfieldBg.size[1]]
    flow = FLOW_HORIZONTAL
    gap = basesGap
    children = rows.map(@(row) mkBase(row, isPlayerBase, colors))
  }
}

let basesRows = @() {
  watch = [bases, playerTeam, scoreColors]
  children = [
    mkBasesRow(bases.get().filter(@(b) b.army == playerTeam.get()), true, scoreColors.get())
    mkBasesRow(bases.get().filter(@(b) b.army != playerTeam.get()), false, scoreColors.get())
  ]
}


function mkZone(zone, team, colors) {
  let { icon, isBaseMark, progress, isCapturing, canCapture } = zone
  let iconIdx = clamp(icon, 0, ZONE_LETTERS.len() - 1)
  let letter = isBaseMark ? baseZoneIcons[iconIdx] : zoneIcons[iconIdx]
  let size = canCapture ? letter.size.map(@(v) (v * zoneScaleCurrent).tointeger()) : letter.size
  let isEnemy = (progress < 0) != (team == 1)
  let share = abs(progress)
  let captureColor = share == 0 ? colorNeutral : isEnemy ? colors.enemy : colors.friend
  let isFull = share >= 100
  let fValue = (isEnemy ? -share : share) / 100.0
  return {
    size
    children = [
      canCapture ? { size = FLEX, rendObj = ROBJ_IMAGE, image = Picture(zoneCurrent.pic) } : null
      {
        key = isCapturing
        size = FLEX
        animations = isCapturing ? zoneBlinkAnim : null
        children = [
          mkIconGauge(isBaseMark ? baseZoneBg : airfieldBg, size, fValue,
            share == 0 ? COLOR_WHITE : captureColor, isFull ? captureColor : COLOR_WHITE)
          mkIconGauge(letter, size, fValue, captureColor, isFull ? captureColor : colorNeutral)
        ]
      }
    ]
  }
}

let zonesRow = @() {
  watch = [captureZones, playerTeam, scoreColors]
  size = 0
  pos = zonesRowPos
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = {
    flow = FLOW_HORIZONTAL
    gap = zonesGap
    valign = ALIGN_CENTER
    children = captureZones.get().map(@(zone) mkZone(zone, playerTeam.get(), scoreColors.get()))
  }
}

let teamScoreParts = freeze([
  mkGaugeBg(true)
  mkGaugeBg(false)
  mkTeamBar("player")
  mkTeamBar("enemy")
  basesRows
  zonesRow
])

let teamScore = @() {
  watch = playerTeam
  size = 0
  hplace = ALIGN_CENTER
  children = playerTeam.get() != 0 ? teamScoreParts : null
}

let ffaTextStyle = freeze({
  rendObj = ROBJ_TEXT
  font = Fonts?[ffaCfg?.font ?? ""] ?? Fonts.medium_text_hud
  color = readColor(ffaCfg, "textColor", E3DCOLOR(200, 200, 200, 255))
  fontFx = FFT_GLOW
  fontFxColor = readColor(ffaCfg, "fontFxColor", E3DCOLOR(0, 0, 0, 255))
  fontFxFactor = ffaCfg?.fontFxScale ?? 42
  fontFxOffsX = ffaCfg?.fontFxOffset ?? 1
  fontFxOffsY = ffaCfg?.fontFxOffset ?? 1
})

let ffaScore = @() {
  watch = ffaLine
  size = 0
  hplace = ALIGN_CENTER
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = { ...ffaTextStyle, text = ffaLine.get() }
}


let scoreBox = freeze({
  size = [dp(396), dp(36)]
  hplace = ALIGN_CENTER
  behavior = Behaviors.RecalcHandler
  onRecalcLayout = @(_initial, elem) mpScoreBox.set({
    pos = [elem.getScreenPosX(), elem.getScreenPosY()]
    size = [elem.getWidth(), elem.getHeight()]
    visible = true
  })
  onDetach = @() mpScoreBox.set(null)
})


let mpScoreLine = @() {
  watch = mpScoreMode
  size = FLEX
  children = mpScoreMode.get() == MpScoreMode.TEAMS ? teamScore
    : mpScoreMode.get() == MpScoreMode.FFA ? ffaScore
    : null
}

let mpScoreHud = @() {
  watch = [anchorY, isUnitAlive]
  size = FLEX
  pos = [0, anchorY.get()]
  children = isUnitAlive.get() ? [scoreBox, mpScoreLine] : null
}

return freeze({
  mpScoreHud
  mpScoreLine
})

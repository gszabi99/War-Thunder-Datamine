import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors
import "%rGui/style/teamColors.nut" as teamColors
import "%rGui/hud/spectator/sideToggleButton.nut" as sideToggleButton
from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mkText, mulAlpha, pictureName
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
from "%rGui/components/commonBg.nut" import commonBg, toColor
import "%rGui/components/scrollBox.nut" as scrollBox
import "%rGui/control/gui_buttons.nut" as JB
from "%rGui/ctrlsState.nut" import showConsoleButtons
from "%rGui/components/gamepadImgByKey.nut" import mkImageCompByDargKey
from "%rGui/style/screenState.nut" import bh
from "%appGlobals/hud/spectatorState.nut" import spectatorTeams, spectatorAirHudOffsetX
from "eventbus" import eventbus_send

let nameFont = fontsState.get("normal")
let unitFont = fontsState.get("small")
let statFont = fontsState.get("tiny")
let headerFont = fontsState.get("medium")
let dpPx = cssConst("dp")
let tableW = cssConst("spectatorTableWidth")
let boxW = px("1@spectatorTableWidth + 1@spectatorBw")
let sideBw = cssConst("spectatorBw")
let framePad = cssConst("framePadding")
let rowW = cssConst("spectatorRowWidth")

let barPlaceW = cssConst("scrollBarSize")
let rowH = cssConst("spectatorRowHeight")
let cellPad = cssConst("tablePad")
let icoSize = cssConst("tableIcoSize")
let stateIcoSize = cssConst("cIco")
let iconBlockW = cssConst("spectatorIconBlockWidth")
let unitBlockW = cssConst("spectatorUnitBlockWidth")
let statW = cssConst("teammateStatWidth")
let statH = rowH / 3
let statGap = px("3@sf/@pf")
let nameOffsetY = px("3@sf/@pf")
let nameH = px("0.75@baseTrHeight")
let unitH = px("0.5@baseTrHeight")

let textIndent = cellPad + iconBlockW
let toggleSize = cssConst("mIco")
let topOffset = cssConst("spectatorTopOffset")
let boxMinH = px("2@sIco")
let fixedColumnH = topOffset + toggleSize + tableW + px("24@sf/@pf")
let headerOffs = px("1.5@mIco")
const deadAlpha = 150
const weaponIds = ["mine", "additionalGuns", "torpedo", "rocket", "bomb"]
let textFx = freeze({ fontFx = FFT_BLUR, fontFxColor = cssColors.textShadeColor, fontFxFactor = 24 })

let battleStateIcons = freeze({
  ExtinguisherActive = ["fire_indicator", 0xFF11BEDD]
  IsBurning = ["fire_indicator", 0xFFDDB711]
  BrokenEngine = ["engine_state_indicator", 0xFFDD1111]
  BrokenGun = ["gun_state_indicator", 0xFFDD1111]
  BrokenTrack = ["track_state_indicator", 0xFFDD1111]
  OutOfAmmo = ["btn_weapons", 0xFFDD1111]
})

let isTableOpen = [Watched(true), Watched(true)]
let tableScroll = [Watched(0), Watched(0)]

function svgImage(path, w, h) {
  let name = pictureName(path)
  return Picture(name.endswith(".svg") ? $"{name}:{w}:{h}:K" : name)
}

function mkUnitIcons(row, isLeft) {
  let { unitIcon, unitColor, weapons } = row
  let unit = {
    size = icoSize
    rendObj = ROBJ_IMAGE
    image = svgImage(unitIcon, icoSize, icoSize)
    keepAspect = KEEP_ASPECT_FIT
    color = toColor(cssColors?[unitColor] ?? 0xFFFFFFFF)
  }
  let icons = weaponIds.filter(@(id) id in weapons).map(function(id) {
    let { icon, ratio, isReloading } = weapons[id]
    let w = (ratio * icoSize + 0.5).tointeger()
    return {
      size = [w, icoSize]
      rendObj = ROBJ_IMAGE
      image = svgImage(icon, w, icoSize)
      color = isReloading ? cssColors.inactiveButtonBgColor : 0xFFFFFFFF
    }
  })
  return {
    size = [unitBlockW, icoSize]
    children = {
      hplace = isLeft ? ALIGN_RIGHT : ALIGN_LEFT
      flow = FLOW_HORIZONTAL
      children = isLeft ? icons.append(unit) : [unit].extend(icons.reverse())
    }
  }
}

function mkBattleStateIcon(battleState) {
  let [icon = null, color = 0] = battleStateIcons?[battleState]
  return {
    size = stateIcoSize
    vplace = ALIGN_CENTER
    rendObj = icon == null ? null : ROBJ_IMAGE
    image = icon == null ? null : svgImage($"#ui/gameuiskin#{icon}.svg", stateIcoSize, stateIcoSize)
    color
  }
}

function mkStatRow(statId, value, isLeft) {
  let icon = mkText(loc($"icon/mpstats/{statId}"), statFont, cssColors.commonTextColor,
    { size = [statH, SIZE_TO_CONTENT], halign = ALIGN_CENTER, margin = isLeft ? [0, statGap, 0, 0] : [0, 0, 0, statGap] })
  let text = mkText(value, statFont, cssColors.commonTextColor, { size = FLEX_H, halign = isLeft ? ALIGN_LEFT : ALIGN_RIGHT })
  return {
    size = [statW, statH]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    children = isLeft ? [icon, text] : [text, icon]
  }
}

function mkStats(row, statIds, isLeft) {
  return {
    size = [statW, rowH]
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    flow = FLOW_VERTICAL
    children = statIds.map(@(statId) mkStatRow(statId, row.stats[statId], isLeft))
  }
}

function onRowClick(id, evt) {
  let button = evt?.button ?? 0
  if (button == 1)
    eventbus_send("spectatorPlayerMenu", { id })
  else if (button == 0) {
    let { l, t, r } = evt.targetRect
    eventbus_send("spectatorActivatePlayer", { id, menuPos = [(l + r) / 2, t] })
  }
}

function getUnitColor(row, teamColor, colors) {
  if (teamColor == "red")
    return colors.teamRedLightColor
  if (row.isHero)
    return colors.userlogColoredText
  return row.isSquad ? colors.mySquadLightColor : colors.teamBlueLightColor
}

function mkRow(row, sf, rowWidth, teamView, colors, isLeft, bgs) {
  let { id, name, unitName, tooltip, battleState, isHero, isBot, isDead } = row
  let { statIds, color } = teamView
  let unitNameColor = getUnitColor(row, color, colors)
  let key = $"spectatorRow{id}"
  let textColor = isHero ? cssColors.userlogColoredText : cssColors.activeTextColor
  let alpha = isDead ? deadAlpha : 255
  let hasActivateHint = !(isBot && isHero)
  let hideTooltip = tooltipDetach(sf, key)
  let iconParts = [
    @() {
      watch = [sf, showConsoleButtons]
      size = stateIcoSize
      children = hasActivateHint && showConsoleButtons.get() && (sf.get() & S_HOVER) != 0 ? bgs.gamepadA : null
    }
    mkBattleStateIcon(battleState)
    mkUnitIcons(row, isLeft)
  ]
  return {
    key
    size = [rowWidth, rowH]
    behavior = Behaviors.Button
    onClick = @(evt) onRowClick(id, evt)
    onElemState = withHint(sf, key, @() tooltip)
    
    function onDetach() {
      hideTooltip()
      sf.set(0)
    }
    children = [
      isHero ? bgs.highlight : null
      bgs.line
      mkStats(row, statIds, isLeft)
      {
        pos = [isLeft ? iconBlockW - 2 * stateIcoSize - unitBlockW : -(iconBlockW - 2 * stateIcoSize - unitBlockW), 0]
        hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
        vplace = ALIGN_CENTER
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        children = isLeft ? iconParts : iconParts.reverse()
      }
      {
        size = FLEX_H
        padding = isLeft ? [nameOffsetY, 0, 0, textIndent] : [nameOffsetY, textIndent, 0, 0]
        flow = FLOW_VERTICAL
        halign = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
        clipChildren = true
        children = [
          mkText(name, nameFont, mulAlpha(textColor, alpha), { size = [SIZE_TO_CONTENT, nameH], valign = ALIGN_CENTER }
            .__update(textFx))
          mkText(unitName, unitFont, mulAlpha(unitNameColor, alpha), { size = [SIZE_TO_CONTENT, unitH], valign = ALIGN_CENTER }
            .__update(textFx))
        ]
      }
    ]
  }
}

function mkTable(idx) {
  let isLeft = idx == 0
  let maxContentH = sh(100) - 2 * bh.get() - fixedColumnH
  let teamView = Computed(@() spectatorTeams.get()?[idx])
  let contentH = Computed(@() (teamView.get()?.rows.len() ?? 0) * rowH)
  let lineAnchor = isLeft ? { hplace = ALIGN_LEFT, transform = { rotate = 180 } } : { hplace = ALIGN_RIGHT }
  let bgs = {
    highlight = {
      size = [tableW, rowH]
      hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
      children = commonBg({ image = "#ui/gameuiskin#expandable_item_sub_transp_sym", repeat = "expand",
        position = "0, 4", bgcolor = cssColors.switchButtonOnColor })
    }
    line = {
      size = [tableW, dpPx]
      vplace = ALIGN_BOTTOM
      children = commonBg({ image = "#ui/gameuiskin#expandable_item_sub_transp", repeat = "expand",
        position = "1", bgcolor = 0x30000000 })
    }.__update(lineAnchor)
    gamepadA = mkImageCompByDargKey(JB.A, null, { height = stateIcoSize })
  }
  
  let rowSf = {}
  function getRowSf(id) {
    if (id not in rowSf)
      rowSf[id] <- Watched(0)
    return rowSf[id]
  }
  let mkRows = @(rowWidth) @() {
    watch = [teamView, teamColors]
    size = SIZE_TO_CONTENT
    flow = FLOW_VERTICAL
    children = (teamView.get()?.rows ?? [])
      .map(@(row) mkRow(row, getRowSf(row.id), rowWidth, teamView.get(), teamColors.get(), isLeft, bgs))
  }
  let scrolledRows = scrollBox({ size = [rowW, maxContentH], contentHeight = contentH, isBarLeft = isLeft,
    scrollOffsY = tableScroll[idx] }, @(w, _o, _h) mkRows(w))
  let shortRows = isLeft ? { padding = [0, 0, 0, barPlaceW], children = mkRows(rowW - barPlaceW) } : mkRows(rowW)
  let header = @() {
    watch = teamView
    pos = [isLeft ? headerOffs : -headerOffs, 0]
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    children = mkText(teamView.get()?.clanTag ?? "", headerFont, cssColors.mainTitleTextColor, textFx)
  }
  return {
    size = [boxW, SIZE_TO_CONTENT]
    
    zOrder = Layers.Upper
    pos = [isLeft ? -sideBw - 4 * dpPx : sideBw + 4 * dpPx, topOffset]
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    behavior = isLeft ? Behaviors.RecalcHandler : null
    onRecalcLayout = !isLeft ? null : @(_initial, elem) spectatorAirHudOffsetX.set(elem.getScreenPosX() + elem.getWidth())
    onDetach = !isLeft ? null : @() spectatorAirHudOffsetX.set(0)
    children = [
      {
        size = flex()
        children = commonBg({
          image = isLeft ? "#ui/gameuiskin#expandable_item_ww_transp_reflect" : "#ui/gameuiskin#expandable_item_ww_transp"
          repeat = "expand"
          position = isLeft ? "2, 2, 0, 2" : "0, 2, 2, 2"
          bgcolor = 0x99999999
        })
      }
      @() {
        watch = contentH
        size = FLEX_H
        minHeight = boxMinH
        padding = isLeft ? [dpPx, framePad, dpPx, sideBw] : [dpPx, sideBw, dpPx, framePad]
        children = {
          hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
          children = contentH.get() > maxContentH ? scrolledRows : shortRows
        }
      }
      {
        size = [flex(), 0]
        pos = [0, -toggleSize / 2]
        children = { vplace = ALIGN_CENTER, size = FLEX_H, children = header }
      }
    ]
  }
}

function mkToggle(idx) {
  let isLeft = idx == 0
  return {
    pos = [isLeft ? -4 * dpPx : 4 * dpPx, topOffset - toggleSize]
    zOrder = Layers.Upper
    hplace = isLeft ? ALIGN_LEFT : ALIGN_RIGHT
    children = sideToggleButton({ id = $"spectatorTeamToggle{idx}", attachSide = isLeft ? "left" : "right",
      isOpen = isTableOpen[idx] })
  }
}

let mkSide = @(idx, isOpen) [isOpen ? mkTable(idx) : null, mkToggle(idx)]

function mkTeamSide(idx) {
  let isActive = Computed(@() spectatorTeams.get()?[idx].isActive ?? false)
  let isOpen = isTableOpen[idx]
  return @() {
    watch = [isActive, isOpen, bh]
    size = flex()
    
    children = isActive.get() ? mkSide(idx, isOpen.get()) : null 
  }
}


function openTables() {
  isTableOpen.each(@(isOpen) isOpen.set(true))
  tableScroll.each(@(offset) offset.set(0))
}

return freeze({
  size = flex()
  onDetach = openTables
  children = [mkTeamSide(0), mkTeamSide(1)]
})

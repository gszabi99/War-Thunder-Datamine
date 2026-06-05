from "%rGui/globals/ui_library.nut" import *

let { GuiBox, cutBoxesAroundTargets } = require("%globalScripts/guiGeom/guiBox.nut")
let { LinesPriorities, createLinkLines } = require("%globalScripts/guiGeom/linesGenerator.nut")
let { findPlaceForHintByRect } = require("%globalScripts/guiGeom/hintPlacement.nut")
let { screenHelpItems, screenHelpSafeArea, closeScreenHelp
} = require("%rGui/screenHelpOverlay/screenHelpOverlayState.nut")
let { actionBarRect } = require("%rGui/hud/actionBarState.nut")

const DARK_COLOR = 0xCC000000
const SIZE_INC_ADD = -2 

const DEFAULT_HINT_MAX_WIDTH = hdpx(500)
const HINT_BG_COLOR = 0xEE0F1419
const HINT_BORDER_COLOR = 0xFF37454D
const HINT_PADDING = [hdpx(8), hdpx(12)]
const HINT_TEXT_COLOR = 0xFFFFFFFF
const AUTO_HINT_GAP = hdpx(8) 

const HELP_LINE_WIDTH = hdpx(2)
const LINE_COLOR = 0xFFFFFFFF
const LINE_INTERVAL = hdpx(4) 
const DOT_SIZE = hdpx(8)
const DOT_COLOR = 0xFFFFFFFF

let mkSolidBox = @(box, color) {
  pos = [box.c1[0], box.c1[1]]
  size = [box.c2[0] - box.c1[0], box.c2[1] - box.c1[1]]
  rendObj = ROBJ_SOLID
  color
}

let mkDotRect = @(p) {
  pos = [p.x - DOT_SIZE / 2, p.y - DOT_SIZE / 2]
  size = DOT_SIZE
  rendObj = ROBJ_SOLID
  color = DOT_COLOR
}

function calcHintSize(item) {
  let { textMaxWidth = DEFAULT_HINT_MAX_WIDTH, text } = item
  let textComp = {
    maxWidth = textMaxWidth
    rendObj = ROBJ_TEXTAREA
    behavior = Behaviors.TextArea
    color = HINT_TEXT_COLOR
    font = Fonts.tiny_text_hud
    text
  }
  let [ textW, textH ] = calc_comp_size(textComp)
  let w = (textW + 2 * HINT_PADDING[1]).tointeger()
  let h = (textH + 2 * HINT_PADDING[0]).tointeger()
  return { w, h, textComp }
}

let mkHintRender = @(rect, textComp) {
  pos = [rect.x, rect.y]
  size = [rect.w, rect.h]
  rendObj = ROBJ_BOX
  fillColor = HINT_BG_COLOR
  borderColor = HINT_BORDER_COLOR
  borderWidth = dp(1)
  padding = HINT_PADDING
  children = textComp
}

function resolveHintLayouts(items, safeAreaRect, actionBarRectV) {
  let hintLayouts = []  
  let occupiedRects = []
  let pendingAuto = []

  if (actionBarRectV)
    occupiedRects.append(actionBarRectV)

  foreach (it in items) {
    let { targetRect } = it
    let hintSize = calcHintSize(it)
    if (it?.hintPos != null) {
      let { halign = ALIGN_LEFT, valign = ALIGN_TOP } = it
      let dx = halign == ALIGN_CENTER ? -hintSize.w / 2
        : halign == ALIGN_RIGHT ? -hintSize.w
        : 0
      let dy = valign == ALIGN_CENTER ? -hintSize.h / 2
        : valign == ALIGN_BOTTOM ? -hintSize.h
        : 0
      let hintRect = {
        x = (it.hintPos[0] + dx).tointeger()
        y = (it.hintPos[1] + dy).tointeger()
        w = hintSize.w
        h = hintSize.h
      }
      hintLayouts.append({ targetRect, hintRect, textComp = hintSize.textComp })
      occupiedRects.append(targetRect)
      occupiedRects.append(hintRect)
    } else {
      pendingAuto.append({ targetRect, hintSize })
    }
  }

  foreach (entry in pendingAuto) {
    let hintRect = findPlaceForHintByRect(entry.targetRect, occupiedRects,
      { w = entry.hintSize.w, h = entry.hintSize.h }, AUTO_HINT_GAP, safeAreaRect)
    if (hintRect == null)
      continue
    hintLayouts.append({ targetRect = entry.targetRect, hintRect, textComp = entry.hintSize.textComp })
  }

  return hintLayouts
}

function buildLineGeometry(hintLayouts) {
  let pairs = []
  let targetBoxes = []
  let hintBoxes = []
  let hintViews = []
  foreach (layout in hintLayouts) {
    let { targetRect, hintRect, textComp } = layout
    let targetBox = GuiBox(targetRect.x, targetRect.y, targetRect.x + targetRect.w,
      targetRect.y + targetRect.h, LinesPriorities.TARGET)
    let hintBox = GuiBox(hintRect.x, hintRect.y, hintRect.x + hintRect.w,
      hintRect.y + hintRect.h, LinesPriorities.TEXT)
    pairs.append([targetBox, hintBox])
    targetBoxes.append(targetBox)
    hintBoxes.append(hintBox)
    hintViews.append(mkHintRender(hintRect, textComp))
  }
  return { pairs, targetBoxes, hintBoxes, hintViews }
}

function mkHelpContent(helpItems, safeAreaRect, actionBarRectV) {
  if (helpItems == null)
    return null

  let hintLayouts = resolveHintLayouts(helpItems, safeAreaRect, actionBarRectV)
  let { pairs, targetBoxes, hintBoxes, hintViews } = buildLineGeometry(hintLayouts)

  let extraObstacles = []
  foreach (item in helpItems) {
    if (!item?.extraObstacles)
      continue
    foreach (r in item.extraObstacles)
      extraObstacles.append(GuiBox(r.x, r.y, r.x + r.w, r.y + r.h, LinesPriorities.OBSTACLE))
  }

  if (actionBarRectV != null)
    extraObstacles.append(GuiBox(actionBarRectV.x, actionBarRectV.y,
      actionBarRectV.x + actionBarRectV.w, actionBarRectV.y + actionBarRectV.h,
      LinesPriorities.OBSTACLE)
    )

  let root = GuiBox(0, 0, sw(100), sh(100))
  let darkInputs = targetBoxes.map(@(b) b.cloneBox())
  let dark = cutBoxesAroundTargets(root, darkInputs, SIZE_INC_ADD)

  let obstacles = [].extend(targetBoxes, hintBoxes, extraObstacles)
  let lines = createLinkLines(pairs, obstacles, LINE_INTERVAL, HELP_LINE_WIDTH)

  return dark.map(@(b) mkSolidBox(b, DARK_COLOR))
    .extend(
      lines.lines.map(@(b) mkSolidBox(b, LINE_COLOR)),
      lines.dots0.map(mkDotRect),
      hintViews
    )
}

let screenHelpOverlay = @() {
  watch = [screenHelpItems, screenHelpSafeArea, actionBarRect]
  size = flex()
  zOrder = Layers.Tooltip
  behavior = screenHelpItems.get() != null ? Behaviors.Button : null
  onClick = closeScreenHelp
  children = mkHelpContent(screenHelpItems.get(), screenHelpSafeArea.get(), actionBarRect.get())
}

return { screenHelpOverlay }
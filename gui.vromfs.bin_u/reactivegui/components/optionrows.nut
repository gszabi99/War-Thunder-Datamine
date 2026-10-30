














from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mkText, mulAlpha
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
import "%rGui/components/button.nut" as button
import "%rGui/components/switchBox.nut" as switchBox
import "%rGui/components/slider.nut" as slider
import "%rGui/components/comboBox.nut" as comboBox
import "%rGui/components/optionsBar.nut" as optionsBar
import "%rGui/components/editBox.nut" as editBox
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors

let fontNormal = fontsState.get("normal")
let fontMedium = fontsState.get("medium")

const ROW_ALPHA = 170
let dpPx = cssConst("dp")
let blockInterval = cssConst("blockInterval")
let rowH = cssConst("optContainerHeight")
let rowPitch = rowH + blockInterval
let edgePad = cssConst("optContainerCellEdgePadding")
let sepMargin = cssConst("optCellSeparatorMargin")
let tablePad = cssConst("tablePad")
let comboH = cssConst("comboOptContainerHeight")
let iconSize = cssConst("cIco")
let sliderH = px("@sliderHeight + 2@sliderIncHeight")
let defValueTextW = px("32@sf/@pf")
let warningIconGap = px("6@sf/@pf")
let rowButtonH = rowH - 4 * dpPx
let separatorH = (0.75 * rowH).tointeger()
let controlX = dpPx + sepMargin
let controlW = @(cellW) cellW - tablePad - edgePad - sepMargin
let navAnchorPad = blockInterval
let disabledLabelColor = mulAlpha(cssColors.commonTextColor, 85)

let headerCells = @(title) [
  { rendObj = ROBJ_TEXT, font = fontMedium, color = cssColors.activeTextColor, text = title, vplace = ALIGN_BOTTOM }
  { size = [flex(), 2 * dpPx], vplace = ALIGN_BOTTOM, rendObj = ROBJ_SOLID, color = cssColors.separatorBlockColor }
]

let rowLabel = @(text, color, ovr = {}) mkText(text, fontNormal, color, { vplace = ALIGN_CENTER }.__update(ovr))

let separator = @(alpha) @() {
  watch = alpha
  size = [dpPx, separatorH]
  vplace = ALIGN_CENTER
  rendObj = ROBJ_SOLID
  color = mulAlpha(cssColors.separatorBlockColor, alpha.get())
}

let atX = @(x, comp) { pos = [x, 0], vplace = ALIGN_CENTER, children = comp }

function mkValueStep(p) {
  let { id, kind, value, onChange } = p
  if (kind == "switchbox")
    return @(_dir) onChange(id, !value.get())
  if (kind == "slider" || kind == "options_bar") {
    let lo = p?.min ?? 0
    let hi = p?.max ?? ((p?.items?.len() ?? 1) - 1)
    let stepV = p?.step ?? 1
    return function(dir) {
      let next = clamp((value.get() ?? lo) + dir * stepV, lo, hi)
      if (next != value.get())
        onChange(id, next)
    }
  }
  if (kind == "combobox")
    return function(dir) {
      local idx = value.get() ?? 0
      do {
        idx += dir
      } while (p?.items?[idx]?.enabled == false)
      if (idx in (p?.items ?? []))
        onChange(id, idx)
    }
  return null
}

function valueNav(p) {
  let step = mkValueStep(p)
  if (step == null)
    return null
  let { navActive, isEnabled = null } = p
  let onStep = @(dir) (isEnabled?.get() ?? true) ? step(dir) : null
  let navHotkeys = [["Left | J:D.Left", @() onStep(-1)], ["Right | J:D.Right", @() onStep(1)]]
  return @() { watch = navActive, hotkeys = navActive.get() ? navHotkeys : null }
}


function controlComps(p) {
  let { id, kind, value, onChange, alpha, width, isEnabled = null, highlight = null, items = [] } = p
  let w = controlW(width)
  let skipDirPadNav = true
  if (kind == "combobox")
    return [atX(controlX, comboBox({ id, options = items, alpha, highlight, isEnabled, skipDirPadNav, onHover = p?.onHover },
      value, onChange, [w, comboH]))]
  if (kind == "switchbox")
    return [atX(controlX, switchBox({ id, textChecked = p?.textChecked, textUnchecked = p?.textUnchecked, alpha,
      isEnabled, skipDirPadNav }, value, onChange))]
  if (kind == "options_bar")
    return [{ pos = [controlX, 0], children = optionsBar({ id, items, isEnabled, highlight, skipDirPadNav },
      value, onChange, [w, rowH], p?.onHover) }]
  if (kind == "editbox")
    return [atX(controlX, editBox({ id, maxLen = p?.maxLength, skipDirPadNav }, value, onChange, [w, comboH]))]
  if (kind == "slider") {
    let { valueText = null, valueTextW = defValueTextW } = p
    let sliderW = valueText == null ? w : w - valueTextW
    let sliderComp = atX(controlX, slider({ id, minVal = p.min, maxVal = p.max, step = p.step, alpha, isEnabled,
      skipDirPadNav }, value, onChange, [sliderW, sliderH]))
    return valueText == null ? [sliderComp] : [
      sliderComp
      atX(controlX + sliderW + blockInterval, @() {
        watch = [valueText, alpha]
        rendObj = ROBJ_TEXT
        font = fontNormal
        color = mulAlpha(cssColors.commonTextColor, alpha.get())
        text = valueText.get() ?? ""
      })
    ]
  }
  if (kind == "button")
    return [atX(controlX, button({ id, alpha, text = p.text, size = [SIZE_TO_CONTENT, rowButtonH], minWidth = w,
      margin = 0, isEnabled, skipDirPadNav, hotkey = p?.hotkey }, p.onClick))]
  return []
}

let controlCell = @(p) controlComps(p).append(valueNav(p))


let isClickSafe = @[pure, nodiscard] (kind) kind != "slider" && kind != "options_bar"

function scrollToRow(offset, viewH, idx) {
  let top = idx * rowPitch
  let off = offset.get()
  let next = top < off ? top : top + rowPitch > off + viewH ? top + rowPitch - viewH : off
  if (next != off)
    offset.set(next)
}


let mkListXmb = @() XmbContainer({ wrap = false, isViewport = true })

let mkRowNav = @(anchorX, keepInView) {
  size = flex()
  behavior = Behaviors.ProcessPointingInput
  xmbNode = XmbNode({ onFocus = keepInView })
  cursorNavAnchor = [anchorX, rowH / 2]
}

let rowBox = @(tableW, isLit, isHeader, ovr) {
  size = [tableW, rowH]
  margin = [blockInterval, 0, 0, 0]
  rendObj = ROBJ_SOLID
  color = !isHeader && isLit ? cssColors.rowHoverBackgroundColor : 0
  behavior = isHeader ? null : Behaviors.Button
  eventPassThrough = true
}.__update(ovr)

let changedMarker = freeze({ size = [3 * dpPx, flex()], rendObj = ROBJ_SOLID, color = cssColors.headerOptionSelectedColor })

function rowLabelBox(row, labelColor, width, isLabelLeft) {
  let warningIcon = !(row?.hasWarningIcon ?? false) ? null : { size = iconSize, margin = [0, warningIconGap, 0, 0],
    rendObj = ROBJ_IMAGE, image = Picture($"ui/gameuiskin#urgent_warning.svg:{iconSize}:{iconSize}:K") }
  return @() {
    watch = labelColor
    pos = [edgePad, 0]
    size = [width - edgePad, rowH]
    halign = isLabelLeft ? ALIGN_LEFT : ALIGN_RIGHT
    valign = ALIGN_CENTER
    flow = FLOW_HORIZONTAL
    clipChildren = true
    children = [warningIcon, rowLabel(row.label, labelColor.get())]
  }
}


function optionRow(ctx, row, tableW) {
  let { id, isHeader = false, control = null } = row
  let itemId = row?.itemId ?? id
  let item = ctx.itemW(itemId)
  let shownW = Computed(@() item.get()?.shown ?? true)
  if (isHeader) {
    let header = rowBox(tableW, false, true, { children = headerCells(row.label) })
    return @() { watch = shownW, children = shownW.get() ? header : null }
  }
  let { activeRowIdW } = ctx
  let sf = Watched(0)
  let navActive = Computed(@() (sf.get() & S_HOVER) != 0)
  let isActive = Computed(@() activeRowIdW.get() == id)
  let isLit = Computed(@() isActive.get() || navActive.get())
  let alpha = Computed(@() isActive.get() ? 255 : ROW_ALPHA)
  let isEnabled = Computed(@() (item.get()?.enabled ?? true) && !(item.get()?.isLocked ?? false))
  let labelColor = Computed(@() !isEnabled.get() ? disabledLabelColor
    : isLit.get() ? cssColors.hoverTextColor
    : cssColors.commonTextColor)
  let hasStateMarks = ctx?.hasStateMarks ?? false
  let leftW = ctx.leftW(tableW)
  let cellW = tableW - leftW
  let cellControlW = controlW(cellW)
  let customCell = control == null ? null : ctx?.mkCell?(row, cellControlW, alpha)
  let controlP = (control == null || customCell != null) ? null : control.__merge({
    id = itemId
    value = Computed(@() item.get()?.value)
    valueText = (control?.hasValueText ?? false) ? Computed(@() item.get()?.valueText) : null
    valueTextW = ctx?.valueTextW ?? defValueTextW
    onChange = ctx.onChange
    alpha
    highlight = isActive
    isEnabled
    navActive
    width = min(cellW, ctx?.rightMaxW ?? cellW)
    text = Computed(@() control?.text ?? item.get()?.value)
    onClick = @() ctx.onButton(row)
    onHover = ctx?.onValueHover == null ? null : @(idx) ctx.onValueHover(row, idx)
  })
  
  let shape = Computed(@() { items = item.get()?.items ?? control?.items ?? const [], isLocked = item.get()?.isLocked ?? false })
  let sep = separator(alpha)
  let lockSign = !hasStateMarks ? null : { size = iconSize, hplace = ALIGN_RIGHT, vplace = ALIGN_CENTER,
    rendObj = ROBJ_IMAGE, image = Picture($"ui/gameuiskin#locked.svg:{iconSize}:{iconSize}:K") }
  let controls = @() {
    watch = shape
    pos = [leftW, 0]
    size = [cellW, flex()]
    children = [sep]
      .extend(customCell ?? (controlP == null ? [] : controlCell(controlP.__merge({ items = shape.get().items }))))
      .append(shape.get().isLocked ? lockSign : null)
  }
  let blockerSf = Watched(0)
  let blockerKey = $"{id}_disabled"
  let onBlockerState = withHint(blockerSf, blockerKey, @() item.get()?.disabledTooltip)
  let onBlockerDetach = tooltipDetach(blockerSf, blockerKey)
  let blocker = @() {
    watch = isEnabled
    key = blockerKey
    size = flex()
    behavior = isEnabled.get() ? null : Behaviors.Button
    onElemState = onBlockerState
    onDetach = onBlockerDetach
  }
  let nav = control == null ? null
    : mkRowNav(isClickSafe(control.kind) ? leftW + controlX + navAnchorPad : edgePad, @() ctx.keepInView(id))
  let hasChanged = !hasStateMarks ? null : Computed(@() item.get()?.hasChangedRow ?? false)
  let marker = hasChanged == null ? null
    : @() { watch = hasChanged, size = const [SIZE_TO_CONTENT, flex()], children = hasChanged.get() ? changedMarker : null }
  let children = [marker, rowLabelBox(row, labelColor, leftW, ctx.isLabelLeft), controls, blocker, nav]
  let hint = row?.hint ?? ""
  let hintSf = Watched(0)
  let showHint = hint == "" ? null : withHint(hintSf, id, @() hint)
  let hideHint = hint == "" ? null : tooltipDetach(hintSf, id)
  let rowElem = @() rowBox(tableW, isLit.get(), false, {
    watch = isLit
    key = id
    function onElemState(s) {
      let wasHover = navActive.get()
      sf.set(s)
      showHint?(s)
      if (!wasHover && (s & S_HOVER) != 0)
        ctx?.onHover?(row)
    }
    function onDetach() {
      hideHint?()
      hintSf.set(0)
      sf.set(0)
    }
    onClick = @() ctx?.onClick?(row)
    children
  })
  return @() { watch = shownW, children = shownW.get() ? rowElem : null }
}


const NAV_ROWS_AROUND_VIEW = 2

let mkRowsList = @(rowsW, ctx) function(innerW, offset, viewH) {
  let xmbNode = mkListXmb()
  let rowCtx = ctx.__merge({ keepInView = @(rowId)
    scrollToRow(offset, viewH, rowsW.get().findindex(@(r) r.id == rowId) ?? 0) })
  let firstIdxW = Computed(@() max(0,
    (min(offset.get(), rowsW.get().len() * rowPitch - viewH) / rowPitch).tointeger() - NAV_ROWS_AROUND_VIEW))
  let builtCount = viewH / rowPitch + 2 + 2 * NAV_ROWS_AROUND_VIEW
  
  local builtFor = null
  local built = {}
  function getRow(row) {
    if (row.id not in built)
      built[row.id] <- optionRow(rowCtx, row, innerW)
    return built[row.id]
  }
  return function() {
    if (builtFor != rowsW.get()) {
      builtFor = rowsW.get()
      built = {}
    }
    let first = firstIdxW.get()
    return {
      watch = [rowsW, firstIdxW]
      size = [innerW, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      xmbNode
      children = [{ size = [innerW, first * rowPitch] }]
        .extend(rowsW.get().slice(first, first + builtCount).map(getRow)) 
    }
  }
}

return freeze({
  ROW_ALPHA
  rowH
  rowButtonH
  rowPitch
  edgePad
  controlX
  controlW
  headerCells
  rowLabel
  separator
  scrollToRow
  mkListXmb
  rowBox
  changedMarker
  optionRow
  mkRowsList
})

from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mulAlpha
from "%rGui/components/optionRows.nut" import ROW_ALPHA, rowH, controlX, rowLabel
from "%rGui/hints/shortcuts.nut" import getShortcut
import "%appGlobals/style/cssColors.nut" as cssColors




let dpPx = cssConst("dp")
let leftColW = cssConst("controlsLeftRow")
let rightCellMaxW = cssConst("optContainerRightCellWidth")
let comboOptionPadding = cssConst("comboOptionPadding")
let selectionPad = px("3@dp")

let shortcutPlace = freeze({ place = "controlsCell" })
let cellPart = @(part) "input" in part ? getShortcut(part.input, shortcutPlace)
  : rowLabel(part.text, cssColors.axisSymbolColor)

let selectionFrame = freeze({
  size = flex()
  rendObj = ROBJ_FRAME
  borderWidth = 2 * dpPx
  color = mulAlpha(cssColors.commonTextColor, ROW_ALPHA)
})

function shortcutCell(p, row, w) {
  let { itemW, selectedRowIdW, sendAction } = p
  let item = itemW(row.itemId)
  let isSelected = Computed(@() selectedRowIdW.get() == row.id)
  let { rowIdx } = row
  return @() {
    watch = [item, isSelected]
    pos = [controlX, 0]
    size = [w, rowH]
    behavior = Behaviors.Button
    skipDirPadNav = true
    onClick = @(evt) sendAction("shortcutClick", { rowIdx, byGamepad = evt.devId == DEVID_JOYSTICK })
    onDoubleClick = @() sendAction("shortcutDblClick", { rowIdx })
    onElemState = @(s) sendAction((s & S_HOVER) != 0 ? "shortcutHover" : "shortcutUnhover", { rowIdx })
    children = [
      {
        size = const [SIZE_TO_CONTENT, flex()]
        padding = [0, isSelected.get() ? selectionPad : 0]
        flow = FLOW_HORIZONTAL
        valign = ALIGN_CENTER
        children = (item.get()?.cell ?? []).map(cellPart)
      }
      isSelected.get() ? selectionFrame : null
    ]
  }
}

function mkControlsRowCtx(p) {
  let { itemW, activeRowIdW, sendAction } = p
  return {
    itemW
    activeRowIdW
    leftW = @(_) leftColW
    isLabelLeft = true
    rightMaxW = rightCellMaxW
    onChange = @(id, value) sendAction("value", { id, value })
    onButton = @(row) sendAction("rowButton", { id = row.itemId })
    onClick = @(row) activeRowIdW.set(row.id)
    mkCell = @(row, w, _alpha) row.control.kind != "shortcut" ? null : [shortcutCell(p, row, w - comboOptionPadding)]
  }
}

return freeze({
  mkControlsRowCtx
})

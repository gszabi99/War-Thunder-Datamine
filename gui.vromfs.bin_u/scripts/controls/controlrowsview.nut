from "%scripts/dargScreenBridge.nut" import locText, mkComboItems
from "%scripts/dagui_library.nut" import *



function toPlainControl(control) {
  let { kind } = control
  if (kind == "combobox" || kind == "dropright")
    return { kind = "combobox", items = mkComboItems(control.items) }
  if (kind == "slider") {
    let { params } = control
    return { kind, min = params?.min ?? 0, max = params?.max ?? 100, step = params?.step ?? 5, hasValueText = true }
  }
  if (kind == "switchbox") {
    let { config } = control
    return { kind, textChecked = config?.textChecked ?? loc("options/yes"),
      textUnchecked = config?.textUnchecked ?? loc("options/no") }
  }
  if (kind == "button")
    return { kind, text = locText(control.text) }
  return { kind }
}

let getControlStartValue = @(control) control.kind == "switchbox" ? control.config.value : control?.value


function mkViewRows(rows) {
  let viewRows = []
  let items = {}
  let kinds = {}
  foreach (row in rows) {
    if (row.label == null)
      continue
    let { rowIdx, itemId, control } = row
    viewRows.append({
      id = row.id
      rowIdx
      itemId
      isHeader = row?.isHeader ?? false
      label = locText(row.label)
      control = control == null ? null : toPlainControl(control)
    })
    if (control == null || control.kind == "button")
      continue
    kinds[itemId] <- control.kind
    items[itemId] <- control.kind == "shortcut" ? { cell = control.parts }
      : { value = getControlStartValue(control) }
  }
  return { viewRows, items, kinds }
}

return freeze({
  mkViewRows
})

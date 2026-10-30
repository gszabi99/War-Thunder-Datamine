from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import pictureName
from "%rGui/components/optionRows.nut" import rowH, rowPitch, headerCells, rowLabel, scrollToRow, mkListXmb,
  optionRow, changedMarker
from "%appGlobals/options/optionsScreenState.nut" import optionsScreen
import "%rGui/components/scrollBox.nut" as scrollBox
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors



let fontNormal = fontsState.get("normal")
let dpPx = cssConst("dp")
let iconSize = cssConst("cIco")
let tabPad = cssConst("listboxHPadding")
let sliderTextW = px("80@sf/@pf")

let sectionsW = Computed(@() optionsScreen.get().sysopt?.sections ?? [])
let errorTextW = Computed(@() optionsScreen.get().sysopt?.errorText)
let curTabW = Computed(@() optionsScreen.get().sysopt?.curTab)
let changedTabIdsW = Computed(@() optionsScreen.get().sysopt?.changedTabIds ?? {})

function unitTab(tab, idx, tabId, sendAction) {
  let { image = null, text = null, disabled = false } = tab
  let icon = image == null ? null : { size = iconSize, rendObj = ROBJ_IMAGE,
    image = Picture($"{pictureName(image)}:{iconSize}:{iconSize}:K"), color = disabled ? cssColors.disabledTextColor : 0xFFFFFFFF }
  return watchElemState(@(sf) {
    watch = [curTabW, changedTabIdsW]
    size = [SIZE_TO_CONTENT, rowH]
    padding = [0, tabPad]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_CENTER
    gap = 4 * dpPx
    behavior = disabled ? null : Behaviors.Button
    onClick = @() sendAction("sysoptTab", { idx })
    rendObj = ROBJ_SOLID
    color = curTabW.get() == idx ? cssColors.buttonColor : 0
    children = [
      icon
      text == null ? null
        : rowLabel(text, disabled ? cssColors.disabledTextColor
            : (sf & S_HOVER) != 0 ? cssColors.activeTextColor : cssColors.commonTextColor)
      changedTabIdsW.get()?[tabId] ? changedMarker : null
    ]
  })
}

let sectionHeader = @(section, tableW, sendAction) {
  size = [tableW, rowH]
  margin = [cssConst("blockInterval"), 0, 0, 0]
  children = headerCells(section.title).append(section.tabs == null ? null : {
    hplace = ALIGN_RIGHT
    flow = FLOW_HORIZONTAL
    children = section.tabs.map(@(tab, idx) unitTab(tab, idx, $"{section.titleId}_{tab.unitTypeTag}", sendAction))
  })
}

let sectionRows = @(section, tableW, ctx, sendAction) [sectionHeader(section, tableW, sendAction)]
  .extend(section.rows.map(@(row) optionRow(ctx, row, tableW)))

let contentHeightW = Computed(@() sectionsW.get().reduce(@(res, s) res + 1 + s.rows.len(), 0) * rowPitch)


function stickyHeader(offset, tableW, sendAction) {
  let sectionIdxW = Computed(function() {
    local top = 0
    local res = null
    foreach (idx, s in sectionsW.get()) {
      if (top >= offset.get())
        break
      res = idx
      top += (1 + s.rows.len()) * rowPitch
    }
    return res
  })
  let header = @() {
    watch = [sectionIdxW, sectionsW]
    rendObj = ROBJ_SOLID
    color = cssColors.frameBackgroundColor
    children = sectionIdxW.get() == null ? null
      : sectionHeader(sectionsW.get()[sectionIdxW.get()], tableW, sendAction) 
  }
  return @() { watch = offset, pos = [0, offset.get()], children = header }
}


function sysoptRowIdx(rowId) {
  local idx = 0
  foreach (s in sectionsW.get()) {
    let i = s.rows.findindex(@(r) r.id == rowId)
    if (i != null)
      return idx + 1 + i
    idx += 1 + s.rows.len()
  }
  return 0
}


function sysoptPage(rowCtx, sendAction, listW, listH) {
  let list = scrollBox({ size = [listW, listH], contentHeight = contentHeightW }, function(tableW, offset, viewH) {
    let ctx = rowCtx.__merge({
      leftW = @(w) w / 2
      isLabelLeft = true
      rightMaxW = null
      valueTextW = sliderTextW
      hasStateMarks = true
      onClick = null
      keepInView = @(rowId) scrollToRow(offset, viewH, sysoptRowIdx(rowId))
      onValueHover = @(row, idx) sendAction("sysoptValueHover", { optId = row.optId, idx })
    })
    let xmbNode = mkListXmb()
    let rows = @() {
      watch = sectionsW
      size = [tableW, SIZE_TO_CONTENT]
      flow = FLOW_VERTICAL
      xmbNode
      children = sectionsW.get().reduce(@(res, s) res.extend(sectionRows(s, tableW, ctx, sendAction)), []) 
    }
    return { size = [tableW, SIZE_TO_CONTENT], children = [rows, stickyHeader(offset, tableW, sendAction)] }
  })
  return @() {
    watch = errorTextW
    children = errorTextW.get() == null ? list
      : { size = [listW, listH], rendObj = ROBJ_TEXTAREA, behavior = Behaviors.TextArea, halign = ALIGN_CENTER,
          valign = ALIGN_CENTER, font = fontNormal, color = cssColors.commonTextColor, text = errorTextW.get() }
  }
}

return sysoptPage

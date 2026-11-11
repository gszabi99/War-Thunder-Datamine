from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import pictureName
from "%rGui/components/optionRows.nut" import rowH, rowPitch, headerCells,
  rowLabel, scrollToRow, mkListXmb, optionRow, changedMarker
from "%appGlobals/options/optionsScreenState.nut" import optionsScreen
import "%rGui/components/scrollBox.nut" as scrollBox
import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors



let fontNormal = fontsState.get("normal")
let dpPx = cssConst("dp")
let iconSize = cssConst("cIco")
let tabPad = cssConst("listboxHPadding")
let sliderTextW = px("80@sf/@pf")
let scrollBarPlaceW = cssConst("scrollBarSize")
let headerInterval = cssConst("blockInterval")

let sectionsW = Computed(@() optionsScreen.get().sysopt?.sections ?? [])
let errorTextW = Computed(@() optionsScreen.get().sysopt?.errorText)
let curTabW = Computed(@() optionsScreen.get().sysopt?.curTab)
let changedTabIdsW = Computed(@() optionsScreen.get().sysopt?.changedTabIds ?? {})

function unitTab(tab, idx, tabId, sendAction) {
  let { image = null, text = null, disabled = false } = tab
  return watchElemState(function(sf) {
    let isSelected = curTabW.get() == idx
    let isHover = (sf & S_HOVER) != 0
    let color = disabled ? cssColors.disabledTextColor
      : isSelected ? cssColors.activeTextColor
      : isHover ? cssColors.highlightedTextColor
      : cssColors.commonTextColor
    return {
      watch = [curTabW, changedTabIdsW]
      size = [SIZE_TO_CONTENT, rowH]
      behavior = disabled ? null : Behaviors.Button
      onClick = @() sendAction("sysoptTab", { idx })
      children = [
        {
          flow = FLOW_HORIZONTAL
          vplace = ALIGN_CENTER
          padding = [0, tabPad]
          gap = 4 * dpPx
          children = [
            image == null ? null : {
              size = iconSize
              rendObj = ROBJ_IMAGE
              image = Picture($"{pictureName(image)}:{iconSize}:{iconSize}:K")
              color
            }
            text == null ? null : rowLabel(text, color)
          ]
        }
        changedTabIdsW.get()?[tabId] ? changedMarker : null
        !isSelected && !isHover ? null : {
          size = [flex(), 2 * dpPx]
          vplace = ALIGN_BOTTOM
          rendObj = ROBJ_SOLID
          color = isSelected ? cssColors.headerOptionSelectedColor : cssColors.headerOptionHoverColor
        }
      ]
    }
  })
}

let sectionHeader = @(section, tableW, sendAction) {
  size = [tableW, rowH]
  margin = [headerInterval, 0, 0, 0]
  children = headerCells(section.title)
    .append(section.tabs == null ? null : {
      hplace = ALIGN_RIGHT
      flow = FLOW_HORIZONTAL
      children = section.tabs.map(@(tab, idx)
        unitTab(tab, idx, $"{section.titleId}_{tab.unitTypeTag}", sendAction)
      )
    })
}

let headerSlot = @(s) s.sectionIdx == 0 ? 0 : 1
let sectionPitch = @(s) s.rows.len() + headerSlot(s)

let sectionRows = @(section, tableW, ctx, sendAction)
  (headerSlot(section) == 0 ? [] : [sectionHeader(section, tableW, sendAction)])
    .extend(section.rows.map(@(row) optionRow(ctx, row, tableW)))

let contentHeightW = Computed(@() sectionsW.get().reduce(@(res, s) res + sectionPitch(s), 0) * rowPitch)


function stickyHeader(offset, tableW, sendAction) {
  let sectionIdxW = Computed(function() {
    local top = headerInterval
    local res = 0
    foreach (idx, s in sectionsW.get()) {
      if (offset.get() < top + rowH)
        break
      res = idx
      top += sectionPitch(s) * rowPitch
    }
    return res
  })
  return @() {
    watch = [sectionIdxW, sectionsW]
    size = [tableW, rowH]
    children = sectionHeader(sectionsW.get()[sectionIdxW.get()], tableW, sendAction) 
      .__update({ margin = 0 })
  }
}


function sysoptRowIdx(rowId) {
  local idx = 0
  foreach (s in sectionsW.get()) {
    let i = s.rows.findindex(@(r) r.id == rowId)
    if (i != null)
      return idx + headerSlot(s) + i
    idx += sectionPitch(s)
  }
  return 0
}


function sysoptPage(rowCtx, sendAction, listW, listH) {
  let scrollOffsY = Watched(0)
  let tableWidth = listW - scrollBarPlaceW
  let listH_eff = listH - rowH
  let maxOffset = @() max(0, contentHeightW.get() - listH_eff)
  
  let onWheelScroll = @(delta) scrollOffsY.set(clamp(scrollOffsY.get() - delta, 0, maxOffset()))
  let header = stickyHeader(scrollOffsY, tableWidth, sendAction)
  let list = scrollBox({
      size = [listW, listH_eff]
      contentHeight = contentHeightW
      scrollOffsY
    },
    function(tableW, offset, viewH) {
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
      return @() {
        watch = sectionsW
        size = [tableW, SIZE_TO_CONTENT]
        flow = FLOW_VERTICAL
        xmbNode
        children = sectionsW.get().reduce(@(res, s) res.extend(sectionRows(s, tableW, ctx, sendAction)), []) 
      }
    }
  )
  return @() {
    watch = errorTextW
    children = errorTextW.get() == null
      ? {
          size = [listW, listH]
          flow = FLOW_VERTICAL
          behavior = Behaviors.WheelScroll
          onWheelScroll
          children = [
            header
            list
          ]
        }
      : {
          size = [listW, listH]
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          font = fontNormal
          color = cssColors.commonTextColor
          text = errorTextW.get()
        }
  }
}

return sysoptPage

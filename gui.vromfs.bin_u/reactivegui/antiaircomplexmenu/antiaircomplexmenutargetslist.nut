from "%rGui/hints/shortcuts.nut" import antiAirMenuShortcutHeight
from "%rGui/antiAirComplexMenu/antiAirMenuBaseComps.nut" import mkShortcutButton, mkShortcutText
from "%rGui/components/checkbox.nut" import mkCheckbox
from "%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut" import aaMenuCfg
from "%rGui/style/screenState.nut" import safeAreaSizeHud
from "%appGlobals/hud/hudState.nut" import isAAComplexMenuActive
from "%rGui/globals/ui_library.nut" import *

let modalPopupWnd = require("%rGui/components/modalPopupWnd.nut")
let { filterPresets } = require("%rGui/radarFilters.nut")

const WND_UID = "airComplexMenuTargetsFilter"
let close = @() modalPopupWnd.remove(WND_UID)

const blockInterval = hdpx(6)
const minLabelWidth = hdpx(80)
let labelFont = Fonts.tiny_text_hud
const imageSize = hdpx(20)

let getFilterPresets = @(config) filterPresets.filter(@(preset) config?[preset.filter.filterId] ?? true)

function mkFilterCheckbox(filterValueConfig, getFilterValue, setFilterValue, labelWidth) {
  let { locText, valueMask } = filterValueConfig
  let image = filterValueConfig.getImage(imageSize)
  let curValueMask = getFilterValue()
  let curValue = (curValueMask & valueMask) != 0
  let filterValueWatch = Watched(curValue)
  function setValue(isCheck) {
    let newValueMask = isCheck ? getFilterValue() | valueMask
      : getFilterValue() & ~valueMask
    setFilterValue(newValueMask, true)
    filterValueWatch.set(isCheck)
  }
  return mkCheckbox(filterValueWatch,
    { text = locText, font = labelFont , minWidth = labelWidth },
    { setValue, image })
}

function mkFilterList(filterConfig) {
  let { filter, valuesList } = filterConfig
  let { getFilterValue, setFilterValue } = filter
  let labelMaxWidth = valuesList.reduce(@(res, v) max(res, calc_comp_size({
      rendObj = ROBJ_TEXT, font = labelFont, text = v.locText })[0]),
    minLabelWidth)
  return {
    flow = FLOW_VERTICAL
    gap = blockInterval
    children = valuesList.map(
      @(filterValueConfig) mkFilterCheckbox(filterValueConfig,
        getFilterValue, setFilterValue, labelMaxWidth))
  }
}

let separatorLine = {
  size = [dp(1), FLEX]
  rendObj = ROBJ_SOLID
  color = 0x22222222
  margin = const [0, blockInterval]
}

let filtersList = @() {
  watch = aaMenuCfg
  flow = FLOW_HORIZONTAL
  gap = separatorLine
  children = getFilterPresets(aaMenuCfg.get().targetList).map(mkFilterList)
}

function openFilterPopupWnd(event) {
  let { targetRect } = event
  modalPopupWnd.add(targetRect, {
    uid = WND_UID
    popupHalign = ALIGN_RIGHT
    padding = blockInterval
    children = filtersList
  }, safeAreaSizeHud)
}

let mkFilterImage = @(height) {
  size = [height, height]
  valign = ALIGN_CENTER
  rendObj = ROBJ_IMAGE
  image = Picture($"ui/gameuiskin#filter_icon.svg:{height}:{height}:P")
  keepAspect = true
}

function mkFilterTargetsBtn(contentScaleV) {
  let btnHeight = antiAirMenuShortcutHeight * contentScaleV
  return @() {
    watch = aaMenuCfg
    children = getFilterPresets(aaMenuCfg.get().targetList).len() == 0 ? null
      : mkShortcutButton("",
          [
            mkShortcutText(loc("tournaments/filters"), contentScaleV),
            mkFilterImage((btnHeight*0.8).tointeger())
          ],
          {
            size = [SIZE_TO_CONTENT, btnHeight],
            padding = 0,
            scale = contentScaleV,
            borderWidth = 0,
            onClick = openFilterPopupWnd
          })
   }
}

isAAComplexMenuActive.subscribe(@(v) !v ? close() : null)

return {
  mkFilterTargetsBtn
}

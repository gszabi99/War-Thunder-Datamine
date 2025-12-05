from "%rGui/globals/ui_library.nut" import *
let { RadarTargetIconType } = require("guiRadar")
let { RADAR_TAGET_ICON_JET, RADAR_TAGET_ICON_HELICOPTER, RADAR_TAGET_ICON_ROCKET,
  RADAR_TAGET_ICON_SMALL, RADAR_TAGET_ICON_MEDIUM, RADAR_TAGET_ICON_LARGE
} = RadarTargetIconType
let { antiAirMenuShortcutHeight } = require("%rGui/hints/shortcuts.nut")
let { mkShortcutButton, mkShortcutText
} = require("%rGui/antiAirComplexMenu/antiAirMenuBaseComps.nut")
let modalPopupWnd = require("%rGui/components/modalPopupWnd.nut")
let { mkCheckbox } = require("%rGui/components/checkbox.nut")
let { aaMenuCfg } = require("%rGui/antiAirComplexMenu/antiAirComplexMenuState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")
let { RadarTargetsIffFilterMask } = require("radarGuiControls")
let { IFFFilter, typeFilter, rangeFilter
} = require("%rGui/radarFilters.nut")

const WND_UID = "airComplexMenuTargetsFilter"
let close = @() modalPopupWnd.remove(WND_UID)

let blockInterval = hdpx(6)
let minLabelWidth = hdpx(80)
let labelFont = Fonts.tiny_text_hud
let imageSize = hdpx(20)
let planeTargetPicture = Picture($"ui/gameuiskin#voice_message_jet.svg:{imageSize}:P")
let helicopterTargetPicture = Picture($"ui/gameuiskin#voice_message_helicopter.svg:{imageSize}:P")
let rocketTargetPicture = Picture($"ui/gameuiskin#voice_message_missile.svg:{imageSize}:P")

let filterPresets = [
  {
    filter = IFFFilter
    valuesList = [
      {
        locText = loc("hud/AAComplexMenu/IFF/ally")
        valueMask = RadarTargetsIffFilterMask.ALLY
      },
      {
        locText = loc("hud/AAComplexMenu/IFF/enemy")
        valueMask = RadarTargetsIffFilterMask.ENEMY
      }
    ]
  }
  {
    filter = typeFilter
    valuesList = [
      {
        locText = loc("mainmenu/type_aircraft")
        image = planeTargetPicture
        valueMask = 1 << RADAR_TAGET_ICON_JET
      },
      {
        locText = loc("mainmenu/type_helicopter")
        image = helicopterTargetPicture
        valueMask = 1 << RADAR_TAGET_ICON_HELICOPTER
      },
      {
        locText = loc("logs/ammunition")
        image = rocketTargetPicture
        valueMask = 1 << RADAR_TAGET_ICON_ROCKET
      },
      {
        locText = loc("hud/small")
        image = ""
        valueMask = 1 << RADAR_TAGET_ICON_SMALL
      },
      {
        locText = loc("hud/medium")
        image = ""
        valueMask = 1 << RADAR_TAGET_ICON_MEDIUM
      },
      {
        locText = loc("hud/large")
        image = ""
        valueMask = 1 << RADAR_TAGET_ICON_LARGE
      },
    ]
  }
  {
    filter = rangeFilter
    valuesList = [
      {
        locText = loc("hud/AAComplexMenu/AllowOutOfRangeTargers")
        image = planeTargetPicture
        valueMask = 1
      }
    ]
  }
]

let getFilterPresets = @(config) filterPresets.filter(@(preset) config?[preset.filter.filterId] ?? true)

function mkFilterCheckbox(filterValueConfig, getFilterValue, setFilterValue, labelWidth) {
  let { locText, valueMask, image = null } = filterValueConfig
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
  size = [dp(1), flex()]
  rendObj = ROBJ_SOLID
  color = 0x22222222
  margin = [0, blockInterval]
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
  planeTargetPicture
  helicopterTargetPicture
  rocketTargetPicture
}

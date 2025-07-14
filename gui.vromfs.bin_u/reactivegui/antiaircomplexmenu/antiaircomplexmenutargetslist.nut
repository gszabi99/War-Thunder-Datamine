from "%rGui/globals/ui_library.nut" import *
let { RadarTargetIconType } = require("guiRadar")
let { RADAR_TAGET_ICON_JET, RADAR_TAGET_ICON_HELICOPTER, RADAR_TAGET_ICON_ROCKET,
  RADAR_TAGET_ICON_SMALL = 4, RADAR_TAGET_ICON_MEDIUM = 5, RADAR_TAGET_ICON_LARGE = 6
} = RadarTargetIconType
let { isUnitAlive } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")
let { antiAirMenuShortcutHeight } = require("%rGui/hints/shortcuts.nut")
let { mkShortcutButton, mkShortcutText
} = require("%rGui/antiAirComplexMenu/antiAirMenuBaseComps.nut")
let modalPopupWnd = require("%rGui/components/modalPopupWnd.nut")
let { mkCheckbox } = require("%rGui/components/checkbox.nut")
let { aaMenuCfg } = require("antiAirComplexMenuState.nut")
let { safeAreaSizeHud } = require("%rGui/style/screenState.nut")
let { isAAComplexMenuActive } = require("%appGlobals/hud/hudState.nut")
let { getRadarTargetsIffFilterMask = null, setRadarTargetsIffFilterMask = @(_) null,
  RadarTargetsIffFilterMask = { ALLY = 1, ENEMY = 2 }
  getRadarTargetsTypeFilterMask = null, setRadarTargetsTypeFilterMask = @(_) null
} = require("antiAirComplexMenuControls")

const WND_UID = "airComplexMenuTargetsFilter"
let close = @() modalPopupWnd.remove(WND_UID)

let blockInterval = hdpx(6)
let minLabelWidth = hdpx(80)
let labelFont = Fonts.tiny_text_hud
let imageSize = hdpx(20)
let planeTargetPicture = Picture($"ui/gameuiskin#voice_message_jet.svg:{imageSize}:P")
let helicopterTargetPicture = Picture($"ui/gameuiskin#voice_message_helicopter.svg:{imageSize}:P")
let rocketTargetPicture = Picture($"ui/gameuiskin#voice_message_missile.svg:{imageSize}:P")

let targetsFilterConfig = [
  {
    key = "IFF"
    getFilterValue = getRadarTargetsIffFilterMask
    setFilterValue = setRadarTargetsIffFilterMask
    valuesList = [{
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
    key = "typeIcon"
    getFilterValue = getRadarTargetsTypeFilterMask
    setFilterValue = setRadarTargetsTypeFilterMask
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
]

let clearAllFilters = @() targetsFilterConfig.each(@(v) v.setFilterValue(0))

let getFiltersList = @(targetListColumnsConfig)
  targetsFilterConfig.filter(@(value) (targetListColumnsConfig?[value.key] ?? true)
    && value.getFilterValue != null)

function mkFilterCheckbox(filterValueConfig, getFilterValue, setFilterValue, labelWidth) {
  let { locText, valueMask, image = null } = filterValueConfig
  let curValueMask = getFilterValue()
  let curValue = (curValueMask & valueMask) != 0
  let filterValueWatch = Watched(curValue)
  function setValue(isCheck) {
    let newValueMask = isCheck ? getFilterValue() | valueMask
      : getFilterValue() & ~valueMask
    setFilterValue(newValueMask)
    filterValueWatch.set(isCheck)
  }
  return mkCheckbox(filterValueWatch,
    { text = locText, font = labelFont , minWidth = labelWidth },
    { setValue, image })
}

function mkFilterList(filterConfig) {
  let { getFilterValue, setFilterValue, valuesList } = filterConfig
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

function filtersList() {
  let filters = getFiltersList(aaMenuCfg.get().targetList)
  return {
    watch = aaMenuCfg
    flow = FLOW_HORIZONTAL
    gap = separatorLine
    children = filters.map(mkFilterList)
  }
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
    children = getFiltersList(aaMenuCfg.get().targetList).len() == 0 ? null
      : mkShortcutButton("",
          [
            mkShortcutText(loc("tournaments/filters"), contentScaleV),
            mkFilterImage((btnHeight*0.8).tointeger())
          ],
          {
            size = [SIZE_TO_CONTENT, btnHeight],
            padding = 0,
            scale = contentScaleV,
            onClick = openFilterPopupWnd
          })
   }
}

isAAComplexMenuActive.subscribe(@(v) !v ? close() : null)
isInFlight.subscribe(@(v) !v ? clearAllFilters() : null)
isUnitAlive.subscribe(@(v) !v ? clearAllFilters() : null)

return {
  mkFilterTargetsBtn
  planeTargetPicture
  helicopterTargetPicture
  rocketTargetPicture
}

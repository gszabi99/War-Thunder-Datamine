import "%rGui/style/fontsState.nut" as fontsState
import "%appGlobals/style/cssColors.nut" as cssColors
import "%rGui/components/switchBox.nut" as switchBox
import "%rGui/hud/spectator/sideToggleButton.nut" as sideToggleButton
from "%rGui/globals/ui_library.nut" import *
from "%rGui/dagui/units.nut" import cssConst, px
from "%rGui/components/text.nut" import mkText
from "%rGui/components/tooltip.nut" import withHint, tooltipDetach
from "%rGui/components/blurPanel.nut" import blurPanel
from "%rGui/hud/spectator/spectatorLiveState.nut" import isSensorView
from "camera_control" import setSensorViewFilter, getSensorViewFilter, SVF_HERO, SVF_SQUAD, SVF_ALLY, SVF_ENEMY,
  SVF_GROUND, SVF_AIR, SVF_WEAPON_OTHER, SVF_WEAPON_HERO, SVF_WEAPON_ATTACK_HERO, SVF_ONLY_SELECTED, SVF_RKT_SPEED,
  SVF_RKT_LIFETIME, SVF_RKT_TRAVELED, SVF_RKT_OVERLOAD, SVF_RKT_AOA, SVF_DEAD, SVF_RKT_STATE, SVF_SENSOR_HERO,
  SVF_SENSOR_SQUAD, SVF_SENSOR_ALLY, SVF_SENSOR_ENEMY, SVF_SENSOR_TRACK, SVF_SENSOR_INTEREST

let soundWt = require_optional("sound_wt")

let pages = freeze([
  {
    label = "sensorsFilters/unitMarkers"
    iconText = "icon/mpstats/raceLastCheckpoint"
    options = [
      { text = "options/player", id = SVF_HERO }
      { text = "sensorsFilters/squad", id = SVF_SQUAD }
      { text = "sensorsFilters/allyes", id = SVF_ALLY }
      { text = "sensorsFilters/enemyes", id = SVF_ENEMY }
      { text = "ground_targets/name/short", id = SVF_GROUND }
      { text = "air_targets/name/short", id = SVF_AIR }
      { text = "sensorsFilters/dead", id = SVF_DEAD }
      { text = "sensorsFilters/onlySelected", id = SVF_ONLY_SELECTED }
      { text = "sensorsFilters/allWeapons", id = SVF_WEAPON_OTHER }
      { text = "sensorsFilters/playerWeapons", id = SVF_WEAPON_HERO }
      { text = "sensorsFilters/enemyWeapons", id = SVF_WEAPON_ATTACK_HERO }
    ]
  }
  {
    label = "sensorsFilters/sensorMapping"
    icon = "btn_autodetect_on"
    options = [
      { text = "options/player", id = SVF_SENSOR_HERO }
      { text = "sensorsFilters/squad", id = SVF_SENSOR_SQUAD }
      { text = "sensorsFilters/allyes", id = SVF_SENSOR_ALLY }
      { text = "sensorsFilters/enemyes", id = SVF_SENSOR_ENEMY }
      { text = "sensorsFilters/track_sensor", id = SVF_SENSOR_TRACK }
      { text = "sensorsFilters/sensor_interest", id = SVF_SENSOR_INTEREST }
    ]
  }
  {
    label = "sensorsFilters/rktFlyMarkers"
    icon = "icon_rocket_in_progress"
    options = [
      { text = "options/measure_units_speed", id = SVF_RKT_SPEED }
      { text = "sensorsFilters/rktLifetime", id = SVF_RKT_LIFETIME }
      { text = "sensorsFilters/rktTraveled", id = SVF_RKT_TRAVELED }
      { text = "sensorsFilters/rktOverload", id = SVF_RKT_OVERLOAD }
      { text = "sensorsFilters/rktAttackAngle", id = SVF_RKT_AOA }
      { text = "sensorsFilters/rktStateOfSeeker", id = SVF_RKT_STATE }
    ]
  }
])

let fontNormal = fontsState.get("normal")
let fontSmall = fontsState.get("small")
let tabSize = cssConst("mIco")
let tabImgSize = cssConst("cIco")
let gap = cssConst("blockInterval")
let dpPx = cssConst("dp")
let tabMargin = [0, cssConst("listboxItemsInterval"), 0, 0]
let pageWidth = px("1.25@spectatorTableWidth")
let optionTextWidth = pageWidth - gap - cssConst("switchBoxWidth") - 3 * gap
let panelPos = [-px("4@titleLogoPlateHeight"), cssConst("spectatorTopOffset")]
let panelMinHeight = px("4@sIco")
let stripColor = cssColors.frameDarkTransparentBgColor
const centerPlace = { hplace = ALIGN_CENTER, vplace = ALIGN_CENTER }

let selectedPage = Watched(0)
let isPagesOpen = Watched(true)
let panelPlace = { pos = panelPos }

let mkOptionRow = @(option) {
  size = FLEX_H
  padding = [gap + dpPx, 0, gap + dpPx, gap]
  children = [
    {
      size = [optionTextWidth, SIZE_TO_CONTENT]
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = loc(option.text)
      font = fontSmall
      color = cssColors.commonTextColor
    }
    
    {
      size = [SIZE_TO_CONTENT, 0]
      hplace = ALIGN_RIGHT
      pos = [-2 * gap, -gap]
      children = switchBox({ id = option.id, font = fontSmall, value = getSensorViewFilter(option.id) }, null,
        setSensorViewFilter)
    }
  ]
}

function mkPage(page) {
  return {
    size = [pageWidth, SIZE_TO_CONTENT]
    padding = [gap, 0, 0, 0]
    flow = FLOW_VERTICAL
    children = page.options.map(mkOptionRow)
  }
}

function mkTab(page, idx) {
  let sf = Watched(0)
  let key = $"sensorFilterTab{idx}"
  let { iconText = null, icon = null, label } = page
  let image = icon == null ? null : Picture($"ui/gameuiskin#{icon}.svg:{tabImgSize}:{tabImgSize}:K")
  let onElemState = withHint(sf, key, @() loc(label))
  let onDetach = tooltipDetach(sf, key)
  function onClick() {
    soundWt?.playSound("click")
    selectedPage.set(idx)
  }
  return function() {
    let isSelected = selectedPage.get() == idx
    let isHover = (sf.get() & S_HOVER) != 0
    let textColor = isHover ? cssColors.textInWhiteBlockColor
      : isSelected ? cssColors.activeTextColor
      : cssColors.commonTextColor
    return {
      watch = [sf, selectedPage]
      key
      size = tabSize
      margin = tabMargin
      rendObj = ROBJ_SOLID
      color = isHover ? cssColors.listboxHoverOptionColor
        : isSelected ? cssColors.listboxSelOptionColor
        : 0
      behavior = Behaviors.Button
      onElemState
      onDetach
      onClick
      children = [
        image == null ? mkText(loc(iconText), fontNormal, textColor, centerPlace)
          : { size = tabImgSize, rendObj = ROBJ_IMAGE, image, color = textColor }.__update(centerPlace)
        !isHover && !isSelected ? null : {
          size = [flex(), 2 * dpPx]
          vplace = ALIGN_BOTTOM
          rendObj = ROBJ_SOLID
          color = isHover ? cssColors.listboxHoverOptionLineColor : cssColors.listboxSelOptionLineColor
        }
      ]
    }
  }
}

let pagesLabel = @() !isPagesOpen.get() ? { watch = isPagesOpen } : {
  watch = [isPagesOpen, selectedPage]
  size = [pageWidth, tabSize]
  rendObj = ROBJ_SOLID
  color = stripColor
  clipChildren = true
  children = mkText(loc(pages[selectedPage.get()].label), fontNormal, cssColors.commonTextColor, centerPlace)
}

function mkPanel() {
  return {
    hplace = ALIGN_RIGHT
    pos = panelPlace.pos
    
    zOrder = Layers.Upper
    minHeight = panelMinHeight
    behavior = Behaviors.MoveResize
    moveResizeModes = MR_AREA
    function onMoveResize(dx, dy, _dw, _dh) {
      panelPlace.pos = [panelPlace.pos[0] + dx, panelPlace.pos[1] + dy]
      return panelPlace
    }
    children = [
      blurPanel
      pagesLabel
      {
        margin = [tabSize, 0, 0, 0]
        flow = FLOW_HORIZONTAL
        children = [
          @() {
            watch = [isPagesOpen, selectedPage]
            children = isPagesOpen.get() ? mkPage(pages[selectedPage.get()]) : null 
          }
          {
            flow = FLOW_VERTICAL
            children = pages.map(mkTab)
          }
        ]
      }
      {
        hplace = ALIGN_RIGHT
        children = sideToggleButton({ id = "sensorFiltersToggle", attachSide = "right", isOpen = isPagesOpen,
          bgColor = stripColor })
      }
    ]
  }
}


function resetPanel() {
  isPagesOpen.set(true)
  selectedPage.set(0)
  panelPlace.pos = panelPos
}


return @() {
  watch = isSensorView
  size = flex()
  onDetach = resetPanel
  children = isSensorView.get() ? mkPanel() : null 
}

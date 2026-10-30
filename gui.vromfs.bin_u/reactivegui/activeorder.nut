import "%rGui/style/colors.nut" as colors
import "%rGui/style/fontsState.nut" as fontsState
import "%rGui/style/teamColors.nut" as teamColors
from "%rGui/ctrlsState.nut" import cursorVisible
from "%rGui/orderState.nut" import showOrder, scoresTable, statusText, statusTextBottom
from "%rGui/hud/hudPartVisibleState.nut" import isOrderStatusVisible
from "%rGui/components/scrollbarBase.nut" import makeVertScroll
from "eventbus" import eventbus_send
from "%rGui/globals/ui_library.nut" import *

let isOrderVisible = Computed(@() isOrderStatusVisible.get() && showOrder.get())
let isCollapsed = Watched(false)

let rowHeight = scrn_tgt(0.0224)
const collapseBtnSize = hdpx(45)
const collapseIconSize = hdpx(30)

let lineSpacing = {
  lineSpacing = hdpx(2)
  parSpacing = hdpx(2)
}

let shadow = {
  fontFx = FFT_SHADOW
  fontFxColor = 0xFF000000
  fontFxFactor = 20
  fontFxOffsX = hdpx(1)
  fontFxOffsY = hdpx(1)
}

let mkCollapseIconComp = @(collapseIcon) @() {
  watch = isCollapsed
  rendObj = ROBJ_IMAGE
  size = const [collapseIconSize, collapseIconSize]
  color = Color(192, 192, 192)
  image = collapseIcon
  transform = {
    rotate = isCollapsed.get() ? 90 : 270
  }
}

let mkCollapseButton = @(collapseIconComp) watchElemState(@(sf) {
  behavior = Behaviors.Button
  rendObj = ROBJ_SOLID
  size = const [collapseBtnSize, collapseBtnSize]
  color = (sf & S_ACTIVE) ? Color(2, 5, 9, 153)
    : (sf & S_HOVER) ? Color(58, 71, 79)
    : Color(3, 7, 12, 204)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  onClick = @() isCollapsed.set(!isCollapsed.get())
  children = collapseIconComp
})

let orderIcon = {
  rendObj = ROBJ_TEXT
  text = loc("icon/orderSymbol")
  size = const [collapseBtnSize, collapseBtnSize]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  font = fontsState.get("medium")
  color = Color(249, 219, 120)
  margin = const [hdpx(1), 0, 0, hdpx(1)]
}

let collapsedOrder = {
  rendObj = ROBJ_SOLID
  size = const [collapseBtnSize, collapseBtnSize]
  color = Color(3, 7, 12, 204)
  children = orderIcon
}

let mkPlayerComp = @(item, pilotIcon) {
  size = [SIZE_TO_CONTENT, rowHeight]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  gap = hdpx(2)
  children = [
    {
      rendObj = ROBJ_IMAGE
      size = rowHeight
      image = pilotIcon
    }
    @() {
      watch = teamColors
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = item.player
      size = SIZE_TO_CONTENT
      font = fontsState.get("small")
      color = colors.menu.commonTextColor
      colorTable = teamColors.get()
    }.__update(shadow)
  ]
}

let mkScoreComp = @(item) {
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = [SIZE_TO_CONTENT, rowHeight]
  valign = ALIGN_BOTTOM
  text = item.score
  font = fontsState.get("small")
  color = colors.menu.commonTextColor
}.__update(shadow)

let mkScoresTableComp = @(pilotIcon) function() {
  let res = {
    playerComps = []
    scoreComps = []
  }
  foreach (item in scoresTable.get()) {
    res.playerComps.append(mkPlayerComp(item, pilotIcon))
    res.scoreComps.append(mkScoreComp(item))
  }
  return {
    watch = scoresTable
    flow = FLOW_HORIZONTAL
    gap = hdpx(20)
    size = SIZE_TO_CONTENT
    children = [
      {
        size = SIZE_TO_CONTENT
        flow = FLOW_VERTICAL
        minWidth = hdpx(100)
        children = res.playerComps
      }
      {
        size = SIZE_TO_CONTENT
        flow = FLOW_VERTICAL
        children = res.scoreComps
      }
    ]
  }
}

let orderDesc = @() {
  watch = [statusText, teamColors]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = FLEX_H
  margin = const [0, 0, 0, hdpx(10)]
  text = statusText.get()
  font = fontsState.get("small")
  color = colors.menu.commonTextColor
  colorTable = teamColors.get()
}.__update(shadow, lineSpacing)

let orderStatus = @() {
  watch = [statusTextBottom, teamColors]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = FLEX_H
  text = statusTextBottom.get()
  font = fontsState.get("small")
  color = colors.menu.commonTextColor
  colorTable = teamColors.get()
}.__update(shadow, lineSpacing)

let mkActiveOrder = @() {
  flow = FLOW_VERTICAL
  size = [scrn_tgt(0.4), SIZE_TO_CONTENT]
  margin = const [0, 0, 0, hdpx(4)]
  gap = hdpx(4)
  children = [
    orderDesc
    mkScoresTableComp(Picture("!ui/gameuiskin#player_in_queue"))
    orderStatus
  ]
}

let undateOrderState = @() eventbus_send("active_order_request_update")

function mkOrderComps() {
  let collapseIcon = Picture($"ui/gameuiskin#spinnerListBox_arrow_up.svg:{collapseIconSize}:{collapseIconSize}")
  let collapseButton = mkCollapseButton(mkCollapseIconComp(collapseIcon))
  let activeOrder = mkActiveOrder()
  return @() {
    watch = [cursorVisible, isCollapsed]
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    gap = hdpx(4)
    children = (cursorVisible.get() && isCollapsed.get()) ? [collapseButton, collapsedOrder]
      : cursorVisible.get() ? [collapseButton, activeOrder]
      : isCollapsed.get() ? null
      : activeOrder
  }
}

function activeOrderComps() {
  return {
    watch = isOrderVisible
    children = isOrderVisible.get() ? mkOrderComps() : null

    onAttach = function() {
      eventbus_send("active_order_enable")
      gui_scene.setInterval(1, undateOrderState)
    }
    onDetach = @() gui_scene.clearTimer(undateOrderState)
  }
}

let mkActiveOrderLogContentInner = @() {
  rendObj = ROBJ_SOLID
  size = const [FLEX, SIZE_TO_CONTENT]
  minHeight = hdpx(158)
  padding = [scrn_tgt(0.005), scrn_tgt(0.005)]
  valign = ALIGN_TOP
  color = colors.hud.hudLogBgColor
  children = mkActiveOrder()
}

let activeOrderLogContent = @() makeVertScroll(mkActiveOrderLogContentInner(), {
  size = const [FLEX, hdpx(158)]
  needReservePlace = false
})

return {
  activeOrderComps
  activeOrderLogContent
}
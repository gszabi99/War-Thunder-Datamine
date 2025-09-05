from "%rGui/globals/ui_library.nut" import *
let cross_call = require("%rGui/globals/cross_call.nut")
let { cursorVisible } = require("%rGui/ctrlsState.nut")
let { showOrder, scoresTable, statusText, statusTextBottom } = require("%rGui/orderState.nut")
let colors = require("%rGui/style/colors.nut")
let teamColors = require("%rGui/style/teamColors.nut")
let fontsState = require("%rGui/style/fontsState.nut")
let { isOrderStatusVisible } = require("%rGui/hud/hudPartVisibleState.nut")

let isOrderVisible = Computed(@() isOrderStatusVisible.get() && showOrder.get())
let isCollapsed = Watched(false)

let pilotIcon = Picture("!ui/gameuiskin#player_in_queue")
let rowHeight = scrn_tgt(0.0224)
let collapseBtnSize = hdpx(45)
let collapseIconSize = hdpx(30)
let collapseIcon = Picture($"ui/gameuiskin#spinnerListBox_arrow_up.svg:{collapseIconSize}:{collapseIconSize}")

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

let collapseIconComp = @() {
  watch = isCollapsed
  rendObj = ROBJ_IMAGE
  size = [collapseIconSize, collapseIconSize]
  color = Color(192, 192, 192)
  image = collapseIcon
  transform = {
    rotate = isCollapsed.get() ? 90 : 270
  }
}

let collapseButton = watchElemState(@(sf) {
  behavior = Behaviors.Button
  rendObj = ROBJ_SOLID
  size = [collapseBtnSize, collapseBtnSize]
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
  size = [collapseBtnSize, collapseBtnSize]
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  font = fontsState.get("medium")
  color = Color(249, 219, 120)
  margin = static [hdpx(1), 0, 0, hdpx(1)]
}

let collapsedOrder = {
  rendObj = ROBJ_SOLID
  size = [collapseBtnSize, collapseBtnSize]
  color = Color(3, 7, 12, 204)
  children = orderIcon
}

let mkPlayerComp = @(item) {
  size = [SIZE_TO_CONTENT, rowHeight]
  flow = FLOW_HORIZONTAL
  valign = ALIGN_BOTTOM
  gap = hdpx(2)
  children = [
    {
      rendObj = ROBJ_IMAGE
      size = [rowHeight, rowHeight]
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
      colorTable = teamColors.value
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

function scoresTableComp() {
  let res = {
    playerComps = []
    scoreComps = []
  }
  foreach (item in scoresTable.get()) {
    res.playerComps.append(mkPlayerComp(item))
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
  margin = static [0, 0, 0, hdpx(10)]
  text = statusText.get()
  font = fontsState.get("small")
  color = colors.menu.commonTextColor
  colorTable = teamColors.value
}.__update(shadow, lineSpacing)

let orderStatus = @() {
  watch = [statusTextBottom, teamColors]
  rendObj = ROBJ_TEXTAREA
  behavior = Behaviors.TextArea
  size = FLEX_H
  text = statusTextBottom.get()
  font = fontsState.get("small")
  color = colors.menu.commonTextColor
  colorTable = teamColors.value
}.__update(shadow, lineSpacing)

let order = {
  flow = FLOW_VERTICAL
  size = [scrn_tgt(0.4), SIZE_TO_CONTENT]
  margin = static [0, 0, 0, hdpx(4)]
  gap = hdpx(4)
  children = [
    orderDesc
    scoresTableComp
    orderStatus
  ]
}

let undateOrderState = @() cross_call.active_order_request_update()

return function() {
  local children = null
  if (isOrderVisible.get())
    children = (cursorVisible.get() && isCollapsed.get()) ? [collapseButton, collapsedOrder]
      : cursorVisible.get() ? [collapseButton, order]
      : isCollapsed.get() ? null
      : order

  return {
    watch = [isOrderVisible, cursorVisible, isCollapsed]
    size = SIZE_TO_CONTENT
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    gap = hdpx(4)
    children

    onAttach = function(_) {
      cross_call.active_order_enable()
      gui_scene.setInterval(1, undateOrderState)
    }
    onDetach = @(_) gui_scene.clearTimer(undateOrderState)
  }
}
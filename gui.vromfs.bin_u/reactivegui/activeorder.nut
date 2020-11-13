local orderState = require("orderState.nut")
local colors = require("style/colors.nut")
local teamColors = require("style/teamColors.nut")
local fontsState = require("reactiveGui/style/fontsState.nut")



local pilotIcon = Picture("!ui/gameuiskin#player_in_queue")

local scoresTable = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = orderState.scoresTable
  children = orderState.scoresTable.value.map(@(item) {
    size = [flex(), ::scrn_tgt(0.0224)]
    flow = FLOW_HORIZONTAL
    valign = ALIGN_BOTTOM
    children = [
      {
        rendObj = ROBJ_IMAGE
        size = [::scrn_tgt(0.0224), ::scrn_tgt(0.0224)]
        image = pilotIcon
      }
      @(){
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        watch = teamColors
        text = item.player
        size = [flex(15), SIZE_TO_CONTENT]
        font = fontsState.get("small")
        color = colors.menu.commonTextColor
        colorTable = teamColors.value
      }
      {
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        text = item.score
        size = [flex(6), SIZE_TO_CONTENT]
        font = fontsState.get("small")
        color = colors.menu.commonTextColor
      }
    ]
  })
}


local updateFunction = function () {
  ::cross_call.active_order_request_update()
}


return function() {
  return {
    flow = FLOW_VERTICAL
    size = [::scrn_tgt(0.4), SIZE_TO_CONTENT]
    watch = orderState.showOrder
    isHidden = !orderState.showOrder.value
    onAttach = function (elem) {
      ::cross_call.active_order_enable()
      ::gui_scene.setInterval(1, updateFunction) }
    onDetach = function (elem) { ::gui_scene.clearTimer(updateFunction) }
    children = [
      @() {
        watch = [orderState.statusText, teamColors]
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        size = [flex(), SIZE_TO_CONTENT]
        text = orderState.statusText.value
        font = fontsState.get("small")
        color = colors.menu.commonTextColor
        colorTable = teamColors.value
      }
      scoresTable
      @() {
        watch = [orderState.statusTextBottom, teamColors]
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        size = [flex(), SIZE_TO_CONTENT]
        text = orderState.statusTextBottom.value
        font = fontsState.get("small")
        color = colors.menu.commonTextColor
        colorTable = teamColors.value
      }
    ]
  }
}

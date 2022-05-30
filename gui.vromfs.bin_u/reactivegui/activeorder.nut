let { showOrder, scoresTable, statusText, statusTextBottom } = require("orderState.nut")
let colors = require("style/colors.nut")
let teamColors = require("style/teamColors.nut")
let fontsState = require("%rGui/style/fontsState.nut")
let { isOrderStatusVisible } = require("hud/hudPartVisibleState.nut")


let pilotIcon = Picture("!ui/gameuiskin#player_in_queue")

let scoresTableComp = @() {
  size = [flex(), SIZE_TO_CONTENT]
  flow = FLOW_VERTICAL
  watch = scoresTable
  children = scoresTable.value.map(@(item) {
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


let updateFunction = function () {
  ::cross_call.active_order_request_update()
}

let isOrderVisible = ::Computed(@() isOrderStatusVisible.value && showOrder.value)

return @() {
  flow = FLOW_VERTICAL
  size = [::scrn_tgt(0.4), SIZE_TO_CONTENT]
  watch = isOrderVisible
  onAttach = function (_elem) {
    ::cross_call.active_order_enable()
    ::gui_scene.setInterval(1, updateFunction) }
  onDetach = function (_elem) { ::gui_scene.clearTimer(updateFunction) }
  children = isOrderVisible.value
    ? [
        @() {
          watch = [statusText, teamColors]
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          size = [flex(), SIZE_TO_CONTENT]
          text = statusText.value
          font = fontsState.get("small")
          color = colors.menu.commonTextColor
          colorTable = teamColors.value
        }
        scoresTableComp
        @() {
          watch = [statusTextBottom, teamColors]
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          size = [flex(), SIZE_TO_CONTENT]
          text = statusTextBottom.value
          font = fontsState.get("small")
          color = colors.menu.commonTextColor
          colorTable = teamColors.value
        }
      ]
    : []
}

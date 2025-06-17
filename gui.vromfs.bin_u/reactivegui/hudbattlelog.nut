from "%rGui/globals/ui_library.nut" import *

let battleLogState = require("battleLogState.nut")
let scrollableData = require("components/scrollableData.nut")
let hudLog = require("components/hudLog.nut")
let teamColors = require("style/teamColors.nut")
let fontsState = require("%rGui/style/fontsState.nut")

let logEntryComponent = function (log_entry) {
  return function () {
    return  {
      watch = teamColors
      size = FLEX_H
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = log_entry.message
      font = fontsState.get("small")
      key = log_entry
      colorTable = teamColors.value
    }
  }
}

let logBox = hudLog({
  logComponent = scrollableData.make(battleLogState)
  messageComponent = logEntryComponent
})

return {
  size = FLEX_H
  children = logBox
}

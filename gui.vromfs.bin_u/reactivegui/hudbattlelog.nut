from "%rGui/globals/ui_library.nut" import *

let battleLogState = require("%rGui/battleLogState.nut")
let scrollableData = require("%rGui/components/scrollableData.nut")
let hudLog = require("%rGui/components/hudLog.nut")
let teamColors = require("%rGui/style/teamColors.nut")
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
      colorTable = teamColors.get()
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

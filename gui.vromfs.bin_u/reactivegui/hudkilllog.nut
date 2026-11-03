import "%rGui/components/scrollableData.nut" as scrollableData
import "%rGui/style/fontsState.nut" as fontsState
import "%rGui/killLogState.nut" as killLogState
import "%rGui/components/hudLog.nut" as hudLog
import "%rGui/style/teamColors.nut" as teamColors
from "%rGui/components/psnIconEmbed.nut" import psnIconToEmbed, mkPsnIconEmbed
from "%rGui/globals/ui_library.nut" import *

let logEntryComponent = function (log_entry) {
  return function () {
    return  {
      watch = teamColors
      size = FLEX_H
      rendObj = ROBJ_TEXTAREA
      behavior = Behaviors.TextArea
      text = psnIconToEmbed(log_entry.message)
      embed = mkPsnIconEmbed(fontsState.get("small"))
      font = fontsState.get("small")
      key = log_entry
      colorTable = teamColors.get()
    }
  }
}

let logBox = hudLog({
  logComponent = scrollableData.make(killLogState)
  messageComponent = logEntryComponent
})

return freeze({
  size = FLEX_H
  children = logBox
})

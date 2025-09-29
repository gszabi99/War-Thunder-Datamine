from "%scripts/dagui_library.nut" import *
from "%scripts/clans/clanState.nut" import is_in_clan
import "platform" as platform
let { split_by_chars } = require("string")
let { get_console_model } = platform

let visibleConditionsList = {
  isInClan = @() is_in_clan()
  isNotInClan = @() !is_in_clan()
}

function isVisibleByConsoleModel(blk) {
  let { consoleModels = "" } = blk
  if (consoleModels == "")
    return true

  let curModel = get_console_model()
  foreach (name in consoleModels.split("; "))
    if (platform?[name] == curModel)
      return true

  return false

}

function isVisibleByConditions(blk) {
  if (!isVisibleByConsoleModel(blk))
    return false

  let visibleConditions = blk?.visibleConditions
  if (visibleConditions == null)
    return true

  foreach (name in split_by_chars(visibleConditions, "; "))
    if (!(visibleConditionsList?[name]?() ?? true))
      return false

  return true
}

return {
  isVisibleByConditions
}
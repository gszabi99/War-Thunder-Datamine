from "%rGui/globals/ui_library.nut" import *
let { subscribe, send } = require("eventbus")

let isActionBarCollapsed = Watched(false)
let isActionBarCollapsable = Watched(false)
let isActionBarVisible = Watched(false)
let actionBarPos = Watched(null)
let actionBarSize = Watched(null)
let actionBarCollapseShText = Watched("")

subscribe("setIsActionBarVisible", @(v) isActionBarVisible.set(v))
subscribe("setIsActionBarCollapsed", @(v) isActionBarCollapsed.set(v))
subscribe("setActionBarState", function(params) {
  isActionBarCollapsed.set(params?.isCollapsed ?? false)
  isActionBarCollapsable.set(params?.isCollapsable ?? false)
  isActionBarVisible.set(params?.isVisible ?? false)
  actionBarPos.set(params?.pos)
  actionBarSize.set(params?.size)
  actionBarCollapseShText.set(params?.shortcutText ?? "")
})

send("getActionBarState", {})

return {
  isActionBarCollapsed
  isActionBarCollapsable
  isActionBarVisible
  actionBarPos
  actionBarSize
  actionBarCollapseShText
}
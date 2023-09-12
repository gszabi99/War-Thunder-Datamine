//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { show_obj } = require("%sqDagui/daguiUtil.nut")
let { USEROPT_RANDB_CLUSTER } = require("%scripts/options/optionsExtNames.nut")

let getCurrentClustersInfo = function() {
  let clusterOpt = ::get_option(USEROPT_RANDB_CLUSTER)
  let names = []
  local hasUnstable = false
  for (local i = 0; i < clusterOpt.values.len(); i++)
    if ((clusterOpt.value & (1 << i)) > 0) {
      names.append(clusterOpt.items[i].text)
      hasUnstable = hasUnstable || clusterOpt.items[i].isUnstable
    }
  return { names, hasUnstable }
}

let updateClusters = function(btnObj) {
  local show = isMultiplayerPrivilegeAvailable.value
  if (!show_obj(btnObj, show) || !show)
    return

  let currentClustersInfo = getCurrentClustersInfo()
  let clusterNamesText = "; ".join(currentClustersInfo.names)
  let needWarning = currentClustersInfo.hasUnstable

  btnObj.tooltip = needWarning ? loc("multiplayer/cluster_connection_unstable") : ""

  let btnTextObj = btnObj.findObject("cluster_select_button_text")
  btnTextObj.setValue("".concat(loc("options/cluster"), loc("ui/colon"), clusterNamesText))
  btnTextObj.leftAligned = needWarning ? "yes" : "no"

  let btnIconObj = btnObj.findObject("cluster_select_button_icon")
  btnIconObj.wink = needWarning ? "veryfast" : "no"
  btnIconObj.show(needWarning)
}

let getCurrentClusters = function() {
  let clusterOpt = ::get_option(USEROPT_RANDB_CLUSTER)
  let result = []
  for (local i = 0; i < clusterOpt.values.len(); i++) {
    if (clusterOpt.values[i] == "auto")
      continue
    if ((clusterOpt.value & (1 << i)) > 0)
      result.append(clusterOpt.values[i])
  }
  return result
}

return {
  updateClusters
  getCurrentClusters
}
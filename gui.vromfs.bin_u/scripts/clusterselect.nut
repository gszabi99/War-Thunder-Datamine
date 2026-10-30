from "%scripts/user/xboxFeatures.nut" import isMultiplayerPrivilegeAvailable
from "%scripts/sqDagui/daguiUtil.nut" import show_obj
from "%scripts/options/optionsExtNames.nut" import USEROPT_RANDB_CLUSTERS
from "%scripts/options/optionsExt.nut" import get_option
from "%sqstd/math.nut" import is_bit_set
from "%scripts/dagui_library.nut" import *

function isAutoSelected(clusterOpt) {
  let autoOptBit = clusterOpt.values.findindex(@(v) v == "auto")
  return autoOptBit != null ? is_bit_set(clusterOpt.value, autoOptBit) : false
}

function getCurrentClustersInfo() {
  let clusterOpt = get_option(USEROPT_RANDB_CLUSTERS)
  let isAuto = isAutoSelected(clusterOpt)
  let names = []
  local hasUnstable = false
  for (local i = 0; i < clusterOpt.values.len(); i++)
    if ((isAuto && clusterOpt.items[i].isDefault)
        || (!isAuto && is_bit_set(clusterOpt.value, i))) {
      names.append(clusterOpt.items[i].text)
      hasUnstable = hasUnstable || clusterOpt.items[i].isUnstable
    }
  return { names, hasUnstable }
}

function updateClusters(btnObj) {
  local show = isMultiplayerPrivilegeAvailable.get()
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

function getCurrentClusters() {
  let clusterOpt = get_option(USEROPT_RANDB_CLUSTERS)
  let isAuto = isAutoSelected(clusterOpt)
  if (isAuto)
    return clusterOpt.items.filter(@(c) c.isDefault).map(@(c) c.name)

  let result = []
  for (local i = 0; i < clusterOpt.values.len(); i++) {
    if (clusterOpt.items[i].isAuto)
      continue
    if ((clusterOpt.value & (1 << i)) > 0)
      result.append(clusterOpt.values[i])
  }
  return result
}

return freeze({
  updateClusters
  getCurrentClusters
})
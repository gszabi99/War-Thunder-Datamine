let { is_bit_set } = require("%sqstd/math.nut")

let getViewClusters = function() {
  let clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  return clusterOpt.items.map(@(item, idx) {
    id = $"cluster_item_{idx}"
    value = idx
    selected = is_bit_set(clusterOpt.value, idx)
    text = item.text
    icon = item.image
    tooltip = item.tooltip
  })
}

let createClusterSelectMenu = function(placeObj, alight = "top")
{
  ::gui_start_multi_select_menu({
    list = getViewClusters()
    onChangeValuesBitMaskCb = function(mask) {
      let clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
      let prevMask = clusterOpt.value
      ::set_option(::USEROPT_RANDB_CLUSTER, mask, clusterOpt)

      for (local i = 0; i < clusterOpt.values.len(); i++)
        if ((mask & (1 << i)) > 0 && (prevMask & (1 << i)) == 0 && clusterOpt.items[i].isUnstable)
          ::showInfoMsgBox(::loc("multiplayer/cluster_connection_unstable"), "warning_cluster_unstable")
    }
    align = alight
    alignObj = placeObj
  })
}

let getCurrentClustersInfo = function()
{
  let clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  let names = []
  local hasUnstable = false
  for (local i = 0; i < clusterOpt.values.len(); i++)
    if ((clusterOpt.value & (1 << i)) > 0) {
      names.append(clusterOpt.items[i].text)
      hasUnstable = hasUnstable || clusterOpt.items[i].isUnstable
    }
  return { names, hasUnstable }
}

let updateClusters = function(btnObj)
{
  if (!btnObj?.isValid())
    return

  let currentClustersInfo = getCurrentClustersInfo()
  let clusterNamesText = "; ".join(currentClustersInfo.names)
  let needWarning = currentClustersInfo.hasUnstable

  btnObj.tooltip = needWarning ? ::loc("multiplayer/cluster_connection_unstable") : ""

  let btnTextObj = btnObj.findObject("cluster_select_button_text")
  btnTextObj.setValue("".concat(::loc("options/cluster"), ::loc("ui/colon"), clusterNamesText))
  btnTextObj.leftAligned = needWarning ? "yes" : "no"

  let btnIconObj = btnObj.findObject("cluster_select_button_icon")
  btnIconObj.wink = needWarning ? "veryfast" : "no"
  btnIconObj.show(needWarning)
}

let getCurrentClusters = function()
{
  let clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  let result = []
  for (local i = 0; i < clusterOpt.values.len(); i++)
    if ((clusterOpt.value & (1 << i)) > 0)
      result.append(clusterOpt.values[i])
  return result
}

return {
  createClusterSelectMenu = createClusterSelectMenu
  updateClusters = updateClusters
  getCurrentClusters = getCurrentClusters
}
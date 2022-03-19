local { is_bit_set } = require("std/math.nut")

local getViewClusters = function() {
  local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  return clusterOpt.items.map(@(item, idx) {
    id = $"cluster_item_{idx}"
    value = idx
    selected = is_bit_set(clusterOpt.value, idx)
    text = item.text
    icon = item.image
    addImageProps = item.addImageProps
    tooltip = item.tooltip
  })
}

local createClusterSelectMenu = function(placeObj, alight = "top")
{
  ::gui_start_multi_select_menu({
    list = getViewClusters()
    onChangeValuesBitMaskCb = function(mask) {
      local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
      local prevMask = clusterOpt.value
      ::set_option(::USEROPT_RANDB_CLUSTER, mask, clusterOpt)

      for (local i = 0; i < clusterOpt.values.len(); i++)
        if ((mask & (1 << i)) > 0 && (prevMask & (1 << i)) == 0 && clusterOpt.items[i].isUnstable)
          ::showInfoMsgBox(::loc("multiplayer/cluster_connection_unstable"), "warning_cluster_unstable")
    }
    align = alight
    alignObj = placeObj
  })
}

local getCurrentClustersInfo = function()
{
  local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  local names = []
  local hasUnstable = false
  for (local i = 0; i < clusterOpt.values.len(); i++)
    if ((clusterOpt.value & (1 << i)) > 0) {
      names.append(clusterOpt.items[i].text)
      hasUnstable = hasUnstable || clusterOpt.items[i].isUnstable
    }
  return { names, hasUnstable }
}

local updateClusters = function(btnObj)
{
  if (!btnObj?.isValid())
    return

  local currentClustersInfo = getCurrentClustersInfo()
  local clusterNamesText = "; ".join(currentClustersInfo.names)
  local needWarning = currentClustersInfo.hasUnstable

  btnObj.tooltip = needWarning ? ::loc("multiplayer/cluster_connection_unstable") : ""

  local btnTextObj = btnObj.findObject("cluster_select_button_text")
  btnTextObj.setValue("".concat(::loc("options/cluster"), ::loc("ui/colon"), clusterNamesText))
  btnTextObj.leftAligned = needWarning ? "yes" : "no"

  local btnIconObj = btnObj.findObject("cluster_select_button_icon")
  btnIconObj.wink = needWarning ? "veryfast" : "no"
  btnIconObj.show(needWarning)
}

local getCurrentClusters = function()
{
  local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  local result = []
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
local stdMath = require("std/math.nut")

local getViewClusters = function()
{
  local viewClusters = []
  local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  foreach (idx, item in clusterOpt.items)
  {
    viewClusters.append({
      id = "cluster_item_" + idx
      value = idx
      selected = stdMath.is_bit_set(clusterOpt.value, idx)
      text = item.text
    })
  }
  return viewClusters
}

local createClusterSelectMenu = function(placeObj, alight = "top")
{
  ::gui_start_multi_select_menu({
    list = getViewClusters()
    onChangeValuesBitMaskCb = function(mask) {
      local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
      ::set_option(::USEROPT_RANDB_CLUSTER, mask, clusterOpt)
    }
    align = alight
    alignObj = placeObj
  })
}

local getCurrentClustersTexts = function()
{
  local clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  local result = []
  for (local i = 0; i < clusterOpt.values.len(); i++)
    if ((clusterOpt.value & (1 << i)) > 0)
      result.append(clusterOpt.items[i].text)
  return result
}

local updateClusters = function(placeObj)
{
  if (!::check_obj(placeObj))
    return

  local clustersText = ::loc("options/cluster") + ::loc("ui/colon")
  local currentClusterNames = getCurrentClustersTexts()
  local first = true
  foreach(clusterName in currentClusterNames)
  {
    clustersText += (first ? "" : "; ") + ::loc(clusterName)
    first = false
  }
  placeObj.setValue(clustersText)
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
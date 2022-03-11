let stdMath = require("std/math.nut")

let getViewClusters = function()
{
  let viewClusters = []
  let clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
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

let createClusterSelectMenu = function(placeObj, alight = "top")
{
  ::gui_start_multi_select_menu({
    list = getViewClusters()
    onChangeValuesBitMaskCb = function(mask) {
      let clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
      ::set_option(::USEROPT_RANDB_CLUSTER, mask, clusterOpt)
    }
    align = alight
    alignObj = placeObj
  })
}

let getCurrentClustersTexts = function()
{
  let clusterOpt = ::get_option(::USEROPT_RANDB_CLUSTER)
  let result = []
  for (local i = 0; i < clusterOpt.values.len(); i++)
    if ((clusterOpt.value & (1 << i)) > 0)
      result.append(clusterOpt.items[i].text)
  return result
}

let updateClusters = function(placeObj)
{
  if (!::check_obj(placeObj))
    return

  local clustersText = ::loc("options/cluster") + ::loc("ui/colon")
  let currentClusterNames = getCurrentClustersTexts()
  local first = true
  foreach(clusterName in currentClusterNames)
  {
    clustersText += (first ? "" : "; ") + ::loc(clusterName)
    first = false
  }
  placeObj.setValue(clustersText)
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
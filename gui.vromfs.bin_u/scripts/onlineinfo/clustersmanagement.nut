from "%scripts/dagui_natives.nut" import get_cur_circuit_name, is_online_available
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType
from "app" import is_dev_version

let { split_by_chars } = require("string")
let { checkMatchingError } = require("%scripts/matching/api.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { addListenersWithoutEnv, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { DEFAULT_HANDLER } = require("%scripts/g_listener_priority.nut")
let { getCountryCode } = require("auth_wt")
let { getClustersByCountry } = require("%scripts/onlineInfo/defaultClusters.nut")
let { optimalClusters } = require("%scripts/onlineInfo/optimalClusters.nut")
let { startLogout } = require("%scripts/login/logout.nut")
let { isDataBlock, eachParam } = require("%sqstd/datablock.nut")
let { fetchClustersList } = require("%scripts/matching/serviceNotifications/match.nut")
let { get_network_block } = require("blkGetters")
let { OPTIONS_MODE_MP_DOMINATION, USEROPT_CLUSTERS, USEROPT_RANDB_CLUSTERS
} = require("%scripts/options/optionsExtNames.nut")
let { get_option, registerOption } = require("%scripts/options/optionsExt.nut")
let { isInSessionRoom, getSessionLobbyPublicParam
} = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { get_gui_option_in_mode, set_gui_option_in_mode } = require("%scripts/options/options.nut")
let { get_bit_value_by_array } = require("%scripts/utils_sa.nut")
let { is_bit_set } = require("%sqstd/math.nut")

const MAX_FETCH_RETRIES = 5

let clustersList = []

local unstableClusters = null

function cacheUnstableClustersOnce() {
  if (unstableClusters != null)
    return
  unstableClusters = []
  let blk = get_network_block()?[get_cur_circuit_name()].unstableClusters[getCountryCode()]
  if (isDataBlock(blk))
    eachParam(blk, @(v, k) v ? unstableClusters.append(k) : null)
}

function isClusterUnstable(clusterName) {
  cacheUnstableClustersOnce()
  return unstableClusters.contains(clusterName)
}

let mkCluster = @(name) {
  name
  isUnstable = isClusterUnstable(name)
}

function updateDefaultClusters() {
  let defaults = optimalClusters.get().len() > 0
    ? optimalClusters.get()
    : getClustersByCountry(getCountryCode())
  clustersList.each(@(info) info.isDefault <- defaults.contains(info.name))
  let hasDefault = clustersList.findindex(@(info) info.isDefault) != null
  if (!hasDefault)
    clustersList.each(@(info) info.isDefault = true)
}

function onClustersLoaded(params) {
  log("[MM] clusters loaded")
  debugTableData(params)

  let clusters = getTblValue("clusters", params)
  if (!u.isArray(clusters))
    return false

  clustersList.clear()
  foreach (_idx, val in params.clusters)
    clustersList.append(mkCluster(val))

  updateDefaultClusters()
  return clustersList.len() > 0
}

let getClusterShortName = @(clusterId) loc($"cluster/{clusterId}", clusterId)

function getClusterFullName(clusterId) {
  let longName = loc($"cluster/{clusterId}/full", "")
  if (longName == "")
    return getClusterShortName(clusterId)

  return "".concat(longName,
    loc("ui/parentheses/space", { text = getClusterShortName(clusterId) }))
}

local isClustersFetching = false
local fetchCounter = 0

function updateClustersList() {
  if (isClustersFetching)
    return

  isClustersFetching = true
  ++fetchCounter

  let self = callee()
  fetchClustersList(null,
    function(params) {
      isClustersFetching = false

      if (checkMatchingError(params, false)
          && onClustersLoaded(params)) {
        fetchCounter = 0
        return
      }

      
      if (fetchCounter < MAX_FETCH_RETRIES) {
        log($"fetch cluster error, retry - {fetchCounter}")
        self()
      }
      else if (!is_dev_version())
        startLogout()
    })
}

function forceUpdateClustersList() {
  if (!is_online_available())
    return

  isClustersFetching = false
  updateClustersList()
}

function onClustersChanged(params) {
  local needUpdateDefaultClusters = false
  if ("added" in params) {
    foreach (cluster in params.added) {
      local found = false
      foreach (_idx, c in clustersList) {
        if (c.name == cluster) {
          found = true
          break
        }
      }
      if (!found) {
        clustersList.append(mkCluster(cluster))
        log($"[MM] cluster added {cluster}")
        needUpdateDefaultClusters = true
      }
    }
  }

  if ("removed" in params) {
    foreach (cluster in params.removed) {
      foreach (idx, c in clustersList) {
        if (c.name == cluster) {
          clustersList.remove(idx)
          needUpdateDefaultClusters = true
          break
        }
      }
      log($"[MM] cluster removed {cluster}")
    }
  }
  if (needUpdateDefaultClusters)
    updateDefaultClusters()
  log("clusters list updated")
  debugTableData(clustersList)
}

let getClustersList = @() clustersList

function fillUseroptClustersItemsList(optionId, descr) {
  descr.id = "cluster"
  if (getClustersList().len() > 0) {
    descr.items = getClustersList().map(@(c) {
      text = getClusterShortName(c.name)
      name = c.name
      image = c.isUnstable ? "#ui/gameuiskin#urgent_warning.svg" : null
      tooltip = c.isUnstable ? loc("multiplayer/cluster_connection_unstable") : null
      isUnstable = c.isUnstable
      isDefault = c.isDefault
      isAuto = false
      isVisible = c.name != "SA"
    }).append({
      text = loc("options/auto")
      name = "auto"
      image = null
      tooltip = loc("options/auto/tooltip", {
        clusters = ", ".join(getClustersList().map(@(c) getClusterShortName(c.name)))
      })
      isUnstable = false
      isDefault = false
      isAuto = true
      isVisible = true
    })
    if (optionId == USEROPT_CLUSTERS)
      descr.items = descr.items.filter(@(i) i.isVisible)
    descr.values = descr.items.map(@(i) i.name)
    descr.defaultValue = "auto"
  }
  else {
    
    descr.items = [{
      text = "---"
      name = "---"
      image = null
      tooltip = null
      isUnstable = false
      isDefault = false
      isAuto = false
      isVisible = true
    }]
    descr.values = [""]
    descr.value = descr.controlType == optionControlType.BIT_LIST ? 1 : ""
    descr.defaultValue = ""
    return
  }

  descr.prevValue = get_gui_option_in_mode(optionId, OPTIONS_MODE_MP_DOMINATION)
  if (optionId == USEROPT_CLUSTERS) {
    if (isInSessionRoom.get())
      descr.prevValue = getSessionLobbyPublicParam("cluster", null)
  }
  else if (optionId == USEROPT_RANDB_CLUSTERS) {
    descr.value = 0
    if (u.isString(descr.prevValue)) {
      local selectedValues = split_by_chars(descr.prevValue, ";")
      let isAuto = selectedValues.contains("auto")
      if (isAuto)
        selectedValues = [descr.defaultValue]
      descr.value = get_bit_value_by_array(selectedValues, descr.values)
    }
    if (descr.value == 0)
      descr.value = max(get_bit_value_by_array([descr.defaultValue], descr.values), 1)
  }
}

function fillUseroptClusters(optionId, descr, _context) {
  descr.controlType = optionControlType.LIST
  fillUseroptClustersItemsList(optionId, descr)
}

function fillUseroptRandbClusters(optionId, descr, _context) {
  descr.controlType = optionControlType.BIT_LIST
  fillUseroptClustersItemsList(optionId, descr)
}

function setUseroptClusters(value, descr, optionId) {
  if (value >= 0 && value < descr.values.len())
    set_gui_option_in_mode(optionId, descr.values[value], OPTIONS_MODE_MP_DOMINATION)
}

function setUseroptRandbClusters(value, descr, optionId) {
  if (value < 0 || value > (1 << descr.values.len()) - 1)
    return

  let autoIdx = descr.values.findindex(@(v) v == "auto")
  local prevVal = get_option(USEROPT_RANDB_CLUSTERS).value
  local isAutoSelected = false
  local isAutoDeselected = false
  if (autoIdx != null) {
    let prevAutoVal = is_bit_set(prevVal, autoIdx)
    let curAutoVal = is_bit_set(value, autoIdx)
    isAutoSelected = !prevAutoVal && curAutoVal
    isAutoDeselected = prevAutoVal && !curAutoVal
  }

  local clusters = isAutoSelected ? ["auto"]
    : isAutoDeselected ? descr.values.filter(@(_, i) descr.items[i].isVisible && descr.items[i].isDefault)
    : (value == 0) && (autoIdx != null) ? ["auto"]
    : descr.values.filter(@(_, i) !descr.items[i].isAuto && descr.items[i].isVisible && is_bit_set(value, i))

  if (clusters.len() == 0) 
    clusters = descr.values.filter(@(_, i) descr.items[i].isVisible && !descr.items[i].isAuto)

  let newVal = ";".join(clusters)
  set_gui_option_in_mode(optionId, newVal, OPTIONS_MODE_MP_DOMINATION)
  broadcastEvent("ClusterChange")
}

registerOption(USEROPT_CLUSTERS, fillUseroptClusters, setUseroptClusters)
registerOption(USEROPT_RANDB_CLUSTERS, fillUseroptRandbClusters, setUseroptRandbClusters)

optimalClusters.subscribe(@(_) updateDefaultClusters())

addListenersWithoutEnv({
  MatchingConnect = @(_) forceUpdateClustersList()
  ScriptsReloaded = @(_) forceUpdateClustersList() 
  SignOut = @(_) clustersList.clear()
  ClustersChanged = onClustersChanged
}, DEFAULT_HANDLER)

return {
  getClustersList
  getClusterShortName
  getClusterFullName
  isClusterUnstable
}
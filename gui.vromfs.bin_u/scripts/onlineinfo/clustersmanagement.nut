local { startLogout } = require("scripts/login/logout.nut")

// -------------------------------------------------------
// Clusters managment
// -------------------------------------------------------
::g_clusters <- {
  clusters_info = []

  function forceUpdateClustersList()
  {
    if (!::is_online_available())
      return

    __clusters_fetching = false
    __update_clusters_list()
  }

  function onClustersLoaded(params)
  {
    dagor.debug("[MM] clusters loaded")
    debugTableData(params)

    local clusters = ::getTblValue("clusters", params)
    if (!::u.isArray(clusters))
      return false

    clusters_info.clear()
    foreach (idx, val in params.clusters)
      clusters_info.append({name = val})
    //TODO: need to update clusters in GUI

    return clusters_info.len() > 0
  }

  function onClustersChanged(params)
  {
    if ("added" in params)
    {
      foreach (cluster in params.added)
      {
        local found = false
        foreach (idx, c in clusters_info)
        {
          if (c.name == cluster)
          {
            found = true
            break
          }
        }
        if (!found)
        {
          clusters_info.append({name = cluster})
          dagor.debug("[MM] cluster added " + cluster)
        }
      }
    }

    if ("removed" in params)
    {
      foreach (cluster in params.removed)
      {
        foreach (idx, c in clusters_info)
        {
          if (c.name == cluster)
          {
            clusters_info.remove(idx)
            break
          }
        }
        dagor.debug("[MM] cluster removed " + cluster)
      }
    }
    dagor.debug("clusters list updated")
    debugTableData(clusters_info)
    //TODO: need to update clusters in GUI
  }

// private
  __clusters_fetching = false
  __fetch_counter = 0

  function __update_clusters_list()
  {
    if (__clusters_fetching)
      return

    __clusters_fetching = true
    __fetch_counter++
    ::fetch_clusters_list(null,
      function(params)
      {
        if (!this)
          return

        __clusters_fetching = false

        if (::checkMatchingError(params, false)
            && onClustersLoaded(params))
        {
          __fetch_counter = 0
          return
        }

        //clusters not loaded or broken data
        if (__fetch_counter < MAX_FETCH_RETRIES)
        {
          dagor.debug("fetch cluster error, retry - " + __fetch_counter)
          __update_clusters_list()
        } else
        {
          ::checkMatchingError(params, true)
          if (!::is_dev_version)
            startLogout()
        }
      }.bindenv(::g_clusters))
  }

  function onEventSignOut(p)
  {
    clusters_info.clear()
  }

  function onEventScriptsReloaded(p)
  {
    forceUpdateClustersList()
  }

  function onEventMatchingConnect(p)
  {
    forceUpdateClustersList()
  }

  function getClusterLocName(clusterName)
  {
    if (clusterName.indexof("wthost") != null)
      return clusterName
    return ::loc("cluster/" + clusterName)
  }
}

::subscribe_handler(::g_clusters)
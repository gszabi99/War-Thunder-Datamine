::gui_handlers.QiHandlerByCountries <- class extends ::gui_handlers.QiHandlerBase
{
  sceneBlkName   = "%gui/events/eventQueueByCountries.blk"

  timerUpdateObjId = "queue_box"
  timerTextObjId = "waitText"

  statsObj = null
  curClusterName = null
  visibleCountrySets = null

  function initTimer()
  {
    base.initTimer()
    scene.findObject("wait_time_block").show(hasTimerText)
  }

  function createStats()
  {
    createClustersList()

    statsObj = scene.findObject("stats_table")
    ::g_qi_view_utils.createViewByCountries(statsObj, queue, event)
  }

  function updateStats()
  {
    ::g_qi_view_utils.updateViewByCountries(statsObj, queue, curClusterName)
    let countrySets = ::events.getAllCountriesSets(event)
    if (!::u.isEqual(visibleCountrySets, countrySets))
      fillCountrySets(countrySets)
    updateCustomModeCheckbox()
  }

  function fillCountrySets(countrySets)
  {
    visibleCountrySets = countrySets
    if (countrySets.len() < 2)
      return

    let myCountry = ::queues.getQueueCountry(queue)
    let sortedSets = clone countrySets
    sortedSets.sort((@(myCountry) function(a, b) {
      let countryDiff = (myCountry in a.allCountries ? 0 : 1) - (myCountry in b.allCountries ? 0 : 1)
      if (countryDiff)
        return countryDiff
      return a.gameModeIds[0] - b.gameModeIds[0]
    })(myCountry))

    let view = {
      isCentered = true
      countriesSets = ::u.map(sortedSets, function(cSet)
      {
        let res = {}
        let teams = ::g_team.getTeams()
        foreach(idx, team in teams)
          if (idx in cSet.countries)
          {
            res[team.name] <- {
              countries = ::u.map(cSet.countries[idx], function(c)
              {
                return { countryIcon = ::get_country_icon(c) }
              })
            }
          }

        return res
      })
    }

    let markup = ::handyman.renderCached("%gui/events/countriesByTeamsList", view)
    let nestObj = scene.findObject("countries_sets")
    guiScene.replaceContentFromText(nestObj, markup, markup.len(), this)
    showSceneBtn("countries_sets_header", true)
  }

  function updateCustomModeCheckbox()
  {
    let isVisible = queue && queue.hasCustomMode()
    showSceneBtn("custom_mode_header", isVisible)
    let obj = showSceneBtn("custom_mode_checkbox", isVisible)
    if (!isVisible)
      return

    obj.enable(queue.isAllowedToSwitchCustomMode())
    let value = getCustomModeCheckboxValue()
    if (value != obj.getValue())
      obj.setValue(value)
  }

  function getCustomModeCheckboxValue()
  {
    if (!queue)
      return false
    if (queue.isAllowedToSwitchCustomMode())
      return queue.isCustomModeSwitchedOn()
    return queue.isCustomModeQUeued()
  }

  function onCustomModeCheckbox(obj)
  {
    if (queue)
      queue.switchCustomMode(obj.getValue())
  }

  function onEventQueueChanged(q)
  {
    if (q == queue)
      updateCustomModeCheckbox()
  }

  function createClustersList()
  {
    let clustersObj = scene.findObject("clusters_list")
    if (::events.isMultiCluster(event))
    {
      clustersObj.show(false)
      clustersObj.enable(false)
      return
    }

    let view = { tabs = [] }
    foreach (clusterName in ::queues.getQueueClusters(queue)) {
      let isUnstable = ::g_clusters.isClusterUnstable(clusterName)
      view.tabs.append({
        id = clusterName
        tabName = ::g_clusters.getClusterLocName(clusterName)
        tabImage = isUnstable ? "#ui/gameuiskin#urgent_warning.svg" : null
        tabImageParam = isUnstable ? "isLeftAligned:t='yes';isColoredImg:t='yes';wink:t='veryfast';" : null
      })
    }

    let markup = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(clustersObj, markup, markup.len(), this)
    if (view.tabs.len())
    {
      curClusterName = view.tabs[0].id
      clustersObj.setValue(0)
    }
  }

  function onClusterChange(obj)
  {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    curClusterName = obj.getChild(value).id
    if (queue && isStatsCreated)
      updateStats()
  }
}
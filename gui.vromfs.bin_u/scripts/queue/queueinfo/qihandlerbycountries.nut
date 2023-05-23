//checked for plus_string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

::gui_handlers.QiHandlerByCountries <- class extends ::gui_handlers.QiHandlerBase {
  sceneBlkName   = "%gui/events/eventQueueByCountries.blk"

  timerUpdateObjId = "queue_box"
  timerTextObjId = "waitText"

  statsObj = null
  curClusterName = null
  visibleCountrySets = null

  function initTimer() {
    base.initTimer()
    this.scene.findObject("wait_time_block").show(this.hasTimerText)
  }

  function createStats() {
    this.createClustersList()

    this.statsObj = this.scene.findObject("stats_table")
    ::g_qi_view_utils.createViewByCountries(this.statsObj, this.queue, this.event)
  }

  function updateStats() {
    ::g_qi_view_utils.updateViewByCountries(this.statsObj, this.queue, this.curClusterName)
    let countrySets = ::events.getAllCountriesSets(this.event)
    if (!u.isEqual(this.visibleCountrySets, countrySets))
      this.fillCountrySets(countrySets)
    this.updateCustomModeCheckbox()
  }

  function fillCountrySets(countrySets) {
    this.visibleCountrySets = countrySets
    if (countrySets.len() < 2)
      return

    let myCountry = ::queues.getQueueCountry(this.queue)
    let sortedSets = clone countrySets
    sortedSets.sort(function(a, b) {
      let countryDiff = (myCountry in a.allCountries ? 0 : 1) - (myCountry in b.allCountries ? 0 : 1)
      if (countryDiff)
        return countryDiff
      return a.gameModeIds[0] - b.gameModeIds[0]
    })

    let view = {
      isCentered = true
      countriesSets = u.map(sortedSets, function(cSet) {
        let res = {}
        let teams = ::g_team.getTeams()
        foreach (idx, team in teams)
          if (idx in cSet.countries) {
            res[team.name] <- {
              countries = u.map(cSet.countries[idx], function(c) {
                return { countryIcon = ::get_country_icon(c) }
              })
            }
          }

        return res
      })
    }

    let markup = handyman.renderCached("%gui/events/countriesByTeamsList.tpl", view)
    let nestObj = this.scene.findObject("countries_sets")
    this.guiScene.replaceContentFromText(nestObj, markup, markup.len(), this)
    this.showSceneBtn("countries_sets_header", true)
  }

  function updateCustomModeCheckbox() {
    let isVisible = this.queue && this.queue.hasCustomMode()
    this.showSceneBtn("custom_mode_header", isVisible)
    let obj = this.showSceneBtn("custom_mode_checkbox", isVisible)
    if (!isVisible)
      return

    obj.enable(this.queue.isAllowedToSwitchCustomMode())
    let value = this.getCustomModeCheckboxValue()
    if (value != obj.getValue())
      obj.setValue(value)
  }

  function getCustomModeCheckboxValue() {
    if (!this.queue)
      return false
    if (this.queue.isAllowedToSwitchCustomMode())
      return this.queue.isCustomModeSwitchedOn()
    return this.queue.isCustomModeQUeued()
  }

  function onCustomModeCheckbox(obj) {
    if (this.queue)
      this.queue.switchCustomMode(obj.getValue())
  }

  function onEventQueueChanged(q) {
    if (q == this.queue)
      this.updateCustomModeCheckbox()
  }

  function createClustersList() {
    let clustersObj = this.scene.findObject("clusters_list")
    if (::events.isMultiCluster(this.event)) {
      clustersObj.show(false)
      clustersObj.enable(false)
      return
    }

    let view = { tabs = [] }
    foreach (clusterName in ::queues.getQueueClusters(this.queue)) {
      let isUnstable = ::g_clusters.isClusterUnstable(clusterName)
      view.tabs.append({
        id = clusterName
        tabName = ::g_clusters.getClusterLocName(clusterName)
        tabImage = isUnstable ? "#ui/gameuiskin#urgent_warning.svg" : null
        tabImageParam = isUnstable ? "isLeftAligned:t='yes';isColoredImg:t='yes';wink:t='veryfast';" : null
      })
    }

    let markup = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(clustersObj, markup, markup.len(), this)
    if (view.tabs.len()) {
      this.curClusterName = view.tabs[0].id
      clustersObj.setValue(0)
    }
  }

  function onClusterChange(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    this.curClusterName = obj.getChild(value).id
    if (this.queue && this.isStatsCreated)
      this.updateStats()
  }
}
from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { g_team } = require("%scripts/teams.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getClusterShortName, isClusterUnstable
} = require("%scripts/onlineInfo/clustersManagement.nut")
let { createQueueViewByCountries, updateQueueViewByCountries } = require("%scripts/queue/queueInfo/qiViewUtils.nut")
let { getQueueCountry, getQueueClusters } = require("%scripts/queue/queueInfo.nut")

gui_handlers.QiHandlerByCountries <- class (gui_handlers.QiHandlerBase) {
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
    createQueueViewByCountries(this.statsObj, this.queue, this.event)
  }

  function updateStats() {
    updateQueueViewByCountries(this.statsObj, this.queue, this.curClusterName)
    let countrySets = events.getAllCountriesSets(this.event)
    if (!u.isEqual(this.visibleCountrySets, countrySets))
      this.fillCountrySets(countrySets)
    this.updateCustomModeCheckbox()
  }

  function fillCountrySets(countrySets) {
    this.visibleCountrySets = countrySets
    if (countrySets.len() < 2)
      return

    let myCountry = getQueueCountry(this.queue)
    let sortedSets = clone countrySets
    sortedSets.sort(function(a, b) {
      let countryDiff = (myCountry in a.allCountries ? 0 : 1) - (myCountry in b.allCountries ? 0 : 1)
      if (countryDiff)
        return countryDiff
      return a.gameModeIds[0] - b.gameModeIds[0]
    })

    let view = {
      isCentered = true
      countriesSets = sortedSets.map(function(cSet) {
        let res = {}
        let teams = g_team.getTeams()
        foreach (idx, team in teams)
          if (idx in cSet.countries) {
            res[team.name] <- {
              countries = cSet.countries[idx].map(@(c) { countryIcon = getCountryIcon(c) })
            }
          }

        return res
      })
    }

    let markup = handyman.renderCached("%gui/events/countriesByTeamsList.tpl", view)
    let nestObj = this.scene.findObject("countries_sets")
    this.guiScene.replaceContentFromText(nestObj, markup, markup.len(), this)
    showObjById("countries_sets_header", true, this.scene)
  }

  function updateCustomModeCheckbox() {
    let isVisible = this.queue && this.queue.hasCustomMode()
    showObjById("custom_mode_header", isVisible, this.scene)
    let obj = showObjById("custom_mode_checkbox", isVisible, this.scene)
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
    if (events.isMultiCluster(this.event)) {
      clustersObj.show(false)
      clustersObj.enable(false)
      return
    }

    let view = { tabs = [] }
    foreach (clusterName in getQueueClusters(this.queue)) {
      let isUnstable = isClusterUnstable(clusterName)
      view.tabs.append({
        id = clusterName
        tabName = getClusterShortName(clusterName)
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

  onEventQueueStatsClusterAdded = @(_) this.createClustersList()
}
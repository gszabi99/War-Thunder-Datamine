from "%scripts/dagui_library.nut" import *
from "%scripts/teamsConsts.nut" import Team
from "%scripts/utils_sa.nut" import buildTableRow

let { getGlobalModule } = require("%scripts/global_modules.nut")
let events = getGlobalModule("events")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let time = require("%scripts/time.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let { getQueueWaitIconImageMarkup } = require("%scripts/queue/waitIconImage.nut")
let { getCurEsUnitTypesMask } = require("%scripts/queue/curEsUnitTypesMask.nut")
let { move_mouse_on_child_by_value } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getCountryIcon } = require("%scripts/options/countryFlagsPreset.nut")
let { getClusterShortName, isClusterUnstable
} = require("%scripts/onlineInfo/clustersManagement.nut")
let { isEventForClan, getCustomViewCountryData } = require("%scripts/events/eventInfo.nut")
let { calcBattleRatingFromRank } = require("%appGlobals/ranks_common_shared.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")
let { MAX_COUNTRY_RANK } = require("%scripts/ranks.nut")
let { createQueueViewByCountries, updateQueueViewByCountries } = require("%scripts/queue/queueInfo/qiViewUtils.nut")
let { fillCountriesList } = require("%scripts/matchingRooms/fillCountriesList.nut")
let { isQueueActive, isQueuesEqual, findQueue, checkQueueType } = require("%scripts/queue/queueState.nut")
let { getQueueEvent, isClanQueue, getQueueCountry, getQueueClusters, getMyRankInQueue
} = require("%scripts/queue/queueInfo.nut")

dagui_propid_add_name_id("_queueTableGenCode")

local WAIT_TO_SHOW_CROSSPLAY_TIP_SEC_F = 120.0

gui_handlers.QueueTable <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/queue/queueTable.blk"

  queueMask = QUEUE_TYPE_BIT.UNKNOWN

  isCrossPlayTipShowed = false

  build_IA_shop_filters = false

  function initScreen() {
    this.setCurQueue(findQueue({}, this.queueMask))
    this.updateWaitTime()

    this.scene.findObject("queue_players_total").show(!isMeNewbie())

    this.scene.findObject("queue_table_timer").setUserData(this)
    this.scene.findObject("countries_header").setValue($"{loc("available_countries")}:")
    this.updateTip()
  }

  curQueue = null
  function getCurQueue() { return this.curQueue }
  function setCurQueue(value) {
    if (isQueuesEqual(this.curQueue, value))
      return

    this.curQueue = value
    this.fullUpdate()
  }

  function fullUpdate() {
    this.build_IA_shop_filters = true
    this.fillQueueInfo()
    this.updateScene()
  }

  function getCurCountry() {
    let queue = this.getCurQueue()
    return queue != null ? getQueueCountry(queue) : ""
  }

  function goBack() {
    this.setShowQueueTable(false)
  }

  function onUpdate(_obj, _dt) {
    if (!this.scene.isVisible())
      return

    this.updateWaitTime()
  }

  function getShowQueueTable() { return this.scene.isVisible() }
  function setShowQueueTable(value) {
    if (value && this.scene.isVisible())
      return

    if (value) { 
      this.updateTip()
      this.updateQueueWaitIconImage()
    }

    broadcastEvent("RequestToggleVisibility", { target = this.scene, visible = value })
  }

  function updateTip() {
    let tipObj = this.scene.findObject("queue_tip")
    if (!tipObj?.isValid())
      return

    tipObj.setValue(getCurEsUnitTypesMask())
  }

  function fillQueueInfo() {
    local txtPlayersWaiting = ""
    let queueStats = this.getCurQueue()?.queueStats
    if (queueStats) {
      let playersOfMyRank = queueStats?.isClanStats
        ? queueStats.getClansCount()
        : queueStats.getPlayersCountOfMyRank()
      txtPlayersWaiting = loc("ui/colon").concat(loc("multiplayer/playersInQueue"), playersOfMyRank)
    }
    this.scene.findObject("queue_players_total").setValue(txtPlayersWaiting)

    let params = this.getCurQueue().params
    let hasMrank = "mrank" in params
    this.scene.findObject("battle_rating").setValue(
      hasMrank ? format("%.1f", calcBattleRatingFromRank(params.mrank)) : "")
    this.scene.findObject("battle_rating_label").setValue(
      hasMrank ? loc("shop/battle_rating") : "")

    this.updateAvailableCountries()
  }

  function updateWaitTime() {
    local txtWaitTime = ""
    let waitTime = this.getCurQueue()?.getActiveTime() ?? 0
    if (waitTime > 0) {
      let minutes = time.secondsToMinutes(waitTime).tointeger()
      let seconds = waitTime - time.minutesToSeconds(minutes)
      txtWaitTime = format("%d:%02d", minutes, seconds)
    }

    this.scene.findObject("msgText").setValue(txtWaitTime)

    if (!this.isCrossPlayTipShowed
      && waitTime >= WAIT_TO_SHOW_CROSSPLAY_TIP_SEC_F
      && !crossplayModule.isCrossPlayEnabled()) {
      this.scene.findObject("crossplay_tip").show(true)
      this.isCrossPlayTipShowed = true
    }
  }

  function updateAvailableCountries() {
    let queue = this.getCurQueue()
    let availCountriesObj = this.scene.findObject("available_countries")

    if (!queue) {
      availCountriesObj.show(false)
      return
    }

    let event = events.getEvent(queue.name)
    let countriesList = events.getAvailableCountriesByEvent(event)

    if (countriesList.len() == 0)
      availCountriesObj.show(false)
    else {
      let customViewCountryData = getCustomViewCountryData(event)
      let blk = handyman.renderCached("%gui/countriesList.tpl", {
        countries = countriesList.map(@(countryName) {
          countryName
          countryIcon = getCountryIcon(customViewCountryData?[countryName].icon ?? countryName)
        })
      })
      let iconsObj = availCountriesObj.findObject("countries_icons")
      availCountriesObj.show(true)
      this.guiScene.replaceContentFromText(iconsObj, blk, blk.len(), this)
    }
  }

  function updateScene() {
    if (!checkObj(this.scene))
      return

    let queueTblObj = this.scene.findObject("queue_table")
    if (!checkObj(queueTblObj))
      return

    let showQueueTbl = isQueueActive(this.getCurQueue())
    this.setShowQueueTable(showQueueTbl)
    if (!showQueueTbl)
      return

    this.fillQueueTable()
  }

  function onClustersTabChange() {
    this.updateTabContent()
  }

  function updateTabs(queue) {
    if (!queue || !this.build_IA_shop_filters)
      return

    let clustersListObj = this.scene.findObject("ia_table_clusters_list")
    if (!checkObj(clustersListObj))
      return

    this.build_IA_shop_filters = false

    let data = this.createClustersFiltersData(queue)
    this.guiScene.replaceContentFromText(clustersListObj, data, data.len(), this)
    clustersListObj.setValue(0)
  }

  function createClustersFiltersData(queue) {
    let view = { tabs = [] }
    view.tabs.append({ tabName = "#multiplayer/currentWaitTime" })

    if (isClanQueue(queue))
      view.tabs.append({ tabName = "#multiplayer/currentPlayers" })
    else {
      foreach (clusterName in getQueueClusters(queue)) {
        let isUnstable = isClusterUnstable(clusterName)
        view.tabs.append({
          id = clusterName
          tabName = getClusterShortName(clusterName)
          tabImage = isUnstable ? "#ui/gameuiskin#urgent_warning.svg" : null
          tabImageParam = isUnstable ? "isLeftAligned:t='yes';isColoredImg:t='yes';wink:t='veryfast';" : null
        })
      }
    }

    return handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
  }

  function fillQueueTable() {
    let queue = this.getCurQueue()
    this.updateTabs(queue)

    let event = getQueueEvent(queue)
    if (!event)
      return

    let nestObj = this.scene.findObject("ia_tooltip")
    if (!checkObj(nestObj))
      return

    let genCode = $"{event.name}_{getQueueCountry(queue)}_{getMyRankInQueue(queue)}"
    if (nestObj?._queueTableGenCode == genCode) {
      this.updateTabContent()
      return
    }
    nestObj._queueTableGenCode = genCode

    if (isEventForClan(event))
      this.createQueueTableClan(nestObj)
    else
      createQueueViewByCountries(nestObj.findObject("ia_tooltip_table"), queue, event)

    
    this.updateTabContent()

    let obj = this.getObj("inQueue-topmenu-text")
    if (obj != null)
      obj.wink = (this.getCurQueue() != null) ? "yes" : "no"
  }

  function createQueueTableClan(nestObj) {
    let queueBoxObj = nestObj.findObject("queue_box_container")
    this.guiScene.replaceContent(queueBoxObj, "%gui/events/eventQueue.blk", this)

    foreach (team in events.getSidesList())
      queueBoxObj.findObject($"{team}_block").show(team == Team.A) 
  }

  function updateTabContent() {
    if (!checkObj(this.scene))
      return
    let queue = this.getCurQueue()
    if (!queue)
      return

    let clustersListBoxObj = this.scene.findObject("ia_table_clusters_list")
    if (!checkObj(clustersListBoxObj))
      return

    let value = max(0, clustersListBoxObj.getValue())
    let timerObj = this.scene.findObject("waiting_time")
    let tableObj = this.scene.findObject("ia_tooltip_table")
    let clanTableObj = this.scene.findObject("queue_box_container")
    let isClanQueueValue = isClanQueue(queue)
    let isQueueTableVisible = value > 0
    timerObj.show(!isQueueTableVisible)
    tableObj.show(isQueueTableVisible && !isClanQueueValue)
    clanTableObj.show(isQueueTableVisible && isClanQueueValue)

    local curCluster = null
    if (!isClanQueueValue) {
      let listBoxObjItemObj = clustersListBoxObj.childrenCount() > value
        ? clustersListBoxObj.getChild(value)
        : null
      curCluster = listBoxObjItemObj?.id
    }
    let needClusterWarning = isQueueTableVisible && curCluster != null && isClusterUnstable(curCluster)
    let unstableClusterWarnObj = this.scene.findObject("unstable_cluster_warning")
    unstableClusterWarnObj.wink = needClusterWarning ? "fast" : "no"
    unstableClusterWarnObj.show(needClusterWarning)

    if (!isQueueTableVisible)
      return

    if (isClanQueueValue)
      this.updateClanQueueTable()
    else if (curCluster != null)
      updateQueueViewByCountries(tableObj, this.getCurQueue(), curCluster)
  }

  function updateClanQueueTable() {
    let tblObj = this.scene.findObject("queue_box")
    if (!checkObj(tblObj))
      return
    tblObj.show(true)

    let queue = this.getCurQueue()
    let queueStats = queue && queue.queueStats
    if (!queueStats)
      return

    let statsObj = tblObj.findObject($"{Team.A}_block")
    if (!statsObj?.isValid())
      return

    let event = getQueueEvent(queue)
    let teamData = events.getTeamData(event, Team.A)
    let isShowTeamData = teamData && teamData.len()
    statsObj.show(isShowTeamData)
    if (!isShowTeamData)
      return

    statsObj.bgTeamColor = "any"
    statsObj.findObject("team_name").setValue("")
    statsObj.findObject("players_count").setValue(
      loc("ui/colon").concat(loc("events/clans_count"), queueStats.getClansCount()))

    fillCountriesList(statsObj.findObject("countries"), events.getCountries(teamData),
      getCustomViewCountryData(event))

    let queueTableObj = statsObj.findObject("table_queue_stat")
    if (!queueTableObj?.isValid())
      return
    let tableMarkup = this.getClanQueueTableMarkup(queueStats)
    this.guiScene.replaceContentFromText(queueTableObj, tableMarkup, tableMarkup.len(), this)
  }

  
  function getClanQueueTableMarkup(queueStats) {
    let totalClans = queueStats.getClansCount()
    if (!totalClans)
      return ""

    local res = this.buildQueueStatsHeader()
    let rowParams = "inactive:t='yes'; commonTextColor:t='yes';"

    let myClanQueueTable = queueStats.getMyClanQueueTable()
    if (myClanQueueTable) {
      let headerData = [{
        text = loc("multiplayer/playersInYourClan")
        width = "0.1@sf"
        textRawParam = "pare-text:t='no'"
      }]
      res = "".concat(res, buildTableRow("", headerData, null, rowParams, "0"))

      let rowData = this.buildQueueStatsRowData(myClanQueueTable)
      res = "".concat(res, buildTableRow("", rowData, null, rowParams, "0"))
    }

    let headerData = [{
      text = loc("multiplayer/clansInQueue")
      width = "0.1@sf"
      textRawParam = "pare-text:t='no'"
    }]
    res = "".concat(res, buildTableRow("", headerData, null, rowParams, "0"))

    let rowData = this.buildQueueStatsRowData(queueStats.getClansQueueTable())
    res = "".concat(res, buildTableRow("", rowData, null, rowParams, "0"))
    return res
  }

  
  function buildQueueStatsRowData(queueStatData, clusterNameLoc = "") {
    let params = []
    params.append({
                    text = clusterNameLoc
                    tdalign = "center"
                 })

    for (local i = 1; i <= MAX_COUNTRY_RANK; i++) {
      params.append({
        text = getTblValue(i.tostring(), queueStatData, 0).tostring()
        tdalign = "center"
      })
    }
    return params
  }

  
  function buildQueueStatsHeader() {
    let headerData = []
    for (local i = 0; i <= MAX_COUNTRY_RANK; i++) {
      headerData.append({
        text = get_roman_numeral(i)
        tdalign = "center"
      })
    }
    return buildTableRow("", headerData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
  }

  
  
  

  function onEventQueueChangeState(p) {
    let queue = p?.queue
    if (!checkQueueType(queue, this.queueMask))
      return

    if (isQueuesEqual(queue, this.getCurQueue())) {
      this.fillQueueInfo()
      this.updateScene()
      return
    }

    if (isQueueActive(this.getCurQueue()))
      return 

    this.setCurQueue(queue)
  }

  function onEventQueueInfoUpdated(_params) {
    if (!checkObj(this.scene) || !this.getCurQueue())
      return

    this.fillQueueInfo()
    this.updateScene()
  }

  function onEventMyStatsUpdated(_params) {
    this.updateScene()
  }

  function onEventSquadStatusChanged(_params) {
    this.updateScene()
  }

  function onEventGamercardDrawerOpened(params) {
    let target = params.target
    if (target != null && target.id == this.scene.id)
      move_mouse_on_child_by_value(this.getObj("ia_table_clusters_list"))
  }

  function onEventShopWndSwitched(_params) {
    this.updateVisibility()
  }

  function updateVisibility() {
    this.scene.show(!topMenuShopActive.value)
  }

  function updateQueueWaitIconImage() {
    if (!checkObj(this.scene))
      return
    let obj = this.scene.findObject("queue_wait_icon_block")
    if (!(obj?.isValid() ?? false))
      return

    let markup = getQueueWaitIconImageMarkup()
    this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }

  onEventQueueStatsClusterAdded = @(_) this.fullUpdate()
}

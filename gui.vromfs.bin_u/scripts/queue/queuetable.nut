let { format } = require("string")
let time = require("%scripts/time.nut")
let crossplayModule = require("%scripts/social/crossplay.nut")
let { topMenuShopActive } = require("%scripts/mainmenu/topMenuStates.nut")
let QUEUE_TYPE_BIT = require("%scripts/queue/queueTypeBit.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")

::dagui_propid.add_name_id("_queueTableGenCode")

let FULL_CIRCLE_GRAD = 360
local WAIT_TO_SHOW_CROSSPLAY_TIP_SEC_F = 120.0

::gui_handlers.QueueTable <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/queue/queueTable.blk"

  queueMask = QUEUE_TYPE_BIT.UNKNOWN

  isCrossPlayTipShowed = false

  build_IA_shop_filters = false

  function initScreen()
  {
    setCurQueue(::queues.findQueue({}, queueMask))
    updateWaitTime()

    scene.findObject("queue_players_total").show(!::is_me_newbie())

    scene.findObject("queue_table_timer").setUserData(this)
    scene.findObject("countries_header").setValue(::loc("available_countries") + ":")
    updateTip()
  }

  curQueue = null
  function getCurQueue() { return curQueue }
  function setCurQueue(value)
  {
    if (::queues.isQueuesEqual(curQueue, value))
      return

    curQueue = value
    fullUpdate()
  }

  function fullUpdate()
  {
    build_IA_shop_filters = true
    fillQueueInfo()
    updateScene()
  }

  function getCurCountry()
  {
    let queue = getCurQueue()
    return queue != null ? ::queues.getQueueCountry(queue) : ""
  }

  function goBack()
  {
    setShowQueueTable(false)
  }

  function onUpdate(obj, dt)
  {
    if (!scene.isVisible())
      return

    updateWaitTime()
  }

  function getShowQueueTable() { return scene.isVisible() }
  function setShowQueueTable(value)
  {
    if (value && scene.isVisible())
      return

    if (value) // Queue wnd opening animation start
    {
      updateTip()
      updateQueueWaitIconImage()
    }

    ::broadcastEvent("RequestToggleVisibility", { target = this.scene, visible = value })
  }

  function updateTip()
  {
    let tipObj = getObj("queue_tip")
    if (!tipObj)
      return

    local esUnitTypes = getCurEsUnitTypesList(true)
    if (!esUnitTypes.len())
      esUnitTypes = getCurEsUnitTypesList(false)

    local mask = 0
    foreach(esUnitType in esUnitTypes)
      mask = mask | (1 << esUnitType)
    tipObj.setValue(mask)
  }

  function fillQueueInfo()
  {
    local txtPlayersWaiting = ""
    let queueStats = getCurQueue()?.queueStats
    if (queueStats)
    {
      let playersOfMyRank = queueStats?.isClanStats
        ? queueStats.getClansCount()
        : queueStats.getPlayersCountOfMyRank()
      txtPlayersWaiting = ::loc("multiplayer/playersInQueue") + ::loc("ui/colon") + playersOfMyRank
    }
    scene.findObject("queue_players_total").setValue(txtPlayersWaiting)

    let params = getCurQueue().params
    let hasMrank = "mrank" in params
    scene.findObject("battle_rating").setValue(
      hasMrank ? format("%.1f", ::calc_battle_rating_from_rank(params.mrank)) : "")
    scene.findObject("battle_rating_label").setValue(
      hasMrank ? ::loc("shop/battle_rating") : "")

    updateAvailableCountries()
  }

  function updateWaitTime()
  {
    local txtWaitTime = ""
    let waitTime = getCurQueue()?.getActiveTime() ?? 0
    if (waitTime > 0)
    {
      let minutes = time.secondsToMinutes(waitTime).tointeger()
      let seconds = waitTime - time.minutesToSeconds(minutes)
      txtWaitTime = format("%d:%02d", minutes, seconds)
    }

    scene.findObject("msgText").setValue(txtWaitTime)

    if (!isCrossPlayTipShowed
      && waitTime >= WAIT_TO_SHOW_CROSSPLAY_TIP_SEC_F
      && !crossplayModule.isCrossPlayEnabled())
    {
      scene.findObject("crossplay_tip").show(true)
      isCrossPlayTipShowed = true
    }
  }

  function updateAvailableCountries()
  {
    let queue = getCurQueue()
    let availCountriesObj = scene.findObject("available_countries")

    if (!queue)
    {
      availCountriesObj.show(false)
      return
    }

    let event = ::events.getEvent(queue.name)
    let countriesList = ::events.getAvailableCountriesByEvent(event)

    if (countriesList.len() == 0)
      availCountriesObj.show(false)
    else
    {
      let blk = ::handyman.renderCached("%gui/countriesList",
                                          {
                                            countries = (@(countriesList) function () {
                                              let res = []
                                              foreach (country in countriesList)
                                                res.append({
                                                  countryName = country
                                                  countryIcon = ::get_country_icon(country)
                                                })
                                              return res
                                            })(countriesList)
                                          })

      let iconsObj = availCountriesObj.findObject("countries_icons")
      availCountriesObj.show(true)
      guiScene.replaceContentFromText(iconsObj, blk, blk.len(), this)
    }
  }

  function updateScene()
  {
    if (!::checkObj(scene))
      return

    let queueTblObj = scene.findObject("queue_table")
    if (!::checkObj(queueTblObj))
      return

    let showQueueTbl = ::queues.isQueueActive(getCurQueue())
    setShowQueueTable(showQueueTbl)
    if (!showQueueTbl)
      return

    fillQueueTable()
  }

  function onClustersTabChange()
  {
    updateTabContent()
  }

  function updateTabs(queue)
  {
    if (!queue || !build_IA_shop_filters)
      return

    let clustersListObj = scene.findObject("ia_table_clusters_list")
    if (!::checkObj(clustersListObj))
      return

    build_IA_shop_filters = false

    let data = createClustersFiltersData(queue)
    guiScene.replaceContentFromText(clustersListObj, data, data.len(), this)
    clustersListObj.setValue(0)
  }

  function createClustersFiltersData(queue)
  {
    let view = { tabs = [] }
    view.tabs.append({ tabName = "#multiplayer/currentWaitTime" })

    if (::queues.isClanQueue(queue))
      view.tabs.append({ tabName = "#multiplayer/currentPlayers" })
    else
    {
      foreach (clusterName in ::queues.getQueueClusters(queue)) {
        let isUnstable = ::g_clusters.isClusterUnstable(clusterName)
        view.tabs.append({
          id = clusterName
          tabName = ::g_clusters.getClusterLocName(clusterName)
          tabImage = isUnstable ? "#ui/gameuiskin#urgent_warning.svg" : null
          tabImageParam = isUnstable ? "isLeftAligned:t='yes';isColoredImg:t='yes';wink:t='veryfast';" : null
        })
      }
    }

    return ::handyman.renderCached("%gui/frameHeaderTabs", view)
  }

  function fillQueueTable()
  {
    let queue = getCurQueue()
    updateTabs(queue)

    let event = ::queues.getQueueEvent(queue)
    if (!event)
      return

    let nestObj = scene.findObject("ia_tooltip")
    if (!::checkObj(nestObj))
      return

    let genCode = event.name + "_" + ::queues.getQueueCountry(queue) + "_" + ::queues.getMyRankInQueue(queue)
    if (nestObj?._queueTableGenCode == genCode)
    {
      updateTabContent()
      return
    }
    nestObj._queueTableGenCode = genCode

    if (::events.isEventForClan(event))
      createQueueTableClan(nestObj)
    else
      ::g_qi_view_utils.createViewByCountries(nestObj.findObject("ia_tooltip_table"), queue, event)

    // Forces table to refill.
    updateTabContent()

    let obj = getObj("inQueue-topmenu-text")
    if (obj != null)
      obj.wink = (getCurQueue() != null) ? "yes" : "no"
  }

  function createQueueTableClan(nestObj)
  {
    let queueBoxObj = nestObj.findObject("queue_box_container")
    guiScene.replaceContent(queueBoxObj, "%gui/events/eventQueue.blk", this)

    foreach(team in ::events.getSidesList())
      queueBoxObj.findObject(team + "_block").show(team == Team.A) //clan queue always symmetric
  }

  function updateTabContent()
  {
    if (!::checkObj(scene))
      return
    let queue = getCurQueue()
    if (!queue)
      return

    let clustersListBoxObj = scene.findObject("ia_table_clusters_list")
    if (!::checkObj(clustersListBoxObj))
      return

    let value = max(0, clustersListBoxObj.getValue())
    let timerObj = scene.findObject("waiting_time")
    let tableObj = scene.findObject("ia_tooltip_table")
    let clanTableObj = scene.findObject("queue_box_container")
    let isClanQueue = ::queues.isClanQueue(queue)
    let isQueueTableVisible = value > 0
    timerObj.show(!isQueueTableVisible)
    tableObj.show(isQueueTableVisible && !isClanQueue)
    clanTableObj.show(isQueueTableVisible && isClanQueue)

    local curCluster = null
    if (!isClanQueue)
    {
      let listBoxObjItemObj = clustersListBoxObj.childrenCount() > value
        ? clustersListBoxObj.getChild(value)
        : null
      curCluster = listBoxObjItemObj?.id
    }
    let needClusterWarning = isQueueTableVisible && curCluster != null && ::g_clusters.isClusterUnstable(curCluster)
    let unstableClusterWarnObj = scene.findObject("unstable_cluster_warning")
    unstableClusterWarnObj.wink = needClusterWarning ? "fast" : "no"
    unstableClusterWarnObj.show(needClusterWarning)

    if (!isQueueTableVisible)
      return

    if (isClanQueue)
      updateClanQueueTable()
    else
      if (curCluster != null)
        ::g_qi_view_utils.updateViewByCountries(tableObj, getCurQueue(), curCluster)
  }

  function updateClanQueueTable()
  {
    let tblObj = scene.findObject("queue_box")
    if (!::checkObj(tblObj))
      return
    tblObj.show(true)

    let queue = getCurQueue()
    let queueStats = queue && queue.queueStats
    if (!queueStats)
      return

    let statsObj = tblObj.findObject(Team.A + "_block")
    let teamData = ::events.getTeamData(::queues.getQueueEvent(queue), Team.A)
    let playersCountText = ::loc("events/clans_count") + ::loc("ui/colon") + queueStats.getClansCount()
    let tableMarkup = getClanQueueTableMarkup(queueStats)

    fillQueueTeam(statsObj, teamData, tableMarkup, playersCountText)
  }

  //!!FIX ME copypaste from events handler
  function fillQueueTeam(teamObj, teamData, tableMarkup, playersCountText , teamColor = "any", teamName = "")
  {
    if (!checkObj(teamObj))
      return

    teamObj.bgTeamColor = teamColor
    teamObj.show(teamData && teamData.len())
    fillCountriesList(teamObj.findObject("countries"), ::events.getCountries(teamData))
    teamObj.findObject("team_name").setValue(teamName)
    teamObj.findObject("players_count").setValue(playersCountText)

    let queueTableObj = teamObj.findObject("table_queue_stat")
    if (!::checkObj(queueTableObj))
      return
    guiScene.replaceContentFromText(queueTableObj, tableMarkup, tableMarkup.len(), this)
  }

  //!!FIX ME copypaste from events handler
  function getClanQueueTableMarkup(queueStats)
  {
    let totalClans = queueStats.getClansCount()
    if (!totalClans)
      return ""

    local res = buildQueueStatsHeader()
    let rowParams = "inactive:t='yes'; commonTextColor:t='yes';"

    let myClanQueueTable = queueStats.getMyClanQueueTable()
    if (myClanQueueTable)
    {
      let headerData = [{
        text = ::loc("multiplayer/playersInYourClan")
        width = "0.1@sf"
        textRawParam = "pare-text:t='no'"
      }]
      res += ::buildTableRow("", headerData, null, rowParams, "0")

      let rowData = buildQueueStatsRowData(myClanQueueTable)
      res += ::buildTableRow("", rowData, null, rowParams, "0")
    }

    let headerData = [{
      text = ::loc("multiplayer/clansInQueue")
      width = "0.1@sf"
      textRawParam = "pare-text:t='no'"
    }]
    res += ::buildTableRow("", headerData, null, rowParams, "0")

    let rowData = buildQueueStatsRowData(queueStats.getClansQueueTable())
    res += ::buildTableRow("", rowData, null, rowParams, "0")
    return res
  }

  //!!FIX ME copypaste from events handler
  function buildQueueStatsRowData(queueStatData, clusterNameLoc = "")
  {
    let params = []
    params.append({
                    text = clusterNameLoc
                    tdalign = "center"
                 })

    for(local i = 1; i <= ::max_country_rank; i++)
    {
      params.append({
        text = ::getTblValue(i.tostring(), queueStatData, 0).tostring()
        tdalign = "center"
      })
    }
    return params
  }

  //!!FIX ME copypaste from events handler
  function buildQueueStatsHeader()
  {
    let headerData = []
    for(local i = 0; i <= ::max_country_rank; i++)
    {
      headerData.append({
        text = ::get_roman_numeral(i)
        tdalign = "center"
      })
    }
    return ::buildTableRow("", headerData, 0, "inactive:t='yes'; commonTextColor:t='yes';", "0")
  }

  //
  // Event handlers
  //

  function onEventQueueChangeState(p)
  {
    let queue = p?.queue
    if (!::queues.checkQueueType(queue, queueMask))
      return

    if (::queues.isQueuesEqual(queue, getCurQueue()))
    {
      fillQueueInfo()
      updateScene()
      return
    }

    if (::queues.isQueueActive(getCurQueue()))
      return //do not switch queue visual when current queue active.

    setCurQueue(queue)
  }

  function onEventQueueInfoUpdated(params)
  {
    if (!::checkObj(scene) || !getCurQueue())
      return

    fillQueueInfo()
    updateScene()
  }

  function onEventQueueClustersChanged(queue)
  {
    if (!::queues.isQueuesEqual(queue, getCurQueue()))
      return

    build_IA_shop_filters = true
    updateScene()
  }

  function onEventMyStatsUpdated(params)
  {
    updateScene()
  }

  function onEventSquadStatusChanged(params)
  {
    updateScene()
  }

  function onEventGamercardDrawerOpened(params)
  {
    let target = params.target
    if (target != null && target.id == scene.id)
      ::move_mouse_on_child_by_value(getObj("ia_table_clusters_list"))
  }

  function onEventShopWndSwitched(params)
  {
    updateVisibility()
  }

  function updateVisibility()
  {
    scene.show(!topMenuShopActive.value)
  }

  function getCurEsUnitTypesList(needRequiredOnly = false)
  {
    let gameModeId = ::game_mode_manager.getCurrentGameModeId()
    let gameMode = ::game_mode_manager.getGameModeById(gameModeId)
    return ::game_mode_manager._getUnitTypesByGameMode(gameMode, true, needRequiredOnly)
  }

  function updateQueueWaitIconImage()
  {
    if (!::check_obj(scene))
      return
    let obj = scene.findObject("queue_wait_icon_block")
    if (!::check_obj(obj))
      return

    let esUnitTypes = getCurEsUnitTypesList()
    let esUnitTypesOrder = [
      ::ES_UNIT_TYPE_SHIP
      ::ES_UNIT_TYPE_TANK
      ::ES_UNIT_TYPE_HELICOPTER
      ::ES_UNIT_TYPE_AIRCRAFT
    ]

    let view = { icons = [] }
    let rotationStart = ::math.rnd() % FULL_CIRCLE_GRAD
    foreach (esUnitType in esUnitTypesOrder)
      if (::isInArray(esUnitType, esUnitTypes))
        view.icons.append({
          unittag = unitTypes.getByEsUnitType(esUnitType).tag
          rotation = rotationStart
        })

    let circlesCount = view.icons.len()
    if (circlesCount)
      foreach (idx, icon in view.icons)
        icon.rotation = (rotationStart + idx * FULL_CIRCLE_GRAD / circlesCount) % FULL_CIRCLE_GRAD
    let markup = ::handyman.renderCached("%gui/queue/queueWaitingIcon", view)
    guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }
}

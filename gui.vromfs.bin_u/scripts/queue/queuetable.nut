local time = require("scripts/time.nut")
local crossplayModule = require("scripts/social/crossplay.nut")
local { topMenuShopActive } = require("scripts/mainmenu/topMenuStates.nut")
local QUEUE_TYPE_BIT = require("scripts/queue/queueTypeBit.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

::dagui_propid.add_name_id("_queueTableGenCode")

local FULL_CIRCLE_GRAD = 360
local WAIT_TO_SHOW_CROSSPLAY_TIP_SEC_F = 120.0

class ::gui_handlers.QueueTable extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/queue/queueTable.blk"

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
    local queue = getCurQueue()
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
    local tipObj = getObj("queue_tip")
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
    local queueStats = getCurQueue()?.queueStats
    if (queueStats)
    {
      local playersOfMyRank = queueStats?.isClanStats
        ? queueStats.getClansCount()
        : queueStats.getPlayersCountOfMyRank()
      txtPlayersWaiting = ::loc("multiplayer/playersInQueue") + ::loc("ui/colon") + playersOfMyRank
    }
    scene.findObject("queue_players_total").setValue(txtPlayersWaiting)

    local params = getCurQueue().params
    local hasMrank = "mrank" in params
    scene.findObject("battle_rating").setValue(
      hasMrank ? format("%.1f", ::calc_battle_rating_from_rank(params.mrank)) : "")
    scene.findObject("battle_rating_label").setValue(
      hasMrank ? ::loc("shop/battle_rating") : "")

    updateAvailableCountries()
  }

  function updateWaitTime()
  {
    local txtWaitTime = ""
    local waitTime = getCurQueue()?.getActiveTime() ?? 0
    if (waitTime > 0)
    {
      local minutes = time.secondsToMinutes(waitTime).tointeger()
      local seconds = waitTime - time.minutesToSeconds(minutes)
      txtWaitTime = ::format("%d:%02d", minutes, seconds)
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
    local queue = getCurQueue()
    local availCountriesObj = scene.findObject("available_countries")

    if (!queue)
    {
      availCountriesObj.show(false)
      return
    }

    local event = ::events.getEvent(queue.name)
    local countriesList = ::events.getAvailableCountriesByEvent(event)

    if (countriesList.len() == 0)
      availCountriesObj.show(false)
    else
    {
      local blk = ::handyman.renderCached("gui/countriesList",
                                          {
                                            countries = (@(countriesList) function () {
                                              local res = []
                                              foreach (country in countriesList)
                                                res.append({
                                                  countryName = country
                                                  countryIcon = ::get_country_icon(country)
                                                })
                                              return res
                                            })(countriesList)
                                          })

      local iconsObj = availCountriesObj.findObject("countries_icons")
      availCountriesObj.show(true)
      guiScene.replaceContentFromText(iconsObj, blk, blk.len(), this)
    }
  }

  function updateScene()
  {
    if (!::checkObj(scene))
      return

    local queueTblObj = scene.findObject("queue_table")
    if (!::checkObj(queueTblObj))
      return

    local showQueueTbl = ::queues.isQueueActive(getCurQueue())
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

    local clustersListObj = scene.findObject("ia_table_clusters_list")
    if (!::checkObj(clustersListObj))
      return

    build_IA_shop_filters = false

    local data = createClustersFiltersData(queue)
    guiScene.replaceContentFromText(clustersListObj, data, data.len(), this)
    clustersListObj.setValue(0)
  }

  function createClustersFiltersData(queue)
  {
    local view = { tabs = [] }
    view.tabs.append({ tabName = "#multiplayer/currentWaitTime" })

    if (::queues.isClanQueue(queue))
      view.tabs.append({ tabName = "#multiplayer/currentPlayers" })
    else
    {
      foreach (clusterName in ::queues.getQueueClusters(queue))
        view.tabs.append({
          id = clusterName
          tabName = ::g_clusters.getClusterLocName(clusterName)
        })
    }

    return ::handyman.renderCached("gui/frameHeaderTabs", view)
  }

  function fillQueueTable()
  {
    local queue = getCurQueue()
    updateTabs(queue)

    local event = ::queues.getQueueEvent(queue)
    if (!event)
      return

    local nestObj = scene.findObject("ia_tooltip")
    if (!::checkObj(nestObj))
      return

    local genCode = event.name + "_" + ::queues.getQueueCountry(queue) + "_" + ::queues.getMyRankInQueue(queue)
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

    local obj = getObj("inQueue-topmenu-text")
    if (obj != null)
      obj.wink = (getCurQueue() != null) ? "yes" : "no"
  }

  function createQueueTableClan(nestObj)
  {
    local queueBoxObj = nestObj.findObject("queue_box_container")
    guiScene.replaceContent(queueBoxObj, "gui/events/eventQueue.blk", this)

    foreach(team in ::events.getSidesList())
      queueBoxObj.findObject(team + "_block").show(team == Team.A) //clan queue always symmetric
  }

  function updateTabContent()
  {
    if (!::checkObj(scene))
      return
    local queue = getCurQueue()
    if (!queue)
      return

    local clustersListBoxObj = scene.findObject("ia_table_clusters_list")
    if (!::checkObj(clustersListBoxObj))
      return

    local value = ::max(0, clustersListBoxObj.getValue())
    local timerObj = scene.findObject("waiting_time")
    local tableObj = scene.findObject("ia_tooltip_table")
    local clanTableObj = scene.findObject("queue_box_container")
    local isClanQueue = ::queues.isClanQueue(queue)
    local isQueueTableVisible = value > 0
    timerObj.show(!isQueueTableVisible)
    tableObj.show(isQueueTableVisible && !isClanQueue)
    clanTableObj.show(isQueueTableVisible && isClanQueue)
    if (!isQueueTableVisible)
      return

    if (isClanQueue)
      updateClanQueueTable()
    else
    {
      if (clustersListBoxObj.childrenCount() <= value)
        return

      local listBoxObjItemObj = clustersListBoxObj.getChild(value)
      local curCluster = listBoxObjItemObj.id
      ::g_qi_view_utils.updateViewByCountries(tableObj, getCurQueue(), curCluster)
    }
  }

  function updateClanQueueTable()
  {
    local tblObj = scene.findObject("queue_box")
    if (!::checkObj(tblObj))
      return
    tblObj.show(true)

    local queue = getCurQueue()
    local queueStats = queue && queue.queueStats
    if (!queueStats)
      return

    local statsObj = tblObj.findObject(Team.A + "_block")
    local teamData = ::events.getTeamData(::queues.getQueueEvent(queue), Team.A)
    local playersCountText = ::loc("events/clans_count") + ::loc("ui/colon") + queueStats.getClansCount()
    local tableMarkup = getClanQueueTableMarkup(queueStats)

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

    local queueTableObj = teamObj.findObject("table_queue_stat")
    if (!::checkObj(queueTableObj))
      return
    guiScene.replaceContentFromText(queueTableObj, tableMarkup, tableMarkup.len(), this)
  }

  //!!FIX ME copypaste from events handler
  function getClanQueueTableMarkup(queueStats)
  {
    local totalClans = queueStats.getClansCount()
    if (!totalClans)
      return ""

    local res = buildQueueStatsHeader()
    local rowParams = "inactive:t='yes'; commonTextColor:t='yes';"

    local myClanQueueTable = queueStats.getMyClanQueueTable()
    if (myClanQueueTable)
    {
      local headerData = [{
        text = ::loc("multiplayer/playersInYourClan")
        width = "0.1@sf"
        textRawParam = "pare-text:t='no'"
      }]
      res += ::buildTableRow("", headerData, null, rowParams, "0")

      local rowData = buildQueueStatsRowData(myClanQueueTable)
      res += ::buildTableRow("", rowData, null, rowParams, "0")
    }

    local headerData = [{
      text = ::loc("multiplayer/clansInQueue")
      width = "0.1@sf"
      textRawParam = "pare-text:t='no'"
    }]
    res += ::buildTableRow("", headerData, null, rowParams, "0")

    local rowData = buildQueueStatsRowData(queueStats.getClansQueueTable())
    res += ::buildTableRow("", rowData, null, rowParams, "0")
    return res
  }

  //!!FIX ME copypaste from events handler
  function buildQueueStatsRowData(queueStatData, clusterNameLoc = "")
  {
    local params = []
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
    local headerData = []
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
    local _queue = p?.queue
    if (!::queues.checkQueueType(_queue, queueMask))
      return

    if (::queues.isQueuesEqual(_queue, getCurQueue()))
    {
      fillQueueInfo()
      updateScene()
      return
    }

    if (::queues.isQueueActive(getCurQueue()))
      return //do not switch queue visual when current queue active.

    setCurQueue(_queue)
  }

  function onEventQueueInfoUpdated(params)
  {
    if (!::checkObj(scene) || !getCurQueue())
      return

    fillQueueInfo()
    updateScene()
  }

  function onEventQueueClustersChanged(_queue)
  {
    if (!::queues.isQueuesEqual(_queue, getCurQueue()))
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
    local target = params.target
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
    local gameModeId = ::game_mode_manager.getCurrentGameModeId()
    local gameMode = ::game_mode_manager.getGameModeById(gameModeId)
    return ::game_mode_manager._getUnitTypesByGameMode(gameMode, true, needRequiredOnly)
  }

  function updateQueueWaitIconImage()
  {
    if (!::check_obj(scene))
      return
    local obj = scene.findObject("queue_wait_icon_block")
    if (!::check_obj(obj))
      return

    local esUnitTypes = getCurEsUnitTypesList()
    local esUnitTypesOrder = [
      ::ES_UNIT_TYPE_SHIP
      ::ES_UNIT_TYPE_TANK
      ::ES_UNIT_TYPE_HELICOPTER
      ::ES_UNIT_TYPE_AIRCRAFT
    ]

    local view = { icons = [] }
    local rotationStart = ::math.rnd() % FULL_CIRCLE_GRAD
    foreach (esUnitType in esUnitTypesOrder)
      if (::isInArray(esUnitType, esUnitTypes))
        view.icons.append({
          unittag = unitTypes.getByEsUnitType(esUnitType).tag
          rotation = rotationStart
        })

    local circlesCount = view.icons.len()
    if (circlesCount)
      foreach (idx, icon in view.icons)
        icon.rotation = (rotationStart + idx * FULL_CIRCLE_GRAD / circlesCount) % FULL_CIRCLE_GRAD
    local markup = ::handyman.renderCached("gui/queue/queueWaitingIcon", view)
    guiScene.replaceContentFromText(obj, markup, markup.len(), this)
  }
}

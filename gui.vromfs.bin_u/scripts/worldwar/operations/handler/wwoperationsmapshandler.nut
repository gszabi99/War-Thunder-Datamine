let { format } = require("string")
let time = require("%scripts/time.nut")
let seenWWMapsAvailable = require("%scripts/seen/seenList.nut").get(SEEN.WW_MAPS_AVAILABLE)
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { getAllUnlocks, unlocksChapterName } = require("%scripts/worldWar/unlocks/wwUnlocks.nut")
let globalBattlesListData = require("%scripts/worldWar/operations/model/wwGlobalBattlesList.nut")
let { isMatchFilterMask } = require("%scripts/worldWar/handler/wwBattlesFilterMenu.nut")
let { getNearestMapToBattle, getMyClanOperation, getMapByName, isMyClanInQueue, isRecievedGlobalStatusMaps
} = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { refreshGlobalStatusData } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { addClanTagToNameInLeaderbord } = require("%scripts/leaderboard/leaderboardView.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { getUnlockLocName } = require("%scripts/unlocks/unlocksViewModule.nut")
let wwAnimBgLoad = require("%scripts/worldWar/wwAnimBg.nut")
let { addPopupOptList } = require("%scripts/popups/popupOptList.nut")

const MY_CLUSRTERS = "ww/clusters"

let WW_DAY_SEASON_OVER_NOTICE = "worldWar/seasonOverNotice/day"
local WW_SEASON_OVER_NOTICE_PERIOD_DAYS = 7

::dagui_propid.add_name_id("countryId")
::dagui_propid.add_name_id("mapId")

let hasOperationActive = @() !::g_world_war.isCurrentOperationFinished()

::gui_handlers.WwOperationsMapsHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName   = "%gui/worldWar/wwOperationsMaps.blk"
  shouldBlurSceneBgFn = needUseHangarDof
  handlerLocId = "mainmenu/btnWorldwar"

  needToOpenBattles = false
  autoOpenMapOperation = null

  mapsTbl = null

  selMap = null
  mapsListObj = null
  mapsListNestObj = null
  collapsedChapters = []
  descHandlerWeak = null
  topMenuHandlerWeak = null

  hasClanOperation = false
  hasRightsToQueueClan = false

  queuesJoinTime = 0

  isFillingList = false

  nearestAvailableMapToBattle = null
  isDeveloperMode = false
  mapDescrObj = null
  selCountryId = ""
  trophiesAmount = 0
  needCheckSeasonIsOverNotice = true //need check and show notice only once on init screen

  clusterOptionsSelector        = null
  clustersList                  = null
  isRequestCanceled             = false
  autoselectOperationTimeout    = 0

  function initScreen()
  {
    backSceneFunc = ::gui_start_mainmenu
    mapsTbl = {}
    mapsListObj = scene.findObject("maps_list")
    mapsListNestObj = this.showSceneBtn("operation_list", isDeveloperMode)

    topMenuHandlerWeak = ::gui_handlers.TopMenuButtonsHandler.create(
      scene.findObject("topmenu_menu_panel"),
      this,
      ::g_ww_top_menu_operation_map,
      scene.findObject("left_gc_panel_free_width")
    )
    registerSubHandler(topMenuHandlerWeak)

    foreach (timerObjId in [
        "ww_status_check_timer",  // periodic ww status updates check
        "queues_wait_timer",      // frequent queues wait time text update
        "begin_map_wait_timer",    // frequent map begin wait time text update
        "global_battles_update_timer" // update global battles list for battle buttons status updated
      ])
    {
      let timerObj = scene.findObject(timerObjId)
      if (timerObj)
        timerObj.setUserData(this)
    }

    autoselectOperationTimeout = ::g_world_war.getWWConfigurableValue(
      "autoselectOperationTimeoutSec", 10) * 1000
    loadAndCheckMyClusters()
    clusterOptionsSelector = createClustersList()
    updateClustersTxt()

    reinitScreen()
    ::enableHangarControls(true)

    if (needToOpenBattles)
      onStart()
    else if (autoOpenMapOperation)
      openOperationsListByMap(autoOpenMapOperation)
    checkSeasonIsOverNotice()
  }

  function reinitScreen()
  {
    hasClanOperation = getMyClanOperation() != null
    hasRightsToQueueClan = ::g_clans.hasRightsToQueueWWar()

    collectMaps()
    findMapForSelection()
    wwAnimBgLoad(selMap?.name)
    updateRewardsPanel()
    onClansQueue()
  }

  function collectMaps()
  {
    foreach (mapId, map in ::g_ww_global_status_type.MAPS.getList())
      if (map.isVisible())
        mapsTbl[mapId] <- map
  }

  function findMapForSelection()
  {
    let priorityConfigMapsArray = []
    foreach(map in mapsTbl) {
      let changeStateTime = map.getChangeStateTime() - ::get_charserver_time_sec()
      priorityConfigMapsArray.append({
        hasActiveOperations = map.getOpGroup().hasActiveOperations()
        isActive = map.isActive()
        needCheckStateTime = changeStateTime > 0
        changeStateTime = changeStateTime
        map = map
      })
    }

    priorityConfigMapsArray.sort(@(a, b) b.hasActiveOperations <=> a.hasActiveOperations
      || b.isActive <=> a.isActive
      || b.needCheckStateTime <=> a.needCheckStateTime
      || a.changeStateTime <=> b.changeStateTime)

    let bestMap = priorityConfigMapsArray?[0]
    selMap = bestMap != null
      && (bestMap.hasActiveOperations || bestMap.isActive || bestMap.changeStateTime > 0)
        ? bestMap.map
        : null
  }

  function fillMapsList()
  {
    let chaptersList = []
    let mapsByChapter = {}
    foreach (mapId, map in mapsTbl)
    {
      let chapterId = map.getChapterId()
      let chapterObjId = getChapterObjId(map)

      if (!(chapterId in mapsByChapter))
      {
        let title = map.getChapterText()
        let weight = chapterId == "" ? 0 : 1
        let view = {
          id = chapterObjId
          itemTag = "ww_map_item"
          itemText = title
          itemClass = "header"
          isCollapsable = true
        }

        if (map.isDebugChapter())
          collapsedChapters.append(chapterObjId)

        let mapsList = []
        chaptersList.append({ weight = weight, title = title, view = view, mapsList = mapsList })
        mapsByChapter[chapterId] <- mapsList
      }

      let title = map.getNameText()
      let weight = 1
      let view = {
        id = mapId
        itemTag = "ww_map_item"
        itemIcon = map.getOpGroup().isMyClanParticipate() ? ::g_world_war.myClanParticipateIcon : null
        itemText = title
        hasWaitAnim = true
        isActive = map.isActive()
        unseenIcon = map.isAnnounceAndNotDebug() && bhvUnseen.makeConfigStr(SEEN.WW_MAPS_AVAILABLE, mapId)
      }
      mapsByChapter[chapterId].append({ weight = weight, title = title, view = view, map = map })
    }

    let sortFunc = function(a, b)
    {
      if (a.weight != b.weight)
        return a.weight > b.weight ? -1 : 1
      if (a.title != b.title)
        return a.title < b.title ? -1 : 1
      return 0
    }

    local selIdx = -1
    let view = {
      items = []
      isCreateOperationMode = true
    }

    chaptersList.sort(sortFunc)
    foreach (c in chaptersList)
    {
      view.items.append(c.view)
      c.mapsList.sort(sortFunc)
      foreach (m in c.mapsList)
      {
        view.items.append(m.view)
        if (m.map.isEqual(selMap))
          selIdx = view.items.len() - 1
      }
    }

    if (selIdx == -1 && view.items.len())
      selIdx = 0

    isFillingList = true

    let markup = ::handyman.renderCached("%gui/worldWar/wwOperationsMapsItemsList", view)
    guiScene.replaceContentFromText(mapsListObj, markup, markup.len(), this)

    selMap = null //force refresh description
    if (selIdx >= 0)
      mapsListObj.setValue(selIdx)
    else
      onItemSelect()

    foreach (id in collapsedChapters)
      if (!selMap || getChapterObjId(selMap) != id)
        onCollapse(mapsListObj.findObject("btn_" + id))

    isFillingList = false
  }

  function fillTrophyList()
  {
    let res = []
    let trophiesBlk = ::g_world_war.getSetting("dailyTrophies", ::DataBlock())
    let reqFeatureId = trophiesBlk?.reqFeature
    if (reqFeatureId && !::has_feature(reqFeatureId))
      return res

    trophiesAmount = trophiesBlk.blockCount()
    if (!trophiesAmount)
      return res

    let updStatsText = time.buildTimeStr(time.getUtcMidnight(), false, false)
    let curDay = time.getUtcDays() - time.DAYS_TO_YEAR_1970 + 1
    let trophiesProgress = ::get_es_custom_blk(-1)?.customClientData
    for (local i = 0; i < trophiesAmount; i++)
    {
      let trophy = trophiesBlk.getBlock(i)
      let trophyId = trophy?.itemName || trophy?.trophyName || trophy?.mainTrophyId
      let trophyItem = ::ItemsManager.findItemById(trophyId)
      if (!trophyItem)
        continue

      let progressDay = trophiesProgress?[trophy.getBlockName() + "Day"]
      let isActualProgressData = progressDay ? progressDay == curDay : false

      let progressCurValue = isActualProgressData ?
        trophiesProgress?[trophy?.progressParamName] ?? 0 : 0
      let progressMaxValue = trophy?.rewardedParamValue ?? 0
      let isProgressReached = progressCurValue >= progressMaxValue
      let progressText = ::loc("ui/parentheses",
        { text = $"{min(progressCurValue, progressMaxValue)}/{progressMaxValue}"})

      res.append({
        trophyDesc = $"{getTrophyDesc(trophy)} {progressText}"
        status = isProgressReached ? "received" : ""
        descTooltipText = getTrophyTooltip(trophy, updStatsText)
        iconTooltipText = getTrophyTooltip(trophiesBlk, updStatsText)
        rewardImage = trophyItem.getIcon()
        isTrophy = true
      })
    }
    return res
  }

  function fillUnlocksList()
  {
    let res = []
    let unlocksArray = getAllUnlocks()
    foreach (blk in unlocksArray)
    {
      let unlConf = ::build_conditions_config(blk)
      let mainCond = ::UnlockConditions.getMainProgressCondition(unlConf.conditions)
      let imgConf = ::g_unlock_view.getUnlockImageConfig(unlConf)
      let progressTxt = ::UnlockConditions._genMainConditionText(
        mainCond, unlConf.curVal, unlConf.maxVal, {isProgressTextOnly = true})
      let isComplete = ::g_unlocks.isUnlockComplete(unlConf)
      res.append({
        descTooltipText = unlConf.locId != "" ? getUnlockLocName(unlConf)
          : ::get_unlock_name_text(unlConf.unlockType, unlConf.id)
        progressTxt = progressTxt
        rewardImage = ::LayersIcon.getIconData(
          imgConf.style,
          imgConf.image,
          imgConf.ratio,
          null,
          imgConf.params
        )
        status = isComplete ? "received" : ""
      })
    }
    return res
  }

  function fillRewards(rewards)
  {
    let rewardsObj = scene.findObject("wwRewards")
    if (!rewardsObj?.isValid())
      return

    let data = ::handyman.renderCached("%gui/worldWar/wwRewards", {wwRewards = rewards})
    guiScene.replaceContentFromText(rewardsObj, data, data.len(), this)
  }

  getTrophyLocId = @(blk) blk?.locId ?? ("worldwar/" + blk.getBlockName())
  getTrophyDesc = @(blk) ::loc(getTrophyLocId(blk))
  getTrophyTooltip = @(blk, timeText) ::loc(getTrophyLocId(blk) + "/desc", {time = timeText})

  onEventItemsShopUpdate = @(p) updateRewardsPanel()
  onEventWWUnlocksCacheInvalidate = @(p) updateRewardsPanel()

  function refreshSelMap()
  {
    let mapObj = getSelectedMapObj()
    if (!::check_obj(mapObj))
      return false

    let isHeader = isMapObjChapter(mapObj)
    let newMap = isHeader ? null : getMapByName(mapObj?.id)
    if (newMap == selMap)
      return false

    local isChanged = !newMap || !selMap || !selMap.isEqual(newMap)
    selMap = newMap
    return isChanged
  }

  //operation select
  _wasSelectedOnce = false
  function onItemSelect()
  {
    let isSelChanged = refreshSelMap()

    if (!isSelChanged && _wasSelectedOnce)
      return updateButtons()

    _wasSelectedOnce = true

    updateUnseen()
    updateDescription()
    updateButtons()
    wwAnimBgLoad(selMap?.name)
  }

  function getSelectedMapObj()
  {
    if (!::check_obj(mapsListObj))
      return null

    let value = mapsListObj.getValue()
    return value >= 0 ? mapsListObj.getChild(value) : null
  }

  function getSelectedMapEditBtnText(mapObj)
  {
    if (!::check_obj(mapObj))
      return ""

    if (isMapObjChapter(mapObj))
      return mapObj?.collapsed == "yes"
        ? ::loc("mainmenu/btnExpand")
        : ::loc("mainmenu/btnCollapse")

    return ::loc("options/arcadeCountry")
  }

  function onMapAction(obj)
  {
    let mapObj = getSelectedMapObj()
    if (!::check_obj(mapObj))
      return

    if (isMapObjChapter(mapObj))
      onCollapse(mapObj)
    else if (mapObj?.selected == "yes")
      onSelectCountriesBlock()
  }

  function onSelectCountriesBlock()
  {
    let mapObj = getSelectedMapObj()
    if (!::check_obj(mapObj) || isMapObjChapter(mapObj))
      return

    onOperationListSwitch()
  }

  isMapObjChapter = @(obj) !!obj?.collapse_header
  canEditMapCountries = @(obj) ::check_obj(obj) && obj.isVisible() && obj.isEnabled()

  function onCollapse(obj)
  {
    if (!::check_obj(obj))
      return
    let itemObj = isMapObjChapter(obj) ? obj : obj.getParent()
    let listObj = ::check_obj(itemObj) ? itemObj.getParent() : null
    if (!::check_obj(listObj) || !isMapObjChapter(itemObj))
      return

    itemObj.collapsing = "yes"
    let isShow = itemObj?.collapsed == "yes"
    let listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++)
    {
      let child = listObj.getChild(i)
      if (!found)
      {
        if (child?.collapsing == "yes")
        {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else
      {
        if (isMapObjChapter(child))
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect || !selMap)
    {
      let indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes)
      {
        let child = listObj.getChild(idx)
        if (!isMapObjChapter(child) && child.isEnabled())
        {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }

    if (collapsedChapters && !::u.isEmpty(itemObj?.id))
    {
      let idx = ::find_in_array(collapsedChapters, itemObj.id)
      if (isShow && idx != -1)
        collapsedChapters.remove(idx)
      else if (!isShow && idx == -1)
        collapsedChapters.append(itemObj.id)
    }

    if (isShow)
      updateQueueElementsInList()
  }

  function onTimerStatusCheck(obj, dt)
  {
    refreshGlobalStatusData()
    if (selMap != null && !selMap.hasValidStatus())
      onSelectedMapInvalidate()
  }

  function updateWindow()
  {
    updateQueueElementsInList()
    updateDescription()
    updateButtons()
  }

  function updateDescription()
  {
    let obj = scene.findObject("item_status_text")
    if (::checkObj(obj))
      obj.setValue(getMapStatusText())
    let isCreateOperationMode = selMap != null
    local item = selMap
    if (isCreateOperationMode)
      item = item.getQueue()

    if (descHandlerWeak)
      return descHandlerWeak.setDescItem(item)

    if (!item)
      return

    mapDescrObj = ::gui_handlers.WwMapDescription.link(scene.findObject("item_desc"), item, item,
      isCreateOperationMode ? {
        onJoinQueueCb = onJoinQueue.bindenv(this)
        onLeaveQueueCb = onLeaveQueue.bindenv(this)
        onJoinClanOperationCb = onJoinClanOperation.bindenv(this)
        onFindOperationBtnCb = onFindOperationBtn.bindenv(this)
        onMapSideActionCb = onMapSideAction.bindenv(this)
        onToBattlesCb = onToBattles.bindenv(this)
        onBackOperationCb = onBackOperation.bindenv(this)
      } : null)
    descHandlerWeak = mapDescrObj.weakref()
    registerSubHandler(mapDescrObj)
  }

  function updateButtons()
  {
    this.showSceneBtn("gamercard_logo", true)

    let hasMap = selMap != null
    let isInQueue = isMyClanInQueue()
    let isQueueJoiningEnabled =  ::WwQueue.getCantJoinAnyQueuesReasonData().canJoin
    let myClanOperation = getMyClanOperation()
    let isMyClanOperation = hasMap && hasClanOperation && myClanOperation?.data.map == selMap?.name

    nearestAvailableMapToBattle = getNearestMapToBattle()
    let needShowBeginMapWaitTime = !(nearestAvailableMapToBattle?.isActive?() ?? true)
    if ((queuesJoinTime > 0) != isInQueue)
      queuesJoinTime = isInQueue ? getLatestQueueJoinTime() : 0
    this.showSceneBtn("queues_wait_time_div", isInQueue)
    updateQueuesWaitTime()
    this.showSceneBtn("begin_map_wait_time_div", needShowBeginMapWaitTime)
    updateBeginMapWaitTime()
    updateWwarUrlButton()

    if (::show_console_buttons)
    {
      let selectedMapObj = getSelectedMapObj()
      let isMapActionVisible = !hasMap ||
        (selMap.isActive() && isQueueJoiningEnabled && !isInQueue)
      let btnMapActionObj = this.showSceneBtn("btn_map_action", isMapActionVisible && isDeveloperMode)
      btnMapActionObj.setValue(getSelectedMapEditBtnText(selectedMapObj))
    }

    if (!hasMap)
      return

    let cantJoinAnyQueues = ::WwQueue.getCantJoinAnyQueuesReasonData()
    foreach (side in ::g_world_war.getCommonSidesOrder())
    {
      let sideObj = scene.findObject($"side_{side}")
      let joinQueueBtn = ::showBtn("btn_join_queue",
        selMap?.isClanQueueAvaliable() && isQueueJoiningEnabled && !isInQueue, sideObj)
      joinQueueBtn.inactiveColor = (cantJoinAnyQueues.canJoin && clustersList != null) ? "no" : "yes"
      let sideCountry = sideObj.countryId
      let enable = hasOperationActive()
      sideObj.findObject("btn_find_operation").inactiveColor = enable ? "no" : "yes"

      let myLastOperation = ::g_world_war.getLastPlayedOperation()
      let isJoinedAnotherOperation = myLastOperation && myClanOperation
        && !myLastOperation.isEqual(myClanOperation)
      let isJoinedMyClanOperation = myLastOperation?.isEqual(myClanOperation)
      let isBackOperBtnVisible = isJoinedMyClanOperation || isJoinedAnotherOperation
      let isJoinBtnVisible = isMyClanOperation && !isJoinedMyClanOperation

      let backOperBtn = ::showBtn("btn_back_operation", isBackOperBtnVisible, sideObj)
      if (isBackOperBtnVisible) {
        let myCountryId = myLastOperation?.getMyClanCountry() ?? ""
        let isMyClanSide = myCountryId == sideCountry
        backOperBtn.inactiveColor = isMyClanSide ? "no" : "yes"
        backOperBtn.findObject("btn_back_operation_text")?.setValue(
          $"{::loc("worldwar/backOperation")}{myLastOperation.getNameText(false)}")
      }
      let joinBtn = ::showBtn("btn_join_clan_operation", isJoinBtnVisible, sideObj)
      if (isJoinBtnVisible) {
        let myCountryId = myClanOperation?.getMyClanCountry() ?? ""
        let isMyClanSide = myCountryId == sideCountry
        joinBtn.inactiveColor = isMyClanSide ? "no" : "yes"
        joinBtn.findObject("btn_join_operation_text")?.setValue(
          $"{::loc("worldwar/joinOperation")}{myClanOperation.getNameText(false)}")
        ::showBtn("is_clan_participate_img", isMyClanSide, joinBtn)
      }
      ::showBtn("btn_leave_queue",
        (hasClanOperation || isInQueue) && hasRightsToQueueClan && isInQueue
          && ::isInArray(sideCountry, selMap.getQueue().getMyClanCountries()), sideObj)
    }
  }

  function getLatestQueueJoinTime()
  {
    local res = 0
    foreach (map in mapsTbl)
    {
      let queue = map.getQueue()
      let t = queue.isMyClanJoined() ? queue.getMyClanQueueJoinTime() : 0
      if (t > 0)
        res = (res == 0) ? t : min(res, t)
    }
    return res
  }

  function onTimerQueuesWaitTime(obj, dt)
  {
    updateQueuesWaitTime()
  }

  function updateQueuesWaitTime()
  {
    if (!queuesJoinTime)
      return

    refreshGlobalStatusData()

    let queueInfoobj = scene.findObject("queues_wait_time_text")
    if (!::checkObj(queueInfoobj))
      return

    let timeInQueue = ::get_charserver_time_sec() - queuesJoinTime
    queueInfoobj.setValue(::loc("worldwar/mapStatus/yourClanInQueue")
      + ::loc("ui/colon") + time.secondsToString(timeInQueue, false))
  }

  function updateQueueElementsInList()
  {
    foreach (mapId, map in mapsTbl)
    {
      ::showBtn("wait_icon_" + mapId, map.getQueue().isMyClanJoined(), mapsListObj)
      let membersIconObj = scene.findObject("queue_members_" + mapId)
      if (::check_obj(membersIconObj))
        membersIconObj.show(map.getQueue().getArmyGroupsAmountTotal() > 0)
    }
  }

  function hasAvailableBattles(country)
  {
    let mapName = selMap?.name ?? ""
    return globalBattlesListData.getList().findvalue(function(battle) {
      let side = battle.getSideByCountry(country)
      let team = battle.getTeamBySide(side)
      if (!battle.hasSideCountry(country)
         || !battle.isAvaliableForMap(mapName)
         || ! battle.hasAvailableUnits(team))
       return false

      return isMatchFilterMask(battle, country, team, side, false)
    }) != null
  }

  function getMapStatusText()
  {
    if (!selMap)
      return ""

    let res = selMap.getOpGroup().hasOperations() ? "" :
        ::colorize("badTextColor", ::loc("worldwar/msg/noActiveOperations"))

    let operation = getMyClanOperation()
    if (operation && operation.getMapId() == selMap.getId())
      return ::colorize("userlogColoredText",
        ::loc("worldwar/mapStatus/yourClanInOperation", { name = operation.getNameText(false) }))
    let queue = selMap.getQueue()
    let selCountryText = selCountryId != ""
      ? "".concat(::loc("worldwar/mapStatus/chosenCountry"), ::loc("ui/colon"), ::loc(selCountryId))
      : ""
    if (queue.isMyClanJoined())
      return  ::colorize("userlogColoredText",
        "\n".concat(::loc("worldwar/mapStatus/yourClanInQueue"), selCountryText))

    if (operation)
      return ""

    let cantJoinReason = queue.getCantJoinQueueReasonData()
    return "\n".concat(res, cantJoinReason.canJoin
      ? "" : ::colorize("badTextColor", cantJoinReason.reasonText))
  }

  function getChapterObjId(map)
  {
    return "chapter_" + map.getChapterId()
  }

  function onClansQueue()
  {
    if (!::has_feature("WorldWarClansQueue"))
      return

    descHandlerWeak = null
    updateWindow()
    ::move_mouse_on_child_by_value(scene.findObject("countries_container"))
  }

  function joinOperation(operation, country) {
    if (operation == null)
      return ::showInfoMsgBox(::loc("worldwar/operationNotFound"), "cant_join_operation")

    let reasonData = operation.getCantJoinReasonData(country)
    if (reasonData.canJoin)
      return operation.join(country)

    ::showInfoMsgBox(::loc(reasonData.reasonText), "cant_join_operation")
  }

  onBackOperation = @(obj)
    joinOperation(::g_world_war.getLastPlayedOperation(), obj.countryId)

  onJoinClanOperation = @(obj) joinOperation(getMyClanOperation(), obj.countryId)


  function loadAndCheckMyClusters() {
    let clustersStr = ::load_local_account_settings(MY_CLUSRTERS, "")
    if (clustersStr == "")
      return

    let myClusters = clustersStr.split(",")
    let forbiddenClusters = ::g_world_war.getSetting("forbiddenClusters", null)?.split(",")
    local clusters = ::get_option(::USEROPT_CLUSTER)?.items
    if (!clusters)
      return

    clusters = forbiddenClusters
      ? clusters.filter(@(v) !forbiddenClusters.contains(v?.name)).map(@(v) v?.name)
      : clusters
    let allovedClusters = myClusters.filter(@(v) clusters.contains(v))
    clustersList = allovedClusters.len() > 0 ? ",".join(allovedClusters) : null
  }

  function createClustersList() {
    let myClusters = clustersList?.split(",")
    let forbiddenClusters = ::g_world_war.getSetting("forbiddenClusters", null)?.split(",")
    let title = "".concat(::loc("worldwar/cluster"), " ", ::loc("ui/number_sign"))
    let addText = [
      ::loc("ui/parentheses", {text = ::loc("worldwar/max_priority")}),
      "",
      ::loc("ui/parentheses", {text = ::loc("worldwar/min_priority")})
    ]
    let optionsList = []
    for (local i = 0; i < 3; i++)
      optionsList.append({
          optType = ::USEROPT_CLUSTER
          title = $"{title}{i+1} {addText[i]}"
          isEmptyDefault = true
          exceptions = forbiddenClusters
          name = myClusters?[i]
      })
    return addPopupOptList({
      scene = scene.findObject("selector_nest")
      actionText = ::loc("worldwar/cluster")
      optionsList = optionsList
      onActionFn = ::Callback(onClusterApply, this)
    })
  }

  function updateClustersTxt() {
    let clusterBtn = clusterOptionsSelector.getActionBtn()
    if (!clusterBtn?.isValid())
      return

    local clustersTxt = ""
    if (clustersList) {
      let optItems = ::get_option(::USEROPT_CLUSTER).items
      let txtList = []
      foreach (name in clustersList.split(",")) {
        let item = optItems.findvalue(@(v) v.name == name)
        if (item)
          txtList.append(item.text)
      }
      clustersTxt = txtList ? $"{::loc("ui/colon")} {"; ".join(txtList)}" : ""
    }

    clusterBtn.setValue($"{::loc("worldwar/cluster")}{clustersTxt}")
  }

  function onClusterApply(res) {
    let values = res?[::USEROPT_CLUSTER]
    clustersList = values ? ",".join(values) : null
    ::save_local_account_settings(MY_CLUSRTERS, clustersList)
    updateButtons()
    updateClustersTxt()
  }

  function onJoinQueue(obj) {
    if (!clustersList)
      return ::scene_msg_box("cant_join_operation", null, ::loc("worldwar/must_select_cluster"),
       [
         ["ok", ::Callback(@() clusterOptionsSelector.onAction(), this)],
         ["cancel", @() null]
       ], "ok")

    selCountryId = obj.countryId
    selMap.getQueue().joinQueue(selCountryId, true, clustersList)
  }

  function onLeaveQueue()
  {
    selCountryId = ""
    if (!isMyClanInQueue())
      return

    foreach (map in mapsTbl)
      map.getQueue().leaveQueue()
  }

  function findRandomOperationCB(data, countryId, progressBox) {
    if (isRequestCanceled)
      return

    let { operationId = -1, country = null } = data
    if (operationId < 0)
      return ::g_delayed_actions.add(::Callback(@()
        requestRandomOperationByCountry(countryId, progressBox), this), autoselectOperationTimeout)

    ::destroyMsgBox(progressBox)
    ::switch_profile_country(country)
    ::g_world_war.joinOperationById(operationId)
  }

  function requestRandomOperationByCountry(countryId, progressBox) {
    let requestBlk = ::DataBlock()
    requestBlk.country = countryId

    ::g_tasker.charRequestJson("cln_ww_autoselect_operation", requestBlk,
      { clusters = clustersList },
      ::Callback(@(data) findRandomOperationCB(data, countryId, progressBox), this))
  }

  function findRandomOperationByCountry(countryId) {
    isRequestCanceled = false
    let progressBox = ::scene_msg_box("join_operation", null, ::loc("worldwar/searchingOperation"),
      [["cancel", ::Callback(@() isRequestCanceled = true, this)]], null, { waitAnim = true })
    requestRandomOperationByCountry(countryId, progressBox)
  }

  function onFindOperationBtn(obj) {
    if (!clustersList)
      return ::scene_msg_box("cant_join_operation", null, ::loc("worldwar/must_select_cluster"),
       [
         ["ok", ::Callback(@() clusterOptionsSelector.onAction(), this)],
         ["cancel", @() null]
       ], "ok")

    let myClanOperation = getMyClanOperation()
    let myLastOperation = ::g_world_war.getLastPlayedOperation()
    let isJoinedAnotherOperation = myLastOperation && myClanOperation
      && !myLastOperation.isEqual(myClanOperation)
    if (isJoinedAnotherOperation)
      return ::scene_msg_box("disjoin_operation", null,
        ::loc("worldwar/disjoin_operation", {id = myClanOperation.getMapText()}),
       [
         ["ok", ::Callback(@() findRandomOperationByCountry(obj.countryId), this)],
         ["cancel", @() null]
       ], "ok")

    findRandomOperationByCountry(obj.countryId)
  }

  function onOperationListSwitch()
  {
    isDeveloperMode = !isDeveloperMode
    this.showSceneBtn("operation_list", isDeveloperMode)
    let countriesContainerObj = scene.findObject("countries_container")
    local selObj = canEditMapCountries(countriesContainerObj) ? countriesContainerObj : null

    if (isDeveloperMode)
    {
      fillMapsList()
      selObj = mapsListObj
    }
    updateWindow()
    ::move_mouse_on_child_by_value(selObj)
  }

  function onStart()
  {
    if (::has_feature("WorldWarGlobalBattles"))
      openGlobalBattlesModal()
    else
      openOperationsListModal()
  }

  function openGlobalBattlesModal()
  {
    ::gui_handlers.WwGlobalBattlesModal.open()
  }

  function openOperationsListModal()
  {
    if (!selMap)
      return

    openOperationsListByMap(selMap)
  }

  function openOperationsListByMap(map)
  {
    ::gui_start_modal_wnd(::gui_handlers.WwOperationsListModal,
      { map = map, isDescrOnly = !::has_feature("WWOperationsList") })
  }

  function goBack()
  {
    if (isDeveloperMode)
    {
      onOperationListSwitch()
      return
    }

    base.goBack()
  }

  function onDestroy()
  {
    seenWWMapsAvailable.markSeen()
  }

  function updateUnseen()
  {
    if (!selMap)
      return

    seenWWMapsAvailable.markSeen(selMap.name)
  }

  function onEventWWGlobalStatusChanged(p)
  {
    if (p.changedListsMask & (WW_GLOBAL_STATUS_TYPE.MAPS | WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS)) {
      reinitScreen()
      if (needCheckSeasonIsOverNotice)
        checkSeasonIsOverNotice()
    }
    else if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.QUEUE)
      updateWindow()
    else
      updateButtons()

    checkAndJoinClanOperation()
  }

  function checkAndJoinClanOperation()
  {
    if (hasClanOperation)
      return

    let newClanOperation = getMyClanOperation()
    if (!newClanOperation)
      return
    hasClanOperation = true

    let myClanCountry = newClanOperation.getMyClanCountry()
    if (myClanCountry)
      newClanOperation.join(myClanCountry)
    else
    {
      let msg = format("Error: WWar: Bad country for my clan group in just created operation %d:\n%s",
                           newClanOperation.id,
                           ::toString(newClanOperation.getMyClanGroup())
                          )
      ::script_net_assert_once("badClanCountry/" + newClanOperation.id, msg)
    }
  }

  function onEventClanInfoUpdate(params)
  {
    updateWindow()
  }

  /*!!! Will be used in further tasks !!!
  local wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
  local { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
  function onEventWWGlobeMarkerHover(params)
  {
    local obj = scene.findObject("globe_hint")
    if (!::check_obj(obj))
      return

    local map = params.hover ? getMapByName(params.id) : null
    local show = map != null
    obj.show(show)
    if (!show)
      return

    local item =  map.getQueue()
    obj.findObject("title").setValue(item.getNameText())
    obj.findObject("desc").setValue(item.getGeoCoordsText())

    placeHint(obj)

    local statisticsObj = obj.findObject("statistics")
    if (!::check_obj(statisticsObj))
      return

    local lbMode = wwLeaderboardData.getModeByName("ww_countries")
    if (!lbMode)
      return

    statisticsObj.show(true)
    local callback = ::Callback(
      function(countriesData) {
        local statistics = wwLeaderboardData.convertWwLeaderboardData(countriesData).rows
        local view = getStatisticsView(statistics, map)
        local markup = ::handyman.renderCached("%gui/worldWar/wwGlobeMapInfo", view)
        guiScene.replaceContentFromText(statisticsObj, markup, markup.len(), this)
      }, this)
    wwLeaderboardData.requestWwLeaderboardData(
      lbMode.mode,
      {
        gameMode = lbMode.mode + "__" + params.id
        table    = "season"
        start = 0
        count = 2
        category = lbMode.field
      },
      @(countriesData) callback(countriesData))
  }

  function getStatisticsView(statistics, map)
  {
    local countries = map.getCountries()
    if (countries.len() > 2)
      return {}

    local sideAHueOption = ::get_option(::USEROPT_HUE_SPECTATOR_ALLY)
    local sideBHueOption = ::get_option(::USEROPT_HUE_SPECTATOR_ENEMY)
    local mapName = map.getId()
    local view = {
      country_0_icon = getCustomViewCountryData(countries[0], mapName).icon
      country_1_icon = getCustomViewCountryData(countries[1], mapName).icon
      rate_0 = 50
      rate_1 = 50
      side_0_color = ::get_block_hsv_color(sideAHueOption.values[sideAHueOption.value])
      side_1_color = ::get_block_hsv_color(sideBHueOption.values[sideBHueOption.value])
      rows = []
    }

    local rowView = {
      side_0 = 0
      text = "win_operation_count"
      side_1 = 0
    }
    foreach (idx, country in statistics)
      rowView["side_" + idx] <-
        ::round((country?.operation_count ?? 0) * (country?.operation_winrate ?? 0))
    view.rows.append(rowView)
    if (rowView.side_0 + rowView.side_1 > 0)
    {
      view.rate_0 = ::round(rowView.side_0 / (rowView.side_0 + rowView.side_1) * 100)
      view.rate_1 = 100 - view.rate_0
    }

    rowView = { text = "win_battles_count" }
    foreach (idx, country in statistics)
      rowView["side_" + idx] <-
        ::round((country?.battle_count ?? 0) * (country?.battle_winrate ?? 0))
    if (((rowView?.side_0 ?? 0) > 0) || ((rowView?.side_1 ?? 0) > 0))
      view.rows.append(rowView)

    foreach (field in ["playerKills", "aiKills"])
    {
      rowView = { text = ::g_lb_category.getTypeByField(field).visualKey }
      foreach (idx, country in statistics)
        rowView["side_" + idx] <- country?[field] ?? 0
      if (((rowView?.side_0 ?? 0) > 0) || ((rowView?.side_1 ?? 0) > 0))
        view.rows.append(rowView)
    }

    return view
  }*/

  function onEventWWCreateOperation(params)
  {
    onClansQueue()
  }

  function getWndHelpConfig()
  {
    let res = {
      textsBlk = "%gui/worldWar/wwOperationsMapsModalHelp.blk"
      objContainer = scene.findObject("root-box")
    }

    let links = [
      { obj = ["to_battle_button"]
        msgId = "hint_to_battle_button"
      }

      { obj = ["item_desc"]
        msgId = "hint_item_desc"
      }

      { obj = ["maps_list"]
        msgId = "hint_maps_list"
      }

      { obj = ["trophy_list"]
        msgId = "trophy_list_list"
      }

      { obj = ["btn_join_queue"]
        msgId = "hint_btn_join_queue"
      }
    ]

    res.links <- links
    return res
  }

  function updateWwarUrlButton()
  {
    if (!::has_feature("AllowExternalLink") || ::is_vendor_tencent())
      return

    let worldWarUrlBtnKey = ::get_gui_regional_blk()?.worldWarUrlBtnKey ?? ""
    let isVisibleBtn = !::u.isEmpty(worldWarUrlBtnKey)
    let btnObj = this.showSceneBtn("ww_wiki", isVisibleBtn)
    if (!isVisibleBtn || !btnObj?.isValid())
      return

    btnObj.link = ::loc($"url/wWarBtn/{worldWarUrlBtnKey}")
    btnObj.findObject("ww_wiki_text").setValue(::loc($"worldwar/urlBtn/{worldWarUrlBtnKey}"))
  }

  function updateRewardsPanel()
  {
    let rewards = fillTrophyList().extend(fillUnlocksList())
    let isRewardsVisible = rewards.len() > 0
    this.showSceneBtn("rewards_panel", isRewardsVisible)
    if (isRewardsVisible)
      fillRewards(rewards)
  }

  function onTimerBeginMapWaitTime(obj, dt)
  {
    updateBeginMapWaitTime()
  }

  function updateBeginMapWaitTime()
  {
    let waitTime = nearestAvailableMapToBattle?.getChangeStateTime?() ?? -1
    if (waitTime <= 0)
      return

    let waitMapInfoObj = scene.findObject("begin_map_wait_time_text")
    if (!::check_obj(waitMapInfoObj))
      return

    waitMapInfoObj.setValue(::loc("worldwar/operation/willBegin", {
      name = nearestAvailableMapToBattle.getNameText()
      time = nearestAvailableMapToBattle.getChangeStateTimeText()}))
  }

  function showSeasonIsOverNotice()
  {
    let curDay = time.getUtcDays()
    let seasonOverNotice = ::load_local_account_settings(WW_DAY_SEASON_OVER_NOTICE, 0)
      + WW_SEASON_OVER_NOTICE_PERIOD_DAYS
    if (seasonOverNotice && seasonOverNotice > curDay)
      return
    ::save_local_account_settings(WW_DAY_SEASON_OVER_NOTICE, curDay)
    ::scene_msg_box("season_is_over_notice", null, ::loc("worldwar/seasonIsOverNotice"),
      [["ok", null]], "ok")
  }

  function onOpenAchievements()
  {
    ::gui_start_profile({
      initialSheet = "UnlockAchievement"
      curAchievementGroupName = unlocksChapterName
    })
  }

  function getUnlockObj(containerObj, idx)
  {
    if (containerObj.childrenCount() > idx)
        return containerObj.getChild(idx)

    return containerObj.getChild(idx-1).getClone(containerObj, this)
  }

  function updateBattleButtonsStatus() {
    if (selMap == null)
      return

    foreach (side in ::g_world_war.getCommonSidesOrder()) {
      let sideObj = scene.findObject($"side_{side}")
      if (!::check_obj(sideObj))
        continue

      let enable = hasOperationActive()
      sideObj.findObject("btn_find_operation").inactiveColor = enable ? "no" : "yes"
    }
  }

  function onEventWWUpdateGlobalBattles(p) {
    doWhenActiveOnce("updateBattleButtonsStatus")
  }

  function onUpdateGlobalBattles(obj, dt) {
    if (selMap == null
      || !(selMap.isActive() || selMap.getOpGroup().hasActiveOperations()))
      return

    globalBattlesListData.requestList()
  }

  function getFocusedConflictSideObj() {
    let countriesContainerObj = scene.findObject("countries_container")
    if (!::check_obj(countriesContainerObj) || !countriesContainerObj.isFocused())
      return null

    let value = ::get_obj_valid_index(countriesContainerObj)
    if (value < 0)
      return null

    return countriesContainerObj.getChild(value)
  }

  function onToBattles() {
    let sideObj = getFocusedConflictSideObj()
    if (!::check_obj(sideObj))
      return

    onFindOperationBtn(sideObj)
  }

  function onMapSideAction() {
    let sideObj = getFocusedConflictSideObj()
    if (!::check_obj(sideObj))
      return

    let isInQueue = isMyClanInQueue()
    let isQueueJoiningEnabled =  ::WwQueue.getCantJoinAnyQueuesReasonData().canJoin
    let isMyClanOperation = selMap != null && hasClanOperation &&
      getMyClanOperation()?.data.map == selMap?.name
    if (selMap?.isClanQueueAvaliable() && isQueueJoiningEnabled && !isInQueue)
      onJoinQueue(sideObj)
    else if ((hasClanOperation || isInQueue) && hasRightsToQueueClan && isInQueue)
      onLeaveQueue()
    else if (isMyClanOperation)
      onJoinClanOperation(sideObj)
  }

  function checkSeasonIsOverNotice() {
    if (!isRecievedGlobalStatusMaps())
      return

    needCheckSeasonIsOverNotice = false
    if(!::g_world_war.isWWSeasonActive())
      showSeasonIsOverNotice()
  }

  function onSelectedMapInvalidate() {
    findMapForSelection()
    updateDescription()
    updateButtons()
  }

  function onEventUpdateClansInfoList(p) {
    addClanTagToNameInLeaderbord(scene.findObject("top_global_managers"), p?.clansInfoList ?? {})
  }
}

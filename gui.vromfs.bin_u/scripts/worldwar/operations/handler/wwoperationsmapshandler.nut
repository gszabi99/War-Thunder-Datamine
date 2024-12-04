from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *
from "%scripts/mainConsts.nut" import SEEN

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { LayersIcon } = require("%scripts/viewUtils/layeredIcon.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getObjValidIndex } = require("%sqDagui/daguiUtil.nut")
let DataBlock  = require("DataBlock")
let { format } = require("string")
let time = require("%scripts/time.nut")
let seenWWMapsAvailable = require("%scripts/seen/seenList.nut").get(SEEN.WW_MAPS_AVAILABLE)
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { getAllUnlocks, unlocksChapterName } = require("%scripts/worldWar/unlocks/wwUnlocks.nut")
let { getNearestMapToBattle, getMyClanOperation, getMapByName, isMyClanInQueue, isReceivedGlobalStatusMaps,
  getOperationById } = require("%scripts/worldWar/operations/model/wwActionsWhithGlobalStatus.nut")
let { refreshGlobalStatusData,
  actionWithGlobalStatusRequest } = require("%scripts/worldWar/operations/model/wwGlobalStatus.nut")
let { addClanTagToNameInLeaderbord } = require("%scripts/leaderboard/leaderboardView.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { getUnlockLocName, getUnlockMainCondDesc, getUnlockImageConfig,
  getUnlockNameText } = require("%scripts/unlocks/unlocksViewModule.nut")
let wwAnimBgLoad = require("%scripts/worldWar/wwAnimBg.nut")
let { addPopupOptList } = require("%scripts/worldWar/operations/handler/wwClustersList.nut")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let { getMainProgressCondition } = require("%scripts/unlocks/unlocksConditions.nut")
let { isUnlockComplete } = require("%scripts/unlocks/unlocksModule.nut")
let seenWWOperationAvailable = require("%scripts/seen/seenList.nut").get(SEEN.WW_OPERATION_AVAILABLE)
let wwVehicleSetModal = require("%scripts/worldWar/operations/handler/wwVehicleSetModal.nut")
let { get_charserver_time_sec } = require("chard")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { USEROPT_CLUSTERS } = require("%scripts/options/optionsExtNames.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { get_gui_regional_blk, get_es_custom_blk } = require("blkGetters")
let { charRequestJson } = require("%scripts/tasker.nut")
let { move_mouse_on_child_by_value, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { guiStartProfile } = require("%scripts/user/profileHandler.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { getWwSetting } = require("%scripts/worldWar/worldWarStates.nut")
let wwTopMenuOperationMap = require("%scripts/worldWar/externalServices/wwTopMenuOperationMapConfig.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")

const MY_CLUSRTERS = "ww/clusters"

let WW_DAY_SEASON_OVER_NOTICE = "worldWar/seasonOverNotice/day"
local WW_SEASON_OVER_NOTICE_PERIOD_DAYS = 7

dagui_propid_add_name_id("countryId")
dagui_propid_add_name_id("mapId")

gui_handlers.WwOperationsMapsHandler <- class (gui_handlers.BaseGuiHandlerWT) {
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

  function initScreen() {
    this.backSceneParams = { eventbusName = "gui_start_mainmenu" }
    this.mapsTbl = {}
    this.mapsListObj = this.scene.findObject("maps_list")
    this.mapsListNestObj = showObjById("operation_list", this.isDeveloperMode, this.scene)

    foreach (timerObjId in [
        "ww_status_check_timer",  // periodic ww status updates check
        "queues_wait_timer",      // frequent queues wait time text update
        "begin_map_wait_timer",    // frequent map begin wait time text update
      ]) {
      let timerObj = this.scene.findObject(timerObjId)
      if (timerObj)
        timerObj.setUserData(this)
    }

    this.autoselectOperationTimeout = ::g_world_war.getWWConfigurableValue(
      "autoselectOperationTimeoutSec", 10) * 1000
    this.loadAndCheckMyClusters()
    this.clusterOptionsSelector = this.createClustersList()
    this.updateClustersTxt()

    this.reinitScreen()
    let seenEntity = this.selMap?.name
    seenWWOperationAvailable.setListGetter(@() seenEntity ? [seenEntity] : [])
    this.topMenuHandlerWeak = gui_handlers.TopMenuButtonsHandler.create(
      this.scene.findObject("topmenu_menu_panel"),
      this,
      wwTopMenuOperationMap,
      this.scene.findObject("left_gc_panel_free_width")
    )
    this.registerSubHandler(this.topMenuHandlerWeak)
    this.updateWwarUrlButton()

    if (this.needToOpenBattles)
      this.openOperationsListModal()
    else if (this.autoOpenMapOperation)
      this.openOperationsListByMap(this.autoOpenMapOperation)
    this.checkSeasonIsOverNotice()
  }

  function reinitScreen() {
    this.hasClanOperation = getMyClanOperation() != null
    this.hasRightsToQueueClan = ::g_clans.hasRightsToQueueWWar()

    this.collectMaps()
    this.findMapForSelection()
    wwAnimBgLoad(this.selMap?.name)
    this.updateRewardsPanel()
    this.onClansQueue()
  }

  function collectMaps() {
    foreach (mapId, map in ::g_ww_global_status_type.MAPS.getList())
      if (map.isVisible())
        this.mapsTbl[mapId] <- map
  }

  function findMapForSelection() {
    let priorityConfigMapsArray = []
    foreach (map in this.mapsTbl) {
      let changeStateTime = map.getChangeStateTime() - get_charserver_time_sec()
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
    this.selMap = bestMap != null
      && (bestMap.hasActiveOperations || bestMap.isActive || bestMap.changeStateTime > 0)
        ? bestMap.map
        : null
  }

  function fillMapsList() {
    let chaptersList = []
    let mapsByChapter = {}
    foreach (mapId, map in this.mapsTbl) {
      let chapterId = map.getChapterId()
      let chapterObjId = this.getChapterObjId(map)

      if (!(chapterId in mapsByChapter)) {
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
          this.collapsedChapters.append(chapterObjId)

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

    let sortFunc = function(a, b) {
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
    foreach (c in chaptersList) {
      view.items.append(c.view)
      c.mapsList.sort(sortFunc)
      foreach (m in c.mapsList) {
        view.items.append(m.view)
        if (m.map.isEqual(this.selMap))
          selIdx = view.items.len() - 1
      }
    }

    if (selIdx == -1 && view.items.len())
      selIdx = 0

    this.isFillingList = true

    let markup = handyman.renderCached("%gui/worldWar/wwOperationsMapsItemsList.tpl", view)
    this.guiScene.replaceContentFromText(this.mapsListObj, markup, markup.len(), this)

    this.selMap = null //force refresh description
    if (selIdx >= 0)
      this.mapsListObj.setValue(selIdx)
    else
      this.onItemSelect()

    foreach (id in this.collapsedChapters)
      if (!this.selMap || this.getChapterObjId(this.selMap) != id)
        this.onCollapse(this.mapsListObj.findObject($"btn_{id}"))

    this.isFillingList = false
  }

  function fillTrophyList() {
    let res = []
    let trophiesBlk = getWwSetting("dailyTrophies", DataBlock())
    let reqFeatureId = trophiesBlk?.reqFeature
    if (reqFeatureId && !hasFeature(reqFeatureId))
      return res

    this.trophiesAmount = trophiesBlk.blockCount()
    if (!this.trophiesAmount)
      return res

    let updStatsText = time.buildTimeStr(time.getUtcMidnight(), false, false)
    let curDay = time.getUtcDays() - time.DAYS_TO_YEAR_1970 + 1
    let trophiesProgress = get_es_custom_blk(-1)?.customClientData
    for (local i = 0; i < this.trophiesAmount; i++) {
      let trophy = trophiesBlk.getBlock(i)
      let trophyId = trophy?.itemName || trophy?.trophyName || trophy?.mainTrophyId
      let trophyItem = findItemById(trophyId)
      if (!trophyItem)
        continue

      let progressDay = trophiesProgress?[$"{trophy.getBlockName()}Day"]
      let isActualProgressData = progressDay ? progressDay == curDay : false

      let progressCurValue = isActualProgressData ?
        trophiesProgress?[trophy?.progressParamName] ?? 0 : 0
      let progressMaxValue = trophy?.rewardedParamValue ?? 0
      let isProgressReached = progressCurValue >= progressMaxValue
      let progressText = loc("ui/parentheses",
        { text = $"{min(progressCurValue, progressMaxValue)}/{progressMaxValue}" })

      res.append({
        trophyDesc = $"{this.getTrophyDesc(trophy)} {progressText}"
        status = isProgressReached ? "received" : ""
        descTooltipText = this.getTrophyTooltip(trophy, updStatsText)
        tooltipId = getTooltipType("ITEM").getTooltipId(trophyId)
        iconTooltipText = this.getTrophyTooltip(trophiesBlk, updStatsText)
        rewardImage = trophyItem.getIcon()
        isTrophy = true
      })
    }
    return res
  }

  function fillUnlocksList() {
    let res = []
    let unlocksArray = getAllUnlocks()
    foreach (blk in unlocksArray) {
      let unlConf = ::build_conditions_config(blk)
      let imgConf = getUnlockImageConfig(unlConf)
      let mainCond = getMainProgressCondition(unlConf.conditions)
      let progressTxt = getUnlockMainCondDesc(
        mainCond, unlConf.curVal, unlConf.maxVal, { isProgressTextOnly = true })
      let isComplete = isUnlockComplete(unlConf)
      res.append({
        descTooltipText = unlConf.locId != "" ? getUnlockLocName(unlConf)
          : getUnlockNameText(unlConf.unlockType, unlConf.id)
        progressTxt = progressTxt
        rewardImage = LayersIcon.getIconData(
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

  function fillRewards(rewards) {
    let rewardsObj = this.scene.findObject("wwRewards")
    if (!rewardsObj?.isValid())
      return

    let data = handyman.renderCached("%gui/worldWar/wwRewards.tpl", { wwRewards = rewards })
    this.guiScene.replaceContentFromText(rewardsObj, data, data.len(), this)
  }

  getTrophyLocId = @(blk) blk?.locId ?? ($"worldwar/{blk.getBlockName()}")
  getTrophyDesc = @(blk) loc(this.getTrophyLocId(blk))
  getTrophyTooltip = @(blk, timeText) loc($"{this.getTrophyLocId(blk)}/desc", { time = timeText })

  onEventItemsShopUpdate = @(_p) this.updateRewardsPanel()
  onEventWWUnlocksCacheInvalidate = @(_p) this.updateRewardsPanel()

  function refreshSelMap() {
    let mapObj = this.getSelectedMapObj()
    if (!checkObj(mapObj))
      return false

    let isHeader = this.isMapObjChapter(mapObj)
    let newMap = isHeader ? null : getMapByName(mapObj?.id)
    if (newMap == this.selMap)
      return false

    local isChanged = !newMap || !this.selMap || !this.selMap.isEqual(newMap)
    this.selMap = newMap
    return isChanged
  }

  //operation select
  _wasSelectedOnce = false
  function onItemSelect() {
    let isSelChanged = this.refreshSelMap()

    if (!isSelChanged && this._wasSelectedOnce)
      return this.updateButtons()

    this._wasSelectedOnce = true

    this.updateUnseen()
    this.updateDescription()
    this.updateButtons()
    wwAnimBgLoad(this.selMap?.name)
  }

  function getSelectedMapObj() {
    if (!checkObj(this.mapsListObj))
      return null

    let value = this.mapsListObj.getValue()
    return value >= 0 ? this.mapsListObj.getChild(value) : null
  }

  function getSelectedMapEditBtnText(mapObj) {
    if (!checkObj(mapObj))
      return ""

    if (this.isMapObjChapter(mapObj))
      return mapObj?.collapsed == "yes"
        ? loc("mainmenu/btnExpand")
        : loc("mainmenu/btnCollapse")

    return loc("options/arcadeCountry")
  }

  function onMapAction(_obj) {
    let mapObj = this.getSelectedMapObj()
    if (!checkObj(mapObj))
      return

    if (this.isMapObjChapter(mapObj))
      this.onCollapse(mapObj)
    else if (mapObj?.selected == "yes")
      this.onSelectCountriesBlock()
  }

  function onSelectCountriesBlock() {
    let mapObj = this.getSelectedMapObj()
    if (!checkObj(mapObj) || this.isMapObjChapter(mapObj))
      return

    this.onOperationListSwitch()
  }

  isMapObjChapter = @(obj) !!obj?.collapse_header
  canEditMapCountries = @(obj) checkObj(obj) && obj.isVisible() && obj.isEnabled()

  function onCollapse(obj) {
    if (!checkObj(obj))
      return
    let itemObj = this.isMapObjChapter(obj) ? obj : obj.getParent()
    let listObj = checkObj(itemObj) ? itemObj.getParent() : null
    if (!checkObj(listObj) || !this.isMapObjChapter(itemObj))
      return

    itemObj.collapsing = "yes"
    let isShow = itemObj?.collapsed == "yes"
    let listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++) {
      let child = listObj.getChild(i)
      if (!found) {
        if (child?.collapsing == "yes") {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else {
        if (this.isMapObjChapter(child))
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect || !this.selMap) {
      let indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes) {
        let child = listObj.getChild(idx)
        if (!this.isMapObjChapter(child) && child.isEnabled()) {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }

    if (this.collapsedChapters && !u.isEmpty(itemObj?.id)) {
      let idx = u.find_in_array(this.collapsedChapters, itemObj.id)
      if (isShow && idx != -1)
        this.collapsedChapters.remove(idx)
      else if (!isShow && idx == -1)
        this.collapsedChapters.append(itemObj.id)
    }

    if (isShow)
      this.updateQueueElementsInList()
  }

  function onTimerStatusCheck(_obj, _dt) {
    refreshGlobalStatusData()
    if (this.selMap != null && !this.selMap.hasValidStatus())
      this.onSelectedMapInvalidate()
  }

  function updateWindow() {
    this.updateQueueElementsInList()
    this.updateDescription()
    this.updateButtons()
  }

  function updateDescription() {
    let obj = this.scene.findObject("item_status_text")
    if (checkObj(obj))
      obj.setValue(this.getMapStatusText())
    let isCreateOperationMode = this.selMap != null
    local item = this.selMap
    if (isCreateOperationMode)
      item = item.getQueue()

    if (this.descHandlerWeak)
      return this.descHandlerWeak.setDescItem(item)

    if (!item)
      return

    this.mapDescrObj = gui_handlers.WwMapDescription.link(this.scene.findObject("item_desc"), item, item,
      isCreateOperationMode ? {
        onJoinQueueCb = this.onJoinQueue.bindenv(this)
        onLeaveQueueCb = this.onLeaveQueue.bindenv(this)
        onJoinClanOperationCb = this.onJoinClanOperation.bindenv(this)
        onFindOperationBtnCb = this.onFindOperationBtn.bindenv(this)
        onMapSideActionCb = this.onMapSideAction.bindenv(this)
        onToBattlesCb = this.onToBattles.bindenv(this)
        onBackOperationCb = this.onBackOperation.bindenv(this)
        onBackOperationForSelectSideCb = this.onBackOperationForSelectSide.bindenv(this)
      } : null)
    this.descHandlerWeak = this.mapDescrObj.weakref()
    this.registerSubHandler(this.mapDescrObj)
  }

  function updateButtons() {
    showObjById("gamercard_logo", true, this.scene)

    let hasMap = this.selMap != null
    let isInQueue = isMyClanInQueue()
    let isQueueJoiningEnabled =  ::WwQueue.getCantJoinAnyQueuesReasonData().canJoin

    this.nearestAvailableMapToBattle = getNearestMapToBattle()
    let needShowBeginMapWaitTime = !(this.nearestAvailableMapToBattle?.isActive?() ?? true)
    if ((this.queuesJoinTime > 0) != isInQueue)
      this.queuesJoinTime = isInQueue ? this.getLatestQueueJoinTime() : 0
    showObjById("queues_wait_time_div", isInQueue, this.scene)
    this.updateQueuesWaitTime()
    showObjById("begin_map_wait_time_div", needShowBeginMapWaitTime, this.scene)
    this.updateBeginMapWaitTime()
    this.updateWwarUrlButton()

    if (showConsoleButtons.value) {
      let selectedMapObj = this.getSelectedMapObj()
      let isMapActionVisible = !hasMap ||
        (this.selMap.isActive() && isQueueJoiningEnabled && !isInQueue)
      let btnMapActionObj = showObjById("btn_map_action", isMapActionVisible && this.isDeveloperMode, this.scene)
      btnMapActionObj.setValue(this.getSelectedMapEditBtnText(selectedMapObj))
    }

    if (!hasMap)
      return

    let cantJoinAnyQueues = ::WwQueue.getCantJoinAnyQueuesReasonData()
    let isSquadMember = g_squad_manager.isSquadMember()
    let isClanQueueAvaliable = this.selMap?.isClanQueueAvaliable()
    let myClanOperation = getMyClanOperation()
    let isMyClanOperation = myClanOperation != null && myClanOperation.data.map == this.selMap?.name
    let myLastOperation = ::g_world_war.lastPlayedOperationId
      ? getOperationById(::g_world_war.lastPlayedOperationId) : null
    let isMyLastOperation = myLastOperation != null && myLastOperation.data.map == this.selMap?.name
    let isBackOperBtnVisible = !isInQueue && isMyLastOperation
      && myLastOperation.id != myClanOperation?.id
    let isJoinBtnVisible = !isInQueue && isMyClanOperation
    foreach (side in ::g_world_war.getCommonSidesOrder()) {
      let sideObj = this.scene.findObject($"side_{side}")
      let sideCountry = sideObj.countryId

      let joinQueueBtn = showObjById("btn_join_queue", !isSquadMember && isClanQueueAvaliable
        && isQueueJoiningEnabled && !isInQueue, sideObj)
      joinQueueBtn.inactiveColor = (cantJoinAnyQueues.canJoin && this.clustersList != null) ? "no" : "yes"

      showObjById("btn_find_operation", this.selMap.isActive()
        && !isInQueue && !isSquadMember, sideObj)

      let backOperBtn = showObjById("btn_back_operation", isBackOperBtnVisible, sideObj)
      if (isBackOperBtnVisible) {
        backOperBtn.inactiveColor = ::g_world_war.lastPlayedOperationCountry == sideCountry ? "no" : "yes"
        backOperBtn.findObject("btn_back_operation_text")?.setValue(
          $"{loc("worldwar/backOperation")}{myLastOperation.getNameText(false)}")
      }
      let joinBtn = showObjById("btn_join_clan_operation", isJoinBtnVisible, sideObj)
      if (isJoinBtnVisible) {
        let myCountryId = myClanOperation.getMyClanCountry() ?? ""
        let isMyClanSide = myCountryId == sideCountry
        joinBtn.inactiveColor = isMyClanSide ? "no" : "yes"
        joinBtn.findObject("btn_join_operation_text")?.setValue(
          $"{loc("worldwar/joinOperation")}{myClanOperation.getNameText(false)}")
        showObjById("is_clan_participate_img", isMyClanSide, joinBtn)
      }
      showObjById("btn_leave_queue",
        (this.hasClanOperation || isInQueue) && this.hasRightsToQueueClan && isInQueue
          && isInArray(sideCountry, this.selMap.getQueue().getMyClanCountries()), sideObj)
    }
  }

  function getLatestQueueJoinTime() {
    local res = 0
    foreach (map in this.mapsTbl) {
      let queue = map.getQueue()
      let t = queue.isMyClanJoined() ? queue.getMyClanQueueJoinTime() : 0
      if (t > 0)
        res = (res == 0) ? t : min(res, t)
    }
    return res
  }

  function onTimerQueuesWaitTime(_obj, _dt) {
    this.updateQueuesWaitTime()
  }

  function updateQueuesWaitTime() {
    if (!this.queuesJoinTime)
      return

    refreshGlobalStatusData()

    let queueInfoobj = this.scene.findObject("queues_wait_time_text")
    if (!checkObj(queueInfoobj))
      return

    let timeInQueue = get_charserver_time_sec() - this.queuesJoinTime
    queueInfoobj.setValue(loc("ui/colon").concat(loc("worldwar/mapStatus/yourClanInQueue"),
      time.secondsToString(timeInQueue, false)))
  }

  function updateQueueElementsInList() {
    foreach (mapId, map in this.mapsTbl) {
      showObjById($"wait_icon_{mapId}", map.getQueue().isMyClanJoined(), this.mapsListObj)
      let membersIconObj = this.scene.findObject($"queue_members_{mapId}")
      if (checkObj(membersIconObj))
        membersIconObj.show(map.getQueue().getArmyGroupsAmountTotal() > 0)
    }
  }

  function getMapStatusText() {
    if (!this.selMap)
      return ""

    let operation = getMyClanOperation()
    if (operation && operation.getMapId() == this.selMap.getId())
      return colorize("userlogColoredText",
        loc("worldwar/mapStatus/yourClanInOperation", { name = operation.getNameText(false) }))
    let queue = this.selMap.getQueue()
    let selCountryText = this.selCountryId != ""
      ? "".concat(loc("worldwar/mapStatus/chosenCountry"), loc("ui/colon"), loc(this.selCountryId))
      : ""
    if (queue.isMyClanJoined())
      return  colorize("userlogColoredText",
        "\n".concat(loc("worldwar/mapStatus/yourClanInQueue"), selCountryText))

    if (operation)
      return ""

    let cantJoinReason = queue.getCantJoinQueueReasonData()
    return cantJoinReason.canJoin ? "" : colorize("badTextColor", cantJoinReason.reasonText)
  }

  function getChapterObjId(map) {
    return $"chapter_{map.getChapterId()}"
  }

  function onClansQueue() {
    if (!hasFeature("WorldWarClansQueue"))
      return

    this.descHandlerWeak = null
    this.updateWindow()
    move_mouse_on_child_by_value(this.scene.findObject("countries_container"))
  }

  function joinOperation(operation, country) {
    if (operation == null)
      return showInfoMsgBox(loc("worldwar/operationNotFound"), "cant_join_operation")

    let reasonData = operation.getCantJoinReasonData(country)
    if (reasonData.canJoin)
      return operation.join(country)

    return showInfoMsgBox(loc(reasonData.reasonText), "cant_join_operation")
  }

  onBackOperation = @(obj)
    this.joinOperation(::g_world_war.lastPlayedOperationId
      ? getOperationById(::g_world_war.lastPlayedOperationId) : null, obj.countryId)

  onJoinClanOperation = @(obj) this.joinOperation(getMyClanOperation(), obj.countryId)


  function loadAndCheckMyClusters() {
    let clustersStr = loadLocalAccountSettings(MY_CLUSRTERS, "")
    if (clustersStr == "")
      return

    let myClusters = clustersStr.split(",")
    let forbiddenClusters = getWwSetting("forbiddenClusters", null)?.split(",") ?? []
    let clusters = ::get_option(USEROPT_CLUSTERS).items
      .filter(@(c) !c.isAuto && !forbiddenClusters.contains(c.name))
      .map(@(c) c?.name)
    let allovedClusters = myClusters.filter(@(v) clusters.contains(v))
    this.clustersList = allovedClusters.len() > 0 ? ",".join(allovedClusters) : null
  }

  function createClustersList() {
    let myClusters = this.clustersList?.split(",")
    let forbiddenClusters = getWwSetting("forbiddenClusters", null)?.split(",")
    let title = "".concat(loc("worldwar/cluster"), " ", loc("ui/number_sign"))
    let addText = [
      loc("ui/parentheses", { text = loc("worldwar/max_priority") }),
      "",
      loc("ui/parentheses", { text = loc("worldwar/min_priority") })
    ]
    let optionsList = []
    for (local i = 0; i < 3; i++)
      optionsList.append({
          title = $"{title}{i+1} {addText[i]}"
          exceptions = forbiddenClusters
          name = myClusters?[i]
      })
    return addPopupOptList({
      scene = this.scene.findObject("selector_nest")
      actionText = loc("worldwar/cluster")
      optionsList = optionsList
      onActionFn = Callback(this.onClusterApply, this)
    })
  }

  function updateClustersTxt() {
    let clusterBtn = this.clusterOptionsSelector.getActionBtn()
    if (!clusterBtn?.isValid())
      return

    local clustersTxt = ""
    if (this.clustersList) {
      let optItems = ::get_option(USEROPT_CLUSTERS).items
      let txtList = []
      foreach (name in this.clustersList.split(",")) {
        let item = optItems.findvalue(@(v) v.name == name)
        if (item)
          txtList.append(item.text)
      }
      clustersTxt = txtList ? $"{loc("ui/colon")} {"; ".join(txtList)}" : ""
    }

    clusterBtn.setValue($"{loc("worldwar/cluster")}{clustersTxt}")
  }


  function onClusterApply(values) {
    this.clustersList = values.len() > 0 ? ",".join(values) : null
    saveLocalAccountSettings(MY_CLUSRTERS, this.clustersList)
    this.updateButtons()
    this.updateClustersTxt()
  }

  function onJoinQueue(obj) {
    if (!this.clustersList)
      return scene_msg_box("cant_join_operation", null, loc("worldwar/must_select_cluster"),
       [
         ["ok", Callback(@() this.clusterOptionsSelector.onAction(), this)],
         ["cancel", @() null]
       ], "ok")

    this.selCountryId = obj.countryId
    this.selMap.getQueue().joinQueue(this.selCountryId, true, this.clustersList)
  }

  function onLeaveQueue() {
    this.selCountryId = ""
    if (!isMyClanInQueue())
      return

    foreach (map in this.mapsTbl)
      map.getQueue().leaveQueue()
  }

  function findRandomOperationCB(data, countryId, progressBox) {
    if (this.isRequestCanceled) {
      log("cln_ww_autoselect_operation: request canceled")
      return
    }

    let { operationId = -1, country = null } = data
    if (operationId < 0) {
      log("cln_ww_autoselect_operation: no operation available")
      return ::g_delayed_actions.add(Callback(@()
        this.requestRandomOperationByCountry(countryId, progressBox), this), this.autoselectOperationTimeout)
    }

    log($"cln_ww_autoselect_operation: operationId={operationId}, country={country}")
    destroyMsgBox(progressBox)
    switchProfileCountry(country)
    let operation = getOperationById(operationId)
    if (!operation) {
      let requestBlk = DataBlock()
      requestBlk.operationId = operationId
      actionWithGlobalStatusRequest("cln_ww_global_status_short", requestBlk, null,
        @() ::g_world_war.joinOperationById(operationId, null, false, null, true))
      return
    }

    ::g_world_war.joinOperationById(operationId, null, false, null, true)
  }

  function requestRandomOperationByCountry(countryId, progressBox) {
    let requestBlk = DataBlock()
    requestBlk.country = countryId
    requestBlk.clusters = this.clustersList
    if (g_squad_manager.isInSquad()) {
      let leaderUid = g_squad_manager.getLeaderUid()
      let members = [leaderUid].extend(
        g_squad_manager.getMembers().keys().filter(@(v) v != leaderUid))
      requestBlk.squadMembers = ";".join(members)
    }

    log($"cln_ww_autoselect_operation(clusters={this.clustersList}; country={countryId})")
    charRequestJson("cln_ww_autoselect_operation", requestBlk, null,
      Callback(@(data) this.findRandomOperationCB(data, countryId, progressBox), this))
  }

  function findRandomOperationByCountry(countryId) {
    this.isRequestCanceled = false
    let progressBox = scene_msg_box("join_operation", null, loc("worldwar/searchingOperation"),
      [["cancel", Callback(@() this.isRequestCanceled = true, this)]], null, { waitAnim = true })
    this.requestRandomOperationByCountry(countryId, progressBox)
  }

  function onFindOperationBtn(obj) {
    if (!this.clustersList)
      return scene_msg_box("cant_join_operation", null, loc("worldwar/must_select_cluster"),
       [
         ["ok", Callback(@() this.clusterOptionsSelector.onAction(), this)],
         ["cancel", @() null]
       ], "ok")

    let myClanOperation = getMyClanOperation()
    let isMyClanOperation = this.selMap != null && this.hasClanOperation
      && myClanOperation?.data.map == this.selMap?.name
    let myLastOperation = ::g_world_war.lastPlayedOperationId
      ? getOperationById(::g_world_war.lastPlayedOperationId) : null
    let countryId = obj.countryId
    if (myLastOperation || isMyClanOperation)
      return scene_msg_box("disjoin_operation", null,
        loc("worldwar/disjoin_operation",
          { id = myLastOperation?.getNameText(false) ?? myClanOperation?.getNameText(false) ?? "" }),
        [
          ["ok", Callback(@() this.findRandomOperationByCountry(countryId), this)],
          ["cancel", @() null]
        ], "ok")

    this.findRandomOperationByCountry(countryId)
  }

  function onOperationListSwitch() {
    this.isDeveloperMode = !this.isDeveloperMode
    showObjById("operation_list", this.isDeveloperMode, this.scene)
    let countriesContainerObj = this.scene.findObject("countries_container")
    local selObj = this.canEditMapCountries(countriesContainerObj) ? countriesContainerObj : null

    if (this.isDeveloperMode) {
      this.fillMapsList()
      selObj = this.mapsListObj
    }
    this.updateWindow()
    move_mouse_on_child_by_value(selObj)
  }

  function openVehiclesPresetModal() {
    if (!this.selMap)
      return

    if(this.selMap.getUnitsGroupsByCountry() == null)
      return

    wwVehicleSetModal.open({ map = this.selMap })
  }

  function openOperationsListModal() {
    if (!this.selMap)
      return

    this.openOperationsListByMap(this.selMap)
  }

  function openOperationsListByMap(map) {
    loadHandler(gui_handlers.WwOperationsListModal,
      { map = map, isDescrOnly = !hasFeature("WWOperationsList") })
  }

  function goBack() {
    if (this.isDeveloperMode) {
      this.onOperationListSwitch()
      return
    }

    base.goBack()
  }

  function onDestroy() {
    seenWWMapsAvailable.markSeen()
  }

  function updateUnseen() {
    if (!this.selMap)
      return

    seenWWMapsAvailable.markSeen(this.selMap.name)
  }

  function onEventSquadDataUpdated(_) {
    this.updateButtons()
  }

  function onEventWWGlobalStatusChanged(p) {
    if (p.changedListsMask & (WW_GLOBAL_STATUS_TYPE.MAPS | WW_GLOBAL_STATUS_TYPE.ACTIVE_OPERATIONS)) {
      this.reinitScreen()
      if (this.needCheckSeasonIsOverNotice)
        this.checkSeasonIsOverNotice()
    }
    else if (p.changedListsMask & WW_GLOBAL_STATUS_TYPE.QUEUE)
      this.updateWindow()
    else
      this.updateButtons()

    this.checkAndJoinClanOperation()
  }

  function checkAndJoinClanOperation() {
    if (this.hasClanOperation)
      return

    let newClanOperation = getMyClanOperation()
    if (!newClanOperation)
      return
    this.hasClanOperation = true

    let myClanCountry = newClanOperation.getMyClanCountry()
    if (myClanCountry)
      newClanOperation.join(myClanCountry)
    else {
      let msg = format("Error: WWar: Bad country for my clan group in just created operation %d:\n%s",
                           newClanOperation.id,
                           toString(newClanOperation.getMyClanGroup())
                          )
      script_net_assert_once($"badClanCountry/{newClanOperation.id}", msg)
    }
  }

  function onEventClanInfoUpdate(_params) {
    this.updateWindow()
  }

  /*!!! Will be used in further tasks !!!
  local wwLeaderboardData = require("%scripts/worldWar/operations/model/wwLeaderboardData.nut")
  local { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
  let { convertLeaderboardData } = require("%scripts/leaderboard/requestLeaderboardData.nut")
  function onEventWWGlobeMarkerHover(params)
  {
    local obj = scene.findObject("globe_hint")
    if (!checkObj(obj))
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
    if (!checkObj(statisticsObj))
      return

    local lbMode = wwLeaderboardData.getModeByName("ww_countries")
    if (!lbMode)
      return

    statisticsObj.show(true)
    local callback = Callback(
      function(countriesData) {
        local statistics = convertLeaderboardData(countriesData).rows
        local view = getStatisticsView(statistics, map)
        local markup = handyman.renderCached("%gui/worldWar/wwGlobeMapInfo.tpl", view)
        guiScene.replaceContentFromText(statisticsObj, markup, markup.len(), this)
      }, this)
    wwLeaderboardData.requestWwLeaderboardData(
      lbMode.mode,
      {
        gameMode = $"{lbMode.mode}__{params.id}"
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

    local sideAHueOption = ::get_option(USEROPT_HUE_SPECTATOR_ALLY)
    local sideBHueOption = ::get_option(USEROPT_HUE_SPECTATOR_ENEMY)
    local mapName = map.getId()
    local view = {
      country_0_icon = getCustomViewCountryData(countries[0], mapName).icon
      country_1_icon = getCustomViewCountryData(countries[1], mapName).icon
      rate_0 = 50
      rate_1 = 50
      side_0_color = getRgbStrFromHsv(sideAHueOption.values[sideAHueOption.value], 1.0, 1.0)
      side_1_color = getRgbStrFromHsv(sideBHueOption.values[sideBHueOption.value], 1.0, 1.0)
      rows = []
    }

    local rowView = {
      side_0 = 0
      text = "win_operation_count"
      side_1 = 0
    }
    foreach (idx, country in statistics)
      rowView[$"side_{idx}"] <-
        round((country?.operation_count ?? 0) * (country?.operation_winrate ?? 0))
    view.rows.append(rowView)
    if (rowView.side_0 + rowView.side_1 > 0)
    {
      view.rate_0 = round(rowView.side_0 / (rowView.side_0 + rowView.side_1) * 100)
      view.rate_1 = 100 - view.rate_0
    }

    rowView = { text = "win_battles_count" }
    foreach (idx, country in statistics)
      rowView[$"side_{idx}"] <-
        round((country?.battle_count ?? 0) * (country?.battle_winrate ?? 0))
    if (((rowView?.side_0 ?? 0) > 0) || ((rowView?.side_1 ?? 0) > 0))
      view.rows.append(rowView)

    foreach (field in ["playerKills", "aiKills"])
    {
      rowView = { text = lbCategoryTypes.getTypeByField(field).visualKey }
      foreach (idx, country in statistics)
        rowView[$"side_{idx}"] <- country?[field] ?? 0
      if (((rowView?.side_0 ?? 0) > 0) || ((rowView?.side_1 ?? 0) > 0))
        view.rows.append(rowView)
    }

    return view
  }*/

  function onEventWWCreateOperation(_params) {
    this.onClansQueue()
  }

  function onHelp() {
    gui_handlers.HelpInfoHandlerModal.openHelp(this)
  }

  function getWndHelpConfig() {
    let res = {
      textsBlk = "%gui/worldWar/wwOperationsMapsModalHelp.blk"
      objContainer = this.scene.findObject("root-box")
    }

    let links = [
      { obj = ["topmenu_ww_menu_btn"]
        msgId = "hint_topmenu_ww_menu_btn"
      }

      { obj = ["item_name"]
        msgId = "hint_operation_name"
      }

      { obj = ["country_1"]
        msgId = "hint_country"
      }

      { obj = ["btn_find_operation"]
        msgId = "hint_btn_find_operation"
      }

      { obj = ["btn_back_operation"]
        msgId = "hint_btn_back_operation"
      }

      { obj = ["btn_join_queue"]
        msgId = "hint_btn_join_queue"
      }

      { obj = ["btn_join_clan_operation"]
        msgId = "hint_btn_join_clan_operation"
      }

      { obj = ["item_status_text"]
        msgId = "hint_item_status_text"
      }

      { obj = ["rewards_panel"]
        msgId = "hint_rewards_panel"
      }

      { obj = ["selector_nest"]
        msgId = "hint_btn_cluster"
      }
    ]

    res.links <- links
    return res
  }

  function updateWwarUrlButton() {
    if (!hasFeature("AllowExternalLink"))
      return

    let worldWarUrlBtnKey = get_gui_regional_blk()?.worldWarUrlBtnKey ?? ""
    let isVisibleBtn = !u.isEmpty(worldWarUrlBtnKey)
    let btnObj = showObjById("ww_wiki", isVisibleBtn, this.scene)
    if (!isVisibleBtn || !btnObj?.isValid())
      return

    btnObj.link = getCurCircuitOverride($"wikiWWar{worldWarUrlBtnKey}URL", loc($"url/wWarBtn/{worldWarUrlBtnKey}"))
    btnObj.findObject("ww_wiki_text").setValue(loc($"worldwar/urlBtn/{worldWarUrlBtnKey}"))
  }

  function updateRewardsPanel() {
    let rewards = this.fillTrophyList().extend(this.fillUnlocksList())
    let isRewardsVisible = rewards.len() > 0
    showObjById("rewards_panel", isRewardsVisible, this.scene)
    if (isRewardsVisible)
      this.fillRewards(rewards)
  }

  function onTimerBeginMapWaitTime(_obj, _dt) {
    this.updateBeginMapWaitTime()
  }

  function updateBeginMapWaitTime() {
    let waitTime = this.nearestAvailableMapToBattle?.getChangeStateTime?() ?? -1
    if (waitTime <= 0)
      return

    let waitMapInfoObj = this.scene.findObject("begin_map_wait_time_text")
    if (!checkObj(waitMapInfoObj))
      return

    waitMapInfoObj.setValue(loc("worldwar/operation/willBegin", {
      name = this.nearestAvailableMapToBattle.getNameText()
      time = this.nearestAvailableMapToBattle.getChangeStateTimeText() }))
  }

  function showSeasonIsOverNotice() {
    let curDay = time.getUtcDays()
    let seasonOverNotice = loadLocalAccountSettings(WW_DAY_SEASON_OVER_NOTICE, 0)
      + WW_SEASON_OVER_NOTICE_PERIOD_DAYS
    if (seasonOverNotice && seasonOverNotice > curDay)
      return
    saveLocalAccountSettings(WW_DAY_SEASON_OVER_NOTICE, curDay)
    scene_msg_box("season_is_over_notice", null, loc("worldwar/seasonIsOverNotice"),
      [["ok", null]], "ok")
  }

  function onOpenAchievements() {
    guiStartProfile({
      initialSheet = "UnlockAchievement"
      curAchievementGroupName = unlocksChapterName
    })
  }

  function getUnlockObj(containerObj, idx) {
    if (containerObj.childrenCount() > idx)
        return containerObj.getChild(idx)

    return containerObj.getChild(idx - 1).getClone(containerObj, this)
  }

  function getSelectedConflictSideObj() {
    let countriesContainerObj = this.scene.findObject("countries_container")
    if (!checkObj(countriesContainerObj))
      return null

    let value = getObjValidIndex(countriesContainerObj)
    if (value < 0)
      return null

    return countriesContainerObj.getChild(value)
  }

  function onToBattles() {
    let sideObj = this.getSelectedConflictSideObj()
    if (!checkObj(sideObj))
      return

    this.onFindOperationBtn(sideObj)
  }

  function onBackOperationForSelectSide() {
    let sideObj = this.getSelectedConflictSideObj()
    if (!checkObj(sideObj))
      return

    this.onBackOperation(sideObj)
  }

  function onMapSideAction() {
    let sideObj = this.getSelectedConflictSideObj()
    if (!checkObj(sideObj))
      return

    let isInQueue = isMyClanInQueue()
    let isQueueJoiningEnabled =  ::WwQueue.getCantJoinAnyQueuesReasonData().canJoin
    let isMyClanOperation = this.selMap != null && this.hasClanOperation &&
      getMyClanOperation()?.data.map == this.selMap?.name
    if (this.selMap?.isClanQueueAvaliable() && isQueueJoiningEnabled && !isInQueue)
      this.onJoinQueue(sideObj)
    else if ((this.hasClanOperation || isInQueue) && this.hasRightsToQueueClan && isInQueue)
      this.onLeaveQueue()
    else if (isMyClanOperation)
      this.onJoinClanOperation(sideObj)
  }

  function checkSeasonIsOverNotice() {
    if (!isReceivedGlobalStatusMaps())
      return

    this.needCheckSeasonIsOverNotice = false
    if (!::g_world_war.isWWSeasonActive())
      this.showSeasonIsOverNotice()
  }

  function onSelectedMapInvalidate() {
    this.findMapForSelection()
    this.updateDescription()
    this.updateButtons()
  }

  function onEventUpdateClansInfoList(p) {
    addClanTagToNameInLeaderbord(this.scene.findObject("top_global_managers"), p?.clansInfoList ?? {})
  }

  function onEventProfileUpdated(_) {
    // Update view for new role rights
    this.updateWindow()
  }
}

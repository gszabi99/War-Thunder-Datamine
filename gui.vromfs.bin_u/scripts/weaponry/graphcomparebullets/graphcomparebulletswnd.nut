from "%scripts/dagui_library.nut" import *
let { eventbus_send } = require("eventbus")
let { get_time_msec } = require("dagor.time")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { loadProtectionAnalysisOptionsHandler } = require("%scripts/dmViewer/protectionAnalysisOptionsHandler.nut")
let bulletsBallisticOptions = require("%scripts/weaponry/graphCompareBullets/bulletsBallisticOptions.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { enableObjsByTable } = require("%sqDagui/daguiUtil.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")
let { graphColorList, getBulletCacheSaveId
} = require("%scripts/weaponry/graphCompareBullets/bulletsGraphState.nut")
let { round_by_value } = require("%sqstd/math.nut")
let { secondsToMilliseconds, millisecondsToSeconds } = require("%sqstd/time.nut")
let { getStatCardInfo } = require("%scripts/unit/statCardInfo.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")


const MAX_PLAY_VALUE = 1000

let isSameBullets = @(bullet1, bullet2)
  bullet1.bulletName == bullet2.bulletName && bullet1.weaponBlkName == bullet2.weaponBlkName

let getShotSettingsValues = @(shotSettings) shotSettings.reduce(
  function(res, setting) {
    let { id = "", value = null } = setting
    if (value != null)
      res[id] <- value
    return res
  },
  {})

function getMaxFlightTimeMs(graphParams) {
  local maxFlightTime = 0
  foreach (graph in graphParams) {
    let { graphData } = graph
    maxFlightTime = max(maxFlightTime, graphData.len() > 0 ? graphData.top().flightTime : 0)
  }

  return secondsToMilliseconds(maxFlightTime).tointeger()
}

let getPlayTimeMs = @(playValue, maxPlayTimeMs) playValue * maxPlayTimeMs / MAX_PLAY_VALUE

function getStartPlayingTime(curPlayValue, maxPlayTimeMs) {
  let curTimeMs = get_time_msec()
  if (curPlayValue == 0)
    return curTimeMs

  return curTimeMs - getPlayTimeMs(curPlayValue, maxPlayTimeMs)
}

function getUnitRocketStructure() {
  let structure = {}
  let statCardInfo = getStatCardInfo()

  foreach (unit in getAllUnits()) {
    if (!unit.isVisibleInShop())
      continue

    let { name, esUnitType, shopCountry, rank } = unit
    if (!(statCardInfo?[name].hasRockets ?? false)
        && (esUnitType == ES_UNIT_TYPE_AIRCRAFT || esUnitType == ES_UNIT_TYPE_HELICOPTER))
      continue

    if (esUnitType not in structure)
      structure[esUnitType] <- {}

    if (shopCountry not in structure[esUnitType])
      structure[esUnitType][shopCountry] <- {}

    if (rank not in structure[esUnitType][shopCountry])
      structure[esUnitType][shopCountry][rank] <- {}

    if (name not in structure[esUnitType][shopCountry][rank])
      structure[esUnitType][shopCountry][rank][name] <- true
  }

  return structure
}


let GraphCompareBulletsWnd = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/weaponry/bulletsBallisticParametersWnd.blk"
  widgetsList = [
    {
      widgetId = DargWidgets.BULLETS_GRAPH
      placeholderId = "graph_nest"
    }
  ]
  pagesConfig = null
  unit = null
  ammoName = null
  shotSettings = null
  canBeComparedBulletsByUnitType = null

  optionsHandler = null
  updateBulletsGraphDealyedTimer = null

  curBullet = null
  compareBulletsList = null

  curPage = null
  curSubPageIdx = null
  cacheForPages = null
  hasRequestGraphData = false

  maxPlayTimeMs = 0
  curPlayValue = 0
  startPlayingTimeMs = 0

  applySelectedOptionAfterInit = false

  function initScreen() {
    this.compareBulletsList = []
    this.cacheForPages = {}

    let optionsHandler = loadProtectionAnalysisOptionsHandler({
      scene            = this.scene.findObject("options_list_nest")
      unit             = this.unit
      ammoName         = this.ammoName
      optionsList      = bulletsBallisticOptions
      onChangeOptionCb = Callback(this.onChangeOption, this)
      goBackCb         = Callback(this.goBack, this)
      structure        = getUnitRocketStructure()
    })

    this.registerSubHandler(optionsHandler)
    this.optionsHandler = optionsHandler.weakref()
    this.curBullet = bulletsBallisticOptions.BULLET.value
    this.fillTabs()
    if (this.applySelectedOptionAfterInit)
      this.guiScene.performDelayed(this, @() this.onAddBulletForCompare())
  }

  function fillTabs() {
    let pagesCount = this.pagesConfig.len()
    let tabs = []
    foreach (idx, page in this.pagesConfig) {
      let { id, locId, cacheDataId } = page
      this.cacheForPages[cacheDataId] <- {}
      tabs.append({
        id
        tabName = loc(locId)
        navImagesText = getNavigationImagesText(idx, pagesCount)
      })
    }
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", { tabs })
    let tabsObj = this.scene.findObject("tabs_list")
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(0)
  }

  function fillSubTabs() {
    let { subPages = [] } = this.curPage
    let hasSubPages = subPages.len() > 0
    let subPagesNestObj = showObjById("sub_pages_list_nest", hasSubPages, this.scene)
    if (!hasSubPages)
      return

    let tabs = subPages.map(@(v) {
      id = v.id
      tabName = loc(v.locId)
    })
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", { tabs })
    let subPagesObj = subPagesNestObj.findObject("sub_pages_list")
    this.guiScene.replaceContentFromText(subPagesObj, data, data.len(), this)
    subPagesObj.setValue(this.curSubPageIdx ?? 0)
  }

  function onChangePage(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let newPageId = obj.getChild(value).id
    let newPage = this.pagesConfig.findvalue(@(v) v.id == newPageId)
    if (!newPage || newPage == this.curPage)
      return

    this.curPage = newPage
    this.updateShotSetting()
    this.fillSubTabs()
    this.initPlayerPanel()
    this.updateBulletsGraphData()
  }

  function updateShotSetting() {
    let hasShotSetting = this.curPage?.hasShotSetting ?? false
    let settingsObj = showObjById("shot_settings", hasShotSetting, this.scene)
    if (!hasShotSetting)
      return

    let needFill = settingsObj.childrenCount() == 0
    if (!needFill)
      return

    let rows = []
    foreach (option in this.shotSettings) {
      let { id = null, locId, getControlMarkup = null, getValueText = null,
        value = null, isHeader = false } = option

      let title = loc(locId)
      rows.append({
        id
        name = isHeader ? "".concat(title, loc("ui/colon")) : title
        option = getControlMarkup?(option)
        valueText = getValueText?(value)
        valueWidth = "0.3pw"
        hasValueInHeader = !isHeader
      })
    }
    let data = handyman.renderCached("%gui/options/verticalOptions.tpl", { rows })
    this.guiScene.replaceContentFromText(settingsObj, data, data.len(), this)
  }

  function requestGraphDataImpl() {
    let { id, cacheDataId, requestGraphData, needActualize, getGraphDataFromCache } = this.curPage
    let handlerCb = Callback(function handlerCb(res) {
      this.hasRequestGraphData = false
      if (id != this.curPage?.id)
        return
      let hasBullet = this.hasBulletInBulletsList(res)
      if (hasBullet)
        this.cacheForPages[cacheDataId][getBulletCacheSaveId(res)] <- res
      this.requestGraphDataImpl()
    }, this)

    let settings = this.shotSettings != null ? getShotSettingsValues(this.shotSettings) : null
    let cacheList = this.cacheForPages[cacheDataId]
    let bulletForRequest = this.compareBulletsList.findvalue(
      @(bullet) needActualize(cacheList?[getBulletCacheSaveId(bullet)], settings, bullet))
    if (bulletForRequest != null) {
      this.hasRequestGraphData = true
      requestGraphData(bulletForRequest, settings, handlerCb)
      return
    }

    this.updateBulletsGraphDataImpl(getGraphDataFromCache(this.compareBulletsList, this.cacheForPages[cacheDataId]))
  }

  function requestGraphData() {
    if (this.hasRequestGraphData)
      return

    this.requestGraphDataImpl()
  }

  function updateBulletsGraphData() {
    clearTimer(this.updateBulletsGraphDealyedTimer)
    if (this.curPage == null)
      return

    if ("getGraphData" in this.curPage) { 
      this.updateBulletsGraphDataImpl(this.curPage.getGraphData(this.compareBulletsList))
      return
    }

    this.requestGraphData()
  }

  function updateBulletsGraphDataImpl(graphParams) {
    let { hasPlayerPanel = false } = this.curPage
    this.maxPlayTimeMs = hasPlayerPanel ? getMaxFlightTimeMs(graphParams) : 0
    if (hasPlayerPanel)
      this.updatePlayerPanel()
    let hasBulletsToCompare = this.compareBulletsList.len() > 0
    let graphObj = this.scene.findObject("graph_nest")
    showObjById("empty_graph_nest_text", !hasBulletsToCompare, graphObj)
    let graphData = {
      graphId = this.curPage?.subPages[this.curSubPageIdx].id ?? this.curPage.id
      graphSize = graphObj.getSize()
      graphParams
    }
    let graphPlayerData = {
      maxPlayTimeMs       = this.maxPlayTimeMs
      curPlayTimeMs       = getPlayTimeMs(this.curPlayValue, this.maxPlayTimeMs)
      startPlayingTimeMs  = this.startPlayingTimeMs
    }
    eventbus_send("update_bullets_graph_state", { graphData, graphPlayerData })
  }

  function updateGraphPlayerData() {
    let { hasPlayerPanel = false } = this.curPage
    if (!hasPlayerPanel)
      return
    let graphPlayerData = {
      maxPlayTimeMs      = this.maxPlayTimeMs
      curPlayTimeMs      = getPlayTimeMs(this.curPlayValue, this.maxPlayTimeMs)
      startPlayingTimeMs = this.startPlayingTimeMs
    }
    eventbus_send("update_bullets_graph_state", { graphPlayerData })
  }

  function updateBulletsGraphDataDelayed() {
    clearTimer(this.updateBulletsGraphDealyedTimer)
    let cb = Callback(this.updateBulletsGraphData, this)
    this.updateBulletsGraphDealyedTimer = setTimeout(0.8, @() cb())
  }

  function initPlayerPanel() {
    this.curPlayValue = 0
    this.startPlayingTimeMs = 0
    let { hasPlayerPanel = false } = this.curPage
    let playerPanelObj = showObjById("player_panel", hasPlayerPanel, this.scene)
    playerPanelObj.setUserData(hasPlayerPanel ? this : null)
    if (!hasPlayerPanel)
      return

    this.updatePlayerPanel()
  }

  function updatePlayBtnImg() {
    let playObj = this.scene.findObject("btn_play")
    playObj.findObject("icon")["background-image"] = this.startPlayingTimeMs > 0
      ? "#ui/gameuiskin#replay_pause.svg"
      : "#ui/gameuiskin#replay_play.svg"
  }

  function updatePlayerPanel() {
    this.updatePlayBtnImg()
    let hasPlayTime = this.maxPlayTimeMs > 0
    this.scene.findObject("txt_replay_time_total").setValue(!hasPlayTime ? loc("ui/not_applicable")
      : $"{round_by_value(millisecondsToSeconds(this.maxPlayTimeMs), 0.1)} {loc("measureUnits/seconds")}")
    this.scene.findObject("timeline_progress").enable(hasPlayTime)
    this.updatePlayerPanelCurTime()
  }

  function updatePlayerPanelCurTime() {
    let isPlayEnd = this.curPlayValue >= MAX_PLAY_VALUE
    if (isPlayEnd && this.startPlayingTimeMs > 0) {
      this.startPlayingTimeMs = 0
      this.updatePlayBtnImg()
    }

    let hasPlayTime = this.maxPlayTimeMs > 0
    this.scene.findObject("btn_backward").enable(this.curPlayValue > 0)
    this.scene.findObject("btn_play").enable(hasPlayTime && !isPlayEnd)
    this.scene.findObject("btn_forward").enable(hasPlayTime && !isPlayEnd)
    local curTimeText = loc("ui/not_applicable")
    if (hasPlayTime) {
      let curTimeSec = millisecondsToSeconds(getPlayTimeMs(this.curPlayValue, this.maxPlayTimeMs))
      curTimeText = $"{round_by_value(curTimeSec, 0.1)} {loc("measureUnits/seconds")}"
    }
    this.scene.findObject("txt_replay_time_current").setValue(curTimeText)

    let progressObj = this.scene.findObject("timeline_progress")
    let progressValue = progressObj.getValue()
    if (progressValue != this.curPlayValue)
      progressObj.setValue(this.curPlayValue)
  }

  hasBulletInBulletsList = @(bullet) this.compareBulletsList.findvalue(@(v) isSameBullets(v, bullet)) != null

  canAddCurBullet = @() this.compareBulletsList.len() < graphColorList.len()
    && this.curBullet != null
    && !this.hasBulletInBulletsList(this.curBullet)
    && (this.canBeComparedBulletsByUnitType?(this.curBullet, this.compareBulletsList) ?? true)

  function onChangeOption() {
    let newBulletValue = bulletsBallisticOptions.BULLET.value
    if (this.curBullet == newBulletValue)
      return

    if (newBulletValue != null && this.curBullet != null && isSameBullets(this.curBullet, newBulletValue))
      return

    this.curBullet = newBulletValue
    this.updateButtons()
  }

  function updateButtons() {
    let canAddBullet = this.canAddCurBullet()
    let addBtnObj = this.scene.findObject("btn_add_bullet_for_compare")
    addBtnObj.inactiveColor = canAddBullet ? "no" : "yes"
  }

  function onAddBulletForCompare() {
    if (this.curBullet == null) {
      showInfoMsgBox(loc("msg/bulletForCompare/needSelectBullet"))
      return
    }

    if (this.hasBulletInBulletsList(this.curBullet)) {
      showInfoMsgBox(loc("msg/bulletForCompare/alreadyAddedForComparison"))
      return
    }

    let maxCount = graphColorList.len()
    if (this.compareBulletsList.len() >= maxCount) {
      showInfoMsgBox(loc("msg/bulletForCompare/maximumBulletsCountReached", { maxCount }))
      return
    }

    if (!(this.canBeComparedBulletsByUnitType?(this.curBullet, this.compareBulletsList) ?? true)) {
      showInfoMsgBox(loc("msg/bulletForCompare/bulletsCannotBeComparedByUnitTypes"))
      return
    }

    this.compareBulletsList.append(this.curBullet)
    this.updateBulletsGraphData()
    this.updateButtons()
    this.updateBulletInList(this.compareBulletsList.len() - 1)
  }

  function getBulletObj(idx) {
    let bulletsListObj = this.scene.findObject("bullets_list")
    if (bulletsListObj.childrenCount() > idx)
      return bulletsListObj.getChild(idx)

    return bulletsListObj.getChild(idx - 1).getClone(bulletsListObj, this)
  }

  function updateBulletInList(idx) {
    let obj = this.getBulletObj(idx)
    let bulletData = this.compareBulletsList?[idx]
    let isShow = !!bulletData
    obj.show(isShow)
    if (!isShow)
      return

    let deleteBtnObj = obj.findObject("delete_btn")
    deleteBtnObj.holderId = idx.tostring()
    obj.findObject("bullet_name").setValue(bulletData.locName)
    obj.findObject("graph_legend").graphColor = graphColorList[idx].hex
    obj.findObject("tooltip_nest").tooltipId = bulletData.tooltipId
    let layeredIcon = handyman.renderCached("%gui/weaponry/bullets.tpl", bulletData.layeredIconData)
    this.guiScene.replaceContentFromText(obj.findObject("bullet_icon"), layeredIcon, layeredIcon.len(), this)
  }

  function removeCachesForBullet(bullet) {
    let cacheId = getBulletCacheSaveId(bullet)
    foreach (page in this.pagesConfig) {
      let { cacheDataId = "" } = page
      let cacheList = this.cacheForPages[cacheDataId]
      if (cacheId not in cacheList)
        continue
      cacheList.$rawdelete(cacheId)
    }
  }

  function onDeleteBullet(obj) {
    let bulletIdx = obj.holderId.tointeger()
    if (bulletIdx not in this.compareBulletsList)
      return

    let curVisibleBulletCount = this.compareBulletsList.len()
    let bullet = this.compareBulletsList.remove(bulletIdx)
    this.removeCachesForBullet(bullet)
    for (local idx = bulletIdx; idx < curVisibleBulletCount; idx++)
      this.updateBulletInList(idx)

    this.updateBulletsGraphData()
    this.updateButtons()
  }

  getShotSettingById = @(id) this.shotSettings?.findvalue(@(v) v?.id == id)

  onButtonInc = @(obj) this.onProgressButton(obj, true)
  onButtonDec = @(obj) this.onProgressButton(obj, false)
  function onProgressButton(obj, isIncrement) {
    if (!obj?.isValid())
      return
    let optionId = cutPrefix(obj.getParent().id, "container_", "")
    let option = this.getShotSettingById(optionId)
    if (option == null)
      return
    let value = option.value + (isIncrement ? option.step : -option.step)
    this.scene.findObject(option.id).setValue(value)
  }

  function onChangeSliderValue(obj) {
    let option = this.getShotSettingById(obj.id)
    if (option == null)
      return

    let newValue = obj.getValue()
    if (option.value == newValue)
      return

    option.value = newValue
    let parentObj = obj.getParent().getParent()
    parentObj.findObject($"value_{option.id}").setValue(option.getValueText(newValue))
    enableObjsByTable(parentObj, {
      buttonInc = option.value < option.maxValue
      buttonDec = option.value > option.minValue
    })
    this.updateBulletsGraphDataDelayed()
  }

  function onChangeSubPage(obj) {
    let { subPages = null } = this.curPage
    if (subPages == null)
      return

    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let newSubPageId = obj.getChild(value).id
    let newSubPageIdx = subPages.findindex(@(v) v.id == newSubPageId)
    if (newSubPageIdx == null || newSubPageIdx == this.curSubPageIdx)
      return

    this.curSubPageIdx = newSubPageIdx
    this.updateBulletsGraphData()
  }

  function onBtnBackward() {
    this.curPlayValue = 0
    if (this.startPlayingTimeMs != 0)
      this.startPlayingTimeMs = get_time_msec()
    this.updatePlayerPanelCurTime()
    this.updateGraphPlayerData()
  }

  function onBtnForward() {
    this.curPlayValue = MAX_PLAY_VALUE
    this.updatePlayerPanelCurTime()
    this.updateGraphPlayerData()
  }

  function onBtnPlayToggle() {
    this.startPlayingTimeMs = this.startPlayingTimeMs > 0 ? 0
      : getStartPlayingTime(this.curPlayValue, this.maxPlayTimeMs)
    this.updatePlayBtnImg()
    this.updateGraphPlayerData()
  }

  function onChangeTimelineValue(sliderObj) {
    let newValue = sliderObj.getValue()
    if (newValue == this.curPlayValue)
      return
    this.curPlayValue = newValue
    if (this.startPlayingTimeMs != 0)
      this.startPlayingTimeMs = getStartPlayingTime(this.curPlayValue, this.maxPlayTimeMs)
    this.updatePlayerPanelCurTime()
    this.updateGraphPlayerData()
  }

  function onUpdatePlayerPanelByTimer(_obj, _dt) {
    if (this.startPlayingTimeMs == 0)
      return

    let curPlayTime = get_time_msec() - this.startPlayingTimeMs
    this.curPlayValue = this.maxPlayTimeMs == 0 ? 0
      : min(curPlayTime * MAX_PLAY_VALUE / this.maxPlayTimeMs, MAX_PLAY_VALUE)
    this.updatePlayerPanelCurTime()
  }
}

gui_handlers.GraphCompareBulletsWnd <- GraphCompareBulletsWnd

return {
  GraphCompareBulletsWnd
}

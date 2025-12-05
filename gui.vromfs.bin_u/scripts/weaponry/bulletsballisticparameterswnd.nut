from "%scripts/dagui_library.nut" import *
let { eventbus_send } = require("eventbus")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { loadProtectionAnalysisOptionsHandler } = require("%scripts/dmViewer/protectionAnalysisOptionsHandler.nut")
let bulletsBallisticOptions = require("%scripts/weaponry/bulletsBallisticOptions.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { register_command } = require("console")
let { buildBallisticTrajectoryData } = require("unitCalculcation")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { enableObjsByTable } = require("%sqDagui/daguiUtil.nut")
let { setTimeout, clearTimer } = require("dagor.workcycle")

let graphColorList = [
  {
    int = 0xFF1E7FFF 
    hex = "FF1E7FFF"
  }
  {
    int = 0xFF21B34A, 
    hex = "FF21B34A"
  }
  {
    int = 0xFFD03F29, 
    hex = "FFD03F29"
  }
  {
    int = 0xFFDCAA54, 
    hex = "FFDCAA54"
  }
  {
    int = 0xFFD34FE2, 
    hex = "FFD34FE2"
  }
]

let getPenetrationData = @(compareBulletsList) compareBulletsList.map(@(bullet, idx) {
  graphColor = graphColorList[idx].int
  armorPiercingDist = clone (bullet?.bulletParams.armorPiercingDist ?? [])
  armorPiercing = bullet?.bulletParams.armorPiercing.map(@(v) v[0]) ?? []
})

function requestBallisticsData(bullet, settings, handlerCb) {
  let { shotAngle } = settings
  let { unitName, weaponBlkName, bulletName } = bullet
  let cb = @(ballisticsData) handlerCb({ unitName, weaponBlkName, bulletName, shotAngle, ballisticsData })
  buildBallisticTrajectoryData(weaponBlkName, bulletName, shotAngle, cb)
}

let isSameBullets = @(bullet1, bullet2) bullet1.unitName == bullet2.unitName
  && bullet1.bulletName == bullet2.bulletName && bullet1.weaponBlkName == bullet2.weaponBlkName

let getCacheSaveId = @(bullet) $"{bullet.unitName}_{bullet.weaponBlkName}_{bullet.bulletName}"

let getBallisticsData = @(compareBulletsList, cacheBulletsData)
  compareBulletsList.map(@(bullet, idx) {
    graphColor = graphColorList[idx].int
    ballisticsData = cacheBulletsData?[getCacheSaveId(bullet)].ballisticsData ?? []
  })

let bulletsParametersPages = [
  {
    id = "pageBallistics"
    cacheDataId = "pageBallisticsData"
    locId = "mainmenu/ballistics"
    requestGraphData = requestBallisticsData
    needActualize = @(cacheData, settings) cacheData?.shotAngle != settings.shotAngle
    getGraphDataFromCache = getBallisticsData
    hasShotSetting = true
  }
  {
    id = "pagePenetration"
    locId = "bullet_properties/armorPiercing"
    getGraphData = getPenetrationData
    hasShotSetting = false
  }
]

let shotSettings = [
  {
    id = "shotAngle"
    locId = "mainmenu/angle"
    valueWidth = "fw"
    minValue = 0
    maxValue = 90
    step = 1
    value = 10

    getValueText = @(value) $"{value}{loc("measureUnits/deg")}"
    function getControlMarkup() {
      return handyman.renderCached("%gui/dmViewer/distanceSlider.tpl", {
        containerId =$"container_{this.id}"
        id = this.id
        min = this.minValue
        max = this.maxValue
        value = this.value
        step = this.step
        width = "fw"
        btnOnDec = "onButtonDec"
        btnOnInc = "onButtonInc"
        onChangeSliderValue = "onChangeSliderValue"
      })
    }
  }
]

let getShotSettingsValues = @() shotSettings.reduce(
  function(res, setting) {
    res[setting.id] <- setting.value
    return res
  },
  {})

let getShotSettingById = @(id) shotSettings.findvalue(@(v) v.id == id)

let BulletsBallisticParametersWnd = class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName         = "%gui/weaponry/bulletsBallisticParametersWnd.blk"
  widgetsList = [
    {
      widgetId = DargWidgets.BULLETS_GRAPH
      placeholderId = "graph_nest"
    }
  ]
  unit = null
  ammoName = null
  optionsHandler = null
  updateBulletsGraphDealyedTimer = null

  curBullet = null
  compareBulletsList = null

  curPage = null
  pageBallisticsData = null
  hasRequestGraphData = false

  function initScreen() {
    this.compareBulletsList = []
    let optionsHandler = loadProtectionAnalysisOptionsHandler({
      scene            = this.scene.findObject("options_list_nest")
      unit             = this.unit
      ammoName         = this.ammoName
      optionsList      = bulletsBallisticOptions
      onChangeOptionCb = Callback(this.onChangeOption, this)
      goBackCb         = Callback(this.goBack, this)
    })
    this.registerSubHandler(optionsHandler)
    this.optionsHandler = optionsHandler.weakref()
    this.curBullet = bulletsBallisticOptions.BULLET.value
    this.fillTabs()
  }

  function fillTabs() {
    let pagesCount = bulletsParametersPages.len()
    let view = {
      tabs = bulletsParametersPages.map(@(v, idx) {
        id = v.id
        tabName = loc(v.locId)
        navImagesText = getNavigationImagesText(idx, pagesCount)
      })
    }
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let tabsObj = this.scene.findObject("tabs_list")
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)
    tabsObj.setValue(0)
  }

  function onChangePage(obj) {
    let value = obj.getValue()
    if (value < 0 || value >= obj.childrenCount())
      return

    let newPageId = obj.getChild(value).id
    let newPage = bulletsParametersPages.findvalue(@(v) v.id == newPageId)
    if (!newPage || newPage == this.curPage)
      return

    this.curPage = newPage
    this.updateShotSetting()
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

    let view = { rows = shotSettings.map(@(v) {
      id = v.id
      name = loc(v.locId)
      option = v.getControlMarkup()
      valueWidth = v.valueWidth
      valueText= v.getValueText(v.value)
    })}
    let data = handyman.renderCached("%gui/options/verticalOptions.tpl", view)
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
        this[cacheDataId][getCacheSaveId(res)] <- res
      this.requestGraphDataImpl()
    }, this)

    let settings = getShotSettingsValues()
    let cacheList = this?[cacheDataId]
    let bulletForRequest = this.compareBulletsList.findvalue(
      @(bullet) needActualize(cacheList?[getCacheSaveId(bullet)], settings))
    if (bulletForRequest != null) {
      this.hasRequestGraphData = true
      requestGraphData(bulletForRequest, settings, handlerCb)
      return
    }

    this.updateBulletsGraphDataImpl(getGraphDataFromCache(this.compareBulletsList, this[cacheDataId]))
  }

  function requestGraphData() {
    if (this.hasRequestGraphData)
      return

    let { cacheDataId } = this.curPage
    if (this[cacheDataId] == null)
      this[cacheDataId] = {}

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
    let hasBulletsToCompare = this.compareBulletsList.len() > 0
    let graphObj = this.scene.findObject("graph_nest")
    showObjById("empty_graph_nest_text", !hasBulletsToCompare, graphObj)
    let res = {
      graphSize = graphObj.getSize()
      graphParams
    }
    eventbus_send("update_bullets_graph_state", res)
  }

  function updateBulletsGraphDataDelayed() {
    clearTimer(this.updateBulletsGraphDealyedTimer)
    let cb = Callback(this.updateBulletsGraphData, this)
    this.updateBulletsGraphDealyedTimer = setTimeout(0.8, @() cb())
  }

  hasBulletInBulletsList = @(bullet) this.compareBulletsList.findvalue(@(v) isSameBullets(v, bullet)) != null

  canAddCurBullet = @() this.compareBulletsList.len() < graphColorList.len()
    && this.curBullet != null
    && !this.hasBulletInBulletsList(this.curBullet)

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
    let cacheId = getCacheSaveId(bullet)
    foreach (page in bulletsParametersPages) {
      let { cacheDataId = "" } = page
      let cacheList = this?[cacheDataId]
      if (cacheList == null) 
        continue
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

  onButtonInc = @(obj) this.onProgressButton(obj, true)
  onButtonDec = @(obj) this.onProgressButton(obj, false)
  function onProgressButton(obj, isIncrement) {
    if (!obj?.isValid())
      return
    let optionId = cutPrefix(obj.getParent().id, "container_", "")
    let option = getShotSettingById(optionId)
    if (option == null)
      return
    let value = option.value + (isIncrement ? option.step : -option.step)
    this.scene.findObject(option.id).setValue(value)
  }

  function onChangeSliderValue(obj) {
    let option = getShotSettingById(obj.id)
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
}

gui_handlers.BulletsBallisticParametersWnd <- BulletsBallisticParametersWnd

let openBulletsBallisticParametersWnd = @(p) handlersManager.loadHandler(BulletsBallisticParametersWnd, p)

register_command(@() openBulletsBallisticParametersWnd({ unit = getAircraftByName("us_mbt_70") }), "debug.open_bullets_ballistic_parameters_wnd")

return {
  openBulletsBallisticParametersWnd
}

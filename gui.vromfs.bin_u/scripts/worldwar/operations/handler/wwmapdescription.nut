from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let WwQueue = require("%scripts/worldWar/externalServices/wwQueue.nut")

let WwOperation = require("%scripts/worldWar/operations/model/wwOperation.nut")

let g_world_war = require("%scripts/worldWar/worldWarUtils.nut")


gui_handlers.WwMapDescription <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM

  descItem = null 
  map = null
  needEventHeader = true
  descParams = null

  rootDescId = "item_desc"

  
  static function link(v_scene, v_descItem = null, v_map = null, v_descParams = {}) {
    let params = {
      scene = v_scene
      descItem = v_descItem
      map = v_map
      descParams = v_descParams
    }

    if ((!v_descItem && v_map) || (v_descItem instanceof WwOperation))
      return handlersManager.loadHandler(gui_handlers.WwOperationDescriptionCustomHandler, params)
    else if (v_descItem instanceof WwQueue)
      return handlersManager.loadHandler(gui_handlers.WwQueueDescriptionCustomHandler, params)
  }

  function initScreen() {
    this.scene.setUserData(this) 
    this.updateView()

    let timerObj = this.scene.findObject("ww_map_description_timer")
    if (timerObj)
      timerObj.setUserData(this)
  }

  function setDescItem(newDescItem) {
    this.descItem = newDescItem
    this.updateView()
  }

  function initCustomHandlerScene() {
    
    this.guiScene = this.scene.getScene()
    return true
  }

  function updateView() {
    let isShow = this.isVisible()
    this.updateVisibilities(isShow)
    if (!isShow)
      return

    this.updateName()
    this.updateDescription()
    this.updateCountriesList()
    this.updateTotalClansText()
    this.updateAvailableText()
  }

  function isVisible() {
    return this.descItem != null && this.map != null
  }

  function updateVisibilities(isShow) {
    if (this.scene.id == this.rootDescId)
      this.scene.show(isShow)
    else
      showObjById(this.rootDescId, isShow, this.scene)
  }

  function updateName() {
    let nameObj = this.scene.findObject("item_name")
    if (checkObj(nameObj))
      nameObj.setValue(this.descItem.getNameText())
  }

  function updateDescription() {
    let desctObj = this.scene.findObject("item_desc")
    if (checkObj(desctObj))
      desctObj.setValue(this.descItem.getDescription())
  }

  function mapCountriesToView(countries) {
    let mapName = this.descItem.getId()
    return {
      countries = countries.map(@(countryName) {
        countryName = countryName
        countryIcon = getCustomViewCountryData(countryName, mapName).icon
      })
    }
  }

  function updateCountriesList() {
    let obj = this.scene.findObject("div_before_text")
    if (!checkObj(obj))
      return

    let cuntriesByTeams = this.descItem.getCountriesByTeams()
    let sides = []
    foreach (side in g_world_war.getCommonSidesOrder())
      sides.append(this.mapCountriesToView(cuntriesByTeams?[side] ?? []))
    let view = {
      sides = sides
      vsText = "".concat(loc("country/VS"), "\n ")
    }

    let data = handyman.renderCached("%gui/worldWar/wwOperationCountriesInfo.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)
    obj.show(true)
  }

  function updateTotalClansText() {
    let obj = this.scene.findObject("total_members_text")
    if (!checkObj(obj))
      return

    obj.setValue(this.descItem.getClansNumberInQueueText())
  }

  function updateAvailableText() {
    let obj = this.scene.findObject("available_text")
    if (!checkObj(obj) || !this.descItem)
      return

    obj.setValue(this.descItem.getMapChangeStateTimeText())
  }

  function onTimerDescriptionUpdate(_obj, _dt) {
    this.updateAvailableText()
  }

  onJoinQueue = @(obj) this.descParams?.onJoinQueueCb(obj)
  onLeaveQueue = @() this.descParams?.onLeaveQueueCb()
  onJoinClanOperation = @(obj) this.descParams?.onJoinClanOperationCb(obj)
  onFindOperationBtn = @(obj) this.descParams?.onFindOperationBtnCb(obj)
  onMapSideAction = @() this.descParams?.onMapSideActionCb()
  onToBattles = @() this.descParams?.onToBattlesCb()
  onBackOperation = @(obj) this.descParams?.onBackOperationCb(obj)
  onBackOperationForSelectSide = @() this.descParams?.onBackOperationForSelectSideCb()
}

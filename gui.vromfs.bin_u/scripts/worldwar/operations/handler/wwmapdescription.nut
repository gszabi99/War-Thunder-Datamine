//-file:plus-string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


//show info about WwMap, WwOperation or WwOperationgroup
::gui_handlers.WwMapDescription <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.CUSTOM

  descItem = null //WwMap, WwQueue, WwOperation, WwOperationGroup
  map = null
  needEventHeader = true
  descParams = null

  rootDescId = "item_desc"

  //this handler dosnt create own scene, just search objects in already exist scene.
  static function link(v_scene, v_descItem = null, v_map = null, v_descParams = {}) {
    let params = {
      scene = v_scene
      descItem = v_descItem
      map = v_map
      descParams = v_descParams
    }

    if ((!v_descItem && v_map) || (v_descItem instanceof ::WwOperation))
      return ::handlersManager.loadHandler(::gui_handlers.WwOperationDescriptionCustomHandler, params)
    else if (v_descItem instanceof ::WwQueue)
      return ::handlersManager.loadHandler(::gui_handlers.WwQueueDescriptionCustomHandler, params)
  }

  function initScreen() {
    this.scene.setUserData(this) //to not unload handler even when scene not loaded
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
    //this handler dosnt replace content in scene.
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
      this.showSceneBtn(this.rootDescId, isShow)
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
    foreach (side in ::g_world_war.getCommonSidesOrder())
      sides.append(this.mapCountriesToView(cuntriesByTeams?[side] ?? []))
    let view = {
      sides = sides
      vsText = loc("country/VS") + "\n "
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

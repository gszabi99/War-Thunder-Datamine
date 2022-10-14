from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { getCustomViewCountryData } = require("%scripts/worldWar/inOperation/wwOperationCustomAppearance.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")


//show info about WwMap, WwOperation or WwOperationgroup
::gui_handlers.WwMapDescription <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM

  descItem = null //WwMap, WwQueue, WwOperation, WwOperationGroup
  map = null
  needEventHeader = true
  descParams = null

  rootDescId = "item_desc"

  //this handler dosnt create own scene, just search objects in already exist scene.
  static function link(v_scene, v_descItem = null, v_map = null, v_descParams = {})
  {
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

  function initScreen()
  {
    scene.setUserData(this) //to not unload handler even when scene not loaded
    updateView()

    let timerObj = scene.findObject("ww_map_description_timer")
    if (timerObj)
      timerObj.setUserData(this)
  }

  function setDescItem(newDescItem)
  {
    descItem = newDescItem
    updateView()
  }

  function initCustomHandlerScene()
  {
    //this handler dosnt replace content in scene.
    guiScene = scene.getScene()
    return true
  }

  function updateView()
  {
    let isShow = isVisible()
    updateVisibilities(isShow)
    if (!isShow)
      return

    updateName()
    updateDescription()
    updateCountriesList()
    updateTotalClansText()
    updateAvailableText()
  }

  function isVisible()
  {
    return descItem != null && map != null
  }

  function updateVisibilities(isShow)
  {
    if (scene.id == rootDescId)
      scene.show(isShow)
    else
      this.showSceneBtn(rootDescId, isShow)
  }

  function updateName()
  {
    let nameObj = scene.findObject("item_name")
    if (checkObj(nameObj))
      nameObj.setValue(descItem.getNameText())
  }

  function updateDescription()
  {
    let desctObj = scene.findObject("item_desc")
    if (checkObj(desctObj))
      desctObj.setValue(descItem.getDescription())
  }

  function mapCountriesToView(countries)
  {
    let mapName = descItem.getId()
    return {
      countries = countries.map(@(countryName) {
        countryName = countryName
        countryIcon = getCustomViewCountryData(countryName, mapName).icon
      })
    }
  }

  function updateCountriesList()
  {
    let obj = scene.findObject("div_before_text")
    if (!checkObj(obj))
      return

    let cuntriesByTeams = descItem.getCountriesByTeams()
    let sides = []
    foreach (side in ::g_world_war.getCommonSidesOrder())
      sides.append(mapCountriesToView(cuntriesByTeams?[side] ?? []))
    let view = {
      sides = sides
      vsText = loc("country/VS") + "\n "
    }

    let data = ::handyman.renderCached("%gui/worldWar/wwOperationCountriesInfo", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)
    obj.show(true)
  }

  function updateTotalClansText()
  {
    let obj = scene.findObject("total_members_text")
    if (!checkObj(obj))
      return

    obj.setValue(descItem.getClansNumberInQueueText())
  }

  function updateAvailableText()
  {
    let obj = scene.findObject("available_text")
    if (!checkObj(obj) || !descItem)
      return

    obj.setValue(descItem.getMapChangeStateTimeText())
  }

  function onTimerDescriptionUpdate(obj, dt)
  {
    updateAvailableText()
  }

  onJoinQueue = @(obj) descParams?.onJoinQueueCb(obj)
  onLeaveQueue = @() descParams?.onLeaveQueueCb()
  onJoinClanOperation = @(obj) descParams?.onJoinClanOperationCb(obj)
  onFindOperationBtn = @(obj) descParams?.onFindOperationBtnCb(obj)
  onMapSideAction = @() descParams?.onMapSideActionCb()
  onToBattles = @() descParams?.onToBattlesCb()
  onBackOperation = @(obj) descParams?.onBackOperationCb(obj)
}

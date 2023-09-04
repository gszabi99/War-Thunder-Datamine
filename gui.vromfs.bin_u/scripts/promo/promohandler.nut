//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")


let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { set_blk_value_by_path } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { clearOldVotedPolls, setPollBaseUrl, isPollVoted, generatePollUrl } = require("%scripts/web/webpoll.nut")
let { getPromoHandlerUpdateConfigs } = require("%scripts/promo/promoButtonsConfig.nut")
let { subscribe_handler, add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")

let Promo = class {
  owner = null
  guiScene = null
  scene = null

  sourceDataBlock = null

  widgetsTable = {}

  pollIdToObjectId = {}
  needUpdateByTimerArr = null

  updateFunctions = null

  constructor(handler, v_guiScene, v_scene) {
    this.owner = handler
    this.guiScene = v_guiScene
    this.scene = v_scene

    this.updateFunctions = {}
    foreach (key, config in getPromoHandlerUpdateConfigs()) {
      let { updateFunctionInHandler, updateByEvents } = config
      if (updateFunctionInHandler == null)
        continue

      this.updateFunctions[key] <- @() updateFunctionInHandler()
      foreach (event in (updateByEvents ?? []))
        add_event_listener(event, @(_p) updateFunctionInHandler(), this)
    }

    this.initScreen(true)

    let pollsTable = {}
    for (local j = 0; this.sourceDataBlock != null && j < this.sourceDataBlock.blockCount(); j++) {
      let block = this.sourceDataBlock.getBlock(j)
      if (block?.pollId != null)
        pollsTable[block.pollId] <- true
    }
    clearOldVotedPolls(pollsTable)

    subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function initScreen(forceReplaceContent = false) {
    this.updatePromoBlocks(forceReplaceContent)
  }

  function updatePromoBlocks(forceReplaceContent = false) {
    if (!::g_promo.requestUpdate() && !forceReplaceContent)
      return

    this.sourceDataBlock = ::g_promo.getConfig()
    this.updateAllBlocks()
  }

  function updateAllBlocks() {
    this.needUpdateByTimerArr = []
    let data = this.generateData()
    let topPositionPromoPlace = this.scene.findObject("promo_mainmenu_place_top")
    if (checkObj(topPositionPromoPlace))
      this.guiScene.replaceContentFromText(topPositionPromoPlace, data.upper, data.upper.len(), this)

    let bottomPositionPromoPlace = this.scene.findObject("promo_mainmenu_place_bottom")
    if (checkObj(bottomPositionPromoPlace))
      this.guiScene.replaceContentFromText(bottomPositionPromoPlace, data.bottom, data.bottom.len(), this)

    ::g_promo.initWidgets(this.scene, this.widgetsTable)
    this.updateData()
    this.setTimers()
  }

  function onSceneActivate(show) {
    if (show)
      this.updatePromoBlocks()
  }

  function toggleSceneVisibility(isShow) {
    this.scene.show(isShow)
    this.onSceneActivate(isShow)
  }

  function generateData() {
    this.widgetsTable = {}
    let upperPromoView = {
      showAllCheckBoxEnabled = ::g_promo.canSwitchShowAllPromoBlocksFlag()
      showAllCheckBoxValue = ::g_promo.getShowAllPromoBlocks()
      promoButtons = []
    }

    let bottomPromoView = {
      showAllCheckBoxEnabled = false
      promoButtons = []
    }

    for (local i = 0; this.sourceDataBlock != null && i < this.sourceDataBlock.blockCount(); i++) {
      let block = this.sourceDataBlock.getBlock(i)

      let blockView = ::g_promo.generateBlockView(block)
      let blockId = blockView.id
      if (block?.pollId != null) {
        if (::g_promo.getVisibilityById(blockId)) //add pollId to request only for visible promo
          setPollBaseUrl(block.pollId, block?.link)
        this.pollIdToObjectId[block.pollId] <- blockId
      }

      if (block?.bottom != null)
        bottomPromoView.promoButtons.append(blockView)
      else
        upperPromoView.promoButtons.append(blockView)

      if (blockView?.notifyNew && !::g_promo.isWidgetSeenById(blockId))
        this.widgetsTable[blockId] <- {}

      let playlistArray = this.getPlaylistArray(block)
      if (playlistArray.len() > 0) {
        let requestStopPlayTimeSec = block?.requestStopPlayTimeSec || ::g_promo.DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC
        ::g_promo.enablePlayMenuMusic(playlistArray, requestStopPlayTimeSec)
      }

      if (blockView.needUpdateByTimer)
        this.needUpdateByTimerArr.append(blockId)
    }
    return {
      upper = handyman.renderCached("%gui/promo/promoBlocks.tpl", upperPromoView)
      bottom = handyman.renderCached("%gui/promo/promoBlocks.tpl", bottomPromoView)
    }
  }

  function setTplView(tplPath, object, view = {}) {
    if (!checkObj(object))
      return

    let data = handyman.renderCached(tplPath, view)
    this.guiScene.replaceContentFromText(object, data, data.len(), this)
  }

  function updateData() {
    if (this.sourceDataBlock == null)
      return

    for (local i = 0; i < this.sourceDataBlock.blockCount(); i++) {
      let block = this.sourceDataBlock.getBlock(i)
      let id = block.getBlockName()
      if (id in this.updateFunctions)
        this.updateFunctions[id].call(this)

      if (block?.pollId != null)
        this.updateWebPollButton({ pollId = block.pollId })

      if (!(block?.multiple ?? false))
        continue

      let btnObj = this.scene.findObject(id)
      if (checkObj(btnObj))
        btnObj.setUserData(this)
    }
  }

  function getPlaylistArray(block) {
    let defaultName = "playlist"
    let langKey = defaultName + "_" + ::g_language.getShortName()
    let list = block?[langKey] ?? block?[defaultName]
    if (!list)
      return []
    return list % "name"
  }

  function performAction(obj) {
    this.performActionWithStatistics(obj, false)
  }

  function performActionWithStatistics(obj, isFromCollapsed) {
    sendBqEvent("CLIENT_POPUP_1", "promo_click", {
      id = ::g_promo.cutActionParamsKey(obj.id),
      collapsed = isFromCollapsed
    })
    let objScene = obj.getScene()
    objScene.performDelayed(
      this,
      (@(owner, obj, widgetsTable) function() { //-ident-hides-ident
        if (!checkObj(obj))
          return

        if (!::g_promo.performAction(owner, obj))
          if (checkObj(obj))
            ::g_promo.setSimpleWidgetData(widgetsTable, obj.id)
      })(this.owner, obj, this.widgetsTable)
    )
  }

  function performActionCollapsed(obj) {
    let buttonObj = obj.getParent()
    this.performActionWithStatistics(buttonObj.findObject(::g_promo.getActionParamsKey(buttonObj.id)), true)
  }

  function onShowAllCheckBoxChange(obj) {
    ::g_promo.setShowAllPromoBlocks(obj.getValue())
  }

  function isShowAllCheckBoxEnabled() {
    if (!this.isValid())
      return false

    let chBoxObj = this.scene.findObject("checkbox_show_all_promo_blocks")
    if (!checkObj(chBoxObj))
      return false

    return chBoxObj.getValue()
  }

  function getBoolParamByIdFromSourceBlock(param, id, defaultValue = false) {
    if (!this.sourceDataBlock?[id][param])
      return null

    local show = getTblValue(param, this.sourceDataBlock[id], defaultValue)
    if (u.isString(show))
      show = show == "yes" ? true : false

    return show
  }

  function isValid() {
    return checkObj(this.scene)
  }

  function onPromoBlocksUpdate(_obj, _dt) {
    this.updatePromoBlocks()
  }

  //----------------- <NAVIGATION> --------------------------

  function getWrapNestObj() {
    if (!this.isValid())
      return null

    for (local i = 0; i < this.scene.childrenCount(); i++) {
      let child = this.scene.getChild(i)
      if (child.isVisible() && child.isEnabled())
        return this.scene
    }

    return null
  }

  //------------------ </NAVIGATION> --------------------------

  //--------------------- <TOGGLE> ----------------------------

  function onToggleItem(obj) { ::g_promo.toggleItem(obj) }

  //-------------------- </TOGGLE> ----------------------------

  //------------------ <WEB POLL> -------------------------

  function updateWebPollButton(param) {
    let pollId = param?.pollId
    let objectId = getTblValue(pollId, this.pollIdToObjectId)
    if (objectId == null)
      return

    let showByLocalConditions = !isPollVoted(pollId) && ::g_promo.getVisibilityById(objectId)
    if (!showByLocalConditions) {
      showObjById(objectId, false, this.scene)
      return
    }

    let link = generatePollUrl(pollId)
    if (link.len() == 0)
      return
    set_blk_value_by_path(this.sourceDataBlock, objectId + "/link", link)
    ::g_promo.generateBlockView(this.sourceDataBlock[objectId])
    showObjById(objectId, true, this.scene)
  }

  //----------------- </WEB POLL> -------------------------

  //----------------- <RADIOBUTTONS> --------------------------

  function switchBlock(obj) { ::g_promo.switchBlock(obj, this.scene) }
  function manualSwitchBlock(obj) { ::g_promo.manualSwitchBlock(obj, this.scene) }
  function selectNextBlock(obj, dt) { ::g_promo.selectNextBlock(obj, dt) }

  //----------------- </RADIOBUTTONS> -------------------------

  function onEventShowAllPromoBlocksValueChanged(_p) { this.updatePromoBlocks() }
  function onEventPartnerUnlocksUpdated(_p) { this.updatePromoBlocks(true) }
  function onEventShopWndVisible(p) { this.toggleSceneVisibility(!getTblValue("isShopShow", p, false)) }
  function onEventXboxMultiplayerPrivilegeUpdated(_p) { this.updatePromoBlocks(true) }
  function onEventWebPollAuthResult(p) { this.updateWebPollButton(p) }
  function onEventWebPollTokenInvalidated(p) {
    if (p?.pollId == null)
      this.updateData()
    else
      this.updateWebPollButton(p)
  }

  function setTimers() {
    local timerObj = this.owner.scene.findObject("promo_blocks_timer_slow")
    if (checkObj(timerObj))
      timerObj.setUserData(this)

    let isNeedFrequentUpdate = this.needUpdateByTimerArr.len() > 0
    timerObj = this.owner.scene.findObject("promo_blocks_timer_fast")
    if (checkObj(timerObj))
      timerObj.setUserData(isNeedFrequentUpdate ? this : null)
  }

  function onPromoBlocksTimer(_obj, _dt) {
    foreach (promoId in this.needUpdateByTimerArr) {
      this.updateFunctions?[promoId]?.call?(this)
    }
  }
}

let function create_promo_blocks(handler) {
  if (!::handlersManager.isHandlerValid(handler))
    return null

  let owner = handler.weakref()
  let guiScene = handler.guiScene
  local scene = handler.scene.findObject("promo_mainmenu_place")

  return Promo(owner, guiScene, scene)
}

return { create_promo_blocks }

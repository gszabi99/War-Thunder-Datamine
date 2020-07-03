local { clearOldVotedPolls, setPollBaseUrl, isPollVoted, generatePollUrl } = require("scripts/web/webpoll.nut")
local { getTextWithCrossplayIcon, needShowCrossPlayInfo } = require("scripts/social/crossplay.nut")

::create_promo_blocks <- function create_promo_blocks(handler)
{
  if (!::handlersManager.isHandlerValid(handler))
    return null

  local owner = handler.weakref()
  local guiScene = handler.guiScene
  local scene = handler.scene.findObject("promo_mainmenu_place")

  return ::Promo(owner, guiScene, scene)
}

class Promo
{
  owner = null
  guiScene = null
  scene = null

  sourceDataBlock = null

  widgetsTable = {}

  pollIdToObjectId = {}
  needUpdateByTimerArr = null

  updateFunctions = {
    events_mainmenu_button = function() { return updateEventButton() }
    world_war_button = function() { return updateWorldWarButton() }
    tutorial_mainmenu_button = function() { return updateTutorialButton() }
    current_battle_tasks_mainmenu_button = function() { return updateCurrentBattleTaskButton() }
    invite_squad_mainmenu_button = function() { return updateSquadInviteButton() }
    recent_items_mainmenu_button = function() { return createRecentItemsHandler() }
  }

  constructor(_handler, _guiScene, _scene)
  {
    owner = _handler
    guiScene = _guiScene
    scene = _scene

    initScreen(true)

    local pollsTable = {}
    for (local j = 0; sourceDataBlock != null && j < sourceDataBlock.blockCount(); j++)
    {
      local block = sourceDataBlock.getBlock(j)
      if (block?.pollId != null)
        pollsTable[block.pollId] <- true
    }
    clearOldVotedPolls(pollsTable)

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function initScreen(forceReplaceContent = false)
  {
    updatePromoBlocks(forceReplaceContent)
  }

  function updatePromoBlocks(forceReplaceContent = false)
  {
    if (!::g_promo.requestUpdate() && !forceReplaceContent)
      return

    sourceDataBlock = ::g_promo.getConfig()
    updateAllBlocks()
  }

  function updateAllBlocks()
  {
    needUpdateByTimerArr = []
    local data = generateData()
    local topPositionPromoPlace = scene.findObject("promo_mainmenu_place_top")
    if (::checkObj(topPositionPromoPlace))
      guiScene.replaceContentFromText(topPositionPromoPlace, data.upper, data.upper.len(), this)

    local bottomPositionPromoPlace = scene.findObject("promo_mainmenu_place_bottom")
    if (::checkObj(bottomPositionPromoPlace))
      guiScene.replaceContentFromText(bottomPositionPromoPlace, data.bottom, data.bottom.len(), this)

    ::g_promo.initWidgets(scene, widgetsTable)
    updateData()
    setTimers()
    owner.restoreFocus()
  }

  function onSceneActivate(show)
  {
    if (show)
      updatePromoBlocks()
  }

  function toggleSceneVisibility(isShow)
  {
    scene.show(isShow)
    onSceneActivate(isShow)
  }

  function generateData()
  {
    widgetsTable = {}
    local upperPromoView = {
      showAllCheckBoxEnabled = ::g_promo.canSwitchShowAllPromoBlocksFlag()
      showAllCheckBoxValue = ::g_promo.getShowAllPromoBlocks()
      promoButtons = []
    }

    local bottomPromoView = {
      showAllCheckBoxEnabled = false
      promoButtons = []
    }

    for (local i = 0; sourceDataBlock != null && i < sourceDataBlock.blockCount(); i++)
    {
      local block = sourceDataBlock.getBlock(i)

      local blockView = ::g_promo.generateBlockView(block)
      local blockId = blockView.id
      if (block?.pollId != null)
      {
        if (::g_promo.getVisibilityById(blockId)) //add pollId to request only for visible promo
          setPollBaseUrl(block.pollId, block?.link)
        pollIdToObjectId[block.pollId] <- blockId
      }

      if (block?.bottom != null)
        bottomPromoView.promoButtons.append(blockView)
      else
        upperPromoView.promoButtons.append(blockView)

      if (blockView?.notifyNew && !::g_promo.isWidgetSeenById(blockId))
        widgetsTable[blockId] <- {}

      local playlistArray = getPlaylistArray(block)
      if (playlistArray.len() > 0)
      {
        local requestStopPlayTimeSec = block?.requestStopPlayTimeSec || ::g_promo.DEFAULT_REQ_STOP_PLAY_TIME_SONG_SEC
        ::g_promo.enablePlayMenuMusic(playlistArray, requestStopPlayTimeSec)
      }

      if (blockView.needUpdateByTimer)
        needUpdateByTimerArr.append(blockId)
    }
    return {
      upper = ::handyman.renderCached("gui/promo/promoBlocks", upperPromoView)
      bottom = ::handyman.renderCached("gui/promo/promoBlocks", bottomPromoView)
    }
  }

  function setTplView(tplPath, object, view = {})
  {
    if (!::checkObj(object))
      return

    local data = ::handyman.renderCached(tplPath, view)
    guiScene.replaceContentFromText(object, data, data.len(), this)
  }

  function updateData()
  {
    if (sourceDataBlock == null)
      return

    for (local i = 0; i < sourceDataBlock.blockCount(); i++)
    {
      local block = sourceDataBlock.getBlock(i)
      local id = block.getBlockName()
      if (id in updateFunctions)
        updateFunctions[id].call(this)

      if (block?.pollId != null)
        updateWebPollButton({pollId = block.pollId})
    }
  }

  function getPlaylistArray(block)
  {
    local defaultName = "playlist"
    local langKey = defaultName + "_" + ::g_language.getShortName()
    local list = block?[langKey] ?? block?[defaultName]
    if (!list)
      return []
    return list % "name"
  }

  function activateSelectedBlock(obj)
  {
    local promoButtonObj = obj.getChild(obj.getValue())
    local searchObjId = ::g_promo.getActionParamsKey(promoButtonObj.id)
    local radioButtonsObj = promoButtonObj.findObject("multiblock_radiobuttons_list")
    if (::check_obj(radioButtonsObj))
    {
      local val = radioButtonsObj.getValue()
      if (val >= 0)
        searchObjId += "_" + val
    }
    ::g_promo.performAction(owner, promoButtonObj.findObject(searchObjId))
  }

  function performAction(obj)
  {
    performActionWithStatistics(obj, false)
  }

  function performActionWithStatistics(obj, isFromCollapsed)
  {
    ::add_big_query_record("promo_click",
      ::save_to_json({id = ::g_promo.cutActionParamsKey(obj.id), collapsed = isFromCollapsed}))
    local objScene = obj.getScene()
    objScene.performDelayed(
      this,
      (@(owner, obj, widgetsTable) function() {
        if (!::checkObj(obj))
          return

        if (!::g_promo.performAction(owner, obj))
          if (::checkObj(obj))
            ::g_promo.setSimpleWidgetData(widgetsTable, obj.id)
      })(owner, obj, widgetsTable)
    )
  }

  function performActionCollapsed(obj)
  {
    local buttonObj = obj.getParent()
    performActionWithStatistics(buttonObj.findObject(::g_promo.getActionParamsKey(buttonObj.id)), true)
  }

  function onShowAllCheckBoxChange(obj)
  {
    ::g_promo.setShowAllPromoBlocks(obj.getValue())
  }

  function isShowAllCheckBoxEnabled()
  {
    if (!isValid())
      return false

    local chBoxObj = scene.findObject("checkbox_show_all_promo_blocks")
    if (!::checkObj(chBoxObj))
      return false

    return chBoxObj.getValue()
  }

  function getBoolParamByIdFromSourceBlock(param, id, defaultValue = false)
  {
    if (!sourceDataBlock?[id][param])
      return null

    local show = ::getTblValue(param, sourceDataBlock[id], defaultValue)
    if (::u.isString(show))
      show = show == "yes"? true : false

    return show
  }

  function isValid()
  {
    return ::check_obj(scene)
  }

  function onPromoBlocksUpdate(obj, dt)
  {
    updatePromoBlocks()
  }

  //------------- <CURRENT BATTLE TASK ---------------------
  function updateCurrentBattleTaskButton()
  {
    local id = "current_battle_tasks_mainmenu_button"
    local show = ::g_battle_tasks.isAvailableForUser() && ::g_promo.getVisibilityById(id)

    local buttonObj = ::showBtn(id, show, scene)
    if (!show || !::checkObj(buttonObj))
      return

    ::gui_handlers.BattleTasksPromoHandler.open({ scene = buttonObj })
  }
  //------------- </CURRENT BATTLE TASK --------------------

  //-------------- <TUTORIAL> ------------------------------

  function updateTutorialButton()
  {
    local tutorialData = getTutorialData()

    local tutorialMission = tutorialData?.tutorialMission
    local tutorialId = ::getTblValue("tutorialId", tutorialData)

    local id = "tutorial_mainmenu_button"
    local actionKey = ::g_promo.getActionParamsKey(id)
    ::g_promo.setActionParamsData(actionKey, "tutorial", [tutorialId])

    local buttonObj = null
    local show = isShowAllCheckBoxEnabled()
    if (show)
      buttonObj = ::showBtn(id, show, scene)
    else
    {
      show = tutorialMission != null && ::g_promo.getVisibilityById(id)
      buttonObj = ::showBtn(id, show, scene)
    }

    if (!show || !::checkObj(buttonObj))
      return

    local buttonText = ::loc("missions/" + (tutorialMission?.name ?? "") + "/short", "")
    if (!tutorialMission)
      buttonText = ::loc("mainmenu/btnTutorial")
    ::g_promo.setButtonText(buttonObj, id, buttonText)
  }

  function getTutorialData()
  {
    local tutorial = null
    local tutorialId = ""
    local curUnit = ::get_show_aircraft()

    if (::isTank(curUnit) && ::has_feature("Tanks"))
    {
      tutorialId = "lightTank"
      tutorial = ::get_uncompleted_tutorial_data("tutorial_tank_basics_arcade", 0)
    }
    else if (::isShip(curUnit) && ::has_feature("Ships"))
    {
      tutorialId = "boat"
      tutorial = ::get_uncompleted_tutorial_data("tutorial_boat_basic_arcade", 0)
    }

    if (!tutorial)
      foreach (tut in ::tutorials_to_check)
      {
        if (("requiresFeature" in tut) && !::has_feature(tut.requiresFeature))
          continue

        tutorial = ::get_uncompleted_tutorial_data(tut.tutorial, 0)
        if (tutorial)
        {
          tutorialId = tut.id
          break
        }
      }

    return {
      tutorialMission = tutorial?.mission
      tutorialId = tutorialId
    }
  }
  //--------------- </TUTORIAL> ----------------------------

  //--------------- <EVENTS> -------------------------------
  function updateEventButton()
  {
    local id = "events_mainmenu_button"
    local buttonObj = null
    local show = isShowAllCheckBoxEnabled()
    if (show)
      buttonObj = ::showBtn(id, show, scene)
    else
    {
      show = isEventsAvailable() && ::g_promo.getVisibilityById(id)
      buttonObj = ::showBtn(id, show, scene)
    }

    if (!show || !::checkObj(buttonObj))
      return

    ::g_promo.setButtonText(buttonObj, id, getEventsButtonText())
  }

  function getEventsButtonText()
  {
    local activeEventsNum = ::events.getEventsVisibleInEventsWindowCount()
    return activeEventsNum <= 0
      ? ::loc("mainmenu/events/eventlist_btn_no_active_events")
      : ::loc("mainmenu/btnTournamentsAndEvents")
  }

  function isEventsAvailable()
  {
    return ::has_feature("Events")
           && ::events
           && ::events.getEventsVisibleInEventsWindowCount()
  }
  //----------------- </EVENTS> -----------------------------

  //----------------- <WORLD WAR> ---------------------------
  function updateWorldWarButton()
  {
    local id = "world_war_button"
    local isWwEnabled = ::g_world_war.canJoinWorldwarBattle()
    local isVisible = ::g_promo.getShowAllPromoBlocks()
      || (isWwEnabled && ::g_world_war.isWWSeasonActive(true))

    local wwButton = ::showBtn(id, isVisible, scene)
    if (!isVisible || !::checkObj(wwButton))
      return

    local text = ::loc("mainmenu/btnWorldwar")
    if (isWwEnabled)
    {
      local operationText = ::g_world_war.getPlayedOperationText(false)
      if (operationText !=null)
        text = operationText
    }

    text = getTextWithCrossplayIcon(needShowCrossPlayInfo(), text)
    wwButton.findObject("world_war_button_text").setValue("{0} {1}".subst(::loc("icon/worldWar"), text))

    if (!::g_promo.isCollapsed(id))
      return

    if (::g_world_war.hasNewNearestAvailableMapToBattle())
      ::g_promo.toggleItem(wwButton.findObject(id + "_toggle"))
  }
  //----------------- </WORLD WAR> --------------------------

  //---------------- <INVITE SQUAD> -------------------------

  function updateSquadInviteButton()
  {
    local id = "invite_squad_mainmenu_button"
    local show = !::is_me_newbie() && ::g_promo.getVisibilityById(id)
    local buttonObj = ::showBtn(id, show, scene)
    if (!show || !::checkObj(buttonObj))
      return

    buttonObj.inactiveColor = ::checkIsInQueue() ? "yes" : "no"
  }

  //---------------- </INVITE SQUAD> ------------------------

  //----------------- <NAVIGATION> --------------------------

  function getWrapNestObj()
  {
    if (!isValid())
      return null

    for (local i = 0; i < scene.childrenCount(); i++)
    {
      local child = scene.getChild(i)
      if (child.isVisible() && child.isEnabled())
        return scene
    }

    return null
  }

  function onWrapUp(obj)
  {
    owner.onWrapUp(obj)
  }

  function onWrapDown(obj)
  {
    owner.onWrapDown(obj)
  }

  //------------------ </NAVIGATION> --------------------------

  //--------------------- <TOGGLE> ----------------------------

  function onToggleItem(obj) { ::g_promo.toggleItem(obj) }

  //-------------------- </TOGGLE> ----------------------------

  //------------------ <RECENT ITEMS> -------------------------

  function createRecentItemsHandler()
  {
    local id = "recent_items_mainmenu_button"
    local show = isShowAllCheckBoxEnabled() || ::g_promo.getVisibilityById(id)
    local handlerWeak = ::g_recent_items.createHandler(this, scene.findObject(id), show)
    owner.registerSubHandler(handlerWeak)
  }

  //----------------- </RECENT ITEMS> -------------------------

  //------------------ <WEB POLL> -------------------------

  function updateWebPollButton(param)
  {
    local pollId = param?.pollId
    local objectId = ::getTblValue(pollId, pollIdToObjectId)
    if (objectId == null)
      return

    local showByLocalConditions = !isPollVoted(pollId) && ::g_promo.getVisibilityById(objectId)
    if(!showByLocalConditions)
    {
      ::showBtn(objectId, false, scene)
      return
    }

    local link = generatePollUrl(pollId)
    if (link.len() == 0)
      return
    ::set_blk_value_by_path(sourceDataBlock, objectId + "/link", link)
    ::g_promo.generateBlockView(sourceDataBlock[objectId])
    ::showBtn(objectId, true, scene)
  }

  //----------------- </WEB POLL> -------------------------

  //----------------- <RADIOBUTTONS> --------------------------

  function switchBlock(obj) { ::g_promo.switchBlock(obj, scene) }
  function manualSwitchBlock(obj) { ::g_promo.manualSwitchBlock(obj, scene) }
  function selectNextBlock(obj, dt) { ::g_promo.selectNextBlock(obj, dt) }

  //----------------- </RADIOBUTTONS> -------------------------

  function onEventEventsDataUpdated(p)  { updateEventButton() }
  function onEventMyStatsUpdated(p)     { updateEventButton() }
  function onEventQueueChangeState(p)   {
                                          updateSquadInviteButton()
                                        }
  function onEventUnlockedCountriesUpdate(p) { updateEventButton() }
  function onEventHangarModelLoaded(p)  { updateTutorialButton() }
  function onEventShowAllPromoBlocksValueChanged(p) { updatePromoBlocks() }
  function onEventPartnerUnlocksUpdated(p) { updatePromoBlocks(true) }
  function onEventShopWndVisible(p) { toggleSceneVisibility(!::getTblValue("isShopShow", p, false)) }
  function onEventWWLoadOperation(p) { updateWorldWarButton() }
  function onEventWWStopWorldWar(p) { updateWorldWarButton() }
  function onEventWWShortGlobalStatusChanged(p) { updateWorldWarButton() }
  function onEventCrossPlayOptionChanged(p) { updateWorldWarButton() }
  function onEventWebPollAuthResult(p) { updateWebPollButton(p) }
  function onEventWebPollTokenInvalidated(p) {
    if (p?.pollId == null)
      updateData()
    else
      updateWebPollButton(p)
  }

  function setTimers()
  {
    local timerObj = owner.scene.findObject("promo_blocks_timer_slow")
    if (::check_obj(timerObj))
      timerObj.setUserData(this)

    local isNeedFrequentUpdate = needUpdateByTimerArr.len() > 0
    timerObj = owner.scene.findObject("promo_blocks_timer_fast")
    if (::check_obj(timerObj))
      timerObj.setUserData(isNeedFrequentUpdate ? this : null)
  }

  function onPromoBlocksTimer(obj, dt)
  {
    foreach (promoId in needUpdateByTimerArr)
    {
      updateFunctions?[promoId]?.call?(this)
    }
  }
}

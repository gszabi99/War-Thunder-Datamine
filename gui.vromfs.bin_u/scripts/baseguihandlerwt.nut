let { format } = require("string")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let callback = require("%sqStdLibs/helpers/callback.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let updateContacts = require("%scripts/contacts/updateContacts.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let { isChatEnabled } = require("%scripts/chat/chatStates.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { get_time_msec } = require("dagor.time")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = ::require_native("guiOptions")

local stickedDropDown = null
let defaultSlotbarActions = [
  "autorefill", "aircraft", "sec_weapons", "weapons", "showroom",
  "testflight", "crew", "goto_unlock", "info", "repair"
]
let timerPID = ::dagui_propid.add_name_id("_size-timer")
let forceTimePID = ::dagui_propid.add_name_id("force-time")

let function moveToFirstEnabled(obj) {
  let total = obj.childrenCount()
  for(local i = 0; i < total; i++) {
    let child = obj.getChild(i)
    if (!child.isValid() || !child.isEnabled())
      continue
    ::move_mouse_on_obj(child)
    break
  }
}

let function setForceMove(obj, value) {
  obj.forceMove = value
  obj.setIntProp(forceTimePID, get_time_msec())
}

local function getDropDownRootObj(obj) {
  while(obj != null) {
    if (obj?["class"] == "dropDown")
      return obj
    obj = obj.getParent()
  }
  return null
}

local class BaseGuiHandlerWT extends ::BaseGuiHandler {
  canQuitByGoBack = true

  squadWidgetHandlerWeak = null
  squadWidgetNestObjId = "gamercard_squad_widget"
  voiceChatWidgetNestObjId = "base_voice_chat_widget"

  rightSectionHandlerWeak = null

  slotbarWeak = null
  presetsListWeak = null
  shouldCheckCrewsReady = false
  slotbarActions = null

  afterSlotOp = null
  afterSlotOpError = null

  startFunc = null
  progressBox = null
  taskId = null
  task = null

  GCDropdownsList = ["gc_shop"]
  curGCDropdown = null

  mainOptionsMode = -1
  mainGameMode = -1
  wndOptionsMode = -1
  wndGameMode = -1

  wndControlsAllowMask = null //enum CtrlsInGui, when null, it set by wndType
  widgetsList = null
  needVoiceChat = true
  canInitVoiceChatWithSquadWidget = false

  constructor(gui_scene, params = {})
  {
    base.constructor(gui_scene, params)

    if (wndType == handlerType.MODAL || wndType == handlerType.BASE)
      enableHangarControls(false, wndType == handlerType.BASE)

    setWndGameMode()
    setWndOptionsMode()
  }

  function init()
  {
    fillGamercard()
    base.init()
  }

  function getNavbarMarkup()
  {
    let tplView = getNavbarTplView()
    if (!tplView)
      return null
    return ::handyman.renderCached("%gui/commonParts/navBar", tplView)
  }

  function getNavbarTplView() { return null }

  function fillGamercard()
  {
    ::fill_gamer_card(null, "gc_", scene)
    initGcBackButton()
    initSquadWidget()
    initVoiceChatWidget()
    initRightSection()
  }

  function initGcBackButton()
  {
    this.showSceneBtn("gc_nav_back", canQuitByGoBack && useTouchscreen && !::is_in_loading_screen())
  }

  function initSquadWidget()
  {
    if (squadWidgetHandlerWeak)
      return

    let nestObj = scene.findObject(squadWidgetNestObjId)
    if (!::checkObj(nestObj))
      return

    squadWidgetHandlerWeak = ::init_squad_widget_handler(nestObj)
    registerSubHandler(squadWidgetHandlerWeak)
  }

  function initVoiceChatWidget()
  {
    if (canInitVoiceChatWithSquadWidget || squadWidgetHandlerWeak == null)
      ::handlersManager.initVoiceChatWidget(this)
  }

  function updateVoiceChatWidget(shouldShow)
  {
    this.showSceneBtn(voiceChatWidgetNestObjId, shouldShow)
  }

  function initRightSection()
  {
    if (rightSectionHandlerWeak)
      return

    rightSectionHandlerWeak = ::gui_handlers.TopMenuButtonsHandler.create(scene.findObject("topmenu_menu_panel_right"),
                                                                          this,
                                                                          ::g_top_menu_right_side_sections,
                                                                          scene.findObject("right_gc_panel_free_width")
                                                                         )
    registerSubHandler(rightSectionHandlerWeak)
  }

  /**
   * @param filterFunc Optional filter function with mode id
   *                   as parameter and boolean return type.
   */
  function getModesTabsView(selectedDiffCode, filterFunc)
  {
    let tabsView = []
    local isFoundSelected = false
    foreach(diff in ::g_difficulty.types)
    {
      if (!diff.isAvailable() || (filterFunc && !filterFunc(diff)))
        continue

      let isSelected = selectedDiffCode == diff.diffCode
      isFoundSelected = isFoundSelected || isSelected
      tabsView.append({
        tabName = diff.getLocName(),
        selected = isSelected,
        holderDiffCode = diff.diffCode.tostring()
      })
    }
    if (!isFoundSelected && tabsView.len())
      tabsView[0].selected = true

    return tabsView
  }

  function updateModesTabsContent(modesObj, view)
  {
    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(modesObj, data, data.len(), this)

    let selectCb = modesObj?.on_select
    if (selectCb && (selectCb in this))
      this[selectCb](modesObj)
  }

  function fillModeListBox(nest, selectedDiffCode=0, filterFunc = null, addTabs = [])
  {
    if (!::check_obj(nest))
      return

    let modesObj = nest.findObject("modes_list")
    if (!::check_obj(modesObj))
      return

    updateModesTabsContent(modesObj, {
      tabs = getModesTabsView(selectedDiffCode, filterFunc).extend(addTabs)
    })
  }

  function onTopMenuGoBack(...)
  {
    checkedForward(function() {
      goForward(::gui_start_mainmenu, false)
    })
  }

  function afterSave()
  {
    ::dagor.debug("warning! empty afterSave!")
  }

  function save(onlineSave = true)
  {
    let handler = this
    ::dagor.debug("save")
    if (::is_save_device_selected())
    {
      local saveRes = ::SAVELOAD_OK;
      saveRes = ::save_profile(onlineSave && ::is_online_available())

      if (saveRes != ::SAVELOAD_OK)
      {
        ::dagor.debug("saveRes = "+saveRes.tostring())
        local txt = "x360/noSaveDevice"
        if (saveRes == ::SAVELOAD_NO_SPACE)
          txt = "x360/noSpace"
        else if (saveRes == ::SAVELOAD_NOT_SELECTED)
          txt = "xbox360/questionSelectDevice"
        this.msgBox("no_save_device", ::loc(txt),
        [
          ["yes", (@(handler, onlineSave) function() {
              ::dagor.debug("performDelayed save")
              handler.guiScene.performDelayed(handler, (@(handler, onlineSave) function() {
                ::select_save_device(true)
                save(onlineSave)
                handler.afterSave()
              })(handler, onlineSave))
          })(handler, onlineSave)],
          ["no", (@(handler) function() {
            handler.afterSave()
          })(handler)
          ]
        ], "yes")
      }
      else
        handler.afterSave()
    }
    else
    {
      this.msgBox("no_save_device", ::loc("xbox360/questionSelectDevice"),
      [
        ["yes", (@(handler, onlineSave) function() {

            ::dagor.debug("performDelayed save")
            handler.guiScene.performDelayed(handler, (@(handler, onlineSave) function() {
              ::select_save_device(true)
              save(onlineSave)
            })(handler, onlineSave))
        })(handler, onlineSave)],
        ["no", (@(handler) function() {
          handler.afterSave()
        })(handler)
        ]
      ], "yes")
    }
  }

  function goForwardCheckEntitlement(start_func, entitlement)
  {
    guiScene = ::get_cur_gui_scene()

    startFunc = start_func

    if (typeof(entitlement) == "table")
      task = entitlement;
    else
      task = {loc = entitlement, entitlement = entitlement}

    task.gm <- ::get_game_mode()

    taskId = ::update_entitlements()
    if (::is_dev_version && taskId < 0)
      goForward(start_func)
    else
    {
      let taskOptions = {
        showProgressBox = true
        progressBoxText = ::loc("charServer/checking")
      }
      let taskSuccessCallback = ::Callback(function ()
        {
          if (::checkAllowed.bindenv(this)(task))
            goForward(startFunc)
        }, this)
      ::g_tasker.addTask(taskId, taskOptions, taskSuccessCallback)
    }
  }

  function goForwardOrJustStart(start_func, start_without_forward)
  {
    if (start_without_forward)
      start_func();
    else
      goForward(start_func)
  }

  function goForwardIfOnline(start_func, skippable, start_without_forward = false)
  {
    if (::is_online_available())
    {
      goForwardOrJustStart(start_func, start_without_forward)
      return
    }

    let successCb = ::Callback((@(start_func, start_without_forward) function() {
      goForwardOrJustStart(start_func, start_without_forward)
    })(start_func, start_without_forward), this)
    let errorCb = skippable ? successCb : null

    ::g_matching_connect.connect(successCb, errorCb)
  }

  function destroyProgressBox()
  {
    if(::checkObj(progressBox))
    {
      guiScene.destroyElement(progressBox)
      ::broadcastEvent("ModalWndDestroy")
    }
    progressBox = null
  }

  function onShowHud(show = true, needApplyPending = false)
  {
    if (!isSceneActive())
      return

    if (rootHandlerWeak)
      return rootHandlerWeak.onShowHud(show)

    if (!::check_obj(scene))
      return

    scene.show(show)
    if (needApplyPending)
      guiScene.applyPendingChanges(false) //to correct work isVisible() for scene objects after event
  }

  function startOnlineShop(chapter = null, afterCloseShop = null, metric = "unknown")
  {
    let handler = this
    goForwardIfOnline(function() {
        local closeFunc = null
        if (afterCloseShop)
          closeFunc = function() {
            if (handler)
              afterCloseShop.call(handler)
          }
        ::OnlineShopModel.launchOnlineShop(handler, chapter, closeFunc, metric)
      }, false, true)
  }

  function onOnlineShop(obj)          { startOnlineShop() }
  function onOnlineShopPremium()      { startOnlineShop("premium")}
  function onOnlineShopLions()        { startOnlineShop("warpoints") }

  function onOnlineShopEagles()
  {
    if (::has_feature("EnableGoldPurchase"))
      startOnlineShop("eagles", null, "gamercard")
    else
      ::showInfoMsgBox(::loc("msgbox/notAvailbleGoldPurchase"))
  }

  function onItemsShop() { ::gui_start_itemsShop() }
  function onInventory() { ::gui_start_inventory() }

  function onConvertExp(obj)
  {
    ::gui_modal_convertExp()
  }

  function notAvailableYetMsgBox()
  {
    this.msgBox("not_available", ::loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function onUserLog(obj)
  {
    if (::has_feature("UserLog"))
      ::gui_modal_userLog()
    else
      notAvailableYetMsgBox()
  }

  function onProfile(obj)
  {
    ::gui_start_profile()
  }

  function onMyClanOpen()
  {
    ::gui_modal_clans("my_clan")
  }

  function onGC_chat(obj)
  {
    if (!::isMenuChatActive())
      isChatEnabled(true)

    switchChatWindow()
  }

  function switchChatWindow()
  {
    if (gchat_is_enabled() && ::has_feature("Chat"))
      switchMenuChatObj(getChatDiv(scene))
    else
      notAvailableYetMsgBox()
  }

  function onSwitchContacts()
  {
    ::switchContactsObj(scene, this)
  }
  function onGC_contacts(obj)
  {
    if (!::has_feature("Friends"))
      return notAvailableYetMsgBox()

    if (!::isContactsWindowActive())
      updateContacts()

    onSwitchContacts()
  }
  function onGC_invites(obj)
  {
    ::gui_start_invites()
  }
  function onInviteSquad(obj)
  {
    ::gui_start_search_squadPlayer()
  }

  function getSlotbar()
  {
    return rootHandlerWeak ? rootHandlerWeak.slotbarWeak : slotbarWeak
  }

  function getCurSlotUnit()
  {
    let slotbar = getSlotbar()
    return slotbar && slotbar.getCurSlotUnit()
  }

  function getHangarFallbackUnitParams()
  {
    return getSlotbar()?.getHangarFallbackUnitParams()
  }

  function getCurCrew()
  {
    let slotbar = getSlotbar()
    return slotbar && slotbar.getCurCrew()
  }

  function getCurSlotbarCountry()
  {
    local slotbar = getSlotbar()
    return slotbar && slotbar.getCurCountry()
  }

  function onTake(unit, params = {})
  {
    unitActions.take(unit, {
        unitObj = unit?.name? scene.findObject(unit.name) : null
        shouldCheckCrewsReady = shouldCheckCrewsReady
      }.__update(params))
  }

  hasAutoRefillChangeInProcess =false
  function onSlotsChangeAutoRefill(obj)
  {
    if ((slotbarWeak?.slotbarOninit ?? false) || hasAutoRefillChangeInProcess)
      return
    let mode = obj.id == "slots-autorepair" ? 0
      : obj.id == "slots-autoweapon" ? 1
      : -1

    if (mode == -1)
      return

    local value = obj.getValue()
    set_auto_refill(mode, value)
    ::save_online_single_job(SAVE_ONLINE_JOB_DIGIT)

    hasAutoRefillChangeInProcess = true
    ::broadcastEvent("AutorefillChanged", { id = obj.id, value = value })
    hasAutoRefillChangeInProcess = false
  }

  //"nav-help" - navBar
  function createSlotbar(params = {}, nest = "nav-help")
  {
    if (slotbarWeak)
    {
      slotbarWeak.setParams(params)
      return
    }

    if (::u.isString(nest))
      nest = scene.findObject(nest)
    params.scene <- nest
    params.ownerWeak <- this.weakref()

    let slotbar = createSlotbarHandler(params)
    if (!slotbar)
      return

    slotbarWeak = slotbar.weakref()
    registerSubHandler(slotbar)
  }

  function createSlotbarHandler(params)
  {
    return ::gui_handlers.SlotbarWidget.create(params)
  }

  function reinitSlotbar() //!!FIX ME: Better to not use it.
  {
    let slotbar = getSlotbar()
    if (slotbar)
      slotbar.fullUpdate()
  }

  function destroySlotbar()
  {
    if (slotbarWeak)
      slotbarWeak.destroy()
    slotbarWeak = null
  }

  function getSlotbarActions()
  {
    return slotbarActions || defaultSlotbarActions
  }

  getParamsForActionsList = @() {}
  getUnitParamsFromObj = @(unitObj) {
    unit = ::getAircraftByName(unitObj?.unit_name)
    crew = unitObj?.crew_id ? ::get_crew_by_id(unitObj.crew_id.tointeger()) : null
  }

  function openUnitActionsList(unitObj, ignoreSelect = false, ignoreHover = false)
  {
    if (!::checkObj(unitObj) || (!ignoreHover && !unitObj.isHovered()))
      return
    let parentObj = unitObj.getParent()
    if (!::checkObj(parentObj)
      || (!ignoreSelect && (parentObj?.chosen ?? parentObj?.selected) != "yes"))
      return

    if (unitContextMenuState.value?.unitObj.isValid()
      && unitContextMenuState.value.unitObj.isEqual(unitObj))
      return unitContextMenuState(null)

    unitContextMenuState({
      unitObj = unitObj
      actionsNames = getSlotbarActions()
      closeOnUnhover = !ignoreHover
      curEdiff = getCurrentEdiff?() ?? -1
      shouldCheckCrewsReady = shouldCheckCrewsReady
      slotbar = getSlotbar()
    }.__update(getParamsForActionsList()).__update(getUnitParamsFromObj(unitObj)))
  }

  function onOpenActionsList(obj)
  {
    openUnitActionsList(obj.getParent().getParent(), true)
  }

  function getSlotbarPresetsList()
  {
    return rootHandlerWeak ? rootHandlerWeak.presetsListWeak : presetsListWeak
  }

  function setSlotbarPresetsListAvailable(isAvailable)
  {
    if (isAvailable)
    {
      if (presetsListWeak)
        presetsListWeak.update()
      else
        presetsListWeak = SlotbarPresetsList(this).weakref()
    } else
      if (presetsListWeak)
        presetsListWeak.destroy()
  }

  function slotOpCb(id, tType, result)
  {
    if (id != taskId)
    {
      ::dagor.debug("wrong ID in char server cb, ignoring");
      ::g_tasker.charCallback(id, tType, result)
      return
    }
    ::g_tasker.restoreCharCallback()
    destroyProgressBox()

    penalties.showBannedStatusMsgBox(true)

    if (result != 0)
    {
      let handler = this
      local text = ::loc("charServer/updateError/"+result.tostring())

      if (("EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS" in getroottable())
        && ("get_char_extended_error" in getroottable()))
        if (result == ::EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS)
        {
          let notAllowedChars = ::get_char_extended_error()
          text = format(text, notAllowedChars)
        }

      handler.msgBox("char_connecting_error", text,
      [
        ["ok", (@(result) function() { if (afterSlotOpError != null) afterSlotOpError(result);})(result) ]
      ], "ok")
      return
    }
    else if (afterSlotOp != null)
      afterSlotOp();
  }

  function showTaskProgressBox(text = null, cancelFunc = null, delayedButtons = 30)
  {
    if (::checkObj(progressBox))
      return

    if (text == null)
      text = ::loc("charServer/purchase0")

    if (cancelFunc == null)
      cancelFunc = function(){}

    progressBox = this.msgBox("char_connecting",
        text,
        [["cancel", cancelFunc]], "cancel",
        { waitAnim = true,
          delayedButtons = delayedButtons
        })
  }

  function onGenericTooltipOpen(obj)
  {
    ::g_tooltip.open(obj, this)
  }

  function onTooltipObjClose(obj)
  {
    ::g_tooltip.close.call(this, obj)
  }

  function onContactTooltipOpen(obj)
  {
    let uid = obj?.uid
    local canShow = false
    local contact = null
    if (uid)
    {
      contact = ::getContact(uid)
      canShow = canShowContactTooltip(contact)
    }
    obj["class"] = canShow ? "" : "empty"

    if (canShow)
      ::fillContactTooltip(obj, contact, this)
  }

  function canShowContactTooltip(contact)
  {
    return contact != null
  }

  function onQueuesTooltipOpen(obj)
  {
    guiScene.replaceContent(obj, "%gui/queue/queueInfoTooltip.blk", this)
    SecondsUpdater(obj.findObject("queue_tooltip_root"), function(obj, params)
    {
      obj.findObject("text").setValue(::queues.getQueuesInfoText())
    })
  }

  function onProjectawardTooltipOpen(obj)
  {
    if (!::checkObj(obj)) return
    let img = obj?.img ?? ""
    let title = obj?.title ?? ""
    let desc = obj?.desc ?? ""

    guiScene.replaceContent(obj, "%gui/customization/decalTooltip.blk", this)
    obj.findObject("header").setValue(title)
    obj.findObject("description").setValue(desc)
    let imgObj = obj.findObject("image")
    imgObj["background-image"] = img
    let picDiv = imgObj.getParent()
    picDiv["size"] = "128*@sf/@pf_outdated, 128*@sf/@pf_outdated"
    picDiv.show(true)
  }

  function onViewImage(obj)
  {
    ::view_fullscreen_image(obj)
  }

  function onFaq()             { openUrl(::loc("url/faq")) }
  function onForum()           { openUrl(::loc("url/forum")) }
  function onSupport()         { openUrl(::loc("url/support")) }
  function onWiki()            { openUrl(::loc("url/wiki")) }

  function onSquadCreate(obj)
  {
    if (::g_squad_manager.isInSquad())
      this.msgBox("already_in_squad", ::loc("squad/already_in_squad"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
    else
      ::chatInviteToSquad(null, this)
  }

  function unstickLastDropDown(newObj = null, forceMove = "no")
  {
    if (::checkObj(stickedDropDown) && (!newObj || !stickedDropDown.isEqual(newObj)))
    {
      setForceMove(stickedDropDown, forceMove)
      stickedDropDown.getScene().applyPendingChanges(false)
      onStickDropDown(stickedDropDown, false)
      stickedDropDown = null
    }
  }

  function forceCloseDropDown(obj) {
    let rootObj = getDropDownRootObj(obj)
    if (rootObj != null)
      setForceMove(rootObj, "close")
  }

  function onDropDownToggle(obj)
  {
    obj = getDropDownRootObj(obj)
    if (!obj)
      return

    let needStick = obj?.forceMove != "open"
    setForceMove(obj, needStick ? "open" : "no")
    unstickLastDropDown(obj, needStick ? "close" : "no")

    guiScene.applyPendingChanges(false)
    stickedDropDown = needStick ? obj : null
    onStickDropDown(obj, needStick)
  }

  function onHoverSizeMove(obj)
  {
    //this only for pc mouse logic. For animated gamepad cursor look onDropdownAnimFinish
    if (!::is_mouse_last_time_used())
      return
    unstickLastDropDown(getDropDownRootObj(obj))
  }

  function onGCDropdown(obj)
  {
    local id = obj?.id
    let ending = "_panel"
    if (id && id.len() > ending.len() && id.slice(id.len()-ending.len())==ending)
      id = id.slice(0, id.len()-ending.len())
    if (!::isInArray(id, GCDropdownsList))
      return

    let btnObj = obj.findObject(id + "_btn")
    if (::checkObj(btnObj))
      onDropDownToggle(btnObj)
  }

  function onStickDropDown(obj, show)
  {
    if (!::checkObj(obj))
      return

    let id = obj?.id
    if (!show || !::isInArray(id, GCDropdownsList))
    {
      curGCDropdown = null
      return
    }

    curGCDropdown = id
    ::move_mouse_on_obj(obj)
    guiScene.playSound("menu_appear")
  }

  function onDropdownAnimFinish(obj) {
    //this only for animated gamepad cursor. for pc mouse logic look onHoverSizeMove
    let isOpened = obj.getFloatProp(timerPID, 0.0) == 1
    if (!isOpened) {
      let rootObj = getDropDownRootObj(obj)
      guiScene.performDelayed({}, function() {
        if (rootObj?.isValid())
          setForceMove(rootObj, "no") //need to remove flag on the next frame, after hover will be removed
      })
      return
    }

    if (::is_mouse_last_time_used() || !stickedDropDown?.isValid())
      return
    let rootObj = getDropDownRootObj(obj)
    if (!rootObj || !stickedDropDown.isEqual(rootObj))
      return
    let menuObj = getCurGCDropdownMenu()
    if (!menuObj?.isValid())
      return
    moveToFirstEnabled(menuObj)
    local tempTask = -1
    tempTask = ::periodic_task_register(this,
      function(_) {
        if (isValid() && stickedDropDown?.isValid() && rootObj?.isValid() && stickedDropDown.isEqual(rootObj))
          unstickLastDropDown()
        ::periodic_task_unregister(tempTask)
      },
      1)
  }

  function onDropdownHover(obj) {
    // see func onDropdownAnimFinish
    if (!::show_console_buttons || !::check_obj(stickedDropDown) || obj.getFloatProp(timerPID, 0.0) < 1)
      return
    let btn = getCurGCDropdownBtn()
    if (btn && (getDropDownRootObj(btn)?.getIntProp(forceTimePID, 0) ?? 0) > get_time_msec() + 100)
      unstickLastDropDown()
  }

  onBackDropdownMenu   = @(obj) ::move_mouse_on_obj(getObj($"{obj?.sectionId}_btn"))
  getCurGCDropdownBtn  = @() curGCDropdown != null ? getObj(curGCDropdown + "_btn") : null
  getCurGCDropdownMenu = @() curGCDropdown != null ? getObj(curGCDropdown + "_focus") : null

  function setSceneTitle(text, placeObj = null, name = "gc_title")
  {
    if (!placeObj)
     placeObj = scene

    if (text == null || !::check_obj(placeObj))
      return

    let textObj = placeObj.findObject(name)
    if (::check_obj(textObj))
      textObj.setValue(text.tostring())
  }

  function restoreMainOptions()
  {
    if (mainOptionsMode >= 0)
      setGuiOptionsMode(mainOptionsMode)
    if (mainGameMode >= 0)
      ::set_mp_mode(mainGameMode)
  }

  function setWndGameMode()
  {
    if (wndGameMode < 0)
      return
    mainGameMode = ::get_mp_mode()
    ::set_mp_mode(wndGameMode)
  }

  function setWndOptionsMode()
  {
    if (wndOptionsMode < 0)
      return
    mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(wndOptionsMode)
  }

  function checkAndStart(onSuccess, onCancel, checkName, checkParam = null)
  {
    ::queues.checkAndStart(callback.make(onSuccess, this), callback.make(onCancel, this),
      checkName, checkParam)
  }

  function checkedNewFlight(func, cancelFunc=null)
                   { checkAndStart(func, cancelFunc, "isCanNewflight") }
  function checkedForward(func, cancelFunc=null)
                   { checkAndStart(func, cancelFunc, "isCanGoForward") }
  function checkedCrewModify(func, cancelFunc=null)
                   { checkAndStart(func, cancelFunc, "isCanModifyCrew") }
  function checkedAirChange(func, cancelFunc=null)  //change selected air
                   { checkAndStart(func, cancelFunc, "isCanAirChange") }
  function checkedCrewAirChange(func, cancelFunc=null) //change air in slot
  {
    checkAndStart(
      function() {
        ::g_squad_utils.checkSquadUnreadyAndDo(callback.make(func, this),
          callback.make(cancelFunc, this), shouldCheckCrewsReady)
      },
      cancelFunc, "isCanModifyCrew")
  }
  function checkedModifyQueue(qType, func, cancelFunc = null)
  {
    checkAndStart(func, cancelFunc, "isCanModifyQueueParams", qType)
  }

  function onFacebookPostScrnshot(saved_screenshot_path)
  {
    ::make_facebook_login_and_do((@(saved_screenshot_path) function() {::start_facebook_upload_screenshot(saved_screenshot_path)})(saved_screenshot_path), this)
  }

  function onFacebookLoginAndPostScrnshot()
  {
    ::make_screenshot_and_do(onFacebookPostScrnshot, this)
  }

  function onFacebookLoginAndAddFriends()
  {
    ::make_facebook_login_and_do(function()
         {
           ::scene_msg_box("facebook_login", null, ::loc("facebook/downloadingFriends"), null, null)
           ::facebook_load_friends(::EPL_MAX_PLAYERS_IN_LIST)
         }, this)
  }

  function proccessLinkFromText(obj, itype, link)
  {
    openUrl(link, false, false, obj?.bqKey ?? obj?.id)
  }

  function onFacebookPostPurchaseChange(obj)
  {
    ::broadcastEvent("FacebookFeedPostValueChange", {value = obj.getValue()})
  }

  function onModalWndDestroy()
  {
    if (!::handlersManager.isAnyModalHandlerActive())
      ::restoreHangarControls()
    base.onModalWndDestroy()
    ::checkMenuChatBack()
  }

  function onSceneActivate(show)
  {
    if (show)
    {
      setWndGameMode()
      setWndOptionsMode()
    } else
      restoreMainOptions()

    if (::is_hud_visible())
      onShowHud()

    base.onSceneActivate(show)
  }

  function getControlsAllowMask()
  {
    return wndControlsAllowMask
  }

  function switchControlsAllowMask(mask)
  {
    if (mask == wndControlsAllowMask)
      return

    wndControlsAllowMask = mask
    ::handlersManager.updateControlsAllowMask()
  }

  function getWidgetsList()
  {
    let result = []
    if (widgetsList)
      foreach (widgetDesc in widgetsList)
      {
        result.append({ widgetId = widgetDesc.widgetId })
        if ("placeholderId" in widgetDesc)
          result.top()["transform"] <- getWidgetParams(widgetDesc.placeholderId)
      }
    return result
  }

  function getWidgetParams(placeholderId)
  {
    let placeholderObj = scene.findObject(placeholderId)
    if (!::checkObj(placeholderObj))
      return null

    return {
      pos = placeholderObj.getPosRC()
      size = placeholderObj.getSize()
    }
  }

  function onHeaderTabSelect() {} //empty frame

  function onFacebookLoginAndPostMessage() {}
  function sendInvitation() {}
  function onFacebookPostLink() {}

  function onModActionBtn(){}
  function onModItemClick(){}
  function onModItemDblClick(){}
  function onModCheckboxClick(){}
  function onAltModAction(){}
  function onModChangeBulletsSlider(){}

  function onShowMapRenderFilters(){}
}

::gui_handlers.BaseGuiHandlerWT <- BaseGuiHandlerWT

return {
  stickedDropDown = stickedDropDown
}

from "%scripts/dagui_natives.nut" import save_online_single_job, set_auto_refill, is_online_available, periodic_task_register, get_auto_refill, update_entitlements, is_mouse_last_time_used, gchat_is_enabled, periodic_task_unregister
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import SAVE_WEAPON_JOB_DIGIT
from "app" import is_dev_version
from "hudState" import is_hud_visible

let { g_difficulty } = require("%scripts/difficulty.nut")
let { eventbus_send } = require("eventbus")
let { isRanksAllowed } = require("%scripts/ranksAllowed.nut")
let { BaseGuiHandler } = require("%sqDagui/framework/baseGuiHandler.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { isInMenu } = require("%scripts/clientState/clientStates.nut")
let { is_in_loading_screen } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { format } = require("string")
let { get_char_extended_error, save_profile } = require("chard")
let { EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS } = require("chardConst")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let callback = require("%sqStdLibs/helpers/callback.nut")
let updateContacts = require("%scripts/contacts/updateContacts.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let { hasMenuChat } = require("%scripts/chat/chatStates.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { get_time_msec } = require("dagor.time")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { set_game_mode, get_game_mode } = require("mission")
let { getManualUnlocks } = require("%scripts/unlocks/personalUnlocks.nut")
let { checkShowMatchingConnect } = require("%scripts/matching/matchingOnline.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { switchContactsObj, isContactsWindowActive } = require("%scripts/contacts/contactsHandlerState.nut")
let { addTask, charCallback, restoreCharCallback } = require("%scripts/tasker.nut")
let { checkSquadUnreadyAndDo, initSquadWidgetHandler } = require("%scripts/squads/squadUtils.nut")
let { getCrewById } = require("%scripts/slotbar/crewsList.nut")
let { openGenericTooltip, closeGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { steamContactsGroup } = require("%scripts/contacts/contactsManager.nut")
let { defer } = require("dagor.workcycle")
let { fillGamercard } = require("%scripts/gamercard/fillGamercard.nut")
let { getQueuesInfoText } = require("%scripts/queue/queueState.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")
let { topMenuRightSideSections } = require("%scripts/mainmenu/topMenuSections.nut")

local stickedDropDown = null
let defaultSlotbarActions = [
  "autorefill", "aircraft", "sec_weapons", "weapons", "showroom",




  "testflight", "crew", "goto_unlock", "info", "repair"
]
let timerPID = dagui_propid_add_name_id("_size-timer")
let forceTimePID = dagui_propid_add_name_id("force-time")

function setForceMove(obj, value) {
  obj.forceMove = value
  obj.setIntProp(forceTimePID, get_time_msec())
}

function getDropDownRootObj(obj) {
  while (obj != null) {
    if (obj?["class"] == "dropDown")
      return obj
    obj = obj.getParent()
  }
  return null
}

let BaseGuiHandlerWT = class (BaseGuiHandler) {
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

  wndControlsAllowMask = null 
  widgetsList = null
  needVoiceChat = true
  canInitVoiceChatWithSquadWidget = false

  constructor(gui_scene, params = {}) {
    base.constructor(gui_scene, params)

    this.setWndGameMode()
    this.setWndOptionsMode()
  }

  function init() {
    this.fillGamercard()
    base.init()
  }

  function getNavbarMarkup() {
    let tplView = this.getNavbarTplView()
    if (!tplView)
      return null
    return handyman.renderCached("%gui/commonParts/navBar.tpl", tplView)
  }

  function getNavbarTplView() { return null }

  function fillGamercard() {
    fillGamercard(null, "gc_", this.scene)
    this.initGcBackButton()
    this.initSquadWidget()
    this.initVoiceChatWidget()
    this.initRightSection()
  }

  function initGcBackButton() {
    showObjById("gc_nav_back", this.canQuitByGoBack && useTouchscreen && !is_in_loading_screen(), this.scene)
  }

  function initSquadWidget() {
    if (this.squadWidgetHandlerWeak)
      return

    let nestObj = this.scene.findObject(this.squadWidgetNestObjId)
    if (!checkObj(nestObj))
      return

    this.squadWidgetHandlerWeak = initSquadWidgetHandler(nestObj)
    this.registerSubHandler(this.squadWidgetHandlerWeak)
  }

  function initVoiceChatWidget() {
    if (this.canInitVoiceChatWithSquadWidget || this.squadWidgetHandlerWeak == null)
      handlersManager.initVoiceChatWidget(this)
  }

  function updateVoiceChatWidget(shouldShow) {
    showObjById(this.voiceChatWidgetNestObjId, shouldShow, this.scene)
  }

  function initRightSection() {
    if (this.rightSectionHandlerWeak)
      return

    this.rightSectionHandlerWeak = gui_handlers.TopMenuButtonsHandler.create(
      this.scene.findObject("topmenu_menu_panel_right"), this, topMenuRightSideSections,
      this.scene.findObject("right_gc_panel_free_width"))
    this.registerSubHandler(this.rightSectionHandlerWeak)
  }

  



  function getModesTabsView(selectedDiffCode, filterFunc) {
    let tabsView = []
    local isFoundSelected = false
    foreach (diff in g_difficulty.types) {
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

  function updateModesTabsContent(modesObj, view) {
    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(modesObj, data, data.len(), this)

    let selectCb = modesObj?.on_select
    if (selectCb && (selectCb in this))
      this[selectCb](modesObj)
  }

  function fillModeListBox(nest, selectedDiffCode = 0, filterFunc = null, addTabs = []) {
    if (!checkObj(nest))
      return

    let modesObj = nest.findObject("modes_list")
    if (!checkObj(modesObj))
      return

    this.updateModesTabsContent(modesObj, {
      tabs = this.getModesTabsView(selectedDiffCode, filterFunc).extend(addTabs)
    })
  }

  function onTopMenuGoBack(...) {
    this.checkedForward(function() {
      this.goForward(@() eventbus_send("gui_start_mainmenu"), false)
    })
  }

  function afterSave() {
    log("warning! empty afterSave!")
  }

  function save(onlineSave = true) {
    log("save")
    save_profile(onlineSave && is_online_available())
    this.afterSave()
  }

  function goForwardCheckEntitlement(start_func, entitlement) {
    this.guiScene = get_cur_gui_scene()

    this.startFunc = start_func

    if (type(entitlement) == "table")
      this.task = entitlement
    else
      this.task = { loc = entitlement, entitlement = entitlement }

    this.task.gm <- get_game_mode()

    this.taskId = update_entitlements()
    if (is_dev_version() && this.taskId < 0)
      this.goForward(start_func)
    else {
      let taskOptions = {
        showProgressBox = true
        progressBoxText = loc("charServer/checking")
      }
      let taskSuccessCallback = Callback(function () {
          if (isRanksAllowed(this, this.task))
            this.goForward(this.startFunc)
        }, this)
      addTask(this.taskId, taskOptions, taskSuccessCallback)
    }
  }

  function goForwardOrJustStart(start_func, start_without_forward) {
    if (start_without_forward)
      start_func();
    else
      this.goForward(start_func)
  }

  function goForwardIfOnline(start_func, skippable, start_without_forward = false) {
    if (is_online_available()) {
      this.goForwardOrJustStart(start_func, start_without_forward)
      return
    }

    let successCb = Callback( function() {
      this.goForwardOrJustStart(start_func, start_without_forward)
    }, this)
    let errorCb = skippable ? successCb : null

    checkShowMatchingConnect(successCb, errorCb)
  }

  function destroyProgressBox() {
    if (checkObj(this.progressBox)) {
      this.guiScene.destroyElement(this.progressBox)
      broadcastEvent("ModalWndDestroy")
    }
    this.progressBox = null
  }

  function onShowHud(show = true, needApplyPending = false) {
    if (!this.isSceneActive())
      return

    if (this.rootHandlerWeak)
      return this.rootHandlerWeak.onShowHud(show)

    if (!checkObj(this.scene))
      return

    this.scene.show(show)
    if (needApplyPending)
      this.guiScene.applyPendingChanges(false) 
  }

  function startOnlineShop(chapter = null, afterCloseShop = null, metric = "unknown") {
    let handler = this
    this.goForwardIfOnline(function() {
        local closeFunc = null
        if (afterCloseShop)
          closeFunc = function() {
            if (handler)
              afterCloseShop.call(handler)
          }
        ::launchOnlineShop(handler, chapter, closeFunc, metric)
      }, false, true)
  }

  function onOnlineShop(_obj)          { this.startOnlineShop() }
  function onOnlineShopPremium()      { this.startOnlineShop("premium") }
  function onOnlineShopLions()        { this.startOnlineShop("warpoints") }

  function onOnlineShopEagles() {
    if (hasFeature("EnableGoldPurchase"))
      this.startOnlineShop("eagles", null, "gamercard")
    else
      showInfoMsgBox(loc("msgbox/notAvailbleGoldPurchase"))
  }

  function onItemsShop() { eventbus_send("gui_start_itemsShop") }
  function onInventory() { eventbus_send("gui_start_inventory") }

  function onConvertExp(_obj) {
    ::gui_modal_convertExp()
  }

  function notAvailableYetMsgBox() {
    this.msgBox("not_available", loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
  }

  function onUserLog(_obj) {
    if (hasFeature("UserLog"))
      loadHandler(gui_handlers.UserLogHandler)
    else
      this.notAvailableYetMsgBox()
  }

  function onProfile(_obj) {
    let canShowReward = isInMenu.get() && getManualUnlocks().len() >= 1
    let params = canShowReward ? {
      initialSheet = "UnlockAchievement"
      initialUnlockId = getManualUnlocks()[0].id
    } : {}

    if (this.guiScene?.isInAct()) {
      defer(@() loadHandler(gui_handlers.Profile, params))
      return
    }
    loadHandler(gui_handlers.Profile, params)
  }

  function onMyClanOpen() {
    loadHandler(gui_handlers.ClansModalHandler, { startPage = "my_clan" })
  }

  function onGC_chat(_obj) {
    broadcastEvent("ChatCheckIsActive")
    this.switchChatWindow()
  }

  function switchChatWindow() {
    if (gchat_is_enabled() && hasMenuChat.get())
      broadcastEvent("ChatSwitchObject", { scene = this.scene })
  }

  function onSwitchContacts() {
    switchContactsObj(this.scene, this)
  }
  function onGC_contacts(_obj) {
    if (!hasFeature("Friends"))
      return this.notAvailableYetMsgBox()

    if (!isContactsWindowActive())
      updateContacts()

    this.onSwitchContacts()
  }
  function onGC_invites(_obj) {
    loadHandler(gui_handlers.InvitesWnd)
  }
  function onInviteSquad(_obj) {
    eventbus_send("guiStartSearchSquadPlayer")
  }

  function getSlotbar() {
    return this.rootHandlerWeak ? this.rootHandlerWeak.slotbarWeak : this.slotbarWeak
  }

  function getCurSlotUnit() {
    let slotbar = this.getSlotbar()
    return slotbar && slotbar.getCurSlotUnit()
  }

  function getHangarFallbackUnitParams() {
    return this.getSlotbar()?.getHangarFallbackUnitParams()
  }

  function getCurCrew() {
    let slotbar = this.getSlotbar()
    return slotbar && slotbar.getCurCrew()
  }

  function getCurSlotbarCountry() {
    local slotbar = this.getSlotbar()
    return slotbar && slotbar.getCurCountry()
  }

  function onSlotsChangeAutoRefill(obj) {
    if (this.slotbarWeak?.slotbarOninit ?? false)
      return
    let mode = obj.id == "slots-autorepair" ? 0
      : obj.id == "slots-autoweapon" ? 1
      : -1

    if (mode == -1)
      return

    local value = obj.getValue()
    if (value == get_auto_refill(mode))
      return
    set_auto_refill(mode, value)
    addTask(save_online_single_job(SAVE_WEAPON_JOB_DIGIT), { showProgressBox = true })
    broadcastEvent("AutorefillChanged", { id = obj.id, value })
  }

  
  function createSlotbar(params = {}, nest = "nav-help") {
    if (this.slotbarWeak) {
      this.slotbarWeak.setParams(params)
      return
    }

    if (u.isString(nest))
      nest = this.scene.findObject(nest)
    params.scene <- nest
    params.ownerWeak <- this.weakref()

    let slotbar = this.createSlotbarHandler(params)
    if (!slotbar)
      return

    this.slotbarWeak = slotbar.weakref()
    this.registerSubHandler(slotbar)
  }

  function createSlotbarHandler(params) {
    return gui_handlers.SlotbarWidget.create(params)
  }

  function reinitSlotbar() { 
    let slotbar = this.getSlotbar()
    if (slotbar)
      slotbar.fullUpdate()
  }

  function destroySlotbar() {
    if (this.slotbarWeak)
      this.slotbarWeak.destroy()
    this.slotbarWeak = null
  }

  function getSlotbarActions() {
    return this.slotbarActions || defaultSlotbarActions
  }

  getParamsForActionsList = @() {}
  getUnitParamsFromObj = @(unitObj) {
    unit = getAircraftByName(unitObj?.unit_name)
    crew = unitObj?.crew_id ? getCrewById(unitObj.crew_id.tointeger()) : null
  }

  function openUnitActionsList(unitObj, ignoreSelect = false, ignoreHover = false) {
    if (!checkObj(unitObj) || (!ignoreHover && !unitObj.isHovered()))
      return
    let parentObj = unitObj.getParent()
    if (!checkObj(parentObj)
      || (!ignoreSelect && (parentObj?.chosen ?? parentObj?.selected) != "yes"))
      return

    if (unitContextMenuState.value?.unitObj.isValid()
      && unitContextMenuState.value.unitObj.isEqual(unitObj))
      return unitContextMenuState({unitObj, handler = this, needClose = true})

    unitContextMenuState({
      unitObj
      needCloseTooltips = true
      actionsNames = this.getSlotbarActions()
      closeOnUnhover = !ignoreHover
      curEdiff = this.getCurrentEdiff?() ?? -1
      shouldCheckCrewsReady = this.shouldCheckCrewsReady
      slotbar = this.getSlotbar()
    }.__update(this.getParamsForActionsList(), this.getUnitParamsFromObj(unitObj)))
  }

  function onOpenActionsList(obj) {
    this.openUnitActionsList(obj.getParent().getParent(), true)
  }

  function getSlotbarPresetsList() {
    return this.rootHandlerWeak ? this.rootHandlerWeak.presetsListWeak : this.presetsListWeak
  }

  function setSlotbarPresetsListAvailable(isAvailable) {
    if (isAvailable) {
      if (this.presetsListWeak)
        this.presetsListWeak.update()
      else
        this.presetsListWeak = ::SlotbarPresetsList(this).weakref()
    }
    else if (this.presetsListWeak)
      this.presetsListWeak.destroy()
  }

  function slotOpCb(id, tType, result) {
    if (id != this.taskId) {
      log("wrong ID in char server cb, ignoring");
      charCallback(id, tType, result)
      return
    }
    restoreCharCallback()
    this.destroyProgressBox()

    eventbus_send("request_show_banned_status_msgbox", {showBanOnly = true})

    if (result != 0) {
      let handler = this
      local text = loc("charServer/updateError/" + result.tostring())

      if (result == EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS) {
        let notAllowedChars = get_char_extended_error()
        text = format(text, notAllowedChars)
      }

      handler.msgBox("char_connecting_error", text,
      [
        ["ok",  function() {
            if (this.afterSlotOpError != null)
              this.afterSlotOpError(result)
          } ]
      ], "ok")
      return
    }
    else if (this.afterSlotOp != null)
    this.afterSlotOp()
  }

  function showTaskProgressBox(text = null, cancelFunc = null, delayedButtons = 30) {
    if (checkObj(this.progressBox))
      return

    if (text == null)
      text = loc("charServer/purchase0")

    if (cancelFunc == null)
      cancelFunc = function() {}

    this.progressBox = this.msgBox("char_connecting",
        text,
        [["cancel", cancelFunc]], "cancel",
        { waitAnim = true,
          delayedButtons = delayedButtons
        })
  }

  function onGenericTooltipOpen(obj) {
    openGenericTooltip(obj, this)
  }

  function onTooltipObjClose(obj) {
    closeGenericTooltip(obj, this)
  }

  function onContactTooltipOpen(obj) {
    let { uid = "", steamId = "" } = obj
    local contact = null
    if (uid != "")
      contact = ::getContact(uid)
    else if (steamId != "")
      contact = steamContactsGroup.get()?[steamId.tointeger()]
    let canShow = this.canShowContactTooltip(contact)
    obj["class"] = canShow ? "" : "empty"

    if (canShow)
      ::fillContactTooltip(obj, contact, this)
  }

  function canShowContactTooltip(contact) {
    return contact != null
  }

  function onQueuesTooltipOpen(obj) {
    this.guiScene.replaceContent(obj, "%gui/queue/queueInfoTooltip.blk", this)
    SecondsUpdater(obj.findObject("queue_tooltip_root"), function(obj_, _params) {
      obj_.findObject("text").setValue(getQueuesInfoText())
    })
  }

  function onProjectawardTooltipOpen(obj) {
    if (!checkObj(obj))
      return
    let img = obj?.img ?? ""
    let title = obj?.title ?? ""
    let desc = obj?.desc ?? ""

    this.guiScene.replaceContent(obj, "%gui/customization/decalTooltip.blk", this)
    obj.findObject("header").setValue(title)
    obj.findObject("description").setValue(desc)
    let imgObj = obj.findObject("image")
    imgObj["background-image"] = img
    let picDiv = imgObj.getParent()
    picDiv["size"] = "128*@sf/@pf_outdated, 128*@sf/@pf_outdated"
    picDiv.show(true)
  }

  function onViewImage(obj) {
    ::view_fullscreen_image(obj)
  }

  function onFaq()             { openUrl(getCurCircuitOverride("faqURL", loc("url/faq"))) }
  function onSupport()         { openUrl(getCurCircuitOverride("supportURL", loc("url/support"))) }
  function onWiki()            { openUrl(getCurCircuitOverride("wikiURL", loc("url/wiki"))) }

  function unstickLastDropDown(newObj = null, forceMove = "no") {
    if (checkObj(stickedDropDown) && (!newObj || !stickedDropDown.isEqual(newObj))) {
      setForceMove(stickedDropDown, forceMove)
      stickedDropDown.getScene().applyPendingChanges(false)
      this.onStickDropDown(stickedDropDown, false)
      stickedDropDown = null
    }
  }

  function forceCloseDropDown(obj) {
    let rootObj = getDropDownRootObj(obj)
    if (rootObj != null)
      setForceMove(rootObj, "close")
  }

  function onDropDownToggle(obj) {
    obj = getDropDownRootObj(obj)
    if (!obj)
      return

    let needStick = obj?.forceMove != "open"
    setForceMove(obj, needStick ? "open" : "no")
    this.unstickLastDropDown(obj, needStick ? "close" : "no")

    this.guiScene.applyPendingChanges(false)
    stickedDropDown = needStick ? obj : null
    this.onStickDropDown(obj, needStick)
  }

  function onHoverSizeMove(obj) {
    
    if (!is_mouse_last_time_used())
      return
    this.unstickLastDropDown(getDropDownRootObj(obj))
  }

  function onGCDropdown(obj) {
    local id = obj?.id
    let ending = "_panel"
    if (id && id.len() > ending.len() && id.slice(id.len() - ending.len()) == ending)
      id = id.slice(0, id.len() - ending.len())
    if (!isInArray(id, this.GCDropdownsList))
      return

    let btnObj = obj.findObject($"{id}_btn")
    if (checkObj(btnObj))
      this.onDropDownToggle(btnObj)
  }

  function onStickDropDown(obj, show) {
    if (!checkObj(obj))
      return

    let id = obj?.id
    if (!show || !isInArray(id, this.GCDropdownsList)) {
      this.curGCDropdown = null
      return
    }

    this.curGCDropdown = id
    move_mouse_on_obj(obj)
    this.guiScene.playSound("menu_appear")
  }

  function moveToFirstEnabled(obj) {
    let total = obj.childrenCount()
    for (local i = 0; i < total; i++) {
      let child = obj.getChild(i)
      if (!child.isValid() || !child.isEnabled())
        continue
      move_mouse_on_obj(child)
      break
    }
  }

  function onDropdownAnimFinish(obj) {
    
    let isOpened = obj.getFloatProp(timerPID, 0.0) == 1
    if (!isOpened) {
      let rootObj = getDropDownRootObj(obj)
      this.guiScene.performDelayed({}, function() {
        if (rootObj?.isValid())
          setForceMove(rootObj, "no") 
      })
      return
    }

    if (is_mouse_last_time_used() || !stickedDropDown?.isValid())
      return
    let rootObj = getDropDownRootObj(obj)
    if (!rootObj || !stickedDropDown.isEqual(rootObj))
      return
    let menuObj = this.getCurGCDropdownMenu()
    if (!menuObj?.isValid())
      return
    this.moveToFirstEnabled(menuObj)
    local tempTask = -1
    tempTask = periodic_task_register(this,
      function(_) {
        if (this.isValid() && stickedDropDown?.isValid() && rootObj?.isValid() && stickedDropDown.isEqual(rootObj))
          this.unstickLastDropDown()
        periodic_task_unregister(tempTask)
      },
      1)
  }

  function onDropdownHover(obj) {
    
    if (!showConsoleButtons.get() || !checkObj(stickedDropDown) || obj.getFloatProp(timerPID, 0.0) < 1)
      return
    let btn = this.getCurGCDropdownBtn()
    if (btn && (getDropDownRootObj(btn)?.getIntProp(forceTimePID, 0) ?? 0) > get_time_msec() + 100)
      this.unstickLastDropDown()
  }

  onBackDropdownMenu   = @(obj) move_mouse_on_obj(this.getObj($"{obj?.sectionId}_btn"))
  getCurGCDropdownBtn  = @() this.curGCDropdown != null ? this.getObj($"{this.curGCDropdown}_btn") : null
  getCurGCDropdownMenu = @() this.curGCDropdown != null ? this.getObj($"{this.curGCDropdown}_focus") : null

  function setSceneTitle(text, placeObj = null, name = "gc_title") {
    if (!placeObj)
     placeObj = this.scene

    if (text == null || !checkObj(placeObj))
      return

    let textObj = placeObj.findObject(name)
    if (checkObj(textObj))
      textObj.setValue(text.tostring())
  }

  function restoreMainOptions() {
    if (this.mainOptionsMode >= 0)
      setGuiOptionsMode(this.mainOptionsMode)
    if (this.mainGameMode >= 0)
      set_game_mode(this.mainGameMode)
  }

  function setWndGameMode() {
    if (this.wndGameMode < 0)
      return
    this.mainGameMode = get_game_mode()
    set_game_mode(this.wndGameMode)
  }

  function setWndOptionsMode() {
    if (this.wndOptionsMode < 0)
      return
    this.mainOptionsMode = getGuiOptionsMode()
    setGuiOptionsMode(this.wndOptionsMode)
  }

  function checkAndStart(onSuccess, onCancel, checkName, checkParam = null) {
    checkQueueAndStart(callback.make(onSuccess, this), callback.make(onCancel, this),
      checkName, checkParam)
  }

  function checkedNewFlight(func, cancelFunc = null) { this.checkAndStart(func, cancelFunc, "isCanNewflight") }
  function checkedForward(func, cancelFunc = null) { this.checkAndStart(func, cancelFunc, "isCanGoForward") }
  function checkedCrewModify(func, cancelFunc = null) { this.checkAndStart(func, cancelFunc, "isCanModifyCrew") }
  function checkedAirChange(func, cancelFunc = null) {
    
    this.checkAndStart(func, cancelFunc, "isCanAirChange")
  }
  function checkedCrewAirChange(func, cancelFunc = null) {
    
    this.checkAndStart(
      function() {
        checkSquadUnreadyAndDo(callback.make(func, this),
          callback.make(cancelFunc, this), this.shouldCheckCrewsReady)
      },
      cancelFunc, "isCanModifyCrew")
  }
  function checkedModifyQueue(qType, func, cancelFunc = null) {
    this.checkAndStart(func, cancelFunc, "isCanModifyQueueParams", qType)
  }

  function proccessLinkFromText(obj, _itype, link) {
    openUrl(link, false, false, obj?.bqKey ?? obj?.id)
  }

  function onModalWndDestroy() {
    base.onModalWndDestroy()
    broadcastEvent("ChatCheckScene")
  }

  function onSceneActivate(show) {
    if (show) {
      this.setWndGameMode()
      this.setWndOptionsMode()
    }
    else
      this.restoreMainOptions()

    if (is_hud_visible())
      this.onShowHud()

    base.onSceneActivate(show)
  }

  function getControlsAllowMask() {
    return this.wndControlsAllowMask
  }

  function switchControlsAllowMask(mask) {
    if (mask == this.wndControlsAllowMask)
      return

    this.wndControlsAllowMask = mask
    handlersManager.updateControlsAllowMask()
  }

  function getWidgetsList() {
    let result = []
    if (this.widgetsList)
      foreach (widgetDesc in this.widgetsList) {
        result.append({ widgetId = widgetDesc.widgetId })
        if ("placeholderId" in widgetDesc)
          result.top()["transform"] <- this.getWidgetParams(widgetDesc.placeholderId)
      }
    return result
  }

  function getWidgetParams(placeholderId) {
    let placeholderObj = this.scene.findObject(placeholderId)
    if (!checkObj(placeholderObj))
      return null

    return {
      pos = placeholderObj.getPosRC()
      size = placeholderObj.getSize()
    }
  }

  function sendInvitation() {}

  
  function onModActionBtn() {}
  function onModItemClick() {}
  function onModItemDblClick() {}
  function onModCheckboxClick() {}
  function onAltModAction() {}
  function onModChangeBulletsSlider() {}
  onAltModActionCommon = @() null
  onModUnhover = @() null
  onModButtonNestUnhover = @() null
  onGoToModTutorial = @() null

  function onShowMapRenderFilters() {}

  function onCustomLangInfo() {
    this.guiScene.performDelayed(this, @() broadcastEvent("showOptionsWnd"))
  }

  onCustomSoundMods = @() this.guiScene.performDelayed(this,
    @() broadcastEvent("showOptionsWnd", { group = "sound" }))

  function onUnitHover(obj) {
    ::gcb.delayedTooltipHover(obj)
  }
}

gui_handlers.BaseGuiHandlerWT <- BaseGuiHandlerWT

return {
  stickedDropDown
}

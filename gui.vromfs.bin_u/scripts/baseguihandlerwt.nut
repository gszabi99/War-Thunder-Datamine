//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import SAVE_WEAPON_JOB_DIGIT

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { move_mouse_on_obj, isInMenu, handlersManager, loadHandler, is_in_loading_screen
} = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let penalties = require("%scripts/penitentiary/penalties.nut")
let callback = require("%sqStdLibs/helpers/callback.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let updateContacts = require("%scripts/contacts/updateContacts.nut")
let unitContextMenuState = require("%scripts/unit/unitContextMenuState.nut")
let { isChatEnabled, hasMenuChat } = require("%scripts/chat/chatStates.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { get_time_msec } = require("dagor.time")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { setGuiOptionsMode, getGuiOptionsMode } = require("guiOptions")
let { set_game_mode, get_game_mode } = require("mission")
let { getManualUnlocks } = require("%scripts/unlocks/personalUnlocks.nut")
let { checkShowMatchingConnect } = require("%scripts/matching/matchingOnline.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { switchContactsObj, isContactsWindowActive } = require("%scripts/contacts/contactsHandlerState.nut")
let { addTask, charCallback, restoreCharCallback } = require("%scripts/tasker.nut")
let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")

local stickedDropDown = null
let defaultSlotbarActions = [
  "autorefill", "aircraft", "sec_weapons", "weapons", "showroom",
  "testflight", "crew", "goto_unlock", "info", "repair"
]
let timerPID = dagui_propid_add_name_id("_size-timer")
let forceTimePID = dagui_propid_add_name_id("force-time")

let function moveToFirstEnabled(obj) {
  let total = obj.childrenCount()
  for (local i = 0; i < total; i++) {
    let child = obj.getChild(i)
    if (!child.isValid() || !child.isEnabled())
      continue
    move_mouse_on_obj(child)
    break
  }
}

let function setForceMove(obj, value) {
  obj.forceMove = value
  obj.setIntProp(forceTimePID, get_time_msec())
}

let function getDropDownRootObj(obj) {
  while (obj != null) {
    if (obj?["class"] == "dropDown")
      return obj
    obj = obj.getParent()
  }
  return null
}

let BaseGuiHandlerWT = class extends ::BaseGuiHandler {
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
    ::fill_gamer_card(null, "gc_", this.scene)
    this.initGcBackButton()
    this.initSquadWidget()
    this.initVoiceChatWidget()
    this.initRightSection()
  }

  function initGcBackButton() {
    this.showSceneBtn("gc_nav_back", this.canQuitByGoBack && useTouchscreen && !is_in_loading_screen())
  }

  function initSquadWidget() {
    if (this.squadWidgetHandlerWeak)
      return

    let nestObj = this.scene.findObject(this.squadWidgetNestObjId)
    if (!checkObj(nestObj))
      return

    this.squadWidgetHandlerWeak = ::init_squad_widget_handler(nestObj)
    this.registerSubHandler(this.squadWidgetHandlerWeak)
  }

  function initVoiceChatWidget() {
    if (this.canInitVoiceChatWithSquadWidget || this.squadWidgetHandlerWeak == null)
      handlersManager.initVoiceChatWidget(this)
  }

  function updateVoiceChatWidget(shouldShow) {
    this.showSceneBtn(this.voiceChatWidgetNestObjId, shouldShow)
  }

  function initRightSection() {
    if (this.rightSectionHandlerWeak)
      return

    this.rightSectionHandlerWeak = gui_handlers.TopMenuButtonsHandler.create(this.scene.findObject("topmenu_menu_panel_right"),
                                                                          this,
                                                                          ::g_top_menu_right_side_sections,
                                                                          this.scene.findObject("right_gc_panel_free_width")
                                                                         )
    this.registerSubHandler(this.rightSectionHandlerWeak)
  }

  /**
   * @param filterFunc Optional filter function with mode id
   *                   as parameter and boolean return type.
   */
  function getModesTabsView(selectedDiffCode, filterFunc) {
    let tabsView = []
    local isFoundSelected = false
    foreach (diff in ::g_difficulty.types) {
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
      this.goForward(::gui_start_mainmenu, false)
    })
  }

  function afterSave() {
    log("warning! empty afterSave!")
  }

  function save(onlineSave = true) {
    let handler = this
    log("save")
    if (::is_save_device_selected()) {
      local saveRes = SAVELOAD_OK;
      saveRes = ::save_profile(onlineSave && ::is_online_available())

      if (saveRes != SAVELOAD_OK) {
        log("saveRes = " + saveRes.tostring())
        local txt = "x360/noSaveDevice"
        if (saveRes == SAVELOAD_NO_SPACE)
          txt = "x360/noSpace"
        else if (saveRes == SAVELOAD_NOT_SELECTED)
          txt = "xbox360/questionSelectDevice"
        this.msgBox("no_save_device", loc(txt),
        [
          ["yes", function() {
              log("performDelayed save")
              handler.guiScene.performDelayed(handler, function() {
                ::select_save_device(true)
                this.save(onlineSave)
                handler.afterSave()
              })
          }],
          ["no", function() {
            handler.afterSave()
          }
          ]
        ], "yes")
      }
      else
        handler.afterSave()
    }
    else {
      this.msgBox("no_save_device", loc("xbox360/questionSelectDevice"),
      [
        ["yes", function() {

            log("performDelayed save")
            handler.guiScene.performDelayed(handler, function() {
              ::select_save_device(true)
              this.save(onlineSave)
            })
        }],
        ["no", function() {
          handler.afterSave()
        }
        ]
      ], "yes")
    }
  }

  function goForwardCheckEntitlement(start_func, entitlement) {
    this.guiScene = get_cur_gui_scene()

    this.startFunc = start_func

    if (type(entitlement) == "table")
      this.task = entitlement
    else
      this.task = { loc = entitlement, entitlement = entitlement }

    this.task.gm <- get_game_mode()

    this.taskId = ::update_entitlements()
    if (::is_dev_version && this.taskId < 0)
      this.goForward(start_func)
    else {
      let taskOptions = {
        showProgressBox = true
        progressBoxText = loc("charServer/checking")
      }
      let taskSuccessCallback = Callback(function () {
          if (::checkAllowed.bindenv(this)(this.task))
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
    if (::is_online_available()) {
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
      this.guiScene.applyPendingChanges(false) //to correct work isVisible() for scene objects after event
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
        ::OnlineShopModel.launchOnlineShop(handler, chapter, closeFunc, metric)
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

  function onItemsShop() { ::gui_start_itemsShop() }
  function onInventory() { ::gui_start_inventory() }

  function onConvertExp(_obj) {
    ::gui_modal_convertExp()
  }

  function notAvailableYetMsgBox() {
    this.msgBox("not_available", loc("msgbox/notAvailbleYet"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
  }

  function onUserLog(_obj) {
    if (hasFeature("UserLog"))
      ::gui_modal_userLog()
    else
      this.notAvailableYetMsgBox()
  }

  function onProfile(_obj) {
    let canShowReward = isInMenu() && getManualUnlocks().len() >= 1
    let params = canShowReward ? {
      initialSheet = "UnlockAchievement"
      initialUnlockId = getManualUnlocks()[0].id
    } : {}
    ::gui_start_profile(params)
  }

  function onMyClanOpen() {
    loadHandler(gui_handlers.ClansModalHandler, { startPage = "my_clan" })
  }

  function onGC_chat(_obj) {
    if (!::isMenuChatActive())
      isChatEnabled(true)

    this.switchChatWindow()
  }

  function switchChatWindow() {
    if (::gchat_is_enabled() && hasMenuChat.value)
      ::switchMenuChatObj(::getChatDiv(this.scene))
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
    ::gui_start_invites()
  }
  function onInviteSquad(_obj) {
    ::gui_start_search_squadPlayer()
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

  function onTake(unit, params = {}) {
    unitActions.take(unit, {
        unitObj = unit?.name ? this.scene.findObject(unit.name) : null
        shouldCheckCrewsReady = this.shouldCheckCrewsReady
      }.__update(params))
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
    if (value == ::get_auto_refill(mode))
      return
    ::set_auto_refill(mode, value)
    addTask(::save_online_single_job(SAVE_WEAPON_JOB_DIGIT), { showProgressBox = true })
    broadcastEvent("AutorefillChanged", { id = obj.id, value })
  }

  //"nav-help" - navBar
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

  function reinitSlotbar() { //!!FIX ME: Better to not use it.
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
    crew = unitObj?.crew_id ? ::get_crew_by_id(unitObj.crew_id.tointeger()) : null
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
      return unitContextMenuState(null)

    unitContextMenuState({
      unitObj
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

    penalties.showBannedStatusMsgBox(true)

    if (result != 0) {
      let handler = this
      local text = loc("charServer/updateError/" + result.tostring())

      if (("EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS" in getroottable())
        && ("get_char_extended_error" in getroottable()))
        if (result == EASTE_ERROR_NICKNAME_HAS_NOT_ALLOWED_CHARS) {
          let notAllowedChars = ::get_char_extended_error()
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
    ::g_tooltip.open(obj, this)
  }

  function onTooltipObjClose(obj) {
    ::g_tooltip.close.call(this, obj)
  }

  function onContactTooltipOpen(obj) {
    let uid = obj?.uid
    local canShow = false
    local contact = null
    if (uid) {
      contact = ::getContact(uid)
      canShow = this.canShowContactTooltip(contact)
    }
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
      obj_.findObject("text").setValue(::queues.getQueuesInfoText())
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

  function onFaq()             { openUrl(loc("url/faq")) }
  function onForum()           { openUrl(loc("url/forum")) }
  function onSupport()         { openUrl(loc("url/support")) }
  function onWiki()            { openUrl(loc("url/wiki")) }

  function onSquadCreate(_obj) {
    if (::g_squad_manager.isInSquad())
      this.msgBox("already_in_squad", loc("squad/already_in_squad"), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })
    else
      ::chatInviteToSquad(null, this)
  }

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
    //this only for pc mouse logic. For animated gamepad cursor look onDropdownAnimFinish
    if (!::is_mouse_last_time_used())
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

    let btnObj = obj.findObject(id + "_btn")
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

  function onDropdownAnimFinish(obj) {
    //this only for animated gamepad cursor. for pc mouse logic look onHoverSizeMove
    let isOpened = obj.getFloatProp(timerPID, 0.0) == 1
    if (!isOpened) {
      let rootObj = getDropDownRootObj(obj)
      this.guiScene.performDelayed({}, function() {
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
    let menuObj = this.getCurGCDropdownMenu()
    if (!menuObj?.isValid())
      return
    moveToFirstEnabled(menuObj)
    local tempTask = -1
    tempTask = ::periodic_task_register(this,
      function(_) {
        if (this.isValid() && stickedDropDown?.isValid() && rootObj?.isValid() && stickedDropDown.isEqual(rootObj))
          this.unstickLastDropDown()
        ::periodic_task_unregister(tempTask)
      },
      1)
  }

  function onDropdownHover(obj) {
    // see func onDropdownAnimFinish
    if (!showConsoleButtons.value || !checkObj(stickedDropDown) || obj.getFloatProp(timerPID, 0.0) < 1)
      return
    let btn = this.getCurGCDropdownBtn()
    if (btn && (getDropDownRootObj(btn)?.getIntProp(forceTimePID, 0) ?? 0) > get_time_msec() + 100)
      this.unstickLastDropDown()
  }

  onBackDropdownMenu   = @(obj) move_mouse_on_obj(this.getObj($"{obj?.sectionId}_btn"))
  getCurGCDropdownBtn  = @() this.curGCDropdown != null ? this.getObj(this.curGCDropdown + "_btn") : null
  getCurGCDropdownMenu = @() this.curGCDropdown != null ? this.getObj(this.curGCDropdown + "_focus") : null

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
    ::queues.checkAndStart(callback.make(onSuccess, this), callback.make(onCancel, this),
      checkName, checkParam)
  }

  function checkedNewFlight(func, cancelFunc = null) { this.checkAndStart(func, cancelFunc, "isCanNewflight") }
  function checkedForward(func, cancelFunc = null) { this.checkAndStart(func, cancelFunc, "isCanGoForward") }
  function checkedCrewModify(func, cancelFunc = null) { this.checkAndStart(func, cancelFunc, "isCanModifyCrew") }
  function checkedAirChange(func, cancelFunc = null) {
    //change selected air
    this.checkAndStart(func, cancelFunc, "isCanAirChange")
  }
  function checkedCrewAirChange(func, cancelFunc = null) {
    //change air in slot
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
    ::checkMenuChatBack()
  }

  function onSceneActivate(show) {
    if (show) {
      this.setWndGameMode()
      this.setWndOptionsMode()
    }
    else
      this.restoreMainOptions()

    if (::is_hud_visible())
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

  //!!!FIX ME Need remove this functions from base handlre. It is need only for weapons
  function onModActionBtn() {}
  function onModItemClick() {}
  function onModItemDblClick() {}
  function onModCheckboxClick() {}
  function onAltModAction() {}
  function onModChangeBulletsSlider() {}
  onAltModActionCommon = @() null
  onModUnhover = @() null
  onModButtonNestUnhover = @() null

  function onShowMapRenderFilters() {}

  function onCustomLangInfo() {
   this.guiScene.performDelayed(this, @() broadcastEvent("showOptionsWnd"))
  }
}

gui_handlers.BaseGuiHandlerWT <- BaseGuiHandlerWT

return {
  stickedDropDown
}

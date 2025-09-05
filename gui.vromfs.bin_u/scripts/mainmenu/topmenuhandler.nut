from "%scripts/dagui_natives.nut" import is_news_adver_actual, req_news, get_news_blk
from "%scripts/dagui_library.nut" import *

let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { get_current_base_gui_handler } = require("%sqDagui/framework/baseGuiHandlerManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let SecondsUpdater = require("%sqDagui/timer/secondsUpdater.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let DataBlock = require("DataBlock")
let time = require("%scripts/time.nut")
let { topMenuHandler, topMenuShopActive, unitToShowInShop } = require("%scripts/mainmenu/topMenuStates.nut")
let { setShowUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")
let { PRICE, ENTITLEMENTS_PRICE } = require("%scripts/utils/configs.nut")
let { checkUnlockMarkers } = require("%scripts/unlocks/unlockMarkers.nut")
let { isPlatformPS4 } = require("%scripts/clientState/platform.nut")
let { isRunningOnPS5 = @() false } = require_optional("sony")
let { switchContactsObj, getLastContactsSceneShow } = require("%scripts/contacts/contactsHandlerState.nut")
let { isUsedCustomLocalization, getLocalization } = require("%scripts/langUtils/customLocalization.nut")
let { getUnlockedCountries } = require("%scripts/firstChoice/firstChoice.nut")
let math = require("math")
let { getDaguiObjAabb } = require("%sqDagui/daguiUtil.nut")
let { addBgTaskCb } = require("%scripts/tasker.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { isUsedCustomSoundMods } = require("%scripts/options/customSoundMods.nut")
let { getCurLangShortName } = require("%scripts/langUtils/language.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let { stashBhvValueConfig } = require("%sqDagui/guiBhv/guiBhvValueConfig.nut")
let { needShowGameModesNotLoadedMsg } = require("%scripts/matching/matchingGameModes.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { lastChatSceneShow } = require("%scripts/chat/chatConsts.nut")
let { updateGamercards } = require("%scripts/gamercard/gamercard.nut")
let { topMenuLeftSideSections } = require("%scripts/mainmenu/topMenuSections.nut")

let dmViewer = require("%scripts/dmViewer/dmViewer.nut")

class TopMenu (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.ROOT
  keepLoaded = true
  sceneBlkName = "%gui/mainmenu/topMenuScene.blk"

  leftSectionHandlerWeak = null

  topMenu = true
  topMenuInited = false
  menuConfig = null 

  canQuitByGoBack = false

  shopWeak = null

  checkAdvertTimer = 0.0
  checkPriceTimer = 0.0

  isWaitForContentToActivateScene = false
  isInQueue = false

  constructor(gui_scene, params = {}) {
    base.constructor(gui_scene, params)
    topMenuHandler.set(this)
  }

  function initScreen() {
    this.fillGamercard()
    this.reinitScreen()

    this.updateCustomLangInfo()
    this.updateCustomSoundModsBtn()
    this.initModesNotLoadedBtn()
  }

  function reinitScreen(_params = null) {
    if (!this.topMenuInited && isLoggedIn.get()) {
      this.topMenuInited = true

      this.leftSectionHandlerWeak = gui_handlers.TopMenuButtonsHandler.create(
        this.scene.findObject("topmenu_menu_panel"),
        this,
        topMenuLeftSideSections,
        this.scene.findObject("left_gc_panel_free_width")
      )
      this.registerSubHandler(this.leftSectionHandlerWeak)

      if (lastChatSceneShow.get())
        this.switchChatWindow()
      if (getLastContactsSceneShow())
        this.onSwitchContacts()

      this.initTopMenuTimer()
      this.instantOpenShopWnd()
      this.createSlotbar(
        {
          hasResearchesBtn = true
          mainMenuSlotbar = true
          hasExtraInfoBlock = true
          hasExtraInfoBlockTop = true
          onCountryDblClick = function() {
            if (!topMenuShopActive.get())
              this.shopWndSwitch()
          }.bindenv(this)
        },
        "nav-topMenu"
      )

      showObjById("topmenu_psn_update", isPlatformPS4 && isRunningOnPS5(), this.scene)
    }
  }

  function initTopMenuTimer() {
    let obj = this.getObj("top_menu_scene_timer")
    if (checkObj(obj))
      obj.setUserData(this)
  }

  function getBaseHandlersContainer() { 
    return this.scene.findObject("topMenu_content")
  }

  function onNewContentLoaded(handler) {
    this.checkAdvert()

    let hasResearch = getTblValue("hasTopMenuResearch", handler, true)
    showObjById("topmenu_btn_shop_wnd", hasResearch, this.scene)
    if (!hasResearch)
      this.closeShop()

    if (this.isWaitForContentToActivateScene) {
      this.isWaitForContentToActivateScene = false
      this.onSceneActivate(true)
    }
  }

  function onTopMenuUpdate(_obj, dt) {
    this.checkAdvertTimer -= dt
    if (this.checkAdvertTimer <= 0) {
      this.checkAdvertTimer = 120.0
      this.checkAdvert()
    }

    PRICE.checkUpdate()
    ENTITLEMENTS_PRICE.checkUpdate()

    checkUnlockMarkers()
  }

  function checkAdvert() {
    if (!is_news_adver_actual()) {
      let t = req_news()
      if (t >= 0)
        return addBgTaskCb(t, this.updateAdvert, this)
    }
    this.updateAdvert()
  }

  function updateAdvert() {
    let obj = this.scene.findObject("topmenu_advert")
    if (!checkObj(obj))
      return

    let blk = DataBlock()
    get_news_blk(blk)
    let text = loc(blk?.advert ?? "", "")
    SecondsUpdater(obj, function(tObj, _params) {
      let stopUpdate = text.indexof("{time_countdown=") == null
      let textResult = time.processTimeStamps(text)
      let objText = tObj.findObject("topmenu_advert_text")
      objText.setValue(textResult)
      tObj.show(textResult != "")
      return stopUpdate
    })
  }

  function onQueue(inQueue) {
    if (this.isInQueue == inQueue)
      return
    this.isInQueue = inQueue

    let slotbar = this.getSlotbar()
    if (slotbar)
      slotbar.shade(inQueue)
    this.updateSceneShade()

    if (inQueue) {
      if (topMenuShopActive.get())
        this.shopWndSwitch()

      broadcastEvent("SetInQueue")
    }
  }

  function updateSceneShade() {
    local obj = this.getObj("topmenu_backshade_dark")
    if (checkObj(obj))
      obj.animation = this.isInQueue ? "show" : "hide"

    obj = this.getObj("topmenu_backshade_light")
    if (checkObj(obj))
      obj.animation = !this.isInQueue && topMenuShopActive.get() ? "show" : "hide"
  }

  function getCurrentEdiff() {
    return (topMenuShopActive.get() && this.shopWeak) ? this.shopWeak.getCurrentEdiff() : getCurrentGameModeEdiff()
  }

  function canShowShop() {
    return !topMenuShopActive.get()
  }

  function canShowDmViewer() {
    return !topMenuShopActive.get()
  }

  function closeShop() {
    if (topMenuShopActive.get())
      this.shopWndSwitch()
  }

  function setShopUnitType(unitType) {
    if (unitType && this.shopWeak)
      this.shopWeak.setUnitType(unitType)
  }

  function updateCustomLangInfo() {
    let isShowInfo = !topMenuShopActive.get() && isUsedCustomLocalization()
    let infoObj = showObjById("custom_lang_info", isShowInfo, this.scene)
    if (!isShowInfo)
      return

    infoObj.tooltip = getLocalization("mainmenu/custom_lang_info/tooltip")
    infoObj.setValue(getLocalization("mainmenu/custom_lang_info"))
  }

  function updateCustomSoundModsBtn() {
    let isShowBtn = !topMenuShopActive.get() && isUsedCustomSoundMods()
    showObjById("custom_sound_mods", isShowBtn, this.scene)
  }

  function shopWndSwitch(unitType = null) {
    if (!this.isValid())
      return

    if (isSmallScreen) {
      topMenuShopActive.set(false)
      gui_handlers.ShopViewWnd.open({ forceUnitType = unitType })
      return
    }

    topMenuShopActive.set(!topMenuShopActive.get())
    let shopMove = this.getObj("shop_wnd_move")
    shopMove.moveOut = topMenuShopActive.get() ? "yes" : "no"
    let closeResearch = this.getObj("research_closeButton")
    let showButton = shopMove.moveOut == "yes"

    dmViewer.update()

    if (showButton)
      this.guiScene.playSound("menu_appear")
    if (checkObj(closeResearch))
      closeResearch.show(showButton)
    this.activateShopImpl(topMenuShopActive.get(), unitType)
    if (this.shopWeak && this.shopWeak.getCurrentEdiff() != getCurrentGameModeEdiff())
      this.shopWeak.updateSlotbarDifficulty()

    this.updateCustomLangInfo()
    this.updateCustomSoundModsBtn()
    broadcastEvent("ShopWndSwitched")
    if (!topMenuShopActive.get())
      unitToShowInShop.set(null)
  }

  function openShop(unitType = null) {
    this.setShopUnitType(unitType)
    if (!topMenuShopActive.get())
      this.shopWndSwitch(unitType) 
  }

  function instantOpenShopWnd() {
    if (topMenuShopActive.get()) {
      let shopMove = this.getObj("shop_wnd_move")
      if (!checkObj(shopMove))
        return

      let closeResearch = this.getObj("research_closeButton")
      if (checkObj(closeResearch))
        closeResearch.show(true)

      shopMove.moveOut = "yes"
      shopMove["_size-timer"] = "1"
      shopMove.setFloatProp(dagui_propid_add_name_id("_size-timer"), 1.0)
      shopMove.height = "sh"

      this.guiScene.performDelayed(this, function () { this.updateOnShopWndAnim(true) })

      this.activateShopImpl(true)
    }
  }

  function onShopWndAnimStarted(obj) {
    this.onHoverSizeMove(obj)
    this.updateOnShopWndAnim(!topMenuShopActive.get())
    showObjById("gamercard_center", !topMenuShopActive.get())
  }

  function onShopWndAnimFinished(_obj) {
    this.updateOnShopWndAnim(topMenuShopActive.get())
    let unitName = unitToShowInShop.get()
    if (topMenuShopActive.get() && unitName)
      this.shopWeak?.showUnitInShop(unitName)
  }

  function onEventShowUnitInShop(params) {
    this.openShop()

    if(this.shopWeak?.isSceneActive())
      this.shopWeak?.showUnitInShop(params.unitName)
    else
      unitToShowInShop.set(params.unitName)
  }

  function onEventProfileUpdated(_p) {
    if (!this.scene.isVisible())
      this.doWhenActiveOnce("updateGamercards")
  }

  function onEventUpdateGamercards(_p) {
    this.doWhenActiveOnce("updateGamercards")
  }

  function updateGamercards() {
    updateGamercards()
  }

  function updateOnShopWndAnim(isVisible) {
    let isShow = topMenuShopActive.get()
    this.updateSceneShade()
    if (isVisible)
      broadcastEvent("ShopWndVisible", { isShopShow = isShow })
    broadcastEvent("ShopWndAnimation", { isShow = isShow, isVisible = isVisible })
  }

  function activateShopImpl(shouldActivate, unitType = null) {
    if (this.shopWeak)
      this.shopWeak.onShopShow(shouldActivate)

    if (shouldActivate) {
      
      if (!this.shopWeak) {
        let wndObj = this.getObj("shop_wnd_frame")
        let shopHandler = handlersManager.loadHandler(gui_handlers.ShopMenuHandler,
          {
            scene = wndObj
            closeShop = Callback(this.shopWndSwitch, this)
            forceUnitType = unitType
          })
        if (shopHandler) {
          this.registerSubHandler(shopHandler)
          this.shopWeak = shopHandler.weakref()
        }
      }
      else if (unitType)
        this.shopWeak.setUnitType(unitType)
    }
  }

  function goBack() {
    this.topMenuGoBack(true)
  }

  function onTopMenuMain() {
    this.topMenuGoBack()
  }

  function topMenuGoBack(checkTopMenuButtons = false) {
    let current_base_gui_handler = get_current_base_gui_handler()

    if (topMenuShopActive.get())
      this.shopWndSwitch()
    else if (current_base_gui_handler && ("onTopMenuGoBack" in current_base_gui_handler))
      current_base_gui_handler.onTopMenuGoBack.call(current_base_gui_handler, checkTopMenuButtons)
  }

  function onGCShop(_obj) {
    this.shopWndSwitch()
  }

  function onSwitchContacts() {
    switchContactsObj(this.scene, this)
  }

  function fullReloadScene() {
    this.checkedForward(function() {
      if (handlersManager.getLastBaseHandlerStartParams() != null)
        handlersManager.clearScene()
    })
  }

  function onSceneActivate(show) {
    if (show && !this.getCurActiveContentHandler()) {
      this.isWaitForContentToActivateScene = true
      return
    }
    else if (!show && this.isWaitForContentToActivateScene) {
      this.isWaitForContentToActivateScene = false
      return
    }

    base.onSceneActivate(show)
    if (topMenuShopActive.get() && this.shopWeak)
      this.shopWeak.onSceneActivate(show)
    if (show)
      setShowUnit(this.getCurSlotUnit(), this.getHangarFallbackUnitParams())
  }

  function onHelp() {
    gui_handlers.HelpInfoHandlerModal.openHelp(this)
  }

  function getWndHelpConfig() {
    let res = {
      textsBlk = "%gui/mainmenu/instantActionHelp.blk"
      lineInterval = "0.6@helpLineInterval"
    }

    let links = [
      
      { obj = "topmenu_menu_panel"
        msgId = "hint_mainmenu"
      }

      
      {
        obj = ["slot_info_listbox", "slot_collapse"]
        msgId = "hint_unitInfo"
      }

      
      { obj = ["to_battle_button", "to_battle_console_image"]
        msgId = "hint_battle_button"
      }
      { obj = ["game_mode_change_button_text"]
        msgId = "hint_game_mode_change_button"
      }
      { obj = "gc_profile"
        msgId = "hint_profile"
      }

      
      { obj = ["gc_free_exp", "gc_warpoints", "gc_eagles"]
        msgId = "hint_currencies"
      }
      { obj = "topmenu_shop_btn"
        msgId = "hint_onlineShop"
      }
      { obj = "gc_PremiumAccount"
        msgId = "hint_premium"
      }
      { obj = "gc_inventory"
        msgId = "hint_inventory"
      }

      
      { obj = "topmenu_btn_shop_wnd"
        msgId = "hint_research"
      }
      { obj = topMenuShopActive.get() ? null : "slots-autorepair"
        msgId = "hint_autorepair"
      }
      { obj = topMenuShopActive.get() ? null : "slots-autoweapon"
        msgId = "hint_autoweapon"
      }

      
      { obj = topMenuShopActive.get() ? null : "perform_action_recent_items_mainmenu_button_items"
        msgId = "hint_recent_items"
      }
      { obj = ["gc_invites_btn", "gc_contacts", "gc_chat_btn", "gc_userlog_btn"]
        msgId = "hint_social"
      }
      { obj = topMenuShopActive.get() || g_squad_manager.isInSquad() ? null : "btn_squadPlus"
        msgId = "hint_play_with_friends"
      }
      { obj = "air_info_dmviewer_armor"
        msgId = "hint_dmviewer_armor"
      }
      { obj = "dmviewer_show_external_dm"
        msgId = "hint_dmviewer_show_external_dm"
      }
      { obj = "air_info_dmviewer_xray"
        msgId = "hint_dmviewer_xray"
      }
      { obj = "dmviewer_protection_analysis_btn"
        msgId = "hint_dmviewer_protection_analysis_btn"
      }
      { obj = "filter_nest"
        msgId = "hint_dmviewer_xray_part_filter"
      }
      { obj = "dmviewer_show_extended_hints"
        msgId = "hint_dmviewer_show_extended_hints"
      }
      { obj = "gc_BattlePassProgress"
        msgId = "hint_battlepas"
      }
      { obj = "gc_free_exp"
        msgId = "hint_gc_free_exp"
      }
      { obj = "btnAirInfoWeaponry"
        msgId = "hint_btnAirInfoWeaponry"
      }
      { obj = "topmenu_community_btn"
        msgId = "hint_community_btn"
      }
      { obj = "topmenu_pvp_btn"
        msgId = "hint_topmenu_pvp_btn"
      }
      { obj = "topmenu_menu_btn"
        msgId = "hint_topmenu_menu_btn"
      }
    ]

    
    let slotbar = this.getSlotbar()
    if (slotbar) {
      if (getUnlockedCountries().len() > 1)
        links.append({
          obj = slotbar.getBoxOfCountries()
          msgId = "hint_my_country"
        })

      links.append(
        { obj = slotbar.getBoxOfUnits()
          msgId = "hint_my_crews"
        })

      let presetsList = this.getSlotbarPresetsList()
      let listObj = presetsList.getListObj()
      let presetsObjList = ["btn_slotbar_presets"]

      if (listObj)
        for (local i = 0; i < presetsList.maxPresets; i++)
          presetsObjList.append(listObj.getChild(i))
      links.append(
        { obj = presetsObjList
          msgId = "hint_presetsPlace"
        })
    }

    res.links <- links
    return res
  }

  function prepareHelpPage(handler) {
    let topBtnsContainer = handler.scene.findObject("top_btns")
    if (topBtnsContainer?.isValid()) {
      let slotCollapseRect = getDaguiObjAabb(this.scene.findObject("slot_collapse"))
      let topMenuBtnRect = getDaguiObjAabb(this.scene.findObject("topmenu_menu_btn"))
      if (slotCollapseRect != null && topMenuBtnRect != null) {
        let leftButtonsPos = max(slotCollapseRect.pos[0] + slotCollapseRect.size[0], topMenuBtnRect.pos[0])
        topBtnsContainer.pos = $"{leftButtonsPos}, {topMenuBtnRect.pos[1] + topMenuBtnRect.size[1]} + 1@helpInterval"
      }
    }

    let shopBtnHint = handler.scene.findObject("hint_research")
    let btnAirInfoWeaponryRect = getDaguiObjAabb(this.scene.findObject("btnAirInfoWeaponry"))
    if (shopBtnHint?.isValid()) {
      let shopBtnRect = getDaguiObjAabb(this.scene.findObject("topmenu_btn_shop_wnd"))
      let shopHintHeight = to_pixels("5@helpInterval")

      if (shopBtnRect != null && btnAirInfoWeaponryRect != null
          && shopBtnRect.pos[1] - (btnAirInfoWeaponryRect.pos[1] + btnAirInfoWeaponryRect.size[1]) < shopHintHeight){
        let dmviewerListboxRect = getDaguiObjAabb(this.scene.findObject("air_info_dmviewer_listbox"))
        shopBtnHint.pos = $"1@bw, {dmviewerListboxRect.pos[1] - shopHintHeight}"
      } else {
        shopBtnHint.pos = $"1@bw, {shopBtnRect.pos[1] - shopHintHeight} - 1@helpInterval"
      }
    }

    let protectionWeaponryHints = handler.scene.findObject("protectionWeaponry")
    let headerCountriesNestRect = getDaguiObjAabb(this.scene.findObject("header_countries_nest"))
    if (headerCountriesNestRect != null && btnAirInfoWeaponryRect != null) {
      let helpHeight = to_pixels("7@helpInterval")
      if (btnAirInfoWeaponryRect.pos[1] + btnAirInfoWeaponryRect.size[1] < headerCountriesNestRect.pos[1] - helpHeight) {
        protectionWeaponryHints.pos = "".concat($"{btnAirInfoWeaponryRect.pos[0] + btnAirInfoWeaponryRect.size[0]} + 2@helpInterval,",
        $"{btnAirInfoWeaponryRect.pos[1] + btnAirInfoWeaponryRect.size[1]} - h")
      } else {
        protectionWeaponryHints.pos = "".concat($"{btnAirInfoWeaponryRect.pos[0] + btnAirInfoWeaponryRect.size[0]} + 2@helpInterval,",
        $"{headerCountriesNestRect.pos[1] - helpHeight} - 1@helpInterval - h")
      }
      handler.guiScene.applyPendingChanges(true)
    }

    let gameModeTextRect = getDaguiObjAabb(this.scene.findObject("game_mode_change_button_text"))
    let profileBtnRect = getDaguiObjAabb(this.scene.findObject("gc_profile"))

    if ( profileBtnRect != null && gameModeTextRect != null ) {
      let rightPoint = math.min( profileBtnRect.pos[0] + profileBtnRect.size[0], gameModeTextRect.pos[0])
      let profileHint = handler.scene.findObject("hint_profile")
      if (profileHint?.isValid()) {
        profileHint.pos = $"{rightPoint} - w - 1@helpInterval, {profileBtnRect.pos[1] + profileBtnRect.size[1]} + 2@helpInterval"
      }
    }

    let lionsRect = getDaguiObjAabb(this.scene.findObject("gc_warpoints"))
    let rpRect = getDaguiObjAabb(this.scene.findObject("gc_free_exp"))
    let premiumRect = getDaguiObjAabb(this.scene.findObject("gc_PremiumAccount"))
    let battlePassRect = getDaguiObjAabb(this.scene.findObject("gc_BattlePassProgress"))
    let gcButtonsContainerRect = getDaguiObjAabb(handler.scene.findObject("gcButtons"))
    if ( gcButtonsContainerRect != null && lionsRect != null && gameModeTextRect != null &&
         rpRect != null && premiumRect != null && battlePassRect != null) {
      let currenciesHint = handler.scene.findObject("hint_currencies")
      if (currenciesHint?.isValid()) {
        let quarterHelpInterval = to_pixels("0.25@helpInterval")
        let leftX = math.max(gameModeTextRect.pos[0] + gameModeTextRect.size[0] + quarterHelpInterval, gcButtonsContainerRect.pos[0])
        currenciesHint["margin-left"] = $"{leftX - gcButtonsContainerRect.pos[0]}"
        currenciesHint["max-width"] = $"{rpRect.pos[0] + rpRect.size[0]/2 - leftX}"
      }

      let rpHint = handler.scene.findObject("hint_gc_free_exp")
      if ( rpHint?.isValid()) {
        rpHint["margin-left"] = $"{rpRect.pos[0] + rpRect.size[0] - gcButtonsContainerRect.pos[0]} - w"
      }

      let premiumHint = handler.scene.findObject("hint_premium")
      if ( premiumHint?.isValid()) {
        premiumHint["margin-left"] = $"{premiumRect.pos[0] + premiumRect.size[0] - gcButtonsContainerRect.pos[0]} - w"
      }

      let battlePassHint = handler.scene.findObject("hint_battlepas")
      if ( battlePassHint?.isValid()) {
        battlePassHint["margin-left"] = $"{battlePassRect.pos[0] + battlePassRect.size[0] - gcButtonsContainerRect.pos[0]} - w"
      }
    }
  }

  function initModesNotLoadedBtn() {
    let buttonContainerObj = this.scene.findObject("game_modes_not_loaded_suppot")
    if (!buttonContainerObj?.isValid())
      return
    let buttonObj = buttonContainerObj.findObject("game_modes_not_loaded_suppot_link")

    let lang = getCurLangShortName() == "ru" ? "ru" : "en-us"
    let link = getCurCircuitOverride("knowledgebaseModesNotLoaded", $"auto_login https://support.gaijin.net/hc/{lang}/articles/201705251")
    buttonObj.link = link

    buttonContainerObj.setValue(stashBhvValueConfig([{
      watch = needShowGameModesNotLoadedMsg
      updateFunc = @(obj, value) obj.show(value)
    }]))
  }

}

return {
  getHandler = function() {
    if (!gui_handlers?.TopMenu)
      gui_handlers.TopMenu <- TopMenu

    return gui_handlers.TopMenu
  }
}
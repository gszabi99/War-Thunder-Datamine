import "%scripts/global/updateExtWatched.nut" as updateExtWatched
import "fonts" as fonts
import "%appGlobals/style/cssColors.nut" as cssColors
import "%appGlobals/style/cssConsts.nut" as cssConsts
from "%appGlobals/options/screenInfo.nut" import getMainScreenSizePx, getScreenHeightForFonts
from "%scripts/sqDagui/framework/gui_handlers.nut" import get_gui_handler, is_gui_handler_instance
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/options/safeAreaMenu.nut" import getSafearea, getCurrentFont, setCurrentFont
from "%sqstd/platform.nut" import is_android, isSony, isXbox, platformId
from "%scripts/viewUtils/hangarDof.nut" import needUseHangarDof
from "%scripts/clientState/clientStates.nut" import getFromSettingsBlk
from "%scripts/sqDagui/daguiUtil.nut" import check_obj
from "%scripts/options/consoleMode.nut" import showConsoleButtons, getIsConsoleModeEnabled, switchShowConsoleButtons
from "%scripts/sqDagui/framework/msgBox.nut" import is_active_msg_box_in_scene
from "%scripts/contacts/contactsHandlerState.nut" import getContactsHandler
from "%scripts/hangar/hangarModule.nut" import blurHangar
from "%scripts/chat/mpChatState.nut" import getMpChatControlsAllowMask
from "%scripts/waitScreen/waitScreen.nut" import getCurrentWaitScreen
from "%scripts/chat/chatHandler.nut" import menuChatHandler
from "%scripts/gamercard/gamercardHelpers.nut" import setLastGamercardSceneIfExist
from "%scripts/matchingRooms/sessionLobbyMembersInfo.nut" import isPlayerDedicatedSpectator
from "%appGlobals/style/cssTeamColors.nut" import calcTeamColors
from "daguiScene" import register_css_block
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%appGlobals/login/loginState.nut" import hasFullLoginState, isAuthorized
from "controlsMask" import setAllowedControlsMaskDagui
from "string" import format
from "eventbus" import eventbus_send, eventbus_subscribe
from "dagor.workcycle" import deferOnce
from "vr" import is_stereo_mode
from "mission" import get_mp_local_team
from "reactiveGuiCommand" import setSceneActive, reloadDargUiScript
from "guiMission" import get_team_colors
from "gameplayBinding" import isInFlight
from "%scripts/dagui_natives.nut" import switch_gui_scene, enable_dirpad_control_mouse, get_dagui_pre_include_css_str, is_steam_big_picture, ps4_is_circle_selected_as_enter_button, set_dagui_pre_include_css_str, set_gui_vr_params, set_hud_width_limit
from "%scripts/dagui_library.nut" import *
from "%scripts/options/fonts.nut" import getCurrentFontType
from "%scripts/viewUtils/daguiFonts.nut" import getCssFontConsts
let { handlersManager } = require("%scripts/sqDagui/framework/baseGuiHandlerManager.nut")
let safeAreaHud = require("%scripts/options/safeAreaHud.nut")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let focusFrame = require("%scripts/viewUtils/focusFrameWT.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")

dagui_propid_add_name_id("has_ime")
dagui_propid_add_name_id("platformId")

local lastScreenHeightForFont = 0
local lastInFlight = false  
local needReloadMainGuiSceneAfterFinishLoading = false


let controlsAllowMaskDefaults = {
  [handlerType.ROOT] = CtrlsInGui.CTRL_ALLOW_FULL,
  [handlerType.BASE] = CtrlsInGui.CTRL_ALLOW_ANSEL,
  [handlerType.MODAL] = CtrlsInGui.CTRL_ALLOW_NONE,
  [handlerType.CUSTOM] = CtrlsInGui.CTRL_ALLOW_FULL
}

let sceneBgBlurDefaults = {
  [handlerType.ROOT]   = @() false,
  [handlerType.BASE]   = @() false,
  [handlerType.MODAL]  = needUseHangarDof,
  [handlerType.CUSTOM] = @() false,
}

function generateCssString(config) {
  local res = ""
  foreach (cfg in config)
    res = "".concat(res, format("@const %s:%s;", cfg.name, cfg.value))
  return res
}


function generatePreLoadCssString() {
  let countriesCount = shopCountriesList.len()
  let hudSafearea = safeAreaHud.getSafearea()
  let menuSafearea = getSafearea()

  let config = [
    { name = "target_pc",         value = (isSony || isXbox) ? "no" : "yes" }
    { name = "swMain",            value = getMainScreenSizePx()[0].tostring() }
    { name = "_safearea_menu_w",  value = format("%.2f", menuSafearea[0]) }
    { name = "_safearea_menu_h",  value = format("%.2f", menuSafearea[1]) }
    { name = "_safearea_hud_w",   value = format("%.2f", hudSafearea[0]) }
    { name = "_safearea_hud_h",   value = format("%.2f", hudSafearea[1]) }
    { name = "slotbarCountries",  value = countriesCount.tostring() }
    { name = "isInVr",            value = (is_stereo_mode() ? 1 : 0).tostring() }
  ]

  return generateCssString(config)
}


function generateColorConstantsConfig() {
  let isCorrected = isAuthorized.get()
  let standardColors = !hasFullLoginState.get() || !isPlayerDedicatedSpectator()
  
  let colors = calcTeamColors(isCorrected ? get_team_colors() : {}, get_mp_local_team(), standardColors, isCorrected)
  return colors.keys().sort().map(@(name) { name, value = colors[name] })
}


function generatePostLoadCssString() {
  let config = [
    {
      name = "shortcutUpGamepad"
      value = "@shortcutUpDp"
    }
    {
      name = "shortcutDownGamepad"
      value = "@shortcutDownDp"
    }
    {
      name = "shortcutLeftGamepad"
      value = "@shortcutLeftDp"
    }
    {
      name = "shortcutRightGamepad"
      value = "@shortcutRightDp"
    }
  ]

  config.extend(generateColorConstantsConfig())

  return generateCssString(config)
}


register_css_block("const/colors.css", { colors = cssColors })
register_css_block("const/_const.css", { consts = cssConsts })


function getHandlerControlsAllowMask(handler) {
  local res = null
  if ("getControlsAllowMask" in handler)
    res = handler.getControlsAllowMask()
  if (res != null)
    return res
  return (controlsAllowMaskDefaults?[handler.wndType] ?? CtrlsInGui.CTRL_ALLOW_FULL)
}

let reloadDarg = @() reloadDargUiScript(false)

let writeDargLayout = @(font) updateExtWatched({
  fontGenId = font.fontGenId
  fontSizeMultiplier = font.sizeMultiplier
  safeAreaMenu = getSafearea()
})

let hardPersistWatched = mkHardPersistWatched("baseGuiHandlerManagerWT")

let curControlsAllowMask = hardPersistWatched("curControlsAllowMask", CtrlsInGui.CTRL_ALLOW_FULL)
let isCurSceneBgBlurred = hardPersistWatched("isCurSceneBgBlurred", false)
let hadActiveDargScreen = hardPersistWatched("hadActiveDargScreen", false)

handlersManager.__update({
  shouldResetFontsCache = false

  function reloadSceneOnLangOrScreenChange(needReloadNow) {
    let handler = needReloadNow ? this.getActiveBaseHandler() : null
    if (handler)
      handler.fullReloadScene()
    else
      this.markfullReloadOnSwitchScene()
  }

  function beforeClearScene(_guiScene) {
    let sh = getScreenHeightForFonts(screen_width(), screen_height())
    if (lastScreenHeightForFont && lastScreenHeightForFont != sh)
      this.shouldResetFontsCache = true
    lastScreenHeightForFont = sh

    if (this.shouldResetFontsCache) {
      fonts.discardLoadedData()
      this.shouldResetFontsCache = false
    }
  }

  function onClearScene(guiScene) {
    if (this.isMainGuiSceneActive()) 
      lastInFlight = isInFlight()

    focusFrame.enable(getIsConsoleModeEnabled())

    guiScene.setCursorSizeMul(guiScene.calcString("@cursorSizeMul", null))
    guiScene.setPatternSizeMul(guiScene.calcString("@dp", null))
    enable_dirpad_control_mouse(true)
  }

  function isNeedFullReloadAfterClearScene() {
    return !this.isMainGuiSceneActive()
  }

  function isNeedReloadSceneSpecific() {
    return this.isMainGuiSceneActive()
      && (lastInFlight != isInFlight() || this.needFullReloadMainScene())
  }

  function beforeLoadHandler(hType) {
    
    if ((hType == handlerType.BASE || hType == handlerType.ROOT)
        && hasFullLoginState.get()
        && this.lastGuiScene
        && this.lastGuiScene.isEqual(get_main_gui_scene())
        && !this.isMainGuiSceneActive())
      this.clearScene(this.lastGuiScene)
  }

  function onBaseHandlerLoadFailed(handler) {
    if (!hasFullLoginState.get()
        || handler.getclass() == get_gui_handler("MainMenu")
        || handler.getclass() == get_gui_handler("FlightMenu")
       )
      eventbus_send("request_logout")
    else if (isInFlight())
      eventbus_send("gui_start_flight_menu")
    else
      eventbus_send("gui_start_mainmenu")
  }

  function onSwitchBaseHandler() {
    if (!hasFullLoginState.get())
      return
    let curHandler = this.getActiveBaseHandler()
    if (curHandler)
      setLastGamercardSceneIfExist(curHandler.scene)
  }

  function animatedSwitchScene(startFunc) {
    switch_gui_scene(startFunc)
  }

  function markReloadMainSceneIfNeed(hasCssChanged, guiScene) {
    let isMainGuiScene = guiScene.isEqual(get_main_gui_scene())
    if (isMainGuiScene) {
      needReloadMainGuiSceneAfterFinishLoading = false
      return
    }
    if (!hasCssChanged || hasFullLoginState.get()) 
      return
    needReloadMainGuiSceneAfterFinishLoading = true
  }

  function updatePostLoadCss() {
    local haveChanges = false

    let font = getCurrentFontType()
    if (getCurrentFont() != font) {
      this.shouldResetFontsCache = true
      haveChanges = true
    }
    setCurrentFont(font)

    let cssStringPre = "".concat(generateCssString(getCssFontConsts(font)), "\n", generatePreLoadCssString(), "\n", gamepadIcons.getCssString())
    if (get_dagui_pre_include_css_str() != cssStringPre) {
      let safearea = safeAreaHud.getSafearea()
      set_dagui_pre_include_css_str(cssStringPre)
      set_hud_width_limit(safearea[0])
      updateExtWatched({ safeAreaHud = safearea })
      if (writeDargLayout(font))
        deferOnce(reloadDarg)
      haveChanges = true
    }

    set_dagui_pre_include_css("")

    let cssStringPost = generatePostLoadCssString()
    if (get_dagui_post_include_css_str() != cssStringPost) {
      set_dagui_post_include_css_str(cssStringPost)
      let forcedColors = hasFullLoginState.get() ? get_team_colors() : {}
      eventbus_send("recalculateTeamColors", { forcedColors })
      haveChanges = true
    }

    if (switchShowConsoleButtons(getIsConsoleModeEnabled()))
      haveChanges = true

    return haveChanges
  }

  function updateCssParams(guiScene) {
    let rootObj = guiScene.getRoot()

    
    let hasIME = isSony || isXbox || is_android || is_steam_big_picture()
    rootObj["has_ime"] = hasIME ? "yes" : "no"
    rootObj["platformId"] = platformId
  }


  function calcCurrentControlsAllowMask() {
    if (checkObj(getCurrentWaitScreen()))
      return CtrlsInGui.CTRL_ALLOW_NONE
    if (is_active_msg_box_in_scene(get_cur_gui_scene()))
      return CtrlsInGui.CTRL_ALLOW_NONE

    local res = CtrlsInGui.CTRL_ALLOW_FULL
    foreach (group in this.handlers)
      foreach (h in group)
        if (this.isHandlerValid(h, true) && h.isSceneActive()) {
          let mask = getHandlerControlsAllowMask(h)
          res = res & mask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | mask))
        }

    let menuChatMask = menuChatHandler.get()?.getControlsAllowMask()
    if (menuChatMask != null)
      res = res & menuChatMask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | menuChatMask))

    let mpChatMask = getMpChatControlsAllowMask()
    res = res & mpChatMask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | mpChatMask))

    let contactsHandler = getContactsHandler()
    if (contactsHandler != null) {
      let mask = contactsHandler.getControlsAllowMask()
      res = res & mask | (CtrlsInGui.CTRL_WINDOWS_ALL & (res | mask))
    }

    return res
  }

  function updateControlsAllowMask() {
    if (!this._loadHandlerRecursionLevel)
      this._updateControlsAllowMask()
  }

  function _updateControlsAllowMask() {
    let newMask = this.calcCurrentControlsAllowMask()
    if (newMask == curControlsAllowMask.get())
      return

    curControlsAllowMask.set(newMask)
    setAllowedControlsMaskDagui(newMask)
    
  }

  function restoreAllowControlMask() {
    setAllowedControlsMaskDagui(curControlsAllowMask.get())
  }

  function updateWidgets() {
    let widgetsList = []
    local hasActiveDargScene = false
    local hasActiveDargScreen = false
    foreach (group in this.handlers)
      foreach (h in group)
        if (this.isHandlerValid(h, true) && h.isSceneActive() && h?.getWidgetsList) {
          let wList = h.getWidgetsList()
          widgetsList.extend(wList)
          if (wList.len() > 0 && h.isSceneActiveNoModals()) {
            hasActiveDargScene = true
            hasActiveDargScreen = hasActiveDargScreen
              || wList.findvalue(@(w) w.widgetId == DargWidgets.SCREEN && w?.transform == null) != null
          }
        }

    setSceneActive(hasActiveDargScene)
    
    if (hasActiveDargScreen || hadActiveDargScreen.get()) 
      enable_dirpad_control_mouse(!hasActiveDargScreen)
    hadActiveDargScreen.set(hasActiveDargScreen)
    eventbus_send("updateWidgets", { widgetsList })
  }

  function calcCurrentSceneBgBlur() {
    foreach (wndType, group in this.handlers) {
      let defValue = sceneBgBlurDefaults?[wndType]() ?? false
      foreach (h in group)
        if (this.isHandlerValid(h, true) && h.isSceneActive())
          if (h?.shouldBlurSceneBgFn() ?? h?.shouldBlurSceneBg ?? defValue)
            return true
    }
    return false
  }

  function updateSceneBgBlur(forced = false) {
    if (!this._loadHandlerRecursionLevel)
      this._updateSceneBgBlur(forced)
  }


  function _updateSceneBgBlur(forced = false) {
    let isBlur = this.calcCurrentSceneBgBlur()
    if (!forced && isBlur == isCurSceneBgBlurred.get())
      return

    isCurSceneBgBlurred.set(isBlur)
    blurHangar(isBlur)
  }

  function updateSceneVrParams() {
    if (!this._loadHandlerRecursionLevel)
      this._updateSceneVrParams()
  }

  function _updateSceneVrParams() {
    if (!is_stereo_mode())
      return

    local shouldFade = false
    local shouldCenterToCam = false
    foreach (_wndType, group in this.handlers) {
      foreach (h in group)
        if (this.isHandlerValid(h, true) && h.isSceneActive()) {
          shouldFade = shouldFade || (h?.shouldFadeSceneInVr ?? false)
          shouldCenterToCam = shouldCenterToCam || (h?.shouldOpenCenteredToCameraInVr ?? false)
        }
    }
    set_gui_vr_params(shouldCenterToCam, shouldFade)
  }

  function onActiveHandlersChanged() {
    this._updateControlsAllowMask()
    this.updateWidgets()
    this._updateSceneBgBlur()
    this._updateSceneVrParams()
    broadcastEvent("ActiveHandlersChanged")
  }

  function onEventWaitBoxCreated(_p) {
    this._updateControlsAllowMask()
    this.updateWidgets()
    this._updateSceneBgBlur()
    this._updateSceneVrParams()
  }

  function beforeInitHandler(handler) {
    if (handler.rootHandlerClass || this.getHandlerType(handler) == handlerType.CUSTOM)
      return

    if (focusFrame.isEnabled)
      handler.guiScene.createElementByObject(handler.scene, "%gui/focusFrameAnim.blk", "tdiv", null)

    if (!hasFullLoginState.get() || is_gui_handler_instance(handler, "BaseGuiHandlerWT"))
      return

    this.initVoiceChatWidget(handler)
  }

  function initVoiceChatWidget(handler) {
    if (handler.rootHandlerClass || this.getHandlerType(handler) == handlerType.CUSTOM)
      return

    if (hasFullLoginState.get() && (handler?.needVoiceChat ?? true))
      handler.guiScene.createElementByObject(handler.scene, "%gui/chat/voiceChatWidget.blk", "widgets", null)
  }

  needFullReloadMainScene = @() needReloadMainGuiSceneAfterFinishLoading
    && !hasFullLoginState.get() && this.isMainGuiSceneActive()

  function validateHandlersAfterLoading() {
    this.clearInvalidHandlers()
    this.updateLoadingFlag()
    broadcastEvent("FinishLoading")
  }

  function setGuiRootOptions(guiScene, forceUpdate = true) {
    let rootObj = guiScene.getRoot()
    rootObj["show_console_buttons"] = showConsoleButtons.get() ? "yes" : "no" 
    if (ps4_is_circle_selected_as_enter_button())
      rootObj["swap_ab"] = "yes";

    if (!forceUpdate)
      return

    rootObj["css-hier-invalidate"] = "all"  
    guiScene.performDelayed(this, function() {
      if (check_obj(rootObj))
        rootObj["css-hier-invalidate"] = "no"
    })
  }
})

function get_cur_base_gui_handler() { 
  let handler = handlersManager.getActiveBaseHandler()
  if (handler)
    return handler
  return get_gui_handler("BaseGuiHandlerWT")(get_cur_gui_scene())
}

function gui_start_empty_screen(...) {
  handlersManager.emptyScreen()
  let guiScene = get_cur_gui_scene()
  if (guiScene)
    guiScene.clearDelayed() 
}

function gui_finish_loading() {
  if (handlersManager.needFullReloadMainScene())
    handlersManager.startSceneFullReload()
  handlersManager.validateHandlersAfterLoading()
}

let needDebug = getFromSettingsBlk("debug/debugGamepadCursor", false)
get_cur_gui_scene()?.setGamepadCursorDebug(needDebug)
get_cur_gui_scene()?.setUseGamepadCursorControl(true)

handlersManager.init()


eventbus_subscribe("onGuiFinishLoading", @(_) gui_finish_loading())
eventbus_subscribe("gui_start_empty_screen", gui_start_empty_screen)

eventbus_subscribe("gui_start_after_hard_reload", @(_) handlersManager.startMainSceneAfterHardReload())

return {
  handlersManager

  loadHandler = @(handlerClass, params = {}) handlersManager.loadHandler(handlerClass, params)
  get_cur_base_gui_handler
  gui_finish_loading
}

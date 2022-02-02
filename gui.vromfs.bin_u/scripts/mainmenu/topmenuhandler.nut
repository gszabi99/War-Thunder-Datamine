local SecondsUpdater = require("sqDagui/timer/secondsUpdater.nut")
local time = require("scripts/time.nut")
local { topMenuHandler, topMenuShopActive } = require("scripts/mainmenu/topMenuStates.nut")
local { setShowUnit } = require("scripts/slotbar/playerCurUnit.nut")
local { isSmallScreen } = require("scripts/clientState/touchScreen.nut")
local { PRICE, ENTITLEMENTS_PRICE } = require("scripts/utils/configs.nut")
local { checkUnlockMarkers } = require("scripts/unlocks/unlockMarkers.nut")

local class TopMenu extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.ROOT
  keepLoaded = true
  sceneBlkName = "gui/mainmenu/topMenuScene.blk"

  leftSectionHandlerWeak = null

  topMenu = true
  topMenuInited = false
  menuConfig = null /*::topMenu_config*/

  canQuitByGoBack = false

  shopWeak = null

  checkAdvertTimer = 0.0
  checkPriceTimer = 0.0

  isWaitForContentToActivateScene = false
  isInQueue = false

  constructor(gui_scene, params = {})
  {
    base.constructor(gui_scene, params)
    topMenuHandler(this)
  }

  function initScreen()
  {
    fillGamercard()
    reinitScreen()
  }

  function reinitScreen(params = null)
  {
    if (!topMenuInited && ::g_login.isLoggedIn())
    {
      topMenuInited = true

      leftSectionHandlerWeak = ::gui_handlers.TopMenuButtonsHandler.create(
        scene.findObject("topmenu_menu_panel"),
        this,
        ::g_top_menu_left_side_sections,
        scene.findObject("left_gc_panel_free_width")
      )
      registerSubHandler(leftSectionHandlerWeak)

      if (::last_chat_scene_show)
        switchChatWindow()
      if (::last_contacts_scene_show)
        onSwitchContacts()

      initTopMenuTimer()
      instantOpenShopWnd()
      createSlotbar(
        {
          hasResearchesBtn = true
          mainMenuSlotbar = true
          onCountryDblClick = function() {
            if (!topMenuShopActive.value)
              shopWndSwitch()
          }.bindenv(this)
        },
        "nav-topMenu"
      )
    }
  }

  function initTopMenuTimer()
  {
    local obj = getObj("top_menu_scene_timer")
    if (::checkObj(obj))
      obj.setUserData(this)
  }

  function getBaseHandlersContainer() //only for wndType = handlerType.ROOT
  {
    return scene.findObject("topMenu_content")
  }

  function onNewContentLoaded(handler)
  {
    checkAdvert()

    local hasResearch = ::getTblValue("hasTopMenuResearch", handler, true)
    showSceneBtn("topmenu_btn_shop_wnd", hasResearch)
    if (!hasResearch)
      closeShop()

    if (isWaitForContentToActivateScene)
    {
      isWaitForContentToActivateScene = false
      onSceneActivate(true)
    }
  }

  function onTopMenuUpdate(obj, dt)
  {
    checkAdvertTimer -= dt
    if (checkAdvertTimer<=0)
    {
      checkAdvertTimer = 120.0
      checkAdvert()
    }

    PRICE.checkUpdate()
    ENTITLEMENTS_PRICE.checkUpdate()

    checkUnlockMarkers()
  }

  function checkAdvert()
  {
    if (!is_news_adver_actual())
    {
      local t = req_news()
      if (t >= 0)
        return ::add_bg_task_cb(t, updateAdvert, this)
    }
    updateAdvert()
  }

  function updateAdvert()
  {
    local obj = scene.findObject("topmenu_advert")
    if (!::check_obj(obj))
      return

    local blk = ::DataBlock()
    ::get_news_blk(blk)
    local text = ::loc(blk?.advert ?? "", "")
    SecondsUpdater(obj, function(tObj, params)
    {
      local stopUpdate = text.indexof("{time_countdown=") == null
      local textResult = time.processTimeStamps(text)
      local objText = tObj.findObject("topmenu_advert_text")
      objText.setValue(textResult)
      tObj.show(textResult != "")
      return stopUpdate
    })
  }

  function onQueue(inQueue)
  {
    isInQueue = inQueue

    local slotbar = getSlotbar()
    if (slotbar)
      slotbar.shade(inQueue)
    updateSceneShade()

    if (inQueue)
    {
      if (topMenuShopActive.value)
        shopWndSwitch()

      ::broadcastEvent("SetInQueue")
    }
  }

  function updateSceneShade()
  {
    local obj = getObj("topmenu_backshade_dark")
    if (::check_obj(obj))
      obj.animation = isInQueue ? "show" : "hide"

    obj = getObj("topmenu_backshade_light")
    if (::check_obj(obj))
      obj.animation = !isInQueue && topMenuShopActive.value ? "show" : "hide"
  }

  function getCurrentEdiff()
  {
    return (topMenuShopActive.value && shopWeak) ? shopWeak.getCurrentEdiff() : ::get_current_ediff()
  }

  function canShowShop()
  {
    return !topMenuShopActive.value
  }

  function canShowDmViewer()
  {
    return !topMenuShopActive.value
  }

  function closeShop()
  {
    if (topMenuShopActive.value)
      shopWndSwitch()
  }

  function setShopUnitType(unitType)
  {
    if (unitType && shopWeak)
      shopWeak.setUnitType(unitType)
  }

  function shopWndSwitch(unitType = null)
  {
    if (!isValid())
      return

    if (isSmallScreen)
    {
      topMenuShopActive(false)
      ::gui_handlers.ShopViewWnd.open({forceUnitType = unitType})
      return
    }

    topMenuShopActive(!topMenuShopActive.value)
    local shopMove = getObj("shop_wnd_move")
    shopMove.moveOut = topMenuShopActive.value ? "yes" : "no"
    local closeResearch = getObj("research_closeButton")
    local showButton = shopMove.moveOut == "yes"

    ::dmViewer.update()

    if(showButton)
      guiScene.playSound("menu_appear")
    if(::checkObj(closeResearch))
      closeResearch.show(showButton)
    activateShopImpl(topMenuShopActive.value, unitType)
    if (shopWeak && shopWeak.getCurrentEdiff() != ::get_current_ediff())
      shopWeak.updateSlotbarDifficulty()

    ::broadcastEvent("ShopWndSwitched")
  }

  function openShop(unitType = null)
  {
    setShopUnitType(unitType)
    if (!topMenuShopActive.value)
      shopWndSwitch(unitType) //to load shp with correct unit type to avoid several shop updates
  }

  function instantOpenShopWnd()
  {
    if (topMenuShopActive.value)
    {
      local shopMove = getObj("shop_wnd_move")
      if (!::checkObj(shopMove))
        return

      local closeResearch = getObj("research_closeButton")
      if(::checkObj(closeResearch))
        closeResearch.show(true)

      shopMove.moveOut = "yes"
      shopMove["_size-timer"] = "1"
      shopMove.setFloatProp(::dagui_propid.add_name_id("_size-timer"), 1.0)
      shopMove.height = "sh"

      guiScene.performDelayed(this, function () { updateOnShopWndAnim(true) })

      activateShopImpl(true)
    }
  }

  function onShopWndAnimStarted(obj)
  {
    onHoverSizeMove(obj)
    updateOnShopWndAnim(!topMenuShopActive.value)
    ::showBtn("gamercard_center", !topMenuShopActive.value)
  }

  function onShopWndAnimFinished(obj)
  {
    updateOnShopWndAnim(topMenuShopActive.value)
  }

  function updateOnShopWndAnim(isVisible)
  {
    local isShow = topMenuShopActive.value
    updateSceneShade()
    if (isVisible)
      ::broadcastEvent("ShopWndVisible", { isShopShow = isShow })
    ::broadcastEvent("ShopWndAnimation", { isShow = isShow, isVisible = isVisible })
  }

  function activateShopImpl(shouldActivate, unitType = null)
  {
    if (shopWeak)
      shopWeak.onShopShow(shouldActivate)

    if (shouldActivate)
    {
      //instanciate shop window
      if (!shopWeak)
      {
        local wndObj = getObj("shop_wnd_frame")
        local shopHandler = ::handlersManager.loadHandler(::gui_handlers.ShopMenuHandler,
          {
            scene = wndObj
            closeShop = ::Callback(shopWndSwitch, this)
            forceUnitType =unitType
          })
        if (shopHandler)
        {
          registerSubHandler(shopHandler)
          shopWeak = shopHandler.weakref()
        }
      }
      else if (unitType)
        shopWeak.setUnitType(unitType)
    }

    enableHangarControls(!shouldActivate)
  }

  function goBack()
  {
    topMenuGoBack(true)
  }

  function onTopMenuMain()
  {
    topMenuGoBack()
  }

  function topMenuGoBack(checkTopMenuButtons = false)
  {
    if (topMenuShopActive.value)
      shopWndSwitch()
    else if (::current_base_gui_handler && ("onTopMenuGoBack" in ::current_base_gui_handler))
      ::current_base_gui_handler.onTopMenuGoBack.call(::current_base_gui_handler, checkTopMenuButtons)
  }

  function onGCShop(obj)
  {
    shopWndSwitch()
  }

  function onSwitchContacts()
  {
    ::switchContactsObj(scene, this)
  }

  function fullReloadScene()
  {
    checkedForward(function() {
      if (::handlersManager.getLastBaseHandlerStartFunc())
      {
        ::handlersManager.clearScene()
        ::handlersManager.getLastBaseHandlerStartFunc()
      }
    })
  }

  function onSceneActivate(show)
  {
    if (show && !getCurActiveContentHandler())
    {
      isWaitForContentToActivateScene = true
      return
    }
    else if (!show && isWaitForContentToActivateScene)
    {
      isWaitForContentToActivateScene = false
      return
    }

    base.onSceneActivate(show)
    if (topMenuShopActive.value && shopWeak)
      shopWeak.onSceneActivate(show)
    if (show) {
      setShowUnit(getCurSlotUnit(), getHangarFallbackUnitParams())
      enableHangarControls(!topMenuShopActive.value)
    }
  }

  function getWndHelpConfig()
  {
    local res = {
      textsBlk = "gui/mainmenu/instantActionHelp.blk"
      lineInterval = "0.6@helpLineInterval"
    }

    local links = [
      //Top left
      { obj = "topmenu_menu_panel"
        msgId = "hint_mainmenu"
      }

      //airInfo
      {
        obj = ["slot_info_listbox", "slot_collapse"]
        msgId = "hint_unitInfo"
      }

      //Top center
      { obj = ["to_battle_button", "to_battle_console_image"]
        msgId = "hint_battle_button"
      }
      { obj=["game_mode_change_button_text"]
        msgId = "hint_game_mode_change_button"
      }
      {obj = "gc_clanTag"
        msgId = "hint_clan"
      }
      { obj = "gc_profile"
        msgId = "hint_profile"
      }

      //Top right
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

      //Bottom left
      { obj = "topmenu_btn_shop_wnd"
        msgId = "hint_research"
      }
      { obj = topMenuShopActive.value ? null : "slots-autorepair"
        msgId = "hint_autorepair"
      }
      { obj = topMenuShopActive.value ? null : "slots-autoweapon"
        msgId = "hint_autoweapon"
      }

      //bottom right
      { obj = topMenuShopActive.value ? null : "perform_action_recent_items_mainmenu_button_items"
        msgId = "hint_recent_items"
      }
      { obj = ["gc_invites_btn", "gc_contacts", "gc_chat_btn", "gc_userlog_btn"]
        msgId = "hint_social"
      }
      { obj = topMenuShopActive.value || ::g_squad_manager.isInSquad() ? null : "btn_squadPlus"
        msgId = "hint_play_with_friends"
      }
    ]

    //Bottom bars
    local slotbar = getSlotbar()
    if (slotbar)
    {
      if (::unlocked_countries.len() > 1)
        links.append({
          obj = slotbar.getBoxOfCountries()
          msgId = "hint_my_country"
        })

      links.append(
        { obj = slotbar.getBoxOfUnits()
          msgId = "hint_my_crews"
        })

      local presetsList = getSlotbarPresetsList()
      local listObj = presetsList.getListObj()
      local presetsObjList = ["btn_slotbar_presets"]

      if (listObj)
        for(local i = 0; i < presetsList.maxPresets; i++)
          presetsObjList.append(listObj.getChild(i))
      links.append(
        { obj = presetsObjList
          msgId = "hint_presetsPlace"
        })
    }

    res.links <- links
    return res
  }
}

return {
  getHandler = function() {
    if (!::gui_handlers?.TopMenu)
      ::gui_handlers.TopMenu <- TopMenu

    return ::gui_handlers.TopMenu
  }
}
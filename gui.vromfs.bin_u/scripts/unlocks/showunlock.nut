local tutorialModule = require("scripts/user/newbieTutorialDisplay.nut")
local unitActions = require("scripts/unit/unitActions.nut")
local { setPollBaseUrl, generatePollUrl } = require("scripts/web/webpoll.nut")
local { disableSeenUserlogs } = require("scripts/userLog/userlogUtils.nut")
local { setColoredDoubleTextToButton, placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")
local activityFeedPostFunc = require("scripts/social/activityFeed/activityFeedPostFunc.nut")

::delayed_unlock_wnd <- []
::showUnlockWnd <- function showUnlockWnd(config)
{
  if (::isHandlerInScene(::gui_handlers.ShowUnlockHandler) ||
      ::isHandlerInScene(::gui_handlers.RankUpModal) ||
      ::isHandlerInScene(::gui_handlers.TournamentRewardReceivedWnd))
    return ::delayed_unlock_wnd.append(config)

  ::gui_start_unlock_wnd(config)
}

::gui_start_unlock_wnd <- function gui_start_unlock_wnd(config)
{
  local unlockType = ::getTblValue("type", config, -1)
  if (unlockType == ::UNLOCKABLE_COUNTRY)
  {
    if (::isInArray(config.id, ::shopCountriesList))
      return ::checkRankUpWindow(config.id, -1, 1, config)
    return false
  }
  else if (unlockType == "TournamentReward")
    return ::gui_handlers.TournamentRewardReceivedWnd.open(config)
  else if (unlockType == ::UNLOCKABLE_AIRCRAFT)
  {
    if (!::has_feature("Tanks") && ::getAircraftByName(config?.id)?.isTank())
      return false
  }

  ::gui_start_modal_wnd(::gui_handlers.ShowUnlockHandler, { config=config })
  return true
}

::check_delayed_unlock_wnd <- function check_delayed_unlock_wnd(prevUnlockData = null)
{
  disableSeenUserlogs([prevUnlockData?.disableLogId])

  if (!::delayed_unlock_wnd.len())
    return

  local unlockData = ::delayed_unlock_wnd.remove(0)
  if (!::gui_start_unlock_wnd(unlockData))
    ::check_delayed_unlock_wnd(unlockData)
}

class ::gui_handlers.ShowUnlockHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/showUnlock.blk"
  sceneNavBlkName = "gui/showUnlockTakeAirNavBar.blk"

  needShowUnitTutorial = false

  config = null
  unit = null
  slotbarActions = [ "take", "sec_weapons", "weapons", "info" ]

  function initScreen()
  {
    if (!config)
      return

    guiScene.setUpdatesEnabled(false, false)
    scene.findObject("award_name").setValue(config.name)

    if (::getTblValue("type", config, -1) == ::UNLOCKABLE_AIRCRAFT || "unitName" in config)
    {
      local id = ::getTblValue("id", config)
      local unitName = ::getTblValue("unitName", config, id)
      unit = ::getAircraftByName(unitName)
      updateUnitItem()
    }

    updateTexts()
    updateImage()
    guiScene.setUpdatesEnabled(true, true)
    checkUnitTutorial()
    updateButtons()
  }

  function updateUnitItem()
  {
    if (!unit)
      return

    local params = {hasActions = true}
    local data = ::build_aircraft_item(unit.name, unit, params)
    local airObj = scene.findObject("reward_aircrafts")
    guiScene.replaceContentFromText(airObj, data, data.len(), this)
    ::fill_unit_item_timers(airObj.findObject(unit.name), unit, params)
  }

  function updateTexts()
  {
    local desc = ::getTblValue("desc", config)
    if (desc)
    {
      local descObj = scene.findObject("award_desc")
      if (::checkObj(descObj))
      {
        descObj.setValue(desc)

        if("descAlign" in config)
          descObj["text-align"] = config.descAlign
      }
    }

    local rewardText = ::getTblValue("rewardText", config, "")
    if (rewardText != "")
    {
      local rewObj = scene.findObject("award_reward")
      if (::checkObj(rewObj))
        rewObj.setValue(::loc("challenge/reward") + " " + config.rewardText)
    }

    local nObj = scene.findObject("next_award")
    if (::checkObj(nObj) && ("id" in config))
      nObj.setValue(::get_next_award_text(config.id))
  }

  function updateImage()
  {
    local image = ::g_language.getLocTextFromConfig(config, "popupImage", "")
    if (image == "")
      return

    local imgObj = scene.findObject("award_image")
    if (!::checkObj(imgObj))
      return

    imgObj["background-image"] = image

    if ("ratioHeight" in config)
      imgObj["height"] = config.ratioHeight + "w"
    else if ("id" in config)
    {
      local unlockBlk = ::g_unlocks.getUnlockById(config.id)
      if (unlockBlk?.aspect_ratio)
        imgObj["height"] = unlockBlk.aspect_ratio + "w"
    }
  }

  function onPostPs4ActivityFeed()
  {
    activityFeedPostFunc(
      config.ps4ActivityFeedData.config,
      config.ps4ActivityFeedData.params,
      bit_activity.PS4_ACTIVITY_FEED
    )
    showSceneBtn("btn_post_ps4_activity_feed", false)
  }

  function updateButtons()
  {
    showSceneBtn("btn_sendEmail", ::getTblValue("showSendEmail", config, false)
                                  && !::is_vietnamese_version())

    showSceneBtn("btn_postLink", ::has_feature("FacebookWallPost")
                                 && ::getTblValue("showPostLink", config, false))

    local linkText = ::g_promo.getLinkText(config)
    if (config?.pollId && config?.link)
    {
      setPollBaseUrl(config.pollId, config.link)
      linkText = generatePollUrl(config.pollId)
    }

    local show = linkText != "" && ::g_promo.isLinkVisible(config)
    local linkObj = showSceneBtn("btn_link_to_site", show)
    if (show)
    {
      if (::checkObj(linkObj))
      {
        linkObj.link = linkText
        local linkBtnText = ::g_promo.getLinkBtnText(config)
        if (linkBtnText != "")
          setColoredDoubleTextToButton(scene, "btn_link_to_site", linkBtnText)
      }

      local imageObj = scene.findObject("award_image_button")
      if (::checkObj(imageObj))
        imageObj.link = linkText
    }
    local showPs4ActivityFeed = isPlatformSony && ("ps4ActivityFeedData" in config)
    showSceneBtn("btn_post_ps4_activity_feed", showPs4ActivityFeed)


    local showSetAir = unit != null && unit.isUsable() && !::isUnitInSlotbar(unit)
    local canBuyOnline = unit != null && ::canBuyUnitOnline(unit)
    local canBuy = unit != null && !unit.isRented() && !unit.isBought() && (::canBuyUnit(unit) || canBuyOnline)
    showSceneBtn("btn_set_air", showSetAir)
    local okObj = showSceneBtn("btn_ok", !showSetAir)
    if ("okBtnText" in config)
      okObj.setValue(::loc(config.okBtnText))

    showSceneBtn("btn_close", !showSetAir || !needShowUnitTutorial)

    local buyObj = showSceneBtn("btn_buy_unit", canBuy)
    if (canBuy && ::checkObj(buyObj))
    {
      local locText = ::loc("shop/btnOrderUnit", { unit = ::getUnitName(unit.name) })
      local unitCost = canBuyOnline? ::Cost() : ::getUnitCost(unit)
      placePriceTextToButton(scene, "btn_buy_unit", locText, unitCost, 0, ::getUnitRealCost(unit))
    }

    local actionText = ::g_language.getLocTextFromConfig(config, "actionText", "")
    local showActionBtn = actionText != "" && config?.action
    local actionObj = showSceneBtn("btn_action", showActionBtn)
    if (showActionBtn)
      actionObj.setValue(actionText)

    ::show_facebook_screenshot_button(scene, ::getTblValue("showShareBtn", config, false))
  }

  function onTake(unitToTake = null)
  {
    if (!unitToTake && !unit)
      return

    if (!unitToTake)
      unitToTake = unit

    if (needShowUnitTutorial)
      tutorialModule.saveShowedTutorial("takeUnit")

    base.onTake(unitToTake, {
      isNewUnit = true,
      cellClass = "slotbarClone",
      useTutorial = needShowUnitTutorial,
      afterSuccessFunc = goBack.bindenv(this)
    })
    needShowUnitTutorial = false
  }

  function onTakeNavBar(obj)
  {
    onTake()
  }

  function onMsgLink(obj)
  {
    if (::getTblValue("type", config) == "regionalPromoPopup")
      ::add_big_query_record("promo_popup_click",
        ::save_to_json({ id = config?.id ?? config?.link ?? config?.popupImage ?? - 1 }))
    ::g_promo.openLinkWithSource(this, [ obj?.link, config?.forceExternalBrowser ?? false ], "show_unlock")
  }

  function buyUnit()
  {
    unitActions.buy(unit, "show_unlock")
  }

  function onUnitHover(obj)
  {
    if (!::show_console_buttons)
      openUnitActionsList(obj, true)
  }

  function onEventCrewTakeUnit(params)
  {
    if (needShowUnitTutorial)
      return goBack()

    updateUnitItem()
  }

  function onEventUnitBought(params)
  {
    updateUnitItem()
    updateButtons()
    onTake()
  }

  function afterModalDestroy()
  {
    ::check_delayed_unlock_wnd(config)
  }

  function sendInvitation()
  {
    sendInvitationEmail()
  }

  function sendInvitationEmail()
  {
    local linkString = ::format(::loc("msgBox/viralAcquisition"), ::my_user_id_str)
    local msg_head = ::format(::loc("mainmenu/invitationHead"), ::my_user_name)
    local msg_body = ::format(::loc("mainmenu/invitationBody"), linkString)
    ::shell_launch("mailto:yourfriend@email.com?subject=" + msg_head + "&body=" + msg_body)
  }

  function onFacebookPostLink()
  {
    local link = ::format(::loc("msgBox/viralAcquisition"), ::my_user_id_str)
    local message = ::loc("facebook/wallMessage")
    ::make_facebook_login_and_do((@(link, message) function() {
                 ::scene_msg_box("facebook_login", null, ::loc("facebook/uploading"), null, null)
                 ::facebook_post_link(link, message)
               })(link, message), this)
  }

  function onOk()
  {
    local onOkFunc = ::getTblValue("onOkFunc", config)
    if (onOkFunc)
      onOkFunc()
    goBack()
  }

  function checkUnitTutorial()
  {
    if (!unit)
      return

    needShowUnitTutorial = tutorialModule.needShowTutorial("takeUnit", 1)
  }

  function goBack()
  {
    if (needShowUnitTutorial)
      onTake()
    else
      base.goBack()
  }

  function onAction()
  {
    local actionData = ::g_promo.gatherActionParamsData(config)
    if (!actionData)
      return

    ::g_promo.launchAction(actionData, this, null)
  }
}

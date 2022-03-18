let tutorialModule = require("scripts/user/newbieTutorialDisplay.nut")
let unitActions = require("scripts/unit/unitActions.nut")
let { setPollBaseUrl, generatePollUrl } = require("scripts/web/webpoll.nut")
let { disableSeenUserlogs } = require("scripts/userLog/userlogUtils.nut")
let { setColoredDoubleTextToButton, placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
let { isPlatformSony } = require("scripts/clientState/platform.nut")
let activityFeedPostFunc = require("scripts/social/activityFeed/activityFeedPostFunc.nut")
let { openLinkWithSource } = require("scripts/web/webActionsForPromo.nut")
let { checkRankUpWindow } = require("scripts/debriefing/rankUpModal.nut")
let { shopCountriesList } = require("scripts/shop/shopCountriesList.nut")

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
  let unlockType = ::getTblValue("type", config, -1)
  if (unlockType == ::UNLOCKABLE_COUNTRY)
  {
    if (::isInArray(config.id, shopCountriesList))
      return checkRankUpWindow(config.id, -1, 1, config)
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

  let unlockData = ::delayed_unlock_wnd.remove(0)
  if (!::gui_start_unlock_wnd(unlockData))
    ::check_delayed_unlock_wnd(unlockData)
}

::gui_handlers.ShowUnlockHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showUnlock.blk"
  sceneNavBlkName = "%gui/showUnlockTakeAirNavBar.blk"

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
      let id = ::getTblValue("id", config)
      let unitName = ::getTblValue("unitName", config, id)
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

    let params = {hasActions = true}
    let data = ::build_aircraft_item(unit.name, unit, params)
    let airObj = scene.findObject("reward_aircrafts")
    guiScene.replaceContentFromText(airObj, data, data.len(), this)
    airObj.tooltipId = ::g_tooltip.getIdUnit(unit.name)
    airObj.setValue(0)
    ::fill_unit_item_timers(airObj.findObject(unit.name), unit, params)
  }

  function updateTexts()
  {
    let desc = ::getTblValue("desc", config)
    if (desc)
    {
      let descObj = scene.findObject("award_desc")
      if (::checkObj(descObj))
      {
        descObj.setValue(desc)

        if("descAlign" in config)
          descObj["text-align"] = config.descAlign
      }
    }

    let rewardText = ::getTblValue("rewardText", config, "")
    if (rewardText != "")
    {
      let rewObj = scene.findObject("award_reward")
      if (::checkObj(rewObj))
        rewObj.setValue(::loc("challenge/reward") + " " + config.rewardText)
    }

    let nObj = scene.findObject("next_award")
    if (::checkObj(nObj) && ("id" in config))
      nObj.setValue(::get_next_award_text(config.id))
  }

  function updateImage()
  {
    let image = ::g_language.getLocTextFromConfig(config, "popupImage", "")
    if (image == "")
      return

    let imgObj = scene.findObject("award_image")
    if (!::checkObj(imgObj))
      return

    imgObj["background-image"] = image

    if ("ratioHeight" in config)
      imgObj["height"] = config.ratioHeight + "w"
    else if ("id" in config)
    {
      let unlockBlk = ::g_unlocks.getUnlockById(config.id)
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

    let show = linkText != "" && ::g_promo.isLinkVisible(config)
    let linkObj = showSceneBtn("btn_link_to_site", show)
    if (show)
    {
      if (::checkObj(linkObj))
      {
        linkObj.link = linkText
        let linkBtnText = ::g_promo.getLinkBtnText(config)
        if (linkBtnText != "")
          setColoredDoubleTextToButton(scene, "btn_link_to_site", linkBtnText)
      }

      let imageObj = scene.findObject("award_image_button")
      if (::checkObj(imageObj))
        imageObj.link = linkText
    }
    let showPs4ActivityFeed = isPlatformSony && ("ps4ActivityFeedData" in config)
    showSceneBtn("btn_post_ps4_activity_feed", showPs4ActivityFeed)


    let showSetAir = unit != null && unit.isUsable() && !::isUnitInSlotbar(unit)
    let canBuyOnline = unit != null && ::canBuyUnitOnline(unit)
    let canBuy = unit != null && !unit.isRented() && !unit.isBought() && (::canBuyUnit(unit) || canBuyOnline)
    showSceneBtn("btn_set_air", showSetAir)
    let okObj = showSceneBtn("btn_ok", !showSetAir)
    if ("okBtnText" in config)
      okObj.setValue(::loc(config.okBtnText))

    showSceneBtn("btn_close", !showSetAir || !needShowUnitTutorial)

    let buyObj = showSceneBtn("btn_buy_unit", canBuy)
    if (canBuy && ::checkObj(buyObj))
    {
      let locText = ::loc("shop/btnOrderUnit", { unit = ::getUnitName(unit.name) })
      let unitCost = canBuyOnline? ::Cost() : ::getUnitCost(unit)
      placePriceTextToButton(scene, "btn_buy_unit", locText, unitCost, 0, ::getUnitRealCost(unit))
    }

    let actionText = ::g_language.getLocTextFromConfig(config, "actionText", "")
    let showActionBtn = actionText != "" && config?.action
    let actionObj = showSceneBtn("btn_action", showActionBtn)
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
    openLinkWithSource([ obj?.link, config?.forceExternalBrowser ?? false ], "show_unlock")
  }

  function buyUnit()
  {
    unitActions.buy(unit, "show_unlock")
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
    let linkString = ::format(::loc("msgBox/viralAcquisition"), ::my_user_id_str)
    let msg_head = ::format(::loc("mainmenu/invitationHead"), ::my_user_name)
    let msg_body = ::format(::loc("mainmenu/invitationBody"), linkString)
    ::shell_launch("mailto:yourfriend@email.com?subject=" + msg_head + "&body=" + msg_body)
  }

  function onFacebookPostLink()
  {
    let link = ::format(::loc("msgBox/viralAcquisition"), ::my_user_id_str)
    let message = ::loc("facebook/wallMessage")
    ::make_facebook_login_and_do((@(link, message) function() {
                 ::scene_msg_box("facebook_login", null, ::loc("facebook/uploading"), null, null)
                 ::facebook_post_link(link, message)
               })(link, message), this)
  }

  function onOk()
  {
    let onOkFunc = ::getTblValue("onOkFunc", config)
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
    let actionData = ::g_promo.gatherActionParamsData(config)
    if (!actionData)
      return

    ::g_promo.launchAction(actionData, this, null)
  }

  function onUnitActivate(obj)
  {
    openUnitActionsList(obj.findObject(unit.name), true)
  }

  function onUseDecorator() {}
}

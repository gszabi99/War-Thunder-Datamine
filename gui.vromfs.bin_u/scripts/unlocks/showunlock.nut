from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let { shell_launch } = require("url")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let tutorialModule = require("%scripts/user/newbieTutorialDisplay.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let { setPollBaseUrl, generatePollUrl } = require("%scripts/web/webpoll.nut")
let { disableSeenUserlogs } = require("%scripts/userLog/userlogUtils.nut")
let { setColoredDoubleTextToButton, placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { openLinkWithSource } = require("%scripts/web/webActionsForPromo.nut")
let { checkRankUpWindow } = require("%scripts/debriefing/rankUpModal.nut")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")

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
  let unlockType = getTblValue("type", config, -1)
  if (unlockType == UNLOCKABLE_COUNTRY)
  {
    if (isInArray(config.id, shopCountriesList))
      return checkRankUpWindow(config.id, -1, 1, config)
    return false
  }
  else if (unlockType == "TournamentReward")
    return ::gui_handlers.TournamentRewardReceivedWnd.open(config)

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
    if (!this.config)
      return

    this.guiScene.setUpdatesEnabled(false, false)
    this.scene.findObject("award_name").setValue(this.config.name)

    if (getTblValue("type", this.config, -1) == UNLOCKABLE_AIRCRAFT || "unitName" in this.config)
    {
      let id = getTblValue("id", this.config)
      let unitName = getTblValue("unitName", this.config, id)
      this.unit = ::getAircraftByName(unitName)
      this.updateUnitItem()
    }

    this.updateTexts()
    this.updateImage()
    this.guiScene.setUpdatesEnabled(true, true)
    this.checkUnitTutorial()
    this.updateButtons()
  }

  function updateUnitItem()
  {
    if (!this.unit)
      return

    let params = {hasActions = true}
    let data = ::build_aircraft_item(this.unit.name, this.unit, params)
    let airObj = this.scene.findObject("reward_aircrafts")
    this.guiScene.replaceContentFromText(airObj, data, data.len(), this)
    airObj.tooltipId = ::g_tooltip.getIdUnit(this.unit.name)
    airObj.setValue(0)
    ::fill_unit_item_timers(airObj.findObject(this.unit.name), this.unit, params)
  }

  function updateTexts()
  {
    let desc = getTblValue("desc", this.config)
    if (desc)
    {
      let descObj = this.scene.findObject("award_desc")
      if (checkObj(descObj))
      {
        descObj.setValue(desc)

        if("descAlign" in this.config)
          descObj["text-align"] = this.config.descAlign
      }
    }

    let rewardText = getTblValue("rewardText", this.config, "")
    if (rewardText != "")
    {
      let rewObj = this.scene.findObject("award_reward")
      if (checkObj(rewObj))
        rewObj.setValue(loc("challenge/reward") + " " + this.config.rewardText)
    }

    let nObj = this.scene.findObject("next_award")
    if (checkObj(nObj) && ("id" in this.config))
      nObj.setValue(::get_next_award_text(this.config.id))
  }

  function updateImage()
  {
    let image = ::g_language.getLocTextFromConfig(this.config, "popupImage", "")
    if (image == "")
      return

    let imgObj = this.scene.findObject("award_image")
    if (!checkObj(imgObj))
      return

    imgObj["background-image"] = image

    if ("ratioHeight" in this.config)
      imgObj["height"] = this.config.ratioHeight + "w"
    else if ("id" in this.config)
    {
      let unlockBlk = ::g_unlocks.getUnlockById(this.config.id)
      if (unlockBlk?.aspect_ratio)
        imgObj["height"] = unlockBlk.aspect_ratio + "w"
    }
  }

  function onPostPs4ActivityFeed()
  {
    activityFeedPostFunc(
      this.config.ps4ActivityFeedData.config,
      this.config.ps4ActivityFeedData.params,
      bit_activity.PS4_ACTIVITY_FEED
    )
    this.showSceneBtn("btn_post_ps4_activity_feed", false)
  }

  function updateButtons()
  {
    this.showSceneBtn("btn_sendEmail", getTblValue("showSendEmail", this.config, false)
                                  && !::is_vietnamese_version())

    this.showSceneBtn("btn_postLink", hasFeature("FacebookWallPost")
                                 && getTblValue("showPostLink", this.config, false))

    local linkText = ::g_promo.getLinkText(this.config)
    if (this.config?.pollId && this.config?.link)
    {
      setPollBaseUrl(this.config.pollId, this.config.link)
      linkText = generatePollUrl(this.config.pollId)
    }

    let show = linkText != "" && ::g_promo.isLinkVisible(this.config)
    let linkObj = this.showSceneBtn("btn_link_to_site", show)
    if (show)
    {
      if (checkObj(linkObj))
      {
        linkObj.link = linkText
        let linkBtnText = ::g_promo.getLinkBtnText(this.config)
        if (linkBtnText != "")
          setColoredDoubleTextToButton(this.scene, "btn_link_to_site", linkBtnText)
      }

      let imageObj = this.scene.findObject("award_image_button")
      if (checkObj(imageObj))
        imageObj.link = linkText
    }
    let showPs4ActivityFeed = isPlatformSony && ("ps4ActivityFeedData" in this.config)
    this.showSceneBtn("btn_post_ps4_activity_feed", showPs4ActivityFeed)


    let showSetAir = this.unit != null && this.unit.isUsable() && !::isUnitInSlotbar(this.unit)
    let canBuyOnline = this.unit != null && ::canBuyUnitOnline(this.unit)
    let canBuy = this.unit != null && !this.unit.isRented() && !this.unit.isBought() && (::canBuyUnit(this.unit) || canBuyOnline)
    this.showSceneBtn("btn_set_air", showSetAir)
    let okObj = this.showSceneBtn("btn_ok", !showSetAir)
    if ("okBtnText" in this.config)
      okObj.setValue(loc(this.config.okBtnText))

    this.showSceneBtn("btn_close", !showSetAir || !this.needShowUnitTutorial)

    let buyObj = this.showSceneBtn("btn_buy_unit", canBuy)
    if (canBuy && checkObj(buyObj))
    {
      let locText = loc("shop/btnOrderUnit", { unit = ::getUnitName(this.unit.name) })
      let unitCost = canBuyOnline? ::Cost() : ::getUnitCost(this.unit)
      placePriceTextToButton(this.scene, "btn_buy_unit", locText, unitCost, 0, ::getUnitRealCost(this.unit))
    }

    let actionText = ::g_language.getLocTextFromConfig(this.config, "actionText", "")
    let showActionBtn = actionText != "" && this.config?.action
    let actionObj = this.showSceneBtn("btn_action", showActionBtn)
    if (showActionBtn)
      actionObj.setValue(actionText)

    ::show_facebook_screenshot_button(this.scene, getTblValue("showShareBtn", this.config, false))

    this.showSceneBtn("btn_get_qr", this.config?.qrUrl != null)
  }

  function onTake(unitToTake = null)
  {
    if (!unitToTake && !this.unit)
      return

    if (!unitToTake)
      unitToTake = this.unit

    if (this.needShowUnitTutorial)
      tutorialModule.saveShowedTutorial("takeUnit")

    base.onTake(unitToTake, {
      isNewUnit = true,
      cellClass = "slotbarClone",
      useTutorial = this.needShowUnitTutorial,
      afterSuccessFunc = this.goBack.bindenv(this)
    })
    this.needShowUnitTutorial = false
  }

  function onTakeNavBar(_obj)
  {
    this.onTake()
  }

  function onMsgLink(obj)
  {
    if (needShowGuestEmailRegistration()) {
      base.goBack()
      showGuestEmailRegistration()
      return
    }

    if (getTblValue("type", this.config) == "regionalPromoPopup")
      ::add_big_query_record("promo_popup_click",
        ::save_to_json({ id = this.config?.id ?? this.config?.link ?? this.config?.popupImage ?? - 1 }))
    openLinkWithSource([ obj?.link, this.config?.forceExternalBrowser ?? false ], "show_unlock")
  }

  function buyUnit()
  {
    unitActions.buy(this.unit, "show_unlock")
  }

  function onEventCrewTakeUnit(_params)
  {
    if (this.needShowUnitTutorial)
      return this.goBack()

    this.updateUnitItem()
  }

  function onEventUnitBought(_params)
  {
    this.updateUnitItem()
    this.updateButtons()
    this.onTake()
  }

  function afterModalDestroy()
  {
    ::check_delayed_unlock_wnd(this.config)
  }

  function sendInvitation()
  {
    this.sendInvitationEmail()
  }

  function sendInvitationEmail()
  {
    let linkString = format(loc("msgBox/viralAcquisition"), ::my_user_id_str)
    let msg_head = format(loc("mainmenu/invitationHead"), ::my_user_name)
    let msg_body = format(loc("mainmenu/invitationBody"), linkString)
    shell_launch($"mailto:yourfriend@email.com?subject={msg_head}&body={msg_body}")
  }

  function onFacebookPostLink()
  {
    let link = format(loc("msgBox/viralAcquisition"), ::my_user_id_str)
    let message = loc("facebook/wallMessage")
    ::make_facebook_login_and_do((@(link, message) function() {
                 ::scene_msg_box("facebook_login", null, loc("facebook/uploading"), null, null)
                 ::facebook_post_link(link, message)
               })(link, message), this)
  }

  function onOk()
  {
    let onOkFunc = getTblValue("onOkFunc", this.config)
    if (onOkFunc)
      onOkFunc()
    this.goBack()
  }

  function checkUnitTutorial()
  {
    if (!this.unit)
      return

    this.needShowUnitTutorial = tutorialModule.needShowTutorial("takeUnit", 1)
  }

  function goBack()
  {
    if (this.needShowUnitTutorial)
      this.onTake()
    else
      base.goBack()
  }

  function onAction()
  {
    let actionData = ::g_promo.gatherActionParamsData(this.config)
    if (!actionData)
      return

    ::g_promo.launchAction(actionData, this, null)
  }

  function onUnitActivate(obj)
  {
    this.openUnitActionsList(obj.findObject(this.unit.name), true)
  }

  function openQR(_obj) {
    openQrWindow({
      baseUrl = this.config.qrUrl
      needUrlWithQrRedirect = true
      needShowUrlLink = false
    })
  }

  function onUseDecorator() {}
}

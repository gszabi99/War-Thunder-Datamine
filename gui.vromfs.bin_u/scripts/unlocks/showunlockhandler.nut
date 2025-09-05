from "%scripts/dagui_library.nut" import *
from "%scripts/social/psConsts.nut" import bit_activity

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let { format } = require("string")
let { shell_launch } = require("url")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let tutorialModule = require("%scripts/user/newbieTutorialDisplay.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let { setPollBaseUrl, generatePollUrl } = require("%scripts/web/webpoll.nut")
let { setColoredDoubleTextToButton, placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let activityFeedPostFunc = require("%scripts/social/activityFeed/activityFeedPostFunc.nut")
let { openLinkWithSource } = require("%scripts/web/webActionsForPromo.nut")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { showGuestEmailRegistration, needShowGuestEmailRegistration
} = require("%scripts/user/suggestionEmailRegistration.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { isPromoLinkVisible, getPromoLinkBtnText, launchPromoAction,
  gatherPromoActionsParamsData
} = require("%scripts/promo/promo.nut")
let { getLocTextFromConfig } = require("%scripts/langUtils/language.nut")
let { getUnitName, getUnitRealCost, getUnitCost } = require("%scripts/unit/unitInfo.nut")
let { canBuyUnit } = require("%scripts/unit/unitShopInfo.nut")
let { userName, userIdStr } = require("%scripts/user/profileStates.nut")
let { buildUnitSlot, fillUnitSlotTimers } = require("%scripts/slotbar/slotbarView.nut")
let { isUnitInSlotbar } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { getNextAwardText } = require("%scripts/unlocks/unlocksModule.nut")
let takeUnitInSlotbar = require("%scripts/unit/takeUnitInSlotbar.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { checkDelayedUnlockWnd } = require("%scripts/unlocks/showUnlockWnd.nut")
let { canBuyUnitOnline } = require("%scripts/unit/availabilityBuyOnline.nut")

gui_handlers.ShowUnlockHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/showUnlock.blk"
  sceneNavBlkName = "%gui/showUnlockTakeAirNavBar.blk"

  needShowUnitTutorial = false

  config = null
  unit = null
  slotbarActions = [ "take", "sec_weapons", "weapons", "info" ]

  onDestroyFunc = null

  function initScreen() {
    if (!this.config)
      return

    this.onDestroyFunc = this.config?.onDestroyFunc
    this.guiScene.setUpdatesEnabled(false, false)
    this.scene.findObject("award_name").setValue(this.config.name)

    if (getTblValue("type", this.config, -1) == UNLOCKABLE_AIRCRAFT || "unitName" in this.config) {
      let id = getTblValue("id", this.config)
      let unitName = getTblValue("unitName", this.config, id)
      this.unit = getAircraftByName(unitName)
      this.updateUnitItem()
    }

    this.updateTexts()
    this.updateImage()
    this.guiScene.setUpdatesEnabled(true, true)
    this.checkUnitTutorial()
    this.updateButtons()
  }

  function updateUnitItem() {
    if (!this.unit)
      return

    let data = buildUnitSlot(this.unit.name, this.unit)
    let airObj = this.scene.findObject("reward_aircrafts")
    this.guiScene.replaceContentFromText(airObj, data, data.len(), this)
    airObj.tooltipId = getTooltipType("UNIT").getTooltipId(this.unit.name)
    airObj.setValue(0)
    fillUnitSlotTimers(airObj.findObject(this.unit.name), this.unit)
  }

  function updateTexts() {
    let desc = getTblValue("desc", this.config)
    if (desc) {
      let descObj = this.scene.findObject("award_desc")
      if (checkObj(descObj)) {
        descObj.setValue(desc)

        if ("descAlign" in this.config)
          descObj["text-align"] = this.config.descAlign
      }
    }

    let rewardText = getTblValue("rewardText", this.config, "")
    if (rewardText != "") {
      let rewObj = this.scene.findObject("award_reward")
      if (checkObj(rewObj))
        rewObj.setValue(" ".concat(loc("challenge/reward"), this.config.rewardText))
    }

    let nObj = this.scene.findObject("next_award")
    if (checkObj(nObj) && ("id" in this.config))
      nObj.setValue(getNextAwardText(this.config.id))
  }

  function updateImage() {
    let image = getLocTextFromConfig(this.config, "popupImage", "")
    if (image == "")
      return

    let imgObj = this.scene.findObject("award_image")
    if (!checkObj(imgObj))
      return

    imgObj["background-image"] = image
    let { imgWidth = null, ratioHeight = null, id = null } = this.config
    if (imgWidth != null)
      imgObj.width = imgWidth

    if (ratioHeight != null)
      imgObj["height"] = $"{ratioHeight}w"
    else if (id != null) {
      let unlockBlk = getUnlockById(id)
      if (unlockBlk?.aspect_ratio)
        imgObj["height"] = $"{unlockBlk.aspect_ratio}w"
    }
  }

  function onPostPs4ActivityFeed() {
    activityFeedPostFunc(
      this.config.ps4ActivityFeedData.config,
      this.config.ps4ActivityFeedData.params,
      bit_activity.PS4_ACTIVITY_FEED
    )
    showObjById("btn_post_ps4_activity_feed", false, this.scene)
  }

  function updateButtons() {
    showObjById("btn_sendEmail", this.config?.showSendEmail ?? false, this.scene)

    local linkText = getLocTextFromConfig(this.config, "link", "")
    if (this.config?.pollId && this.config?.link) {
      setPollBaseUrl(this.config.pollId, this.config.link)
      linkText = generatePollUrl(this.config.pollId)
    }

    let show = linkText != "" && isPromoLinkVisible(this.config)
    let linkObj = showObjById("btn_link_to_site", show, this.scene)
    if (show) {
      if (checkObj(linkObj)) {
        linkObj.link = linkText
        let linkBtnText = getPromoLinkBtnText(this.config)
        if (linkBtnText != "")
          setColoredDoubleTextToButton(this.scene, "btn_link_to_site", linkBtnText)
      }

      let imageObj = this.scene.findObject("award_image_button")
      if (checkObj(imageObj))
        imageObj.link = linkText
    }
    let showPs4ActivityFeed = isPlatformSony && ("ps4ActivityFeedData" in this.config)
    showObjById("btn_post_ps4_activity_feed", showPs4ActivityFeed, this.scene)


    let showSetAir = this.unit != null && this.unit.isUsable() && !isUnitInSlotbar(this.unit)
    let canBuyOnline = this.unit != null && canBuyUnitOnline(this.unit)
    let canBuy = this.unit != null && !this.unit.isRented() && !this.unit.isBought() && (canBuyUnit(this.unit) || canBuyOnline)
    showObjById("btn_set_air", showSetAir, this.scene)
    let okObj = showObjById("btn_ok", !showSetAir, this.scene)
    if (this.config?.okBtnText)
      okObj.setValue(loc(this.config.okBtnText))
    if (this.config?.okBtnStyle)
      okObj.visualStyle = this.config.okBtnStyle

    showObjById("btn_close", !showSetAir || !this.needShowUnitTutorial, this.scene)

    let buyObj = showObjById("btn_buy_unit", canBuy, this.scene)
    if (canBuy && checkObj(buyObj)) {
      let locText = loc("shop/btnOrderUnit", { unit = getUnitName(this.unit.name) })
      let unitCost = canBuyOnline ? Cost() : getUnitCost(this.unit)
      placePriceTextToButton(this.scene, "btn_buy_unit", locText, unitCost, 0, getUnitRealCost(this.unit))
    }

    let actionText = getLocTextFromConfig(this.config, "actionText", "")
    let showActionBtn = actionText != "" && this.config?.action
    let actionObj = showObjById("btn_action", showActionBtn, this.scene)
    if (showActionBtn)
      actionObj.setValue(actionText)

    showObjById("btn_get_qr", this.config?.qrUrl != null, this.scene)
  }

  function onTake(unitToTake = null) {
    if (!unitToTake && !this.unit)
      return

    if (!unitToTake)
      unitToTake = this.unit

    if (this.needShowUnitTutorial)
      tutorialModule.saveShowedTutorial("takeUnit")

    takeUnitInSlotbar(unitToTake, {
      unitObj = this.scene.findObject(unitToTake.name)
      isNewUnit = true
      cellClass = "slotbarClone"
      useTutorial = this.needShowUnitTutorial
      afterSuccessFunc = this.goBack.bindenv(this)
    })
    this.needShowUnitTutorial = false
  }

  function onTakeNavBar(_obj) {
    this.onTake()
  }

  function onMsgLink(obj) {
    if (needShowGuestEmailRegistration()) {
      base.goBack()
      showGuestEmailRegistration()
      return
    }

    if (getTblValue("type", this.config) == "regionalPromoPopup")
      sendBqEvent("CLIENT_POPUP_1", "promo_popup_click", {
        id = this.config?.id ?? this.config?.link ?? this.config?.popupImage ?? -1
      })
    openLinkWithSource([ obj?.link, this.config?.forceExternalBrowser ?? false ], "show_unlock")
  }

  function buyUnit() {
    unitActions.buy(this.unit, "show_unlock")
  }

  function onEventCrewTakeUnit(_params) {
    if (this.needShowUnitTutorial)
      return this.goBack()

    this.updateUnitItem()
  }

  function onEventUnitBought(_params) {
    this.updateUnitItem()
    this.updateButtons()
    this.onTake()
  }

  function afterModalDestroy() {
    this.onDestroyFunc?()
    checkDelayedUnlockWnd(this.config)
  }

  function sendInvitation() {
    this.sendInvitationEmail()
  }

  function sendInvitationEmail() {
    let linkString = format(loc("msgBox/viralAcquisition"), userIdStr.get())
    let msg_head = format(loc("mainmenu/invitationHead"), userName.get())
    let msg_body = format(loc("mainmenu/invitationBody"), linkString)
    shell_launch($"mailto:yourfriend@email.com?subject={msg_head}&body={msg_body}")
  }

  function onOk() {
    let onOkFunc = getTblValue("onOkFunc", this.config)
    if (onOkFunc)
      onOkFunc()
    this.goBack()
  }

  function checkUnitTutorial() {
    if (!this.unit)
      return

    this.needShowUnitTutorial = tutorialModule.needShowTutorial("takeUnit", 1)
  }

  function goBack() {
    if (this.needShowUnitTutorial)
      this.onTake()
    else
      base.goBack()
  }

  function onAction() {
    let actionData = gatherPromoActionsParamsData(this.config)
    if (!actionData)
      return

    launchPromoAction(actionData, this, null)
  }

  function onUnitActivate(obj) {
    this.openUnitActionsList(obj.findObject(this.unit.name), true)
  }

  function openQR(_obj) {
    openQrWindow({
      qrCodesData = [
        {url = this.config.qrUrl}
      ]
      needUrlWithQrRedirect = true
      needShowUrlLink = false
    })
  }

  function onUseDecorator() {}
}
from "%scripts/dagui_library.nut" import *

let { zero_money } = require("%scripts/money.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { select_editbox, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { stripClanTagDecorators } = require("%scripts/clans/clanTextInfo.nut")
let { prepareUpgradeRequest } = require("%scripts/clans/clanRequests.nut")
let { upgradeClan } = require("%scripts/clans/clanActions.nut")
let { myClanInfo } = require("%scripts/clans/clanState.nut")

gui_handlers.UpgradeClanModalHandler <- class (gui_handlers.ModifyClanModalHandler) {
  owner = null

  function createView() {
    return {
      windowHeader = loc("clan/upgrade_clan_wnd_title")
      hasClanTypeSelect = false
      hasClanNameSelect = false
      hasClanSloganSelect = false
      hasClanRegionSelect = false
    }
  }

  function initScreen() {
    this.newClanType = this.clanData.clanType.getNextType()
    this.lastShownHintObj = this.scene.findObject("req_newclan_tag")
    base.initScreen()
    this.updateSubmitButtonText()
    this.resetTagDecorationObj(this.clanData.tag)
    this.updateDescription()
    this.updateAnnouncement()
    this.scene.findObject("newclan_description").setValue(this.clanData.desc)
    let newClanTagObj = this.scene.findObject("newclan_tag")
    newClanTagObj.setValue(stripClanTagDecorators(this.clanData.tag))
    select_editbox(newClanTagObj)
    this.onFocus(newClanTagObj)

    // Helps to avoid redundant name length check.
    this.newClanName = this.clanData.name
  }

  // Override.
  function updateSubmitButtonText() {
    let cost = this.clanData.getClanUpgradeCost()
    this.setSubmitButtonText(loc("clan/clan_upgrade/button"), cost)
  }

  // Important override.
  function getSelectedClanType() {
    return this.clanData.clanType.getNextType()
  }

  function onSubmit() {
    if (!this.prepareClanData())
      return
    let upgradeCost = this.clanData.getClanUpgradeCost()
    if (upgradeCost <= zero_money)
      this.upgradeClanFn()
    else if (checkBalanceMsgBox(upgradeCost)) {
      let msgText = warningIfGold(
        format(loc("clan/needMoneyQuestion_upgradeClanPrimaryInfo"),
          upgradeCost.getTextAccordingToBalance()),
        upgradeCost)
      this.msgBox("need_money", msgText, [["ok", function() { this.upgradeClanFn() }],
        ["cancel"]], "ok")
    }
  }

  function upgradeClanFn() {
    if (this.isObsceneWord())
      return
    let clanId = (myClanInfo.get()?.id == this.clanData.id) ? "-1" : this.clanData.id
    let params = prepareUpgradeRequest(
      this.newClanType,
      this.newClanTag,
      this.newClanDescription,
      this.newClanAnnouncement
    )
    upgradeClan(clanId, params, this)
  }

  function getDecoratorsList() {
    // cannot use non-paid decorators for upgrade
    return ::g_clan_tag_decorator.getDecoratorsForClanType(this.newClanType)
  }
}

let openUpgradeClanWnd = @(clanData, owner) loadHandler(
  gui_handlers.UpgradeClanModalHandler, { clanData, owner })

return {
  openUpgradeClanWnd
}
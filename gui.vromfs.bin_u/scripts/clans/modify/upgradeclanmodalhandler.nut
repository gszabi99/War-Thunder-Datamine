//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
::gui_handlers.UpgradeClanModalHandler <- class extends ::gui_handlers.ModifyClanModalHandler {
  owner = null

  function createView() {
    return {
      windowHeader = loc("clan/upgrade_clan_wnd_title")
      hasClanTypeSelect = false
      hasClanNameSelect = false
      hasClanSloganSelect = false
      hasClanRegionSelect = false
      isNonLatinCharsAllowedInClanName = ::g_clans.isNonLatinCharsAllowedInClanName()
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
    newClanTagObj.setValue(::g_clans.stripClanTagDecorators(this.clanData.tag))
    ::select_editbox(newClanTagObj)
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
    if (upgradeCost <= ::zero_money)
      this.upgradeClan()
    else if (::check_balance_msgBox(upgradeCost)) {
      let msgText = ::warningIfGold(
        format(loc("clan/needMoneyQuestion_upgradeClanPrimaryInfo"),
          upgradeCost.getTextAccordingToBalance()),
        upgradeCost)
      this.msgBox("need_money", msgText, [["ok", function() { this.upgradeClan() }],
        ["cancel"]], "ok")
    }
  }

  function upgradeClan() {
    if (this.isObsceneWord())
      return
    let clanId = (::my_clan_info != null && ::my_clan_info.id == this.clanData.id) ? "-1" : this.clanData.id
    let params = ::g_clans.prepareUpgradeRequest(
      this.newClanType,
      this.newClanTag,
      this.newClanDescription,
      this.newClanAnnouncement
    )
    ::g_clans.upgradeClan(clanId, params, this)
  }

  function getDecoratorsList() {
    // cannot use non-paid decorators for upgrade
    return ::g_clan_tag_decorator.getDecoratorsForClanType(this.newClanType)
  }
}

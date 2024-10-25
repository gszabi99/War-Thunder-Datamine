from "%scripts/dagui_natives.nut" import clan_get_admin_editor_mode, clan_get_my_role, clan_get_role_rights, clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { zero_money, Cost } = require("%scripts/money.nut")
let { format } = require("string")
let time = require("%scripts/time.nut")
let { placePriceTextToButton, warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { select_editbox, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")

gui_handlers.EditClanModalhandler <- class (gui_handlers.ModifyClanModalHandler) {
  owner = null

  isMyClan = false
  adminMode = false
  myRights = null

  function createView() {
    return {
      windowHeader = loc("clan/edit_clan_wnd_title")
      hasClanTypeSelect = false
      hasClanNameSelect = true
      hasClanSloganSelect = true
      hasClanRegionSelect = true
    }
  }

  function initScreen() {
    this.newClanType = this.clanData.clanType
    this.lastShownHintObj = this.scene.findObject("req_newclan_name")
    base.initScreen()
    this.updateSubmitButtonText()
    this.resetTagDecorationObj(this.clanData.tag)
    this.updateDescription()
    this.updateAnnouncement()
    this.scene.findObject("newclan_tag").setValue(::g_clans.stripClanTagDecorators(this.clanData.tag))
    this.scene.findObject("newclan_slogan").setValue(this.clanData.slogan)
    this.scene.findObject("newclan_description").setValue(this.clanData.desc)
    this.scene.findObject("newclan_announcement").setValue(this.clanData.announcement)

    let regionEditBoxObj = this.scene.findObject("newclan_region")
    regionEditBoxObj.setValue(this.clanData.region)
    if (!this.clanData.isRegionChangeAvailable()) {
      let regionChangeTime = this.clanData.getRegionChangeAvailableTime()
      let regionChangeTimeText = loc(
        "clan/clan_can_change_region_in",
        { time = time.buildDateTimeStr(regionChangeTime) }
      )
      this.scene.findObject("region_change_cooldown").setValue(regionChangeTimeText)
      regionEditBoxObj.enable(false)
    }

    let clanNameObj = this.scene.findObject("newclan_name")
    clanNameObj.setValue(this.clanData.name)

    select_editbox(clanNameObj)

    this.update()
  }

  function editClanInfo() {
    if (this.isObsceneWord())
      return

    let editParams = ::g_clans.prepareEditRequest(
      this.newClanType,
      this.newClanName != this.clanData.name ? this.newClanName : null,
      this.newClanTag != this.clanData.tag ? this.newClanTag : null,
      this.newClanSlogan != this.clanData.slogan ? this.newClanSlogan : null,
      this.newClanDescription != this.clanData.desc ? this.newClanDescription : null,
      this.newClanAnnouncement != this.clanData.announcement ? this.newClanAnnouncement : null,
      this.newClanRegion != this.clanData.region ? this.newClanRegion : null
    )
    let clanId = (::my_clan_info != null && ::my_clan_info.id == this.clanData.id) ? "-1" : this.clanData.id
    ::g_clans.editClan(clanId, editParams, this)
  }


  function hasChangedPrimaryInfo() {
    return this.newClanName != this.clanData.name || this.newClanTag != this.clanData.tag
  }


  function isPrimaryInfoChangeFree() {
    let decorators = this.getDecoratorsList()
    let currentDecorator = decorators[this.newClanTagDecoration]
    if (this.newClanTag != this.clanData.lastPaidTag) {
      if (::g_clans.stripClanTagDecorators(this.newClanTag) != ::g_clans.stripClanTagDecorators(this.clanData.tag) || !currentDecorator.free)
        return false
    }
    if (this.newClanName != this.clanData.name)
      return false
    return true
  }


  function hasChangedSecondaryInfo() {
    if (this.newClanSlogan != this.clanData.slogan)
      return true
    if (this.newClanDescription != this.clanData.desc)
      return true
    if (this.newClanRegion != this.clanData.region)
      return true
    if (this.newClanAnnouncement != this.clanData.announcement)
      return true
    return false
  }

  function getCost(changedPrimary, changedSecondary) {
    if (changedPrimary && !this.isPrimaryInfoChangeFree())
      return this.newClanType.getPrimaryInfoChangeCost()
    if (changedSecondary)
      return this.newClanType.getSecondaryInfoChangeCost()
    return clone zero_money
  }

  function onFieldChange(_obj) {
    if (!this.prepareClanData(true, true))
      return

    this.updateSubmitButtonText()
  }

  // Override.
  function updateSubmitButtonText() {
    let changedPrimary = this.hasChangedPrimaryInfo()
    let changedSecondary = this.hasChangedSecondaryInfo()
    let cost = this.getCost(changedPrimary, changedSecondary)
    this.setSubmitButtonText(loc("clan/btnSaveClanInfo"), cost)
  }

  function onSubmit() {
    if (!this.prepareClanData(true))
      return
    let changedPrimary = this.hasChangedPrimaryInfo()
    let changedSecondary = this.hasChangedSecondaryInfo()
    if (!changedPrimary && !changedSecondary)
      return this.goBack()

    let cost = this.getCost(changedPrimary, changedSecondary)

    if (cost <= zero_money)
      this.editClanInfo()
    else if (checkBalanceMsgBox(cost)) {
      let text = changedPrimary && this.newClanType.getPrimaryInfoChangeCost() > zero_money
                   ? "clan/needMoneyQuestion_editClanPrimaryInfo"
                   : "clan/needMoneyQuestion_editClanSecondaryInfo"
      let msgText = warningIfGold(format(loc(text), cost.getTextAccordingToBalance()), cost)
      this.msgBox("need_money", msgText, [["ok", function() { this.editClanInfo() }],
        ["cancel"]], "ok")
    }
  }

  // Important override.
  function getSelectedClanType() {
    return this.clanData.clanType
  }

  function update() {
    this.isMyClan = clan_get_my_clan_id() == this.clanData.id
    this.adminMode = clan_get_admin_editor_mode()
    this.myRights = []
    if (this.isMyClan || this.adminMode)
      this.myRights = ::clan_get_role_rights(this.adminMode ? ECMR_CLANADMIN : clan_get_my_role())

    this.updateButtons()
  }

  function updateButtons() {
    let canUpgrade = this.clanData.clanType.canUpgradeMembers(this.clanData.mlimit)
    let haveLeaderRight = isInArray("LEADER", this.myRights)

    let upgradeMembersButtonVisible = hasFeature("ClanUpgradeMembers") &&
                          ((this.isMyClan && haveLeaderRight) || this.adminMode) &&
                          canUpgrade

    if (upgradeMembersButtonVisible) {
      let cost = clan_get_admin_editor_mode() ? Cost() : this.clanData.clanType.getMembersUpgradeCost(this.clanData.mlimit)
      let upgStep = this.clanData.clanType.getMembersUpgradeStep()
      placePriceTextToButton(this.scene, "btn_upg_members", loc("clan/members_upgrade_button", { step = upgStep }), cost)
    }

    showObjById("btn_upg_members", upgradeMembersButtonVisible, this.scene)
    showObjById("btn_disbandClan", (this.isMyClan && isInArray("DISBAND", this.myRights)) || this.adminMode, this.scene)
  }

  // Override
  function onUpgradeMembers() {
    let cost = clan_get_admin_editor_mode() ? Cost() : this.clanData.clanType.getMembersUpgradeCost(this.clanData.mlimit)
    if (checkBalanceMsgBox(cost)) {
      let step = this.clanData.clanType.getMembersUpgradeStep()
      let msgText = warningIfGold(loc("clan/needMoneyQuestion_upgradeMembers",
          { step = step,
            cost = cost.getTextAccordingToBalance()
          }),
        cost)
      this.msgBox("need_money", msgText, [["ok", function() { this.upgradeMembers() } ],
        ["cancel"]], "ok")
    }
  }

  function upgradeMembers() {
    ::g_clans.upgradeClanMembers(this.clanData.id)
  }

  // Override
  function onEventClanInfoUpdate(_p) {
    if (this.clanData && this.clanData.id == clan_get_my_clan_id()) {
      if (!::my_clan_info)
        return this.goBack()
      this.clanData = ::my_clan_info
      this.clanData = ::getFilteredClanData(this.clanData)
    }

    this.update()
  }

  function onEventClanInfoAvailable(p) {
    if (p.clanId != this.clanData.id)
      return

    this.clanData = ::get_clan_info_table()
    if (!this.clanData)
      return this.goBack()

    this.update()
  }

  function onDisbandClan() {
    if ((!this.isMyClan || !isInArray("LEADER", this.myRights)) && !clan_get_admin_editor_mode())
      return;

    this.msgBox("disband_clan", loc("clan/disbandClanConfirmation"),
      [
        ["yes", function() {
          ::g_clans.disbandClan(this.isMyClan ? "-1" : this.clanData.id, this)
        }],
        ["no",  function() {} ],
      ], "no", { cancel_fn = function() {} });
  }

  function getDecoratorsList() {
    return ::g_clan_tag_decorator.getDecorators({
      clanType = this.newClanType
      rewardsList = this.clanData.getAllRegaliaTags()
    })
  }
}

let openEditClanWnd = @(clanData, owner) loadHandler(
  gui_handlers.EditClanModalhandler, { clanData, owner })

return {
  openEditClanWnd
}

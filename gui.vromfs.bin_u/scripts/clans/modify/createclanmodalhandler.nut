//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { format } = require("string")

::gui_handlers.CreateClanModalHandler <- class extends ::gui_handlers.ModifyClanModalHandler {
  function createView() {
    let clanTypeItems = []
    foreach (clanType in ::g_clan_type.types) {
      if (clanType == ::g_clan_type.UNKNOWN)
        continue
      let typeName = clanType.getTypeName()
      clanTypeItems.append({
        numItems = ::g_clan_type.types.len() - 1
        itemTooltip = format("#clan/clan_type/%s/tooltip", typeName)
        itemText = format("#clan/clan_type/%s", typeName)
        typePrice = format("(%s)", clanType.getCreateCost().getTextAccordingToBalance())
        typeName = typeName
        typeTextId = this.getTypeTextId(clanType)
      })
    }

    return {
      windowHeader = loc("clan/new_clan_wnd_title")
      hasClanTypeSelect = ::g_clans.clanTypesEnabled()
      clanTypeItems = clanTypeItems
      hasClanNameSelect = true
      hasClanSloganSelect = true
      hasClanRegionSelect = true
    }
  }

  function getTypeTextId(clanType) {
    return format("clan_type_text_%s", clanType.getTypeName())
  }

  function updateTypeCosts() {
    foreach (clanType in ::g_clan_type.types) {
      if (clanType == ::g_clan_type.UNKNOWN)
        continue
      let typeTextId = this.getTypeTextId(clanType)
      let typeTextObj = this.scene.findObject(typeTextId)
      if (checkObj(typeTextObj))
        typeTextObj.setValue(clanType.getCreateCost().getTextAccordingToBalance())
    }
  }

  // Override.
  function onEventOnlineShopPurchaseSuccessful(_params) {
    this.updateSubmitButtonText()
    this.updateTypeCosts()
  }

  function initScreen() {
    base.initScreen()
    this.updateSubmitButtonText()
    ::select_editbox(this.scene.findObject("newclan_name"))
    this.resetTagDecorationObj()
    this.updateDescription()
    this.updateAnnouncement()
  }

  function onClanTypeSelect(obj) {
    if (!checkObj(obj))
      return
    this.prepareClanData(false, true)
    this.updateTagMaxLength()
    this.resetTagDecorationObj()
    this.updateDescription()
    this.updateAnnouncement()
    this.updateReqs()
    this.updateSubmitButtonText()

    this.guiScene.applyPendingChanges(false)
    ::move_mouse_on_child_by_value(this.scene.findObject("newclan_type"))
  }

  // Override.
  function updateSubmitButtonText() {
    let createCost = this.newClanType.getCreateCost()
    this.setSubmitButtonText(loc("clan/create_clan_submit_button"), createCost)
  }

  function createClan(createCost) {
    if (this.isObsceneWord())
      return

    let createParams = ::g_clans.prepareCreateRequest(
      this.newClanType,
      this.newClanName,
      this.newClanTag,
      this.newClanSlogan,
      this.newClanDescription,
      this.newClanAnnouncement,
      this.newClanRegion
    )
    createParams["cost"] = createCost.wp
    createParams["costGold"] = createCost.gold
    ::g_clans.createClan(createParams, this)
  }

  function onSubmit() {
    if (!this.prepareClanData())
      return
    let createCost = this.newClanType.getCreateCost()
    if (createCost <= ::zero_money)
      this.createClan(createCost)
    else if (::check_balance_msgBox(createCost)) {
      let msgText = ::warningIfGold(format(loc("clan/needMoneyQuestion_createClan"),
          createCost.getTextAccordingToBalance()),
        createCost)
      this.msgBox("need_money", msgText, [["ok", function() { this.createClan(createCost) } ],
        ["cancel"]], "ok")
    }
  }

  function getDecoratorsList() {
    return ::g_clan_tag_decorator.getDecoratorsForClanType(this.newClanType)
  }
}

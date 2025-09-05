from "%scripts/dagui_library.nut" import *

let { zero_money } = require("%scripts/money.nut")
let { g_clan_type } = require("%scripts/clans/clanType.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { format } = require("string")
let { warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { move_mouse_on_child_by_value, select_editbox } = require("%sqDagui/daguiUtil.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { checkBalanceMsgBox } = require("%scripts/user/balanceFeatures.nut")
let { createClan } = require("%scripts/clans/clanActions.nut")
let { prepareCreateRequest } = require("%scripts/clans/clanRequests.nut")
let { clanTagDecoratorFuncs } = require("%scripts/clans/clanTagDecorator.nut")


function clanTypesEnabled() {
  return hasFeature("Battalions")
}

gui_handlers.CreateClanModalHandler <- class (gui_handlers.ModifyClanModalHandler) {
  function createView() {
    let clanTypeItems = []
    foreach (clanType in g_clan_type.types) {
      if (clanType == g_clan_type.UNKNOWN)
        continue
      let typeName = clanType.getTypeName()
      clanTypeItems.append({
        numItems = g_clan_type.types.len() - 1
        itemTooltip = format("#clan/clan_type/%s/tooltip", typeName)
        itemText = format("#clan/clan_type/%s", typeName)
        typePrice = format("(%s)", clanType.getCreateCost().getTextAccordingToBalance())
        typeName = typeName
        typeTextId = this.getTypeTextId(clanType)
      })
    }

    return {
      windowHeader = loc("clan/new_clan_wnd_title")
      hasClanTypeSelect = clanTypesEnabled()
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
    foreach (clanType in g_clan_type.types) {
      if (clanType == g_clan_type.UNKNOWN)
        continue
      let typeTextId = this.getTypeTextId(clanType)
      let typeTextObj = this.scene.findObject(typeTextId)
      if (checkObj(typeTextObj))
        typeTextObj.setValue(clanType.getCreateCost().getTextAccordingToBalance())
    }
  }

  
  function onEventOnlineShopPurchaseSuccessful(_params) {
    this.updateSubmitButtonText()
    this.updateTypeCosts()
  }

  function initScreen() {
    base.initScreen()
    this.updateSubmitButtonText()
    select_editbox(this.scene.findObject("newclan_name"))
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
    move_mouse_on_child_by_value(this.scene.findObject("newclan_type"))
  }

  
  function updateSubmitButtonText() {
    let createCost = this.newClanType.getCreateCost()
    this.setSubmitButtonText(loc("clan/create_clan_submit_button"), createCost)
  }

  function createClanFn(createCost) {
    if (this.isObsceneWord())
      return

    let createParams = prepareCreateRequest(
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
    createClan(createParams, this)
  }

  function onSubmit() {
    if (!this.prepareClanData())
      return
    let createCost = this.newClanType.getCreateCost()
    if (createCost <= zero_money)
      this.createClanFn(createCost)
    else if (checkBalanceMsgBox(createCost)) {
      let msgText = warningIfGold(format(loc("clan/needMoneyQuestion_createClan"),
          createCost.getTextAccordingToBalance()),
        createCost)
      this.msgBox("need_money", msgText, [["ok", function() { this.createClanFn(createCost) } ],
        ["cancel"]], "ok")
    }
  }

  function getDecoratorsList() {
    return clanTagDecoratorFuncs.getDecoratorsForClanType(this.newClanType)
  }
}

let openCreateClanWnd = @() loadHandler(gui_handlers.CreateClanModalHandler)

return {
  openCreateClanWnd
}
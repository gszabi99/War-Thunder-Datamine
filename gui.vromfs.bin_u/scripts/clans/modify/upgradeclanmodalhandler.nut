from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
::gui_handlers.UpgradeClanModalHandler <- class extends ::gui_handlers.ModifyClanModalHandler
{
  owner = null

  function createView()
  {
    return {
      windowHeader = loc("clan/upgrade_clan_wnd_title")
      hasClanTypeSelect = false
      hasClanNameSelect = false
      hasClanSloganSelect = false
      hasClanRegionSelect = false
      isNonLatinCharsAllowedInClanName = ::g_clans.isNonLatinCharsAllowedInClanName()
    }
  }

  function initScreen()
  {
    newClanType = clanData.clanType.getNextType()
    lastShownHintObj = scene.findObject("req_newclan_tag")
    base.initScreen()
    updateSubmitButtonText()
    resetTagDecorationObj(clanData.tag)
    updateDescription()
    updateAnnouncement()
    scene.findObject("newclan_description").setValue(clanData.desc)
    let newClanTagObj = scene.findObject("newclan_tag")
    newClanTagObj.setValue(::g_clans.stripClanTagDecorators(clanData.tag))
    ::select_editbox(newClanTagObj)
    onFocus(newClanTagObj)

    // Helps to avoid redundant name length check.
    newClanName = clanData.name
  }

  // Override.
  function updateSubmitButtonText()
  {
    let cost = clanData.getClanUpgradeCost()
    setSubmitButtonText(loc("clan/clan_upgrade/button"), cost)
  }

  // Important override.
  function getSelectedClanType()
  {
    return clanData.clanType.getNextType()
  }

  function onSubmit()
  {
    if(!prepareClanData())
      return
    let upgradeCost = clanData.getClanUpgradeCost()
    if (upgradeCost <= ::zero_money)
      upgradeClan()
    else if (::check_balance_msgBox(upgradeCost))
    {
      let msgText = ::warningIfGold(
        format(loc("clan/needMoneyQuestion_upgradeClanPrimaryInfo"),
          upgradeCost.getTextAccordingToBalance()),
        upgradeCost)
      this.msgBox("need_money", msgText, [["ok", function() { upgradeClan() }],
        ["cancel"]], "ok")
    }
  }

  function upgradeClan()
  {
    if (isObsceneWord())
      return
    let clanId = (::my_clan_info != null && ::my_clan_info.id == clanData.id) ? "-1" : clanData.id
    let params = ::g_clans.prepareUpgradeRequest(
      newClanType,
      newClanTag,
      newClanDescription,
      newClanAnnouncement
    )
    ::g_clans.upgradeClan(clanId, params, this)
  }

  function getDecoratorsList()
  {
    // cannot use non-paid decorators for upgrade
    return ::g_clan_tag_decorator.getDecoratorsForClanType(newClanType)
  }
}

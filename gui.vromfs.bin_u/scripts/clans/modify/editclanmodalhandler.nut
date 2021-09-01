local time = require("scripts/time.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")

class ::gui_handlers.EditClanModalhandler extends ::gui_handlers.ModifyClanModalHandler
{
  owner = null

  isMyClan = false
  adminMode = false
  myRights = null

  function createView()
  {
    return {
      windowHeader = ::loc("clan/edit_clan_wnd_title")
      hasClanTypeSelect = false
      hasClanNameSelect = true
      hasClanSloganSelect = true
      hasClanRegionSelect = true
      isNonLatinCharsAllowedInClanName = ::g_clans.isNonLatinCharsAllowedInClanName()
    }
  }

  function initScreen()
  {
    newClanType = clanData.clanType
    lastShownHintObj = scene.findObject("req_newclan_name")
    base.initScreen()
    updateSubmitButtonText()
    resetTagDecorationObj(clanData.tag)
    updateDescription()
    updateAnnouncement()
    scene.findObject("newclan_tag").setValue(::g_clans.stripClanTagDecorators(clanData.tag))
    scene.findObject("newclan_slogan").setValue(clanData.slogan)
    scene.findObject("newclan_description").setValue(clanData.desc)
    scene.findObject("newclan_announcement").setValue(clanData.announcement)

    local regionEditBoxObj = scene.findObject("newclan_region")
    regionEditBoxObj.setValue(clanData.region)
    if (!clanData.isRegionChangeAvailable())
    {
      local regionChangeTime = clanData.getRegionChangeAvailableTime()
      local regionChangeTimeText = ::loc(
        "clan/clan_can_change_region_in",
        {time = time.buildDateTimeStr(regionChangeTime)}
      )
      scene.findObject("region_change_cooldown").setValue(regionChangeTimeText)
      regionEditBoxObj.enable(false)
    }

    local clanNameObj = scene.findObject("newclan_name")
    clanNameObj.setValue(clanData.name)

    ::select_editbox(clanNameObj)

    update()
  }

  function editClanInfo()
  {
    if (isObsceneWord())
      return

    local editParams = ::g_clans.prepareEditRequest(
      newClanType,
      newClanName != clanData.name ? newClanName : null,
      newClanTag != clanData.tag ? newClanTag : null,
      newClanSlogan != clanData.slogan ? newClanSlogan : null,
      newClanDescription != clanData.desc ? newClanDescription : null,
      newClanAnnouncement != clanData.announcement ? newClanAnnouncement : null,
      newClanRegion != clanData.region ? newClanRegion : null
    )
    local clanId = (::my_clan_info != null && ::my_clan_info.id == clanData.id) ? "-1" : clanData.id
    ::g_clans.editClan(clanId, editParams, this)
  }


  function hasChangedPrimaryInfo()
  {
    return newClanName != clanData.name || newClanTag != clanData.tag
  }


  function isPrimaryInfoChangeFree()
  {
    local decorators = getDecoratorsList()
    local currentDecorator = decorators[newClanTagDecoration]
    if (newClanTag != clanData.lastPaidTag)
    {
      if (::g_clans.stripClanTagDecorators(newClanTag) != ::g_clans.stripClanTagDecorators(clanData.tag) || !currentDecorator.free)
        return false
    }
    if (newClanName != clanData.name)
      return false
    return true
  }


  function hasChangedSecondaryInfo()
  {
    if (newClanSlogan != clanData.slogan)
      return true
    if (newClanDescription != clanData.desc)
      return true
    if (newClanRegion != clanData.region)
      return true
    if (newClanAnnouncement != clanData.announcement)
      return true
    return false
  }

  function getCost(changedPrimary, changedSecondary)
  {
    if (changedPrimary && !isPrimaryInfoChangeFree())
      return newClanType.getPrimaryInfoChangeCost()
    if (changedSecondary)
      return newClanType.getSecondaryInfoChangeCost()
    return clone ::zero_money
  }

  function onFieldChange(obj)
  {
    if (!prepareClanData(true, true))
      return

    updateSubmitButtonText()
  }

  // Override.
  function updateSubmitButtonText()
  {
    local changedPrimary = hasChangedPrimaryInfo()
    local changedSecondary = hasChangedSecondaryInfo()
    local cost = getCost(changedPrimary, changedSecondary)
    setSubmitButtonText(::loc("clan/btnSaveClanInfo"), cost)
  }

  function onSubmit()
  {
    if(!prepareClanData(true))
      return
    local changedPrimary = hasChangedPrimaryInfo()
    local changedSecondary = hasChangedSecondaryInfo()
    if (!changedPrimary && !changedSecondary)
      return goBack()

    local cost = getCost( changedPrimary, changedSecondary )

    if (cost <= ::zero_money)
      editClanInfo()
    else if (::check_balance_msgBox(cost))
    {
      local text = changedPrimary && newClanType.getPrimaryInfoChangeCost() > ::zero_money
                   ? "clan/needMoneyQuestion_editClanPrimaryInfo"
                   : "clan/needMoneyQuestion_editClanSecondaryInfo"
      local msgText = ::warningIfGold(::format(::loc(text), cost.getTextAccordingToBalance()), cost)
      msgBox("need_money", msgText, [["ok", function() { editClanInfo() }],
        ["cancel"]], "ok")
    }
  }

  // Important override.
  function getSelectedClanType()
  {
    return clanData.clanType
  }

  function update()
  {
    isMyClan = ::clan_get_my_clan_id() == clanData.id
    adminMode = ::clan_get_admin_editor_mode()
    myRights = []
    if (isMyClan || adminMode)
      myRights = ::clan_get_role_rights(adminMode ? ::ECMR_CLANADMIN : ::clan_get_my_role())

    updateButtons()
  }

  function updateButtons()
  {
    local canUpgrade = clanData.clanType.canUpgradeMembers(clanData.mlimit)
    local haveLeaderRight = isInArray("LEADER", myRights)

    local upgradeMembersButtonVisible = ::has_feature("ClanUpgradeMembers") &&
                          ((isMyClan && haveLeaderRight) || adminMode) &&
                          canUpgrade

    if (upgradeMembersButtonVisible)
    {
      local cost = ::clan_get_admin_editor_mode() ? ::Cost() : clanData.clanType.getMembersUpgradeCost(clanData.mlimit)
      local upgStep = clanData.clanType.getMembersUpgradeStep()
      placePriceTextToButton(scene, "btn_upg_members", ::loc("clan/members_upgrade_button", {step = upgStep}), cost)
    }

    showSceneBtn("btn_upg_members", upgradeMembersButtonVisible)
    showSceneBtn("btn_disbandClan", (isMyClan && isInArray("DISBAND", myRights)) || adminMode)
  }

  // Override
  function onUpgradeMembers()
  {
    local cost = ::clan_get_admin_editor_mode() ? ::Cost() : clanData.clanType.getMembersUpgradeCost(clanData.mlimit)
    if (::check_balance_msgBox(cost))
    {
      local step = clanData.clanType.getMembersUpgradeStep()
      local msgText = ::warningIfGold(::loc("clan/needMoneyQuestion_upgradeMembers",
          { step = step,
            cost = cost.getTextAccordingToBalance()
          }),
        cost)
      msgBox("need_money", msgText, [["ok", function() { upgradeMembers() } ],
        ["cancel"]], "ok")
    }
  }

  function upgradeMembers()
  {
    ::g_clans.upgradeClanMembers(clanData.id)
  }

  // Override
  function onEventClanInfoUpdate(p)
  {
    if (clanData && clanData.id == ::clan_get_my_clan_id())
    {
      if (!::my_clan_info)
        return goBack()
      clanData = ::my_clan_info
      clanData = ::getFilteredClanData(clanData)
    }

    update()
  }

  function onEventClanInfoAvailable(p)
  {
    if (p.clanId != clanData.id)
      return

    clanData = ::get_clan_info_table()
    if (!clanData)
      return goBack()

    update()
  }

  function onDisbandClan()
  {
    if ((!isMyClan || !isInArray("LEADER", myRights)) && !::clan_get_admin_editor_mode())
      return;

    msgBox("disband_clan", ::loc("clan/disbandClanConfirmation"),
      [
        ["yes", function()
        {
          ::g_clans.disbandClan(isMyClan ? "-1" : clanData.id ,this)
        }],
        ["no",  function() {} ],
      ], "no", { cancel_fn = function(){}} );
  }

  function getDecoratorsList()
  {
    return ::g_clan_tag_decorator.getDecorators({
      clanType = newClanType
      rewardsList = clanData.getAllRegaliaTags()
    })
  }
}

class ::gui_handlers.CreateClanModalHandler extends ::gui_handlers.ModifyClanModalHandler
{
  function createView()
  {
    local clanTypeItems = []
    foreach (clanType in ::g_clan_type.types)
    {
      if (clanType == ::g_clan_type.UNKNOWN)
        continue
      local typeName = clanType.getTypeName()
      clanTypeItems.append({
        numItems = ::g_clan_type.types.len() - 1
        itemTooltip = ::format("#clan/clan_type/%s/tooltip", typeName)
        itemText = ::format("#clan/clan_type/%s", typeName)
        typePrice = ::format("(%s)", clanType.getCreateCost().getTextAccordingToBalance())
        typeName = typeName
        typeTextId = getTypeTextId(clanType)
      })
    }

    return {
      windowHeader = ::loc("clan/new_clan_wnd_title")
      hasClanTypeSelect = ::g_clans.clanTypesEnabled()
      clanTypeItems = clanTypeItems
      hasClanNameSelect = true
      hasClanSloganSelect = true
      hasClanRegionSelect = true
      isNonLatinCharsAllowedInClanName = ::g_clans.isNonLatinCharsAllowedInClanName()
    }
  }

  function getTypeTextId(clanType)
  {
    return ::format("clan_type_text_%s", clanType.getTypeName())
  }

  function updateTypeCosts()
  {
    foreach (clanType in ::g_clan_type.types)
    {
      if (clanType == ::g_clan_type.UNKNOWN)
        continue
      local typeTextId = getTypeTextId(clanType)
      local typeTextObj = scene.findObject(typeTextId)
      if (::checkObj(typeTextObj))
        typeTextObj.setValue(clanType.getCreateCost().getTextAccordingToBalance())
    }
  }

  // Override.
  function onEventOnlineShopPurchaseSuccessful(params)
  {
    updateSubmitButtonText()
    updateTypeCosts()
  }

  function initScreen()
  {
    base.initScreen()
    updateSubmitButtonText()
    local nObj = scene.findObject("newclan_name")
    nObj.select()
    resetTagDecorationObj()
    initFocusArray()
    updateDescription()
    updateAnnouncement()
  }

  function onClanTypeSelect(obj)
  {
    if (!::checkObj(obj))
      return
    obj.select() // Sets focus on click.
    prepareClanData(false, true)
    updateTagMaxLength()
    resetTagDecorationObj()
    updateDescription()
    updateAnnouncement()
    updateReqs()
    updateSubmitButtonText()
  }

  // Override.
  function updateSubmitButtonText()
  {
    local createCost = newClanType.getCreateCost()
    setSubmitButtonText(::loc("clan/create_clan_submit_button"), createCost)
  }

  function createClan()
  {
    if (isObsceneWord())
      return

    local createParams = ::g_clans.prepareCreateRequest(
      newClanType,
      newClanName,
      newClanTag,
      newClanSlogan,
      newClanDescription,
      newClanAnnouncement,
      newClanRegion
    )
    ::g_clans.createClan(createParams, this)
  }

  function onSubmit()
  {
    if(!prepareClanData())
      return
    local createCost = newClanType.getCreateCost()
    if (createCost <= ::zero_money)
      createClan()
    else if (::check_balance_msgBox(createCost))
    {
      local msgText = warningIfGold(format(::loc("clan/needMoneyQuestion_createClan"),
          createCost.getTextAccordingToBalance()),
        createCost)
      msgBox("need_money", msgText, [["ok", function() { createClan() } ],
        ["cancel"]], "ok")
    }
  }

  function getDecoratorsList()
  {
    return ::g_clan_tag_decorator.getDecoratorsForClanType(newClanType)
  }
}

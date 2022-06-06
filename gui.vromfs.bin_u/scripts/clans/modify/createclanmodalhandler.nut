::gui_handlers.CreateClanModalHandler <- class extends ::gui_handlers.ModifyClanModalHandler
{
  function createView()
  {
    let clanTypeItems = []
    foreach (clanType in ::g_clan_type.types)
    {
      if (clanType == ::g_clan_type.UNKNOWN)
        continue
      let typeName = clanType.getTypeName()
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
      let typeTextId = getTypeTextId(clanType)
      let typeTextObj = scene.findObject(typeTextId)
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
    ::select_editbox(scene.findObject("newclan_name"))
    resetTagDecorationObj()
    updateDescription()
    updateAnnouncement()
  }

  function onClanTypeSelect(obj)
  {
    if (!::checkObj(obj))
      return
    prepareClanData(false, true)
    updateTagMaxLength()
    resetTagDecorationObj()
    updateDescription()
    updateAnnouncement()
    updateReqs()
    updateSubmitButtonText()

    guiScene.applyPendingChanges(false)
    ::move_mouse_on_child_by_value(scene.findObject("newclan_type"))
  }

  // Override.
  function updateSubmitButtonText()
  {
    let createCost = newClanType.getCreateCost()
    setSubmitButtonText(::loc("clan/create_clan_submit_button"), createCost)
  }

  function createClan(createCost)
  {
    if (isObsceneWord())
      return

    let createParams = ::g_clans.prepareCreateRequest(
      newClanType,
      newClanName,
      newClanTag,
      newClanSlogan,
      newClanDescription,
      newClanAnnouncement,
      newClanRegion
    )
    createParams["cost"] = createCost.wp
    createParams["costGold"] = createCost.gold
    ::g_clans.createClan(createParams, this)
  }

  function onSubmit()
  {
    if(!prepareClanData())
      return
    let createCost = newClanType.getCreateCost()
    if (createCost <= ::zero_money)
      createClan(createCost)
    else if (::check_balance_msgBox(createCost))
    {
      let msgText = warningIfGold(format(::loc("clan/needMoneyQuestion_createClan"),
          createCost.getTextAccordingToBalance()),
        createCost)
      msgBox("need_money", msgText, [["ok", function() { createClan(createCost) } ],
        ["cancel"]], "ok")
    }
  }

  function getDecoratorsList()
  {
    return ::g_clan_tag_decorator.getDecoratorsForClanType(newClanType)
  }
}

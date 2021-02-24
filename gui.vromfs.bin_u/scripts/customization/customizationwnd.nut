local time = require("scripts/time.nut")
local penalty = ::require_native("penalty")
local decorLayoutPresets = require("scripts/customization/decorLayoutPresetsWnd.nut")
local unitActions = require("scripts/unit/unitActions.nut")
local contentPreview = require("scripts/customization/contentPreview.nut")
local { openUrl } = require("scripts/onlineShop/url.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local weaponryPresetsModal = require("scripts/weaponry/weaponryPresetsModal.nut")
local { canBuyNotResearched,
        isUnitHaveSecondaryWeapons } = require("scripts/unit/unitStatus.nut")

local { isPlatformPC } = require("scripts/clientState/platform.nut")
local { canUseIngameShop, getShopItemsTable } = require("scripts/onlineShop/entitlementsStore.nut")
local { needSecondaryWeaponsWnd } = require("scripts/weaponry/weaponryInfo.nut")
local { isCollectionPrize, isCollectionItem } = require("scripts/collections/collections.nut")
local { openCollectionsWnd, hasAvailableCollections } = require("scripts/collections/collectionsWnd.nut")

::dagui_propid.add_name_id("gamercardSkipNavigation")

enum decoratorEditState
{
  NONE     = 0x0001
  SELECT   = 0x0002
  REPLACE  = 0x0004
  ADD      = 0x0008
  PURCHASE = 0x0010
  EDITING  = 0x0020
}

enum decalTwoSidedMode
{
  OFF
  ON
  ON_MIRRORED
}

::on_decal_job_complete <- function on_decal_job_complete(taskId)
{
  local callback = ::getTblValue(taskId, ::g_decorator_type.DECALS.jobCallbacksStack, null)
  if (callback)
  {
    callback()
    delete ::g_decorator_type.DECALS.jobCallbacksStack[taskId]
  }

  ::broadcastEvent("DecalJobComplete", { taskId = taskId })
}

::gui_start_decals <- function gui_start_decals(params = null)
{
  if (params?.unit)
    ::show_aircraft = params.unit
  else if (params?.unitId)
    ::show_aircraft = ::getAircraftByName(params?.unitId)

  if (!::show_aircraft
      ||
        ( ::hangar_get_loaded_unit_name() == (::show_aircraft && ::show_aircraft.name)
        && !::is_loaded_model_high_quality()
        && !::check_package_and_ask_download("pkg_main"))
    )
    return

  params = params || {}
  params.backSceneFunc <- ::gui_start_mainmenu
  ::handlersManager.loadHandler(::gui_handlers.DecalMenuHandler, params)
}

class ::gui_handlers.DecalMenuHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/customization/customization.blk"
  unit = null
  owner = null

  access_WikiOnline = false
  access_Decals = false
  access_Attachables = false
  access_UserSkins = false
  access_Skins = false
  access_SkinsUnrestrictedPreview = false
  access_SkinsUnrestrictedExport  = false

  editableDecoratorId = null

  skinList = null
  curSlot = 0
  curAttachSlot = 0
  previewSkinId = null

  initialAppliedSkinId = null
  initialUserSkinId = null
  initialUnitId = null

  currentType = ::g_decorator_type.UNKNOWN

  isLoadingRot = false
  isDecoratorsListOpen = false
  isDecoratorItemUsed = false

  isUnitTank = false
  isUnitOwn = false

  currentState = decoratorEditState.NONE

  previewParams = null
  previewMode = PREVIEW_MODE.NONE

  decoratorPreview = null

  preSelectDecorator = null
  preSelectDecoratorSlot = -1

  unitInfoPanelWeak = null
  needForceShowUnitInfoPanel = false

  function initScreen()
  {
    owner = this
    unit = ::show_aircraft
    ::cur_aircraft_name = unit.name

    access_WikiOnline = ::has_feature("WikiUnitInfo")
    access_UserSkins = isPlatformPC && ::has_feature("UserSkins")
    access_SkinsUnrestrictedPreview = ::has_feature("SkinsPreviewOnUnboughtUnits")
    access_SkinsUnrestrictedExport  = access_UserSkins && access_SkinsUnrestrictedExport

    initialAppliedSkinId   = ::hangar_get_last_skin(unit.name)
    initialUserSkinId      = ::get_user_skins_profile_blk()?[unit.name] ?? ""

    ::enableHangarControls(true)
    scene.findObject("timer_update").setUserData(this)

    ::hangar_focus_model(true)

    local unitInfoPanel = ::create_slot_info_panel(scene, false, "showroom")
    registerSubHandler(unitInfoPanel)
    unitInfoPanelWeak = unitInfoPanel.weakref()
    if (needForceShowUnitInfoPanel)
      unitInfoPanelWeak.uncollapse()

    initPreviewMode()
    initMainParams()
    showDecoratorsList()

    updateDecalActionsTexts()

    ::hangar_model_load_manager.loadModel(unit.name)

    if (!isUnitOwn && !previewMode)
    {
      local skinId = unit.getPreviewSkinId()
      if (skinId != "" && skinId != initialAppliedSkinId)
        applySkin(skinId, true)
    }

    if (preSelectDecorator)
    {
      preSelectSlotAndDecorator(preSelectDecorator, preSelectDecoratorSlot)
      preSelectDecorator = null
      preSelectDecoratorSlot = -1
    }
  }

  function canRestartSceneNow()
  {
    return ::isInArray(currentState, [ decoratorEditState.NONE, decoratorEditState.SELECT ])
  }

  function getHandlerRestoreData()
  {
    local data = {
      openData = {
      }
      stateData = {
        initialAppliedSkinId = initialAppliedSkinId
        initialUserSkinId    = initialUserSkinId
      }
    }
    return data
  }

  function restoreHandler(stateData)
  {
    initialAppliedSkinId = stateData.initialAppliedSkinId
    initialUserSkinId    = stateData.initialUserSkinId
  }

  function initMainParams()
  {
    isUnitOwn = unit.isUsable()
    isUnitTank = unit.isTank()

    access_Decals      = !previewMode && isUnitOwn && ::g_decorator_type.DECALS.isAvailable(unit)
    access_Attachables = !previewMode && isUnitOwn && ::g_decorator_type.ATTACHABLES.isAvailable(unit)
    access_Skins = (previewMode & (PREVIEW_MODE.UNIT | PREVIEW_MODE.SKIN)) ? true
      : (previewMode & PREVIEW_MODE.DECORATOR) ? false
      : isUnitOwn || access_SkinsUnrestrictedPreview || access_SkinsUnrestrictedExport

    updateTitle()

    setDmgSkinMode(::hangar_get_loaded_model_damage_state(unit.name) == MDS_DAMAGED)

    local bObj = scene.findObject("btn_testflight")
    if (::checkObj(bObj))
    {
      bObj.setValue(unit.unitType.getTestFlightText())
      bObj.findObject("btn_testflight_image")["background-image"] = unit.unitType.testFlightIcon
    }

    createSkinSliders()
    updateMainGuiElements()
  }

  function updateMainGuiElements()
  {
    updateSlotsBlockByType()
    updateSkinList()
    updateAutoSkin()
    updateUserSkinList()
    updateSkinSliders()
    updateUnitStatus()
    updatePreviewedDecoratorInfo()
    updateButtons()
  }

  function updateTitle()
  {
    local title = ::loc(isUnitOwn && !previewMode? "mainmenu/showroom" : "mainmenu/btnPreview") + " " + ::loc("ui/mdash") + " "
    if (!previewMode || (previewMode & (PREVIEW_MODE.UNIT | PREVIEW_MODE.SKIN)))
      title += ::getUnitName(unit.name)

    if (previewMode & PREVIEW_MODE.SKIN)
    {
      local skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
      local skin = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
      if (skin)
        title += ::loc("ui/comma") + ::loc("options/skin") + " " + ::colorize(skin.getRarityColor(), skin.getName())
    }
    else if (previewMode & PREVIEW_MODE.DECORATOR)
    {
      local typeText = ::loc("trophy/unlockables_names/" + decoratorPreview.decoratorType.resourceType)
      local nameText = ::colorize(decoratorPreview.getRarityColor(), decoratorPreview.getName())
      title += typeText + " " + nameText
    }

    setSceneTitle(title)
  }

  function getCurCategoryListObj()
  {
    local decalsObj = scene.findObject("decals_list")
    if (!::checkObj(decalsObj))
      return null

    local value = decalsObj.getValue()
    if (value < 0 || value >= decalsObj.childrenCount())
      return null

    local categoryObj = decalsObj.getChild(value)
    if (::checkObj(categoryObj))
    {
      local categoryListObj = categoryObj.findObject("collapse_content_" + (categoryObj?.id ?? ""))
      if (::checkObj(categoryListObj))
        return categoryListObj
    }

    return null
  }

  function updateDecalActionsTexts()
  {
    local bObj = null
    local shortcuts = []

    local hasKeyboard = isPlatformPC
    local hasGamepad = ::show_console_buttons

    //Flip
    local btn_toggle_mirror_text = ::loc("decals/flip") + (hasKeyboard ? " (F)" : "")
    bObj = scene.findObject("btn_toggle_mirror")
    if(::checkObj(bObj))
      bObj.setValue(btn_toggle_mirror_text)

    //TwoSided
    local text = ::loc("decals/twosided") + (hasKeyboard ? " (T)" : "") + ::loc("ui/colon")
    bObj = scene.findObject("two_sided_label")
    if(::checkObj(bObj))
      bObj.setValue(text)

    //Size
    shortcuts = []
    if (hasGamepad)
      shortcuts.append(::loc("xinp/L1") + ::loc("ui/slash") + ::loc("xinp/R1"))
    if (hasKeyboard)
      shortcuts.append(::loc("key/Shift") + ::loc("keysPlus") + ::loc("key/Wheel"))
    bObj = scene.findObject("push_to_change_size")
    if (::checkObj(bObj))
      bObj.setValue(::g_string.implode(shortcuts, ::loc("ui/comma")))

    //Rotate
    shortcuts = []
    if (hasGamepad)
      shortcuts.append(::loc("xinp/D.Left") + ::loc("ui/slash") + ::loc("xinp/D.Right"))
    if (hasKeyboard)
      shortcuts.append(::loc("key/Alt") + ::loc("keysPlus") + ::loc("key/Wheel"))
    bObj = scene.findObject("push_to_rotate")
    if (::checkObj(bObj))
      bObj.setValue(::g_string.implode(shortcuts, ::loc("ui/comma")))
  }

  function getSelectedBuiltinSkinId()
  {
    local res = previewSkinId || ::hangar_get_last_skin(unit.name)
    return res == "" ? "default" : res // hangar_get_last_skin() can return empty string.
  }

  function exportSampleUserSkin(obj)
  {
    if (!::hangar_is_loaded())
      return

    if (!::can_save_current_skin_template())
    {
      local message = ::format(::loc("decals/noUserSkinForCurUnit"), ::getUnitName(unit.name))
      msgBox("skin_template_export", message, [["ok", function(){}]], "ok")
      return
    }

    local allowCurrentSkin = access_SkinsUnrestrictedExport // true - current skin, false - default skin.
    local success = ::save_current_skin_template(allowCurrentSkin)

    local templateName = "template_" + unit.name
    local message = success ? ::format(::loc("decals/successfulLoadedSkinSample"), templateName) : ::loc("decals/failedLoadedSkinSample")
    msgBox("skin_template_export", message, [["ok", function(){}]], "ok")

    updateMainGuiElements()
  }

  function refreshSkinsList(obj)
  {
    if (!::hangar_is_loaded())
      return

    updateUserSkinList()
    if (::get_option(::USEROPT_USER_SKIN).value > 0)
      ::hangar_force_reload_model()
  }

  function onEventHangarModelLoaded(params = {})
  {
    if (previewMode)
      removeAllDecorators(false)

    updateMainGuiElements()
    if (::hangar_get_loaded_unit_name() == unit.name
        && !::is_loaded_model_high_quality())
      ::check_package_and_ask_download("pkg_main", null, null, this, "air_in_hangar", goBack)
  }

  function onEventDecalJobComplete(params)
  {
    local isInEditMode = currentState & decoratorEditState.EDITING
    if (isInEditMode && currentType == ::g_decorator_type.DECALS)
      updateDecoratorActionBtnStates()
  }

  function updateAutoSkin()
  {
    if (!access_Skins)
      return

    local isVisible = !previewMode && isUnitOwn && unit.unitType.isSkinAutoSelectAvailable()
    showSceneBtn("auto_skin_block", isVisible)
    if (!isVisible)
      return

    local autoSkinId = "auto_skin_control"
    local controlObj = scene.findObject(autoSkinId)
    if (::check_obj(controlObj))
    {
      controlObj.setValue(::g_decorator.isAutoSkinOn(unit.name))
      return
    }

    local placeObj = scene.findObject("auto_skin_place")
    local markup = ::create_option_switchbox({
      id = autoSkinId
      value = ::g_decorator.isAutoSkinOn(unit.name)
      cb = "onAutoSkinchange"
    })
    guiScene.replaceContentFromText(placeObj, markup, markup.len(), this)
  }

  function onAutoSkinchange(obj)
  {
    ::g_decorator.setAutoSkin(unit.name, obj.getValue())
  }

  function updateSkinList()
  {
    if (!access_Skins)
      return

    skinList = ::g_decorator.getSkinsOption(unit.name, true, false, true)
    local curSkinId = getSelectedBuiltinSkinId()
    local curSkinIndex = ::find_in_array(skinList.values, curSkinId, 0)
    local tooltipParams = previewMode ? { showAsTrophyContent = true } : null

    local skinItems = []
    foreach(i, decorator in skinList.decorators)
    {
      local access = skinList.access[i]
      local canBuy = !previewMode && decorator.canBuyUnlock(unit)
      local canFindOnMarketplace = !previewMode && decorator.canBuyCouponOnMarketplace(unit)
      local priceText = canBuy ? decorator.getCost().getTextAccordingToBalance() : ""
      local isUnlocked = decorator.isUnlocked()
      local text = skinList.items[i].text
      local image = skinList.items[i].image
      if (canBuy)
        text = ::loc("ui/parentheses", {text = priceText}) + " " + text
      else if (canFindOnMarketplace)
        text = "".concat(::loc("currency/gc/sign"), " ", text)

      if (!access.isVisible)
        text = ::colorize("comboExpandedLockedTextColor", "(" + ::loc("worldWar/hided_logs") + ") ") + text

      skinItems.append({
        text = text
        textStyle = skinList.items[i].textStyle
        addDiv = ::g_tooltip_type.DECORATION.getMarkup(decorator.id, ::UNLOCKABLE_SKIN, tooltipParams)
        image  = image == "" ? null : image
        image2 = isUnlocked ? null : "#ui/gameuiskin#locked"
        imageNoMargin = !isUnlocked
        image2NoMargin = true
      })
    }

    renewDropright("skins_list", "skins_dropright", skinItems, curSkinIndex, "onSkinChange")
  }

  function renewDropright(nestObjId, listObjId, items, index, cb)
  {
    local nestObj = scene.findObject(listObjId)
    local needCreateList = false
    if (!::checkObj(nestObj))
    {
      needCreateList = true
      nestObj = scene.findObject(nestObjId)
      if (!::checkObj(nestObj))
        return
    }
    local skinsDropright = ::create_option_combobox(listObjId, items, index, cb, needCreateList)
    if (needCreateList)
      guiScene.prependWithBlk(nestObj, skinsDropright, this)
    else
      guiScene.replaceContentFromText(nestObj, skinsDropright, skinsDropright.len(), this)
  }

  function updateUserSkinList()
  {
    ::reload_user_skins()
    local userSkinsOption = ::get_option(::USEROPT_USER_SKIN)
    renewDropright("user_skins_list", "user_skins_dropright", userSkinsOption.items, userSkinsOption.value, "onUserSkinChanged")
  }

  function createSkinSliders()
  {
    if (!isUnitOwn || !isUnitTank)
      return

    local options = [::USEROPT_TANK_CAMO_SCALE,
                     ::USEROPT_TANK_CAMO_ROTATION]
    if (::has_feature("SpendGold"))
      options.insert(0, ::USEROPT_TANK_SKIN_CONDITION)

    local view = { rows = [] }
    foreach(optType in options)
    {
      local option = ::get_option(optType)
      view.rows.append({
        id = option.id
        name = "#options/" + option.id
        option = ::create_option_slider(option.id, option.value, option.cb, true, "slider", option)
      })
    }
    local data = ::handyman.renderCached(("gui/options/verticalOptions"), view)
    local slObj = scene.findObject("tank_skin_settings")
    if (::checkObj(slObj))
      guiScene.replaceContentFromText(slObj, data, data.len(), this)

    updateSkinSliders()
  }

  function updateSkinSliders()
  {
    if (!isUnitOwn || !isUnitTank)
      return

    local skinIndex = skinList?.values.indexof(previewSkinId) ?? 0
    local skinDecorator = skinList?.decorators[skinIndex]
    local canScaleAndRotate = skinDecorator?.getCouponItemdefId() == null

    local have_premium = ::havePremium()
    local option = null

    option = ::get_option(::USEROPT_TANK_SKIN_CONDITION)
    local tscId = option.id
    local tscTrObj = scene.findObject("tr_" + tscId)
    if (::checkObj(tscTrObj))
    {
      tscTrObj.inactiveColor = have_premium? "no" : "yes"
      tscTrObj.tooltip = have_premium ? "" : ::loc("mainmenu/onlyWithPremium")
      local sliderObj = scene.findObject(tscId)
      local value = have_premium ? option.value : option.defVal
      sliderObj.setValue(value)
      updateSkinConditionValue(value, sliderObj)
    }

    option = ::get_option(::USEROPT_TANK_CAMO_SCALE)
    local tcsId = option.id
    local tcsTrObj = scene.findObject("tr_" + tcsId)
    if (::checkObj(tcsTrObj))
    {
      tcsTrObj.tooltip = canScaleAndRotate ? "" : ::loc("guiHints/not_available_on_this_camo")
      local sliderObj = scene.findObject(tcsId)
      local value = canScaleAndRotate ? option.value : option.defVal
      sliderObj.setValue(value)
      sliderObj.enable(canScaleAndRotate)
      onChangeTankCamoScale(sliderObj)
    }

    option = ::get_option(::USEROPT_TANK_CAMO_ROTATION)
    local tcrId = option.id
    local tcrTrObj = scene.findObject("tr_" + tcrId)
    if (::checkObj(tcrTrObj))
    {
      tcrTrObj.tooltip = canScaleAndRotate ? "" : ::loc("guiHints/not_available_on_this_camo")
      local sliderObj = scene.findObject(tcrId)
      local value = canScaleAndRotate ? option.value : option.defVal
      sliderObj.setValue(value)
      sliderObj.enable(canScaleAndRotate)
      onChangeTankCamoRotation(sliderObj)
    }
  }

  function onChangeTankSkinCondition(obj)
  {
    if (!::checkObj(obj))
      return

    local oldValue = ::get_option(::USEROPT_TANK_SKIN_CONDITION).value
    local newValue = obj.getValue()
    if (oldValue == newValue)
      return

    if (!::havePremium())
    {
      obj.setValue(oldValue)
      guiScene.performDelayed(this, @()
        isValid() && askBuyPremium(::Callback(updateSkinSliders, this)))
      return
    }

    updateSkinConditionValue(newValue, obj)
  }

  function askBuyPremium(afterCloseFunc)
  {
    local msgText = ::loc("msgbox/noEntitlement/PremiumAccount")
    msgBox("no_premium", msgText,
         [["ok", @() startOnlineShop("premium", afterCloseFunc) ],
         ["cancel", @() null ]], "ok", { checkDuplicateId = true })
  }

  function updateSkinConditionValue(value, obj)
  {
    local textObj = scene.findObject("value_" + (obj?.id ?? ""))
    if (!::checkObj(textObj))
      return

    textObj.setValue(((value + 100) / 2).tostring() + "%")
    ::hangar_set_tank_skin_condition(value)
  }

  function onChangeTankCamoScale(obj)
  {
    if (!::checkObj(obj))
      return

    local textObj = scene.findObject("value_" + (obj?.id ?? ""))
    if (::checkObj(textObj))
    {
      local value = obj.getValue()
      ::hangar_set_tank_camo_scale(value / TANK_CAMO_SCALE_SLIDER_FACTOR)
      textObj.setValue((hangar_get_tank_camo_scale_result_value() * 100 + 0.5).tointeger().tostring() + "%")
    }
  }

  function onChangeTankCamoRotation(obj)
  {
    if (!::checkObj(obj))
      return

    local textObj = scene.findObject("value_" + (obj?.id ?? ""))
    if (::checkObj(textObj))
    {
      local value = obj.getValue()
      local visualValue = value * 180 / 100
      textObj.setValue((visualValue > 0 ? "+" : "") + visualValue.tostring())
      ::hangar_set_tank_camo_rotation(value)
    }
  }

  function updateAttachablesSlots()
  {
    if (!access_Attachables)
      return

    local view = {buttons = []}
    for (local i = 0; i < ::g_decorator_type.ATTACHABLES.getMaxSlots(); i++)
    {
      local button = getViewButtonTable(i, ::g_decorator_type.ATTACHABLES)
      button.id = "slot_attach_" + i
      button.onClick = "onAttachableSlotClick"
      button.onDblClick = "onAttachableSlotDoubleClick"
      button.onDeleteClick = "onDeleteAttachable"
      view.buttons.append(button)
    }

    local dObj = scene.findObject("attachable_div")
    if (!::checkObj(dObj))
      return

    local attachListObj = dObj.findObject("slots_attachable_list")
    if (!::checkObj(attachListObj))
      return

    dObj.show(true)
    local data = ::handyman.renderCached("gui/commonParts/imageButton", view)

    guiScene.replaceContentFromText(attachListObj, data, data.len(), this)
    attachListObj.setValue(curAttachSlot)
  }

  function updateDecalSlots()
  {
    local view = {buttons = []}
    for (local i = 0; i < ::g_decorator_type.DECALS.getMaxSlots(); i++)
    {
      local button = getViewButtonTable(i, ::g_decorator_type.DECALS)
      button.id = "slot_" + i
      button.onClick = "onDecalSlotClick"
      button.onDblClick = "onDecalSlotDoubleClick"
      button.onDeleteClick = "onDeleteDecal"
      view.buttons.append(button)
    }

    local dObj = scene.findObject("slots_list")
    if (::checkObj(dObj))
    {
      local data = ::handyman.renderCached("gui/commonParts/imageButton", view)
      guiScene.replaceContentFromText(dObj, data, data.len(), this)
    }

    dObj.setValue(curSlot)
  }

  function getViewButtonTable(slotIdx, decoratorType)
  {
    local canEditDecals = isUnitOwn && previewSkinId == null
    local slot = getSlotInfo(slotIdx, false, decoratorType)
    local decalId = slot.decalId
    local decorator = ::g_decorator.getDecorator(decalId, decoratorType)
    local slotRatio = ::clamp(decoratorType.getRatio(decorator), 1, 2)
    local buttonTooltip = slot.isEmpty ? ::loc(decoratorType.emptySlotLocId) : ""
    if (!isUnitOwn)
      buttonTooltip = "#mainmenu/decalUnitLocked"
    else if (!canEditDecals)
      buttonTooltip = "#mainmenu/decalSkinLocked"
    else if (!slot.unlocked)
    {
      if (::has_feature("EnablePremiumPurchase"))
        buttonTooltip = "#mainmenu/onlyWithPremium"
      else
        buttonTooltip = "#charServer/notAvailableYet"
    }

    return {
      id = null
      onClick = null
      onDblClick = null
      onDeleteClick = null
      ratio = slotRatio
      statusLock = slot.unlocked? getStatusLockText(decorator)
        : ::has_feature("EnablePremiumPurchase") ? "noPremium_" + slotRatio
        : "achievement"
      unlocked = slot.unlocked && (!decorator || decorator.isUnlocked())
      emptySlot = slot.isEmpty || !decorator
      image = decoratorType.getImage(decorator)
      rarityColor = decorator?.isRare() ? decorator.getRarityColor() : null
      tooltipText = buttonTooltip
      tooltipId = slot.isEmpty? null : ::g_tooltip_type.DECORATION.getTooltipId(decalId, decoratorType.unlockedItemType)
      tooltipOffset = "1@bw, 1@bh + 0.1@sf"
    }
  }

  onSlotsHoverChange = @() updateButtons()

  function updateButtons(decoratorType = null, needUpdateSlotDivs = true)
  {
    local isGift   = ::isUnitGift(unit)
    local canBuyOnline = ::canBuyUnitOnline(unit)
    local canBuyNotResearchedUnit = canBuyNotResearched(unit)
    local canBuyIngame = !canBuyOnline && (::canBuyUnit(unit) || canBuyNotResearchedUnit)
    local canFindUnitOnMarketplace = !canBuyOnline && !canBuyIngame && ::canBuyUnitOnMarketplace(unit)

    if (isGift && canUseIngameShop() && getShopItemsTable().len() == 0)
    {
      //Override for ingameShop.
      //There is rare posibility, that shop data is empty.
      //Because of external error.
      canBuyOnline = false
    }

    local bObj = showSceneBtn("btn_buy", canBuyIngame)
    if (canBuyIngame && ::check_obj(bObj))
    {
      local price = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
      placePriceTextToButton(scene, "btn_buy", ::loc("mainmenu/btnOrder"), price)

      ::showUnitDiscount(bObj.findObject("buy_discount"), unit)
    }

    local bOnlineObj = showSceneBtn("btn_buy_online", canBuyOnline)
    if (canBuyOnline && ::check_obj(bOnlineObj))
      ::showUnitDiscount(bOnlineObj.findObject("buy_online_discount"), unit)

    showSceneBtn("btn_marketplace_find_unit", canFindUnitOnMarketplace)

    local skinDecorator = null
    local skinCouponItemdefId = null

    if (isUnitOwn && previewSkinId && skinList)
    {
      local skinIndex = skinList.values.indexof(previewSkinId) ?? -1
      skinDecorator = skinList.decorators?[skinIndex]
      skinCouponItemdefId = skinDecorator?.getCouponItemdefId()
    }

    local canBuySkin = skinDecorator?.canBuyUnlock(unit) ?? false
    local canConsumeSkinCoupon = !canBuySkin &&
      (::ItemsManager.getInventoryItemById(skinCouponItemdefId)?.canConsume() ?? false)
    local canFindSkinOnMarketplace = !canBuySkin && !canConsumeSkinCoupon && skinCouponItemdefId != null

    bObj = showSceneBtn("btn_buy_skin", canBuySkin)
    if (canBuySkin && ::check_obj(bObj))
    {
      local price = skinDecorator.getCost()
      placePriceTextToButton(scene, "btn_buy_skin", ::loc("mainmenu/btnOrder"), price)
    }

    local can_testflight = ::isTestFlightAvailable(unit) && !decoratorPreview
    local can_createUserSkin = ::can_save_current_skin_template()

    bObj = scene.findObject("btn_load_userskin_sample")
    if (::checkObj(bObj))
      bObj.inactiveColor = can_createUserSkin ? "no" : "yes"

    local isInEditMode = currentState & decoratorEditState.EDITING
    updateBackButton()

    if (decoratorType == null)
      decoratorType = currentType

    local focusedType = getCurrentFocusedType()
    local focusedSlot = getSlotInfo(getCurrentDecoratorSlot(focusedType), true, focusedType)

    bObj = scene.findObject("btn_toggle_damaged")
    local isDmgSkinPreviewMode = ::checkObj(bObj) && bObj.getValue()

    local usableSkinsCount = ::u.filter(skinList?.access ?? [], @(a) a.isOwn).len()

    ::showBtnTable(scene, {
          btn_go_to_collection = ::show_console_buttons && !isInEditMode && isDecoratorsListOpen
            && isCollectionItem(getSelectedDecal(decoratorType))

          btn_apply = currentState & decoratorEditState.EDITING

          btn_testflight = !isInEditMode && !isDecoratorsListOpen && can_testflight
          btn_info       = !isInEditMode && !isDecoratorsListOpen && ::isUnitDescriptionValid(unit) && !access_WikiOnline
          btn_info_online = !isInEditMode && !isDecoratorsListOpen && ::isUnitDescriptionValid(unit) && access_WikiOnline
          btn_sec_weapons    = !isInEditMode && !isDecoratorsListOpen &&
            needSecondaryWeaponsWnd(unit) && isUnitHaveSecondaryWeapons(unit)
          btn_weapons    = !isInEditMode && !isDecoratorsListOpen

          btn_decal_edit   = ::show_console_buttons && !isInEditMode && !isDecoratorsListOpen && !focusedSlot.isEmpty && focusedSlot.unlocked
          btn_decal_delete = ::show_console_buttons && !isInEditMode && !isDecoratorsListOpen && !focusedSlot.isEmpty && focusedSlot.unlocked

          btn_marketplace_consume_coupon_skin = !previewMode && canConsumeSkinCoupon
          btn_marketplace_find_skin = !previewMode && canFindSkinOnMarketplace

          skins_div = !isInEditMode && !isDecoratorsListOpen && access_Skins
          user_skins_block = !previewMode && access_UserSkins
          tank_skin_settings = !previewMode && isUnitTank

          previewed_decorator_div  = !isInEditMode && decoratorPreview
          previewed_decorator_unit = !isInEditMode && decoratorPreview && initialUnitId && initialUnitId != unit?.name

          btn_dm_viewer = !isInEditMode && !isDecoratorsListOpen && ::dmViewer.canUse()

          decor_layout_presets = !isInEditMode && !isDecoratorsListOpen && isUnitOwn &&
            ::has_feature("CustomizationLayoutPresets") && usableSkinsCount > 1 &&
            !previewMode && !previewSkinId

          dmg_skin_div = ::has_feature("DamagedSkinPreview") && !isInEditMode && !isDecoratorsListOpen
          dmg_skin_buttons_div = isDmgSkinPreviewMode && (unit.isAir() || unit.isHelicopter())
    })

    if (unitInfoPanelWeak?.isValid() ?? false)
      unitInfoPanelWeak.onSceneActivate(!isInEditMode && !isDecoratorsListOpen && !isDmgSkinPreviewMode)

    if (needUpdateSlotDivs)
      updateSlotsDivsVisibility(decoratorType)

    local isHangarLoaded = ::hangar_is_loaded()
    ::enableBtnTable(scene, {
          decalslots_div     = isHangarLoaded
          slots_list         = isHangarLoaded
          skins_navigator    = isHangarLoaded
          tank_skin_settings = isHangarLoaded
    })

    updateDecoratorActions(isInEditMode, decoratorType)
    scene.findObject("gamercard_div")["gamercardSkipNavigation"] = isInEditMode ? "yes" : "no"
    update_gamercards()
  }

  function updateBackButton()
  {
    local bObj = scene.findObject("btn_back")
    if (!bObj?.isValid())
      return

    if (currentState & decoratorEditState.EDITING)
    {
      bObj.text = ::loc("mainmenu/btnCancel")
      bObj["skip-navigation"] = "yes"
      return
    }

    if ((currentState & decoratorEditState.SELECT) && ::show_console_buttons)
    {
      local listObj = getCurCategoryListObj()
      if (listObj?.isValid() && listObj.isHovered())
      {
        bObj.text = ::loc("mainmenu/btnCollapse")
        bObj["skip-navigation"] = "no"
        return
      }
    }

    bObj.text = ::loc("mainmenu/btnBack")
    bObj["skip-navigation"] = "no"
  }

  function isNavigationAllowed()
  {
    return !(currentState & decoratorEditState.EDITING)
  }

  function updateDecoratorActions(show, decoratorType)
  {
    local hintsObj = showSceneBtn("decals_hint", show)
    if (show && ::checkObj(hintsObj))
    {
      ::showBtnTable(hintsObj, {
        decals_hint_rotate = decoratorType.canRotate()
        decals_hint_resize = decoratorType.canResize()
      })
    }

    //Flip
    local showMirror = show && decoratorType.canMirror()
    showSceneBtn("btn_toggle_mirror", showMirror)
    //TwoSided
    local showAbsBf = show && decoratorType.canToggle()
    showSceneBtn("two_sided", showAbsBf)

    if (showMirror || showAbsBf)
      updateDecoratorActionBtnStates()
  }

  function updateDecoratorActionBtnStates()
  {
    // TwoSided
    local obj = scene.findObject("two_sided_select")
    if (::check_obj(obj))
      obj.setValue(getTwoSidedState())

    // Flip
    obj = scene.findObject("btn_toggle_mirror")
    if (::check_obj(obj))
    {
      local enabled = ::get_hangar_mirror_current_decal()
      local icon = "#ui/gameuiskin#btn_flip_decal" + (enabled ? "_active" : "") + ".svg"
      local iconObj = obj.findObject("btn_toggle_mirror_img")
      iconObj["background-image"] = icon
      iconObj.getParent().active = enabled ? "yes" : "no"
    }
  }

  function updateSlotsDivsVisibility(decoratorType = null)
  {
    local inBasicMode = currentState & decoratorEditState.NONE
    local showDecalsSlotDiv = access_Decals
      && (inBasicMode || (decoratorType == ::g_decorator_type.DECALS && (currentState & decoratorEditState.SELECT)))

    local showAttachableSlotsDiv = access_Attachables
      && (inBasicMode || (decoratorType == ::g_decorator_type.ATTACHABLES && (currentState & decoratorEditState.SELECT)))

    ::showBtnTable(scene, {
      decalslots_div = showDecalsSlotDiv
      attachable_div = showAttachableSlotsDiv
    })
  }

  function updateUnitStatus()
  {
    local obj = scene.findObject("unit_status")
    if (!::check_obj(obj))
      return
    local isShow = previewMode & (PREVIEW_MODE.UNIT | PREVIEW_MODE.SKIN)
    obj.show(isShow)
    if (!isShow)
      return
    obj.findObject("icon")["background-image"] = isUnitOwn ? "ui/gameuiskin#favorite" : "ui/gameuiskin#locked"
    local textObj = obj.findObject("text")
    textObj.setValue(::loc(isUnitOwn ? "conditions/unitExists" : "weaponry/unit_not_bought"))
    textObj.overlayTextColor = isUnitOwn ? "good" : "bad"
  }

  function updatePreviewedDecoratorInfo()
  {
    if (previewMode != PREVIEW_MODE.DECORATOR)
      return

    local isUnitAutoselected = initialUnitId && initialUnitId != unit?.name
    local obj = showSceneBtn("previewed_decorator_unit", isUnitAutoselected)
    if (obj && isUnitAutoselected)
      obj.findObject("label").setValue(::loc("decoratorPreview/autoselectedUnit", {
          previewUnit = ::colorize("activeTextColor", ::getUnitName(unit))
          hangarUnit  = ::colorize("activeTextColor", ::getUnitName(initialUnitId))
        }) + " " + ::loc("decoratorPreview/autoselectedUnit/desc", {
          preview       = ::loc("mainmenu/btnPreview")
          customization = ::loc("mainmenu/btnShowroom")
        }))

    obj = showSceneBtn("previewed_decorator", true)
    if (obj)
    {
      local txtApplyDecorator = ::loc("decoratorPreview/applyManually/" + currentType.resourceType)
      local labelObj = obj.findObject("label")
      labelObj.setValue(txtApplyDecorator + ::loc("ui/colon"))

      local params = { showAsTrophyContent = true }
      local view = { buttons = [ generateDecalButton("", decoratorPreview, currentType, params) ]}
      local slotsObj = obj.findObject("decorator_preview_div")
      local markup = ::handyman.renderCached("gui/commonParts/imageButton", view)
      guiScene.replaceContentFromText(slotsObj, markup, markup.len(), this)
    }
  }

  function onUpdate(obj, dt)
  {
    showLoadingRot(!::hangar_is_loaded())
  }

  function getCurrentDecoratorSlot(decoratorType)
  {
    if (decoratorType == ::g_decorator_type.UNKNOWN)
      return -1

    if (decoratorType == ::g_decorator_type.ATTACHABLES)
      return curAttachSlot

    return curSlot
  }

  function setCurrentDecoratorSlot(slotIdx, decoratorType)
  {
    if (decoratorType == ::g_decorator_type.DECALS)
      curSlot = slotIdx
    else if (decoratorType == ::g_decorator_type.ATTACHABLES)
      curAttachSlot = slotIdx
  }

  function onSkinOptionSelect(obj)
  {
    if (!::checkObj(scene))
      return

    updateButtons()
  }

  function onDecalSlotSelect(obj)
  {
    if (!::checkObj(obj))
      return

    local slotId = obj.getValue()

    setCurrentDecoratorSlot(slotId, ::g_decorator_type.DECALS)
    updateButtons(::g_decorator_type.DECALS)
  }

  function onDecalSlotActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (::check_obj(childObj))
      onDecalSlotClick(childObj)
  }

  function onAttachSlotSelect(obj)
  {
    if (!::checkObj(obj))
      return

    local slotId = obj.getValue()

    setCurrentDecoratorSlot(slotId, ::g_decorator_type.ATTACHABLES)
    updateButtons(::g_decorator_type.ATTACHABLES)
  }

  function onAttachableSlotActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (!::checkObj(childObj))
      return

    onAttachableSlotClick(childObj)
  }

  function onDecalSlotCancel(obj)
  {
    onBtnBack()
  }

  function openDecorationsListForSlot(slotId, actionObj, decoratorType)
  {
    if (!checkCurrentUnit())
      return
    if (!checkCurrentSkin())
      return
    if (!checkSlotIndex(slotId, decoratorType))
      return

    local prevSlotId = actionObj.getParent().getValue()
    if (isDecoratorsListOpen && slotId == prevSlotId)
      return

    setCurrentDecoratorSlot(slotId, decoratorType)
    currentState = decoratorEditState.SELECT

    if (prevSlotId != slotId)
      actionObj.getParent().setValue(slotId)
    else
      updateButtons(decoratorType)

    local slot = getSlotInfo(slotId, false, decoratorType)
    if (!slot.isEmpty && decoratorType != ::g_decorator_type.ATTACHABLES
                      && decoratorType != ::g_decorator_type.DECALS)
      decoratorType.specifyEditableSlot(slotId)

    generateDecorationsList(slot, decoratorType)
  }

  function checkCurrentUnit()
  {
    if (isUnitOwn)
      return true

    local onOkFunc = function() {}
    if (::canBuyUnit(unit))
      onOkFunc = (@(unit) function() { ::buyUnit(unit) })(unit)

    msgBox("unit_locked", ::loc("decals/needToBuyUnit"), [["ok", onOkFunc ]], "ok")
    return false
  }

  function checkCurrentSkin()
  {
    if (::u.isEmpty(previewSkinId) || !skinList)
      return true

    local skinIndex = ::find_in_array(skinList.values, previewSkinId, 0)
    local skinDecorator = skinList.decorators[skinIndex]

    if (skinDecorator.canBuyUnlock(unit))
    {
      local cost = skinDecorator.getCost()
      local priceText = cost.getTextAccordingToBalance()
      local msgText = ::warningIfGold(
        ::loc("decals/needToBuySkin",
          {purchase = skinDecorator.getName(), cost = priceText}),
        skinDecorator.getCost())
      msgBox("skin_locked", msgText,
        [["ok", (@(previewSkinId) function() { buySkin(previewSkinId, cost) })(previewSkinId) ],
        ["cancel", function() {} ]], "ok")
    }
    else
      msgBox("skin_locked", ::loc("decals/skinLocked"), [["ok", function() {} ]], "ok")
    return false
  }

  function checkSlotIndex(slotIdx, decoratorType)
  {
    if (slotIdx < 0)
      return false

    if (slotIdx < decoratorType.getAvailableSlots(unit))
      return true

    if (::has_feature("EnablePremiumPurchase"))
    {
      msgBox("no_premium", ::loc("decals/noPremiumAccount"),
           [["ok", function()
            {
               onOnlineShopPremium()
               saveDecorators(true)
            }],
           ["cancel", function() {} ]], "ok")
    }
    else
    {
      msgBox("premium_not_available", ::loc("charServer/notAvailableYet"),
           [["cancel"]], "cancel")
    }
    return false
  }

  function onAttachableSlotClick(obj)
  {
    if (!::checkObj(obj))
      return

    local slotName = ::getObjIdByPrefix(obj, "slot_attach_")
    local slotId = slotName ? slotName.tointeger() : -1

    openDecorationsListForSlot(slotId, obj, ::g_decorator_type.ATTACHABLES)
  }

  function onDecalSlotClick(obj)
  {
    local slotName = ::getObjIdByPrefix(obj, "slot_")
    local slotId = slotName ? slotName.tointeger() : -1
    openDecorationsListForSlot(slotId, obj, ::g_decorator_type.DECALS)
  }

  function onDecalSlotDoubleClick(obj)
  {
    onDecoratorSlotDoubleClick(::g_decorator_type.DECALS)
  }

  function onAttachableSlotDoubleClick(obj)
  {
    onDecoratorSlotDoubleClick(::g_decorator_type.ATTACHABLES)
  }

  function onDecoratorSlotDoubleClick(decoratorType)
  {
    local slotIdx = getCurrentDecoratorSlot(decoratorType)
    local slotInfo = getSlotInfo(slotIdx, false, decoratorType)
    if (slotInfo.isEmpty)
      return

    local decorator = ::g_decorator.getDecorator(slotInfo.decalId, decoratorType)
    currentState = decoratorEditState.REPLACE
    enterEditDecalMode(slotIdx, decorator)
  }

  function generateDecorationsList(slot, decoratorType)
  {
    if (::u.isEmpty(slot)
        || decoratorType == ::g_decorator_type.UNKNOWN
        || (currentState & decoratorEditState.NONE))
      return

    local wObj = scene.findObject("decals_list")
    if (!::checkObj(wObj))
      return

    currentType = decoratorType

    local decCategories = ::g_decorator.getCachedOrderByType(decoratorType, unit.unitType.tag)
    local view = { collapsableBlocks = [] }
    foreach (idx, category in decCategories)
      view.collapsableBlocks.append({
        id = decoratorType.categoryWidgetIdPrefix + category
        headerText = "#" + decoratorType.categoryPathPrefix + category
        type = "decoratorsList"
        onSelect = "onDecoratorItemSelect"
        onActivate = "onDecoratorItemActivate"
        onHoverChange = "onDecoratorsListHoverChange"
        contentParams = "on_wrap_up:t='onDecalItemHeader'; on_wrap_down:t='onDecalItemNextHeader';"
      })

    local data = ::handyman.renderCached("gui/commonParts/collapsableBlock", view)
    guiScene.replaceContentFromText(wObj, data, data.len(), this)

    showDecoratorsList()

    local selCategoryId = ""
    if (preSelectDecorator)
      selCategoryId = preSelectDecorator.category
    else if (slot.isEmpty)
      selCategoryId = ::loadLocalByAccount(decoratorType.currentOpenedCategoryLocalSafePath, "")
    else
    {
      local decal = ::g_decorator.getDecorator(slot.decalId, decoratorType)
      selCategoryId = decal ? decal.category : ""
    }

    if (selCategoryId != "")
    {
      local idx = decCategories.indexof(selCategoryId) ?? -1
      if (idx >= 0)
        wObj.setValue(idx)
      else
        updateButtons(decoratorType)
    }
    else
      updateButtons(decoratorType)
  }

  function generateDecalCategoryContent(categoryId, decoratorType)
  {
    local curSlotDecalId = getSlotInfo(getCurrentDecoratorSlot(decoratorType), false, decoratorType).decalId
    local decoratorsData = ::g_decorator.getCachedDecoratorsDataByType(decoratorType, unit.unitType.tag)

    if (!(categoryId in decoratorsData))
      return ""

    local view = { buttons = [] }
    foreach (decorator in decoratorsData[categoryId])
      view.buttons.append(generateDecalButton(curSlotDecalId, decorator, decoratorType))

    if (!view.buttons.len())
      return ""

    return ::handyman.renderCached("gui/commonParts/imageButton", view)
  }

  function generateDecalButton(curSlotDecalId, decorator, decoratorType, params = null)
  {
    local isTrophyContent = params?.showAsTrophyContent ?? false
    local isUnlocked = decorator.canUse(unit)
    local lockCountryImg = ::get_country_flag_img("decal_locked_" + ::getUnitCountry(unit))
    local unitLocked = decorator.getUnitTypeLockIcon()
    local cost = decorator.canBuyUnlock(unit) ? decorator.getCost().getTextAccordingToBalance()
      : decorator.canBuyCouponOnMarketplace(unit) ? ::colorize("warningTextColor", ::loc("currency/gc/sign"))
      : null
    local statusLock = !isTrophyContent ? getStatusLockText(decorator)
      : isUnlocked || cost != null ? null
      : "achievement"
    local leftAmount = decorator.limit - decorator.getCountOfUsingDecorator(unit)

    return {
      id = "decal_" + decorator.id
      highlighted = decorator.id == curSlotDecalId
      onClick = "onDecoratorItemClick"
      onDblClick = "onDecalItemDoubleClick"
      ratio = ::clamp(decoratorType.getRatio(decorator), 1, 2)
      unlocked = isUnlocked
      image = decoratorType.getImage(decorator)
      tooltipId = ::g_tooltip_type.DECORATION.getTooltipId(decorator.id, decoratorType.unlockedItemType)
      rarityColor = decorator.isRare() ? decorator.getRarityColor() : null
      leftBottomButtonCb = isCollectionItem(decorator) ? "onCollectionIconClick" : null
      leftBottomButtonImg = "#ui/gameuiskin#collection.svg"
      leftBottomButtonTooltip = "#collection/go_to_collection"
      leftBottomButtonHolderId = decorator.id
      cost = cost
      statusLock = statusLock
      unitLocked = unitLocked
      leftAmount = leftAmount
      limit = decorator.limit
      isMax = leftAmount <= 0
      showLimit = !isTrophyContent && decorator.limit > 0 && !statusLock && !cost && !unitLocked
      lockCountryImg = lockCountryImg
    }
  }

  function getStatusLockText(decorator)
  {
    if (!decorator)
      return null

    if (decorator.canUse(unit))
      return null

    if (decorator.isLockedByCountry(unit))
      return "country"

    if (decorator.isLockedByUnit(unit))
      return "achievement"

    if (decorator.lockedByDLC)
      return "noDLC"

    if (!decorator.isUnlocked() && !decorator.canBuyUnlock(unit) && !decorator.canBuyCouponOnMarketplace(unit))
      return "achievement"

    return null
  }

  function showDecoratorAccessRestriction(decorator)
  {
    if (!decorator || decorator.canUse(unit))
      return false

    local text = []
    if (decorator.isLockedByCountry(unit))
      text.append(::loc("mainmenu/decalNotAvailable"))

    if (decorator.isLockedByUnit(unit))
    {
      local unitsList = []
      foreach(unitName in decorator.units)
        unitsList.append(::colorize("userlogColoredText", ::getUnitName(unitName)))
      text.append(::loc("mainmenu/decoratorAvaiblableOnlyForUnit", {
        decoratorName = ::colorize("activeTextColor", decorator.getName()),
        unitsList = ::g_string.implode(unitsList, ",")}))
    }

    if (decorator.lockedByDLC != null)
      text.append(::format(::loc("mainmenu/decalNoCampaign"), ::loc("charServer/entitlement/" + decorator.lockedByDLC)))

    if (text.len() != 0)
    {
      ::g_popups.add("", ::g_string.implode(text, ", "))
      return true
    }

    if (decorator.isUnlocked() || decorator.canBuyUnlock(unit) || decorator.canBuyCouponOnMarketplace(unit))
      return false

    if (hasAvailableCollections() && isCollectionPrize(decorator))
    {
      ::g_popups.add(
        null,
        ::loc("mainmenu/decoratorNoCompletedCollection" {
          decoratorName = ::colorize("activeTextColor", decorator.getName())
        }),
        null,
        [{
          id = "gotoCollection"
          text = ::loc("collection/go_to_collection")
          func = @() openCollectionsWnd({ selectedDecoratorId = decorator.id })
        }])
      return true
    }

    ::g_popups.add("", ::loc("mainmenu/decalNoAchievement"))
    return true
  }

  function onCollectionIconClick(obj)
  {
    openCollectionsWnd({ selectedDecoratorId = obj.holderId })
    updateBackButton()
  }

  function onCollectionButtonClick()
  {
    local selectedDecorator = getSelectedDecal(currentType)
    if (!isCollectionItem(selectedDecorator))
      return

    openCollectionsWnd({ selectedDecoratorId = selectedDecorator.id })
    updateBackButton()
  }

  function onDecoratorItemSelect(obj)
  {
    updateButtons(null, false)
  }

  function onDecoratorsListHoverChange()
  {
    updateBackButton()
  }

  function getSelectedDecal(decoratorType)
  {
    local listObj = getCurCategoryListObj()
    if (!::checkObj(listObj))
      return null

    local value = listObj.getValue()
    local decalObj = (value >= 0 && value < listObj.childrenCount()) ? listObj.getChild(value) : null
    return getDecalInfoByObj(decalObj, decoratorType)
  }

  function getDecalInfoByObj(obj, decoratorType)
  {
    if (!::checkObj(obj))
      return null

    local decalId = ::getObjIdByPrefix(obj, "decal_") || ""

    return ::g_decorator.getDecorator(decalId, decoratorType)
  }

  function onDecoratorItemActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    onDecoratorItemClick(childObj)
  }

  function collapseOpenedCategory() {
    local wObj = scene.findObject("decals_list")
    if (!::check_obj(wObj))
      return
    local prevValue = wObj.getValue()
    wObj.setValue(-1)
    updateBackButton()
    guiScene.applyPendingChanges(false)
    if (::show_console_buttons)
      ::move_mouse_on_child(wObj, prevValue)
  }

  function moveMouseOnDecalsHeader(valueDiff = 0) {
    local wObj = scene.findObject("decals_list")
    if (!::check_obj(wObj))
      return false
    local newValue = wObj.getValue() + valueDiff
    if (newValue < 0 || wObj.childrenCount() <= newValue)
      return false
    ::move_mouse_on_child(wObj.getChild(newValue), 0)
    return true
  }

  onDecalItemHeader = @(obj) moveMouseOnDecalsHeader()

  function onDecalItemNextHeader(obj) {
    if (!moveMouseOnDecalsHeader(1))
      ::set_dirpad_event_processed(false)
  }

  function onDecoratorItemClick(obj)
  {
    local decorator = getDecalInfoByObj(obj, currentType)
    if (!decorator)
      return

    local decoratorsListObj = obj.getParent()
    if (decoratorsListObj.getValue() != decorator.catIndex)
      decoratorsListObj.setValue(decorator.catIndex)

    if (!decoratorPreview && decorator.isOutOfLimit(unit))
      return ::g_popups.add("", ::loc("mainmenu/decoratorExceededLimit", {limit = decorator.limit}))

    local curSlotIdx = getCurrentDecoratorSlot(currentType)
    local isDecal = currentType == ::g_decorator_type.DECALS
    if (!decoratorPreview && isDecal)
    {
      local isRestrictionShown = showDecoratorAccessRestriction(decorator)
      if (isRestrictionShown)
        return

      if (decorator.canBuyUnlock(unit))
        return askBuyDecorator(decorator, (@(curSlotIdx, decorator) function() {
                                            enterEditDecalMode(curSlotIdx, decorator)
                                          })(curSlotIdx, decorator))

      if (decorator.canBuyCouponOnMarketplace(unit))
        return askMarketplaceCouponAction(decorator)

      if (!decorator.isUnlocked())
        return
    }

    isDecoratorItemUsed = true

    if (!decoratorPreview && isDecal)
    {
      //getSlotInfo is too slow for decals (~150ms)(because of code func hangar_get_decal_in_slot),
      // so it better to use as last check, so not to worry with lags
      local slotInfo = getSlotInfo(curSlotIdx, false, currentType)
      if (!slotInfo.isEmpty && decorator.id != slotInfo.decalId)
      {
        currentState = decoratorEditState.REPLACE
        currentType.replaceDecorator(curSlotIdx, decorator.id)
        return installDecorationOnUnit(decorator)
      }
    }

    currentState = decoratorEditState.ADD
    enterEditDecalMode(curSlotIdx, decorator)
  }

  function onDecalItemDoubleClick(obj)
  {
    if (!checkObj(obj))
      return

    local decalId = ::getObjIdByPrefix(obj, "decal_") || ""

    local decal = ::g_decorator.getDecorator(decalId, currentType)
    if (!decal)
      return

    if (!decal.canUse(unit))
      return

    local slotIdx = getCurrentDecoratorSlot(currentType)
    local slotInfo = getSlotInfo(slotIdx, false, currentType)
    if (!slotInfo.isEmpty)
      enterEditDecalMode(slotIdx, decal)
  }

  function onDecalCategoryActivate(obj)
  {
    local value = obj.getValue()
    local childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (::checkObj(childObj))
      fillDecalCategoryContent(childObj)
  }

  function fillDecalCategoryContent(obj)
  {
    fillDecalsCategoryContentImpl(currentType)
  }

  function fillDecalsCategoryContentImpl(decoratorType)
  {
    local wObj = scene.findObject("decals_list")
    if (!::checkObj(wObj))
      return
    local idx = wObj.getValue()
    if (idx < 0)
      return

    local categoriesOrder = ::g_decorator.getCachedOrderByType(decoratorType, unit.unitType.tag)
    local category = categoriesOrder[idx]
    local categoryBlockId = decoratorType.categoryWidgetIdPrefix + category
    local categoryObj = wObj.findObject(categoryBlockId)
    if (!::checkObj(categoryObj))
      return

    local decalsListObj = categoryObj.findObject("collapse_content_" + categoryBlockId)
    if (!::checkObj(decalsListObj))
      return

    local data = generateDecalCategoryContent(category, decoratorType)
    guiScene.replaceContentFromText(decalsListObj, data, data.len(), this)

    ::saveLocalByAccount(decoratorType.currentOpenedCategoryLocalSafePath, category)

    local decalId = preSelectDecorator ? preSelectDecorator.id :
      getSlotInfo(getCurrentDecoratorSlot(decoratorType), false, decoratorType).decalId
    local decal = ::g_decorator.getDecorator(decalId, decoratorType)
    local index = decal && decal.category == category? decal.catIndex : 0
    editableDecoratorId = decal? decalId : null

    decalsListObj.setValue(index)
    scrollDecalsCategory(category, decoratorType)
    guiScene.applyPendingChanges(false)
    ::move_mouse_on_child_by_value(decalsListObj)
  }

  function scrollDecalsCategory(categoryId, decoratorType)
  {
    if (!categoryId)
      return

    local categoryBlockId = decoratorType.categoryWidgetIdPrefix + categoryId
    local categoryObj = scene.findObject(categoryBlockId)
    if (!::check_obj(categoryObj))
      return

    local headerObj = categoryObj.findObject("btn_" + categoryBlockId)
    if (::check_obj(headerObj))
      headerObj.scrollToView(true)

    local decalsListObj = categoryObj.findObject("collapse_content_" + categoryBlockId)
    local index = (::checkObj(decalsListObj) && decalsListObj.childrenCount()) ? decalsListObj.getValue() : -1
    local itemObj = (index >= 0) ? decalsListObj.getChild(index) : null
    if (::checkObj(itemObj))
      itemObj.scrollToView()
  }

  function onBtnAccept()
  {
    stopDecalEdition(true)
  }

  function onBtnBack()
  {
    if (currentState & decoratorEditState.NONE)
      return goBack()

    if (currentState & decoratorEditState.SELECT)
    {
      local listObj = getCurCategoryListObj()
      if (listObj?.isValid() && listObj.isHovered())
        return collapseOpenedCategory()

      return onBtnCloseDecalsMenu()
    }

    editableDecoratorId = null
    if (currentType == ::g_decorator_type.ATTACHABLES
        && (currentState & (decoratorEditState.REPLACE | decoratorEditState.EDITING | decoratorEditState.PURCHASE)))
      ::hangar_force_reload_model()
    stopDecalEdition()
  }

  function buyDecorator(decorator, cost, afterPurchDo = null)
  {
    if (!::check_balance_msgBox(decorator.getCost()))
      return false

    decorator.decoratorType.save(unit.name, false)

    local afterSuccessFunc = ::Callback((@(decorator, afterPurchDo) function() {
      ::update_gamercards()
      updateSelectedCategory(decorator)
      if (afterPurchDo)
        afterPurchDo()
    })(decorator, afterPurchDo), this)

    decorator.decoratorType.buyFunc(unit.name, decorator.id, cost, afterSuccessFunc)
    return true
  }

  function updateSelectedCategory(decorator)
  {
    if (!isDecoratorsListOpen)
      return

    local categoryBlockId = decorator.decoratorType.categoryWidgetIdPrefix + decorator.category
    local categoryObj = getObj(categoryBlockId)

    if (!::checkObj(categoryObj) || categoryObj.isVisible())
      return

    local decalsListObj = categoryObj.findObject("collapse_content_" + categoryBlockId)
    if (::checkObj(decalsListObj))
    {
      local data = generateDecalCategoryContent(decorator.category, decorator.decoratorType)
      guiScene.replaceContentFromText(decalsListObj, data, data.len(), this)
      decalsListObj.getChild(decalsListObj.getValue()).selected = "yes"
    }
  }

  function enterEditDecalMode(slotIdx, decorator)
  {
    if ((currentState & decoratorEditState.EDITING) || !decorator)
      return

    local decoratorType = decorator.decoratorType
    decoratorType.specifyEditableSlot(slotIdx)

    if (!decoratorType.enterEditMode(decorator.id))
      return

    currentState = decoratorEditState.EDITING
    editableDecoratorId = decorator.id
    updateSceneOnEditMode(true, decoratorType)
  }

  function updateSceneOnEditMode(isInEditMode, decoratorType, contentUpdate = false)
  {
    if (decoratorType == ::g_decorator_type.DECALS)
      ::dmViewer.update()

    local slotInfo = getSlotInfo(getCurrentDecoratorSlot(decoratorType), true, decoratorType)
    if (contentUpdate)
    {
      updateSlotsBlockByType(decoratorType)
      if (isDecoratorItemUsed)
        generateDecorationsList(slotInfo, decoratorType)
    }

    showDecoratorsList()

    updateButtons(decoratorType)

    if (!isInEditMode)
      isDecoratorItemUsed = false
  }

  function stopDecalEdition(save = false)
  {
    if (!(currentState & decoratorEditState.EDITING))
      return

    local decorator = g_decorator.getDecorator(editableDecoratorId, currentType)

    if (previewMode & PREVIEW_MODE.DECORATOR)
      return setDecoratorInSlot(decorator)

    if (!save || !decorator)
    {
      currentType.exitEditMode(false, false, ::Callback(afterStopDecalEdition, this))
      return
    }

    if (decorator.canBuyUnlock(unit))
      return askBuyDecoratorOnExitEditMode(decorator)

    if (decorator.canBuyCouponOnMarketplace(unit))
      return askMarketplaceCouponActionOnExitEditMode(decorator)

    local isRestrictionShown = showDecoratorAccessRestriction(decorator)
    if (isRestrictionShown)
      return

    setDecoratorInSlot(decorator)
  }

  function askBuyDecoratorOnExitEditMode(decorator)
  {
    if (!currentType.exitEditMode(true, false,
              ::Callback((@(decorator) function() {
                          askBuyDecorator(decorator, function()
                            {
                              ::hangar_save_current_attachables()
                            })
                        })(decorator), this)))
      showFailedInstallPopup()
  }

  function askMarketplaceCouponActionOnExitEditMode(decorator)
  {
    if (!currentType.exitEditMode(true, false,
              ::Callback(@() askMarketplaceCouponAction(decorator), this)))
      showFailedInstallPopup()
  }

  function askBuyDecorator(decorator, afterPurchDo = null)
  {
    local cost = decorator.getCost()
    local msgText = ::warningIfGold(
      ::loc("shop/needMoneyQuestion_purchaseDecal",
        {purchase = ::colorize("userlogColoredText", decorator.getName()),
          cost = cost.getTextAccordingToBalance()}),
      decorator.getCost())
    msgBox("buy_decorator_on_preview", msgText,
      [["ok", (@(decorator, afterPurchDo) function() {
          currentState = decoratorEditState.PURCHASE
          if (!buyDecorator(decorator, cost, afterPurchDo))
            return forceResetInstalledDecorators()

          ::dmViewer.update()
          onFinishInstallDecoratorOnUnit(true)
        })(decorator, afterPurchDo)],
      ["cancel", onBtnBack]
      ], "ok", { cancel_fn = onBtnBack })
  }

  function askMarketplaceCouponAction(decorator)
  {
    local inventoryItem = ::ItemsManager.getInventoryItemById(decorator.getCouponItemdefId())
    if (inventoryItem?.canConsume() ?? false)
    {
      inventoryItem.consume(::Callback(function(result) {
        if ((result?.success ?? false) == true)
          updateSelectedCategory(decorator)
      }, this), null)
      return
    }

    local couponItem = ::ItemsManager.findItemById(decorator.getCouponItemdefId())
    if (!(couponItem?.hasLink() ?? false))
      return
    local couponName = ::colorize("activeTextColor", couponItem.getName())
    msgBox("go_to_marketplace", ::loc("msgbox/find_on_marketplace", { itemName = couponName }), [
        [ "find_on_marketplace", function() { couponItem.openLink(); onBtnBack() } ],
        [ "cancel", onBtnBack ]
      ], "find_on_marketplace", { cancel_fn = onBtnBack })
  }

  function forceResetInstalledDecorators()
  {
    currentType.removeDecorator(getCurrentDecoratorSlot(currentType), true)
    if (currentType == ::g_decorator_type.ATTACHABLES)
    {
      ::hangar_force_reload_model()
    }
    afterStopDecalEdition()
  }

  function setDecoratorInSlot(decorator)
  {
    if (!installDecorationOnUnit(decorator))
      return showFailedInstallPopup()

    if (currentType == ::g_decorator_type.DECALS)
      ::req_unlock_by_client("decal_applied", false)
  }

  function showFailedInstallPopup()
  {
    ::g_popups.add("", ::loc("mainmenu/failedInstallAttachable"))
  }

  function afterStopDecalEdition()
  {
    currentState = isDecoratorsListOpen? decoratorEditState.SELECT : decoratorEditState.NONE
    updateSceneOnEditMode(false, currentType)
  }

  function installDecorationOnUnit(decorator)
  {
    local save = !!decorator && decorator.isUnlocked() && previewMode != PREVIEW_MODE.DECORATOR
    return currentType.exitEditMode(true, save,
      ::Callback( function () { onFinishInstallDecoratorOnUnit(true) }, this))
  }

  function onFinishInstallDecoratorOnUnit(isInstalled = false)
  {
    if (!isInstalled)
      return

    currentState = isDecoratorsListOpen? decoratorEditState.SELECT : decoratorEditState.NONE
    updateSceneOnEditMode(false, currentType, true)
  }

  function onOnlineShopEagles()
  {
    if (::has_feature("EnableGoldPurchase"))
      startOnlineShop("eagles", afterReplenishCurrency, "customization")
    else
      ::showInfoMsgBox(::loc("msgbox/notAvailbleGoldPurchase"))
  }

  function onOnlineShopLions()
  {
    startOnlineShop("warpoints", afterReplenishCurrency)
  }

  function onOnlineShopPremium()
  {
    startOnlineShop("premium", checkPremium)
  }

  function checkPremium()
  {
    if (!::havePremium())
      return

    ::update_gamercards()
    updateMainGuiElements()
  }

  function afterReplenishCurrency()
  {
    if (!::checkObj(scene))
      return

    updateMainGuiElements()
  }

  function onSkinChange(obj)
  {
    local skinNum = obj.getValue()
    if (!skinList || !(skinNum in skinList.values))
    {
      ::callstack()
      ::dagor.assertf(false, "Error: try to set incorrect skin " + skinList + ", value = " + skinNum)
      return
    }

    local skinId = skinList.values[skinNum]
    local access = skinList.access[skinNum]

    if (isUnitOwn && access.isOwn && !previewMode)
    {
      local curSkinId = ::hangar_get_last_skin(unit.name)
      if (!previewSkinId && (skinId == curSkinId || (skinId == "" && curSkinId == "default")))
        return

      resetUserSkin(false)
      applySkin(skinId)
    }
    else if (access.isDownloadable)
    {
      // Starting skin download...
      contentPreview.showResource(skinId, "skin", ::Callback(onSkinReadyToShow, this))
    }
    else if (skinId != previewSkinId)
    {
      resetUserSkin(false)
      applySkin(skinId, true)
    }
  }

  function onSkinReadyToShow(unitId, skinId, result)
  {
    if (!result || !contentPreview.canStartPreviewScene(true, true) ||
      unitId != unit.name || (skinList?.values ?? []).indexof(skinId) == null)
        return

    ::g_decorator.previewedLiveSkinIds.append($"{unitId}/{skinId}")
    ::g_delayed_actions.add(::Callback(function() {
      resetUserSkin(false)
      applySkin(skinId, true)
    }, this), 100)
  }

  function onUserSkinChanged(obj)
  {
    local value = obj.getValue()
    local prevValue = ::get_option(::USEROPT_USER_SKIN).value
    if (prevValue == value)
      return

    ::set_option(::USEROPT_USER_SKIN, value)
    ::hangar_force_reload_model()
  }

  function resetUserSkin(needReloadModel = true)
  {
    if (previewMode)
      return

    initialUserSkinId = ""
    ::set_option(::USEROPT_USER_SKIN, 0)

    if (needReloadModel)
      ::hangar_force_reload_model()
    else
      updateUserSkinList()
  }

  function applySkin(skinId, previewSkin = false)
  {
    if (previewSkin)
      ::hangar_apply_skin_preview(skinId)
    else
    {
      ::g_decorator.setLastSkin(unit.name, skinId, false)
      ::hangar_apply_skin(skinId)
    }

    previewSkinId = previewSkin? skinId : null

    if (!previewSkin)
    {
      ::save_online_single_job(3210)
      ::save_profile(false)
    }
  }

  function setDmgSkinMode(enable)
  {
    local cObj = scene.findObject("btn_toggle_damaged")
    if (::checkObj(cObj))
      cObj.setValue(enable)
  }

  function onToggleDmgSkinState(obj)
  {
    ::hangar_show_model_damaged(obj.getValue() ? 1:0)
  }

  function onToggleDamaged(obj)
  {
    if (unit.isAir() || unit.isHelicopter())
    {
      ::hangar_set_dm_viewer_mode(obj.getValue() ? ::DM_VIEWER_EXTERIOR : ::DM_VIEWER_NONE)
      if (obj.getValue())
      {
        local bObj = scene.findObject("dmg_skin_state")
        if (::checkObj(bObj))
          bObj.setValue(::hangar_get_loaded_model_damage_state(unit.name))
      }
      else
        ::hangar_show_model_damaged(MDS_ORIGINAL)
    }
    else
      ::hangar_show_model_damaged(obj.getValue() ? MDS_DAMAGED : MDS_UNDAMAGED)

    updateButtons()
  }

  function onBuySkin()
  {
    local skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
    local previewSkinDecorator = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
    if (!previewSkinDecorator)
      return

    local cost = previewSkinDecorator.getCost()
    local msgText = ::warningIfGold(::loc("shop/needMoneyQuestion_purchaseSkin",
                          { purchase = previewSkinDecorator.getName(),
                            cost = cost.getTextAccordingToBalance()
                          }), cost)

    msgBox("need_money", msgText,
          [["ok", (@(previewSkinId, cost) function() {
            if (::check_balance_msgBox(cost))
              buySkin(previewSkinId, cost)
          })(previewSkinId, cost)],
          ["cancel", function() {} ]], "ok")
  }

  function buySkin(skinName, cost)
  {
    local afterSuccessFunc = ::Callback((@(skinName) function() {
        ::update_gamercards()
        applySkin(skinName)
        updateMainGuiElements()
      })(skinName), this)

    ::g_decorator_type.SKINS.buyFunc(unit.name, skinName, cost, afterSuccessFunc)
  }

  function onBtnMarketplaceFindSkin(obj)
  {
    local skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
    local skinDecorator = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
    local item = ::ItemsManager.findItemById(skinDecorator?.getCouponItemdefId())
    if (!item?.hasLink())
      return
    item.openLink()
  }

  function onBtnMarketplaceConsumeCouponSkin(obj)
  {
    local skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
    local skinDecorator = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
    local itemdefId = skinDecorator?.getCouponItemdefId()
    local inventoryItem = ::ItemsManager.getInventoryItemById(itemdefId)
    if (!inventoryItem?.canConsume())
      return

    local skinName = previewSkinId
    inventoryItem.consume(::Callback(function(result) {
      if (this == null || !result?.success)
        return
      applySkin(skinName)
      updateMainGuiElements()
    }, this), null)
  }

  function getSlotInfo(slotId, checkDecalsList = false, decoratorType = null)
  {
    local isValid = 0 <= slotId
    local decalId = ""
    if (checkDecalsList && isDecoratorsListOpen && slotId == getCurrentDecoratorSlot(decoratorType))
    {
      local decal = getSelectedDecal(decoratorType)
      if (decal)
        decalId = decal.id
    }

    if (decalId == "" && isValid && decoratorType != null)
    {
      local liveryName = getSelectedBuiltinSkinId()
      decalId = decoratorType.getDecoratorNameInSlot(slotId, unit.name, liveryName, false)
      isValid = isValid && slotId < decoratorType.getMaxSlots()
    }

    return {
      id = isValid ? slotId : -1
      unlocked = isValid && slotId < decoratorType.getAvailableSlots(unit)
      decalId = decalId
      isEmpty = !decalId.len()
    }
  }

  function showLoadingRot(flag)
  {
    if (isLoadingRot == flag)
      return

    isLoadingRot = flag
    scene.findObject("loading_rot").show(flag)

    updateMainGuiElements()
  }

  function onTestFlight()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true }))
      return

    // TestFlight wnd can have a Slotbar, where unit can be changed.
    local afterCloseFunc = (@(owner, unit) function() {
      local newUnitName = ::get_show_aircraft_name()
      if (unit.name != newUnitName)
      {
        owner.unit = ::getAircraftByName(newUnitName)
        owner.previewSkinId = null
        if (owner && ("initMainParams" in owner) && owner.initMainParams)
          owner.initMainParams.call(owner)
      }
    })(owner, unit)

    saveDecorators(false)
    checkedNewFlight(function() {
      ::gui_start_testflight(unit, afterCloseFunc)
    })
  }

  function onBuy()
  {
    unitActions.buy(unit, "customization")
  }

  function onBtnMarketplaceFindUnit(obj)
  {
    local item = ::ItemsManager.findItemById(unit.marketplaceItemdefId)
    if (!(item?.hasLink() ?? false))
      return
    item.openLink()
  }

  function onEventUnitBought(params)
  {
    initMainParams()
  }

  function onEventUnitRented(params)
  {
    initMainParams()
  }

  function onBtnDecoratorEdit()
  {
    currentType = getCurrentFocusedType()
    local curSlotIdx = getCurrentDecoratorSlot(currentType)
    local slotInfo = getSlotInfo(curSlotIdx, true, currentType)
    local decorator = ::g_decorator.getDecorator(slotInfo.decalId, currentType)
    enterEditDecalMode(curSlotIdx, decorator)
  }

  function onBtnDeleteDecal()
  {
    local decoratorType = getCurrentFocusedType()
    deleteDecorator(decoratorType, getCurrentDecoratorSlot(decoratorType))
  }

  function onDeleteDecal(obj)
  {
    if (!::checkObj(obj))
      return

    local slotName = ::getObjIdByPrefix(obj.getParent(), "slot_")
    local slotId = slotName.tointeger()

    deleteDecorator(::g_decorator_type.DECALS, slotId)
  }

  function onDeleteAttachable(obj)
  {
    if (!::checkObj(obj))
      return

    local slotName = ::getObjIdByPrefix(obj.getParent(), "slot_attach_")
    local slotId = slotName.tointeger()

    deleteDecorator(::g_decorator_type.ATTACHABLES, slotId)
  }

  function deleteDecorator(decoratorType, slotId)
  {
    local slotInfo = getSlotInfo(slotId, false, decoratorType)
    msgBox("delete_decal", ::loc(decoratorType.removeDecoratorLocId, {name = decoratorType.getLocName(slotInfo.decalId)}),
    [
      ["ok", (@(decoratorType, slotInfo) function() {
          decoratorType.removeDecorator(slotInfo.id, true)
          ::save_profile(false)

          generateDecorationsList(slotInfo, decoratorType)
          updateSlotsBlockByType(decoratorType)
          updateButtons(decoratorType, false)
        })(decoratorType, slotInfo)
      ],
      ["cancel", function(){} ]
    ], "cancel")
  }

  function updateSlotsBlockByType(decoratorType = ::g_decorator_type.UNKNOWN)
  {
    local all = decoratorType == ::g_decorator_type.UNKNOWN
    if (all || decoratorType == ::g_decorator_type.ATTACHABLES)
      updateAttachablesSlots()

    if (all || decoratorType == ::g_decorator_type.DECALS)
      updateDecalSlots()

    updatePenaltyText()
  }

  function onDecorLayoutPresets(obj)
  {
    decorLayoutPresets.open(unit, getSelectedBuiltinSkinId())
  }

  function onWeaponsInfo(obj)
  {
    ::open_weapons_for_unit(unit)
  }

  function onSecWeaponsInfo(obj)
  {
    weaponryPresetsModal.open({ unit = unit })
  }

  function getTwoSidedState()
  {
    local isTwoSided = ::get_hangar_abs()
    local isOppositeMirrored = ::get_hangar_opposite_mirrored()
    return !isTwoSided ? decalTwoSidedMode.OFF
         : !isOppositeMirrored ? decalTwoSidedMode.ON
         : decalTwoSidedMode.ON_MIRRORED
  }

  function setTwoSidedState(idx)
  {
    local isTwoSided = ::get_hangar_abs()
    local isOppositeMirrored = ::get_hangar_opposite_mirrored()
    local needTwoSided  = idx != decalTwoSidedMode.OFF
    local needOppositeMirrored = idx == decalTwoSidedMode.ON_MIRRORED
    if (needTwoSided != isTwoSided)
      ::hangar_toggle_abs()
    if (needOppositeMirrored != isOppositeMirrored)
      ::set_hangar_opposite_mirrored(needOppositeMirrored)
  }

  function onMirror() // Flip
  {
    ::hangar_mirror_current_decal()
    updateDecoratorActionBtnStates()
  }

  function onTwoSided() // TwoSided
  {
    local obj = scene.findObject("two_sided_select")
    if (check_obj(obj))
      obj.setValue((obj.getValue() + 1) % obj.childrenCount())
  }

  function onTwoSidedSelect(obj) // TwoSided select
  {
    setTwoSidedState(obj.getValue())
  }

  function onInfo()
  {
    if (::has_feature("WikiUnitInfo"))
      openUrl(::format(::loc("url/wiki_objects"), unit.name), false, false, "customization_wnd")
    else
      ::showInfoMsgBox(::colorize("activeTextColor", ::getUnitName(unit, false)) + "\n" + ::loc("profile/wiki_link"))
  }

  function clearCurrentDecalSlotAndShow()
  {
    if (!::checkObj(scene))
      return

    updateSlotsBlockByType()
  }

  function saveDecorators(withProgressBox = false)
  {
    if (previewMode)
      return
    ::g_decorator_type.DECALS.save(unit.name, withProgressBox)
    ::g_decorator_type.ATTACHABLES.save(unit.name, withProgressBox)
  }

  function showDecoratorsList()
  {
    local show = !!(currentState & decoratorEditState.SELECT)

    isDecoratorsListOpen = show
    local slotsObj = scene.findObject(currentType.listId)
    if (::check_obj(slotsObj))
    {
      local sel = slotsObj.getValue()
      for (local i = 0; i < slotsObj.childrenCount(); i++)
      {
        local selectedItem = sel == i && show
        slotsObj.getChild(i).highlighted = selectedItem? "yes" : "no"
      }
    }

    ::hangar_notify_decal_menu_visibility(show)

    local mObj = scene.findObject("decals_wnd")
    if (!::check_obj(mObj))
      return

    mObj.show(show)

    local headerObj = mObj.findObject("decals_wnd_header")
    if (::check_obj(headerObj))
      headerObj.setValue(::loc(currentType.listHeaderLocId))
  }

  function onScreenClick()
  {
    if (currentState == decoratorEditState.NONE)
      return

    if (currentState == decoratorEditState.EDITING)
      return stopDecalEdition(true)

    local curSlotIdx = getCurrentDecoratorSlot(currentType)
    local curSlotInfo = getSlotInfo(curSlotIdx, false, currentType)
    if (curSlotInfo.isEmpty)
      return

    local curSlotDecoratorId = curSlotInfo.decalId
    if (curSlotDecoratorId == "")
      return

    local curSlotDecorator = ::g_decorator.getDecorator(curSlotDecoratorId, currentType)
    enterEditDecalMode(curSlotIdx, curSlotDecorator)
  }

  function onBtnCloseDecalsMenu()
  {
    currentState = decoratorEditState.NONE
    showDecoratorsList()
    currentType = ::g_decorator_type.UNKNOWN
    updateButtons()
  }

  function goBack()
  {
    ::g_decorator.clearLivePreviewParams()  // clear only when closed by player
    if (isValid())
      setDmgSkinMode(false)
    ::hangar_show_model_damaged(MDS_ORIGINAL)
    ::hangar_prem_vehicle_view_close()
    guiScene.performDelayed(this, base.goBack)
  }

  function onDestroy()
  {
    if (unit)
    {
      if (currentState & decoratorEditState.EDITING)
      {
        currentType.exitEditMode(false, false)
        currentType.specifyEditableSlot(-1)
      }

      if (previewSkinId)
      {
        applySkin(::hangar_get_last_skin(unit.name), true)
        previewSkinId = null
        if (initialUserSkinId != "")
          ::get_user_skins_profile_blk()[unit.name] = initialUserSkinId
      }

      if (previewMode)
      {
        ::hangar_force_reload_model()
      }
      else
      {
        saveDecorators(false)
        ::save_profile(true)
      }
    }
  }

  function onAirInfoToggleDMViewer(obj)
  {
    setDmgSkinMode(false)
    ::dmViewer.toggle(obj.getValue())
  }

  function getCurrentFocusedType()
  {
    if (scene.findObject("slots_list").isHovered())
      return ::g_decorator_type.DECALS
    if (scene.findObject("slots_attachable_list").isHovered())
      return ::g_decorator_type.ATTACHABLES
    return ::g_decorator_type.UNKNOWN
  }

  function canShowDmViewer()
  {
    return currentState && !(currentState & decoratorEditState.EDITING)
  }

  function updatePenaltyText()
  {
    local obj = scene.findObject("decal_text_area")
    if (!::check_obj(obj))
      return

    local txt = ""
    if (::is_decals_disabled())
    {
      local timeSec = ::get_time_till_decals_disabled()
      if (timeSec == 0)
      {
        local st = penalty.getPenaltyStatus()
        if ("seconds_left" in st)
          timeSec = st.seconds_left
      }

      if (timeSec == 0)
        txt = ::format(::loc("charServer/decal/permanent"))
      else
        txt = ::format(::loc("charServer/decal/timed"), time.hoursToString(time.secondsToHours(timeSec), false))
    }

    obj.setValue(txt)
  }

  function onEventBeforeStartTestFlight(params)
  {
    ::handlersManager.requestHandlerRestore(this, this.getclass())
  }

  function onEventItemsShopUpdate(params)
  {
    updateDecalSlots()
    updateAttachablesSlots()
    updateSkinList()
  }

  function initPreviewMode()
  {
    if (!previewParams)
      return
    if (::hangar_get_loaded_unit_name() == previewParams.unitName)
      removeAllDecorators(false)
    switch (previewMode)
    {
      case PREVIEW_MODE.UNIT:
      case PREVIEW_MODE.SKIN:
        local skinBlockName = previewParams.unitName + "/" + previewParams.skinName
        ::g_decorator.previewedLiveSkinIds.append(skinBlockName)
        if (initialUserSkinId != "")
          ::get_user_skins_profile_blk()[unit.name] = ""
        local isForApprove = previewParams?.isForApprove ?? false
        ::g_decorator.approversUnitToPreviewLiveResource = isForApprove ? ::show_aircraft : null
        ::g_delayed_actions.add(::Callback(function() {
          applySkin(previewParams.skinName, true)
        }, this), 100)
        break
      case PREVIEW_MODE.DECORATOR:
        decoratorPreview = previewParams.decorator
        currentType = decoratorPreview.decoratorType
        break
    }
  }

  function removeAllDecorators(save)
  {
    foreach (decoratorType in [ ::g_decorator_type.DECALS, ::g_decorator_type.ATTACHABLES ])
      for (local i = 0; i < decoratorType.getAvailableSlots(unit); i++)
      {
        local slot = getSlotInfo(i, false, decoratorType)
        if (!slot.isEmpty)
            decoratorType.removeDecorator(slot.id, save)
      }
  }

  function onEventActiveHandlersChanged(p)
  {
    if (!isSceneActiveNoModals())
      setDmgSkinMode(false)
  }

  function preSelectSlotAndDecorator(decorator, slotIdx)
  {
    local decoratorType = decorator.decoratorType
    if (decoratorType == ::g_decorator_type.SKINS)
    {
      if (unit.name == ::g_unlocks.getPlaneBySkinId(decorator.id))
        applySkin(::g_unlocks.getSkinNameBySkinId(decorator.id))
    }
    else
    {
      if (slotIdx != -1)
      {
        local listObj = scene.findObject(decoratorType.listId)
        if (::check_obj(listObj))
        {
          local slotObj = listObj.getChild(slotIdx)
          if (::check_obj(slotObj))
            openDecorationsListForSlot(slotIdx, slotObj, decoratorType)
        }
      }
    }
  }
}

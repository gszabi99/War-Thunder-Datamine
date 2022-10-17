from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let time = require("%scripts/time.nut")
let { acos, PI } = require("math")
let penalty = require("penalty")
let decorLayoutPresets = require("%scripts/customization/decorLayoutPresetsWnd.nut")
let unitActions = require("%scripts/unit/unitActions.nut")
let { showResource, canStartPreviewScene,
  showDecoratorAccessRestriction } = require("%scripts/customization/contentPreview.nut")
let { openUrl } = require("%scripts/onlineShop/url.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let weaponryPresetsModal = require("%scripts/weaponry/weaponryPresetsModal.nut")
let { canBuyNotResearched,
        isUnitHaveSecondaryWeapons } = require("%scripts/unit/unitStatus.nut")
let { DECORATION } = require("%scripts/utils/genericTooltipTypes.nut")
let decorMenuHandler = require("%scripts/customization/decorMenuHandler.nut")
let { getDecorLockStatusText, getDecorButtonView } = require("%scripts/customization/decorView.nut")
let { isPlatformPC } = require("%scripts/clientState/platform.nut")
let { canUseIngameShop, getShopItemsTable } = require("%scripts/onlineShop/entitlementsStore.nut")
let { needSecondaryWeaponsWnd } = require("%scripts/weaponry/weaponryInfo.nut")
let { isCollectionItem } = require("%scripts/collections/collections.nut")
let { openCollectionsWnd } = require("%scripts/collections/collectionsWnd.nut")
let { loadModel } = require("%scripts/hangarModelLoadManager.nut")
let { showedUnit, getShowedUnitName, setShowUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { needSuggestSkin, saveSeenSuggestedSkin } = require("%scripts/customization/suggestedSkins.nut")
let { getAxisTextOrAxisName } = require("%scripts/controls/controlsVisual.nut")

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
  let callback = getTblValue(taskId, ::g_decorator_type.DECALS.jobCallbacksStack, null)
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
    showedUnit(params.unit)
  else if (params?.unitId)
    showedUnit(::getAircraftByName(params?.unitId))

  if (!showedUnit.value
      ||
        ( ::hangar_get_loaded_unit_name() == showedUnit.value.name
        && !::is_loaded_model_high_quality()
        && !::check_package_and_ask_download("pkg_main"))
    )
    return

  params = params || {}
  params.backSceneFunc <- ::gui_start_mainmenu
  ::handlersManager.loadHandler(::gui_handlers.DecalMenuHandler, params)
}

::hangar_add_popup <- function hangar_add_popup(text) // called from client
{
  ::g_popups.add("", loc(text))
}

::delayed_download_enabled_msg <- function delayed_download_enabled_msg()
{
  if (!::g_login.isProfileReceived())
    return
  let skip = ::load_local_account_settings("skipped_msg/delayedDownloadContent", false)
  if (!skip)
  {
    ::gui_start_modal_wnd(::gui_handlers.SkipableMsgBox,
    {
      parentHandler = ::handlersManager.getActiveBaseHandler()
      message = loc("msgbox/delayedDownloadContent")
      ableToStartAndSkip = true
      startBtnText = loc("msgbox/confirmDelayedDownload")
      onStartPressed = function() {
        ::set_option_delayed_download_content(true)
        ::save_local_account_settings("delayDownloadContent", true)
      }
      cancelFunc = function(){
        ::set_option_delayed_download_content(false)
        ::save_local_account_settings("delayDownloadContent", false)
      }
      skipFunc = function(value) {
        ::save_local_account_settings("skipped_msg/delayedDownloadContent", value)
      }
    })
  }
  else
  {
    local choosenDDC = ::load_local_account_settings("delayDownloadContent", true)
    ::set_option_delayed_download_content(choosenDDC)
  }
}

::gui_handlers.DecalMenuHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/customization/customization.blk"
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

  decorMenu = null

  function initScreen()
  {
    owner = this
    unit = showedUnit.value
    if (!unit)
      return goBack()
    ::cur_aircraft_name = unit.name

    access_WikiOnline = hasFeature("WikiUnitInfo")
    access_UserSkins = isPlatformPC && hasFeature("UserSkins")
    access_SkinsUnrestrictedPreview = hasFeature("SkinsPreviewOnUnboughtUnits")
    access_SkinsUnrestrictedExport  = access_UserSkins && access_SkinsUnrestrictedExport

    initialAppliedSkinId   = ::hangar_get_last_skin(unit.name)
    initialUserSkinId      = ::get_user_skins_profile_blk()?[unit.name] ?? ""

    ::enableHangarControls(true)
    scene.findObject("timer_update").setUserData(this)

    ::hangar_focus_model(true)

    let unitInfoPanel = ::create_slot_info_panel(scene, false, "showroom")
    registerSubHandler(unitInfoPanel)
    unitInfoPanelWeak = unitInfoPanel.weakref()
    if (needForceShowUnitInfoPanel)
      unitInfoPanelWeak.uncollapse()

    decorMenu = decorMenuHandler(scene.findObject("decor_menu_container")).weakref()

    initPreviewMode()
    initMainParams()
    showDecoratorsList()

    updateDecalActionsTexts()

    loadModel(unit.name)

    if (!isUnitOwn && !previewMode)
    {
      let skinId = unit.getPreviewSkinId()
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
    return isInArray(currentState, [ decoratorEditState.NONE, decoratorEditState.SELECT ])
  }

  function getHandlerRestoreData()
  {
    let data = {
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

    let bObj = scene.findObject("btn_testflight")
    if (checkObj(bObj))
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
    local title = loc(isUnitOwn && !previewMode? "mainmenu/showroom" : "mainmenu/btnPreview") + " " + loc("ui/mdash") + " "
    if (!previewMode || (previewMode & (PREVIEW_MODE.UNIT | PREVIEW_MODE.SKIN)))
      title += ::getUnitName(unit.name)

    if (previewMode & PREVIEW_MODE.SKIN)
    {
      let skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
      let skin = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
      if (skin)
        title += loc("ui/comma") + loc("options/skin") + " " + colorize(skin.getRarityColor(), skin.getName())
    }
    else if (previewMode & PREVIEW_MODE.DECORATOR)
    {
      let typeText = loc("trophy/unlockables_names/" + decoratorPreview.decoratorType.resourceType)
      let nameText = colorize(decoratorPreview.getRarityColor(), decoratorPreview.getName())
      title += typeText + " " + nameText
    }

    setSceneTitle(title)
  }

  function updateDecalActionsTexts()
  {
    local bObj = null
    let hasKeyboard = isPlatformPC

    //Flip
    let btn_toggle_mirror_text = loc("decals/flip") + (hasKeyboard ? " (F)" : "")
    bObj = scene.findObject("btn_toggle_mirror")
    if(checkObj(bObj))
      bObj.setValue(btn_toggle_mirror_text)

    //TwoSided
    let text = loc("decals/twosided") + (hasKeyboard ? " (T)" : "") + loc("ui/colon")
    bObj = scene.findObject("two_sided_label")
    if(checkObj(bObj))
      bObj.setValue(text)

    //Size
    bObj = scene.findObject("push_to_change_size")
    if (bObj?.isValid() ?? false)
      bObj.setValue(getAxisTextOrAxisName("decal_scale"))

    //Rotate
    bObj = scene.findObject("push_to_rotate")
    if (bObj?.isValid() ?? false)
      bObj.setValue(getAxisTextOrAxisName("decal_rotate"))
  }

  function getSelectedBuiltinSkinId()
  {
    let res = previewSkinId || ::hangar_get_last_skin(unit.name)
    return res == "" ? "default" : res // hangar_get_last_skin() can return empty string.
  }

  function exportSampleUserSkin(obj)
  {
    if (!::hangar_is_loaded())
      return

    if (!::can_save_current_skin_template())
    {
      let message = format(loc("decals/noUserSkinForCurUnit"), ::getUnitName(unit.name))
      this.msgBox("skin_template_export", message, [["ok", function(){}]], "ok")
      return
    }

    let allowCurrentSkin = access_SkinsUnrestrictedExport // true - current skin, false - default skin.
    let success = ::save_current_skin_template(allowCurrentSkin)

    let templateName = "template_" + unit.name
    let message = success ? format(loc("decals/successfulLoadedSkinSample"), templateName) : loc("decals/failedLoadedSkinSample")
    this.msgBox("skin_template_export", message, [["ok", function(){}]], "ok")

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

  function switchUnit(unitName) {
    unit = ::getAircraftByName(unitName)
    if (unit == null) {
      ::script_net_assert_once("not found loaded model unit", "customization: not found unit after model loaded")
      return goBack()
    }
    ::cur_aircraft_name = unit.name
    initMainParams()
  }

  function onEventHangarModelLoaded(params = {})
  {
    if (previewMode)
      removeAllDecorators(false)

    let { modelName } = params
    if (modelName != unit.name)
      switchUnit(modelName)
    else
      updateMainGuiElements()
    if (::hangar_get_loaded_unit_name() == unit.name
        && !::is_loaded_model_high_quality())
      ::check_package_and_ask_download("pkg_main", null, null, this, "air_in_hangar", goBack)
  }

  function onEventDecalJobComplete(params)
  {
    let isInEditMode = currentState & decoratorEditState.EDITING
    if (isInEditMode && currentType == ::g_decorator_type.DECALS)
      updateDecoratorActionBtnStates()
  }

  function updateAutoSkin()
  {
    if (!access_Skins)
      return

    let isVisible = !previewMode && isUnitOwn && unit.unitType.isSkinAutoSelectAvailable()
    this.showSceneBtn("auto_skin_block", isVisible)
    if (!isVisible)
      return

    let autoSkinId = "auto_skin_control"
    let controlObj = scene.findObject(autoSkinId)
    if (checkObj(controlObj))
    {
      controlObj.setValue(::g_decorator.isAutoSkinOn(unit.name))
      return
    }

    let placeObj = scene.findObject("auto_skin_place")
    let markup = ::create_option_switchbox({
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
    let curSkinId = getSelectedBuiltinSkinId()
    let curSkinIndex = ::find_in_array(skinList.values, curSkinId, 0)
    let tooltipParams = previewMode ? { showAsTrophyContent = true } : null

    let skinItems = []
    foreach(i, decorator in skinList.decorators)
    {
      let access = skinList.access[i]
      let canBuy = !previewMode && decorator.canBuyUnlock(unit)
      let canFindOnMarketplace = !previewMode && decorator.canBuyCouponOnMarketplace(unit)
      let priceText = canBuy ? decorator.getCost().getTextAccordingToBalance() : ""
      let isUnlocked = decorator.isUnlocked()
      local text = skinList.items[i].text
      let image = skinList.items[i].image ?? ""
      let images = []
      if (image != "")
        images.append({ image, imageNoMargin = !isUnlocked })
      if (!isUnlocked)
        images.append({ image = "#ui/gameuiskin#locked.svg", imageNoMargin = true })

      if (canBuy)
        text = loc("ui/parentheses", {text = priceText}) + " " + text
      else if (canFindOnMarketplace)
        text = "".concat(loc("currency/gc/sign"), " ", text)

      if (!access.isVisible)
        text = colorize("comboExpandedLockedTextColor", "(" + loc("worldWar/hided_logs") + ") ") + text

      skinItems.append({
        text = text
        textStyle = skinList.items[i].textStyle
        addDiv = DECORATION.getMarkup(decorator.id, UNLOCKABLE_SKIN, tooltipParams)
        images
      })
    }

    renewDropright("skins_list", "skins_dropright", skinItems, curSkinIndex, "onSkinChange")
    updateSkinTooltip(curSkinId)
  }

  function updateSkinTooltip(skinId)
  {
    let tooltipObj = scene.findObject("skinTooltip")
    tooltipObj.tooltipId = DECORATION.getTooltipId($"{unit.name}/{skinId}", UNLOCKABLE_SKIN)
  }

  function renewDropright(nestObjId, listObjId, items, index, cb)
  {
    local nestObj = scene.findObject(listObjId)
    local needCreateList = false
    if (!checkObj(nestObj))
    {
      needCreateList = true
      nestObj = scene.findObject(nestObjId)
      if (!checkObj(nestObj))
        return
    }
    let skinsDropright = ::create_option_combobox(listObjId, items, index, cb, needCreateList)
    if (needCreateList)
      guiScene.prependWithBlk(nestObj, skinsDropright, this)
    else
      guiScene.replaceContentFromText(nestObj, skinsDropright, skinsDropright.len(), this)
  }

  function updateUserSkinList()
  {
    ::reload_user_skins()
    let userSkinsOption = ::get_option(::USEROPT_USER_SKIN)
    renewDropright("user_skins_list", "user_skins_dropright", userSkinsOption.items, userSkinsOption.value, "onUserSkinChanged")
  }

  function createSkinSliders()
  {
    if (!isUnitOwn || !isUnitTank)
      return

    let options = [::USEROPT_TANK_CAMO_SCALE,
                     ::USEROPT_TANK_CAMO_ROTATION]
    if (hasFeature("SpendGold"))
      options.insert(0, ::USEROPT_TANK_SKIN_CONDITION)

    let view = { isTooltipByHold = ::show_console_buttons, rows = [] }
    foreach(optType in options)
    {
      let option = ::get_option(optType)
      view.rows.append({
        id = option.id
        name = "#options/" + option.id
        option = ::create_option_slider(option.id, option.value, option.cb, true, "slider", option)
      })
    }
    let data = ::handyman.renderCached(("%gui/options/verticalOptions"), view)
    let slObj = scene.findObject("tank_skin_settings")
    if (checkObj(slObj))
      guiScene.replaceContentFromText(slObj, data, data.len(), this)

    updateSkinSliders()
  }

  function updateSkinSliders()
  {
    if (!isUnitOwn || !isUnitTank)
      return

    let skinIndex = skinList?.values.indexof(previewSkinId) ?? 0
    let skinDecorator = skinList?.decorators[skinIndex]
    let canScaleAndRotate = skinDecorator?.getCouponItemdefId() == null

    let have_premium = havePremium.value
    local option = null

    option = ::get_option(::USEROPT_TANK_SKIN_CONDITION)
    let tscId = option.id
    let tscTrObj = scene.findObject("tr_" + tscId)
    if (checkObj(tscTrObj))
    {
      tscTrObj.inactiveColor = have_premium? "no" : "yes"
      tscTrObj.tooltip = have_premium ? "" : loc("mainmenu/onlyWithPremium")
      let sliderObj = scene.findObject(tscId)
      let value = have_premium ? option.value : option.defVal
      sliderObj.setValue(value)
      updateSkinConditionValue(value, sliderObj)
    }

    option = ::get_option(::USEROPT_TANK_CAMO_SCALE)
    let tcsId = option.id
    let tcsTrObj = scene.findObject("tr_" + tcsId)
    if (checkObj(tcsTrObj))
    {
      tcsTrObj.tooltip = canScaleAndRotate ? "" : loc("guiHints/not_available_on_this_camo")
      let sliderObj = scene.findObject(tcsId)
      let value = canScaleAndRotate ? option.value : option.defVal
      sliderObj.setValue(value)
      sliderObj.enable(canScaleAndRotate)
      onChangeTankCamoScale(sliderObj)
    }

    option = ::get_option(::USEROPT_TANK_CAMO_ROTATION)
    let tcrId = option.id
    let tcrTrObj = scene.findObject("tr_" + tcrId)
    if (checkObj(tcrTrObj))
    {
      tcrTrObj.tooltip = canScaleAndRotate ? "" : loc("guiHints/not_available_on_this_camo")
      let sliderObj = scene.findObject(tcrId)
      let value = canScaleAndRotate ? option.value : option.defVal
      sliderObj.setValue(value)
      sliderObj.enable(canScaleAndRotate)
      onChangeTankCamoRotation(sliderObj)
    }
  }

  function onChangeTankSkinCondition(obj)
  {
    if (!checkObj(obj))
      return

    let oldValue = ::get_option(::USEROPT_TANK_SKIN_CONDITION).value
    let newValue = obj.getValue()
    if (oldValue == newValue)
      return

    if (!havePremium.value)
    {
      obj.setValue(oldValue)
      guiScene.performDelayed(this, @()
        isValid() && askBuyPremium(Callback(updateSkinSliders, this)))
      return
    }

    updateSkinConditionValue(newValue, obj)
  }

  function askBuyPremium(afterCloseFunc)
  {
    let msgText = loc("msgbox/noEntitlement/PremiumAccount")
    this.msgBox("no_premium", msgText,
         [["ok", @() startOnlineShop("premium", afterCloseFunc) ],
         ["cancel", @() null ]], "ok", { checkDuplicateId = true })
  }

  function updateSkinConditionValue(value, obj)
  {
    let textObj = scene.findObject("value_" + (obj?.id ?? ""))
    if (!checkObj(textObj))
      return

    textObj.setValue(((value + 100) / 2).tostring() + "%")
    ::hangar_set_tank_skin_condition(value)
  }

  function onChangeTankCamoScale(obj)
  {
    if (!checkObj(obj))
      return

    let textObj = scene.findObject("value_" + (obj?.id ?? ""))
    if (checkObj(textObj))
    {
      let value = obj.getValue()
      ::hangar_set_tank_camo_scale(value / TANK_CAMO_SCALE_SLIDER_FACTOR)
      textObj.setValue((::hangar_get_tank_camo_scale_result_value() * 100 + 0.5).tointeger().tostring() + "%")
    }
  }

  function onChangeTankCamoRotation(obj)
  {
    if (!checkObj(obj))
      return

    let textObj = scene.findObject("value_" + (obj?.id ?? ""))
    if (checkObj(textObj))
    {
      let value = obj.getValue()
      let visualValue = value * 180 / 100
      textObj.setValue((visualValue > 0 ? "+" : "") + visualValue.tostring())
      ::hangar_set_tank_camo_rotation(value)
    }
  }

  function updateAttachablesSlots()
  {
    if (!access_Attachables)
      return

    let view = { isTooltipByHold = ::show_console_buttons, buttons = []}
    for (local i = 0; i < ::g_decorator_type.ATTACHABLES.getMaxSlots(); i++)
    {
      let button = getViewButtonTable(i, ::g_decorator_type.ATTACHABLES)
      button.id = "slot_attach_" + i
      button.onClick = "onAttachableSlotClick"
      button.onDblClick = "onAttachableSlotDoubleClick"
      button.onDeleteClick = "onDeleteAttachable"
      view.buttons.append(button)
    }

    let dObj = scene.findObject("attachable_div")
    if (!checkObj(dObj))
      return

    let attachListObj = dObj.findObject("slots_attachable_list")
    if (!checkObj(attachListObj))
      return

    dObj.show(true)
    let data = ::handyman.renderCached("%gui/commonParts/imageButton", view)

    guiScene.replaceContentFromText(attachListObj, data, data.len(), this)
    attachListObj.setValue(curAttachSlot)
  }

  function updateDecalSlots()
  {
    let view = { isTooltipByHold = ::show_console_buttons, buttons = [] }
    for (local i = 0; i < ::g_decorator_type.DECALS.getMaxSlots(); i++)
    {
      let button = getViewButtonTable(i, ::g_decorator_type.DECALS)
      button.id = "slot_" + i
      button.onClick = "onDecalSlotClick"
      button.onDblClick = "onDecalSlotDoubleClick"
      button.onDeleteClick = "onDeleteDecal"
      view.buttons.append(button)
    }

    let dObj = scene.findObject("slots_list")
    if (checkObj(dObj))
    {
      let data = ::handyman.renderCached("%gui/commonParts/imageButton", view)
      guiScene.replaceContentFromText(dObj, data, data.len(), this)
    }

    dObj.setValue(curSlot)
  }

  function getViewButtonTable(slotIdx, decoratorType)
  {
    let canEditDecals = isUnitOwn && previewSkinId == null
    let slot = getSlotInfo(slotIdx, false, decoratorType)
    let decalId = slot.decalId
    let decorator = ::g_decorator.getDecorator(decalId, decoratorType)
    let slotRatio = clamp(decoratorType.getRatio(decorator), 1, 2)
    local buttonTooltip = slot.isEmpty ? loc(decoratorType.emptySlotLocId) : ""
    if (!isUnitOwn)
      buttonTooltip = "#mainmenu/decalUnitLocked"
    else if (!canEditDecals)
      buttonTooltip = "#mainmenu/decalSkinLocked"
    else if (!slot.unlocked)
    {
      if (hasFeature("EnablePremiumPurchase"))
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
      statusLock = slot.unlocked ? getDecorLockStatusText(decorator, unit)
        : hasFeature("EnablePremiumPurchase") ? "noPremium_" + slotRatio
        : "achievement"
      unlocked = slot.unlocked && (!decorator || decorator.isUnlocked())
      emptySlot = slot.isEmpty || !decorator
      image = decoratorType.getImage(decorator)
      rarityColor = decorator?.isRare() ? decorator.getRarityColor() : null
      tooltipText = buttonTooltip
      tooltipId = slot.isEmpty? null : DECORATION.getTooltipId(decalId, decoratorType.unlockedItemType)
      tooltipOffset = "1@bw, 1@bh + 0.1@sf"
    }
  }

  onSlotsHoverChange = @() updateButtons()

  function updateButtons(decoratorType = null, needUpdateSlotDivs = true)
  {
    let isGift   = ::isUnitGift(unit)
    local canBuyOnline = ::canBuyUnitOnline(unit)
    let canBuyNotResearchedUnit = canBuyNotResearched(unit)
    let canBuyIngame = !canBuyOnline && (::canBuyUnit(unit) || canBuyNotResearchedUnit)
    let canFindUnitOnMarketplace = !canBuyOnline && !canBuyIngame && ::canBuyUnitOnMarketplace(unit)

    if (isGift && canUseIngameShop() && getShopItemsTable().len() == 0)
    {
      //Override for ingameShop.
      //There is rare posibility, that shop data is empty.
      //Because of external error.
      canBuyOnline = false
    }

    local bObj = this.showSceneBtn("btn_buy", canBuyIngame)
    if (canBuyIngame && checkObj(bObj))
    {
      let price = canBuyNotResearchedUnit ? unit.getOpenCost() : ::getUnitCost(unit)
      placePriceTextToButton(scene, "btn_buy", loc("mainmenu/btnOrder"), price)

      ::showUnitDiscount(bObj.findObject("buy_discount"), unit)
    }

    let bOnlineObj = this.showSceneBtn("btn_buy_online", canBuyOnline)
    if (canBuyOnline && checkObj(bOnlineObj))
      ::showUnitDiscount(bOnlineObj.findObject("buy_online_discount"), unit)

    this.showSceneBtn("btn_marketplace_find_unit", canFindUnitOnMarketplace)

    local skinDecorator = null
    local skinCouponItemdefId = null

    if (isUnitOwn && previewSkinId && skinList)
    {
      let skinIndex = skinList.values.indexof(previewSkinId) ?? -1
      skinDecorator = skinList.decorators?[skinIndex]
      skinCouponItemdefId = skinDecorator?.getCouponItemdefId()
    }

    let canBuySkin = skinDecorator?.canBuyUnlock(unit) ?? false
    let canConsumeSkinCoupon = !canBuySkin &&
      (::ItemsManager.getInventoryItemById(skinCouponItemdefId)?.canConsume() ?? false)
    let canFindSkinOnMarketplace = !canBuySkin && !canConsumeSkinCoupon && skinCouponItemdefId != null

    bObj = this.showSceneBtn("btn_buy_skin", canBuySkin)
    if (canBuySkin && checkObj(bObj))
    {
      let price = skinDecorator.getCost()
      placePriceTextToButton(scene, "btn_buy_skin", loc("mainmenu/btnOrder"), price)
    }

    let can_testflight = ::isTestFlightAvailable(unit) && !decoratorPreview
    let can_createUserSkin = ::can_save_current_skin_template()

    bObj = scene.findObject("btn_load_userskin_sample")
    if (checkObj(bObj))
      bObj.inactiveColor = can_createUserSkin ? "no" : "yes"

    let isInEditMode = currentState & decoratorEditState.EDITING
    updateBackButton()

    if (decoratorType == null)
      decoratorType = currentType

    let focusedType = getCurrentFocusedType()
    let focusedSlot = getSlotInfo(getCurrentDecoratorSlot(focusedType), true, focusedType)

    bObj = scene.findObject("btn_toggle_damaged")
    let isDmgSkinPreviewMode = checkObj(bObj) && bObj.getValue()

    let usableSkinsCount = ::u.filter(skinList?.access ?? [], @(a) a.isOwn).len()

    ::showBtnTable(scene, {
          btn_go_to_collection = ::show_console_buttons && !isInEditMode && decorMenu?.isOpened
            && isCollectionItem(decorMenu?.getSelectedDecor())

          btn_apply = currentState & decoratorEditState.EDITING

          btn_testflight = !isInEditMode && !decorMenu?.isOpened && can_testflight
          btn_info       = !isInEditMode && !decorMenu?.isOpened && ::isUnitDescriptionValid(unit) && !access_WikiOnline
          btn_info_online = !isInEditMode && !decorMenu?.isOpened && ::isUnitDescriptionValid(unit) && access_WikiOnline
          btn_sec_weapons    = !isInEditMode && !decorMenu?.isOpened &&
            needSecondaryWeaponsWnd(unit) && isUnitHaveSecondaryWeapons(unit)

          btn_decal_edit   = ::show_console_buttons && !isInEditMode && !decorMenu?.isOpened && !focusedSlot.isEmpty && focusedSlot.unlocked
          btn_decal_delete = ::show_console_buttons && !isInEditMode && !decorMenu?.isOpened && !focusedSlot.isEmpty && focusedSlot.unlocked

          btn_marketplace_consume_coupon_skin = !previewMode && canConsumeSkinCoupon
          btn_marketplace_find_skin = !previewMode && canFindSkinOnMarketplace

          skins_div = !isInEditMode && !decorMenu?.isOpened && access_Skins
          user_skins_block = !previewMode && access_UserSkins
          tank_skin_settings = !previewMode && isUnitTank

          previewed_decorator_div  = !isInEditMode && decoratorPreview
          previewed_decorator_unit = !isInEditMode && decoratorPreview && initialUnitId && initialUnitId != unit?.name

          decor_layout_presets = !isInEditMode && !decorMenu?.isOpened && isUnitOwn &&
            hasFeature("CustomizationLayoutPresets") && usableSkinsCount > 1 &&
            !previewMode && !previewSkinId

          dmg_skin_div = hasFeature("DamagedSkinPreview") && !isInEditMode && !decorMenu?.isOpened
          dmg_skin_buttons_div = isDmgSkinPreviewMode && (unit.isAir() || unit.isHelicopter())
    })


    let isVisibleSuggestedSkin = needSuggestSkin(unit.name, previewSkinId)
    let suggestedSkinObj = this.showSceneBtn("suggested_skin", isVisibleSuggestedSkin)
    if (isVisibleSuggestedSkin) {
      ::showBtn("btn_suggested_skin_find", canFindSkinOnMarketplace, suggestedSkinObj)
      ::showBtn("btn_suggested_skin_exchange", canConsumeSkinCoupon, suggestedSkinObj)
      let textArr = [loc("suggested_skin/info")]
      if (canFindSkinOnMarketplace)
        textArr.append(loc("suggested_skin/find"))
      suggestedSkinObj.findObject("suggested_skin_info_text").setValue("\n".join(textArr))
    }

    if (unitInfoPanelWeak?.isValid() ?? false)
      unitInfoPanelWeak.onSceneActivate(!isInEditMode && !decorMenu?.isOpened && !isDmgSkinPreviewMode)

    if (needUpdateSlotDivs)
      updateSlotsDivsVisibility(decoratorType)

    let isHangarLoaded = ::hangar_is_loaded()
    ::enableBtnTable(scene, {
          decalslots_div     = isHangarLoaded
          slots_list         = isHangarLoaded
          skins_navigator    = isHangarLoaded
          tank_skin_settings = isHangarLoaded
    })

    updateDecoratorActions(isInEditMode, decoratorType)
    scene.findObject("gamercard_div")["gamercardSkipNavigation"] = isInEditMode ? "yes" : "no"
    ::update_gamercards()
  }

  function updateBackButton()
  {
    let bObj = scene.findObject("btn_back")
    if (!bObj?.isValid())
      return

    if (currentState & decoratorEditState.EDITING)
    {
      bObj.text = loc("mainmenu/btnCancel")
      bObj["skip-navigation"] = "yes"
      return
    }

    if ((currentState & decoratorEditState.SELECT) && ::show_console_buttons)
    {
      if (decorMenu?.isCurCategoryListObjHovered())
      {
        bObj.text = loc("mainmenu/btnCollapse")
        bObj["skip-navigation"] = "no"
        return
      }
    }

    bObj.text = loc("mainmenu/btnBack")
    bObj["skip-navigation"] = "no"
  }

  function isNavigationAllowed()
  {
    return !(currentState & decoratorEditState.EDITING)
  }

  function updateDecoratorActions(show, decoratorType)
  {
    let hintsObj = this.showSceneBtn("decals_hint", show)
    if (show && checkObj(hintsObj))
    {
      ::showBtnTable(hintsObj, {
        decals_hint_rotate = decoratorType.canRotate()
        decals_hint_resize = decoratorType.canResize()
      })
    }

    //Flip
    let showMirror = show && decoratorType.canMirror()
    this.showSceneBtn("btn_toggle_mirror", showMirror)
    //TwoSided
    let showAbsBf = show && decoratorType.canToggle()
    this.showSceneBtn("two_sided", showAbsBf)

    if (showMirror || showAbsBf)
      updateDecoratorActionBtnStates()
  }

  function updateDecoratorActionBtnStates()
  {
    // TwoSided
    local obj = scene.findObject("two_sided_select")
    if (checkObj(obj))
      obj.setValue(getTwoSidedState())

    // Flip
    obj = scene.findObject("btn_toggle_mirror")
    if (checkObj(obj))
    {
      let enabled = ::get_hangar_mirror_current_decal()
      let icon = "#ui/gameuiskin#btn_flip_decal" + (enabled ? "_active" : "") + ".svg"
      let iconObj = obj.findObject("btn_toggle_mirror_img")
      iconObj["background-image"] = icon
      iconObj.getParent().active = enabled ? "yes" : "no"
    }
  }

  function updateSlotsDivsVisibility(decoratorType = null)
  {
    let inBasicMode = currentState & decoratorEditState.NONE
    let showDecalsSlotDiv = access_Decals
      && (inBasicMode || (decoratorType == ::g_decorator_type.DECALS && (currentState & decoratorEditState.SELECT)))

    let showAttachableSlotsDiv = access_Attachables
      && (inBasicMode || (decoratorType == ::g_decorator_type.ATTACHABLES && (currentState & decoratorEditState.SELECT)))

    ::showBtnTable(scene, {
      decalslots_div = showDecalsSlotDiv
      attachable_div = showAttachableSlotsDiv
    })
  }

  function updateUnitStatus()
  {
    let obj = scene.findObject("unit_status")
    if (!checkObj(obj))
      return
    let isShow = previewMode & (PREVIEW_MODE.UNIT | PREVIEW_MODE.SKIN)
    obj.show(isShow)
    if (!isShow)
      return
    obj.findObject("icon")["background-image"] = isUnitOwn ? "ui/gameuiskin#favorite.png" : "ui/gameuiskin#locked.svg"
    let textObj = obj.findObject("text")
    textObj.setValue(loc(isUnitOwn ? "conditions/unitExists" : "weaponry/unit_not_bought"))
    textObj.overlayTextColor = isUnitOwn ? "good" : "bad"
  }

  function updatePreviewedDecoratorInfo()
  {
    if (previewMode != PREVIEW_MODE.DECORATOR)
      return

    let isUnitAutoselected = initialUnitId && initialUnitId != unit?.name
    local obj = this.showSceneBtn("previewed_decorator_unit", isUnitAutoselected)
    if (obj && isUnitAutoselected)
      obj.findObject("label").setValue(loc("decoratorPreview/autoselectedUnit", {
          previewUnit = colorize("activeTextColor", ::getUnitName(unit))
          hangarUnit  = colorize("activeTextColor", ::getUnitName(initialUnitId))
        }) + " " + loc("decoratorPreview/autoselectedUnit/desc", {
          preview       = loc("mainmenu/btnPreview")
          customization = loc("mainmenu/btnShowroom")
        }))

    obj = this.showSceneBtn("previewed_decorator", true)
    if (obj)
    {
      let txtApplyDecorator = loc("decoratorPreview/applyManually/" + currentType.resourceType)
      let labelObj = obj.findObject("label")
      labelObj.setValue(txtApplyDecorator + loc("ui/colon"))

      let params = {
        showAsTrophyContent = true
        onClick = "onDecoratorItemClick"
        onDblClick = "onDecalItemDoubleClick"
        onCollectionBtnClick = isCollectionItem(decoratorPreview)
          ? "onCollectionIconClick"
          : null
      }
      let view = {
        isTooltipByHold = ::show_console_buttons,
        buttons = [ getDecorButtonView(decoratorPreview, unit, params) ]
      }
      let slotsObj = obj.findObject("decorator_preview_div")
      let markup = ::handyman.renderCached("%gui/commonParts/imageButton", view)
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
    if (!checkObj(scene))
      return

    updateButtons()
  }

  function onDecalSlotSelect(obj)
  {
    if (!checkObj(obj))
      return

    let slotId = obj.getValue()

    setCurrentDecoratorSlot(slotId, ::g_decorator_type.DECALS)
    updateButtons(::g_decorator_type.DECALS)
  }

  function onDecalSlotActivate(obj)
  {
    let value = obj.getValue()
    let childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (checkObj(childObj))
      onDecalSlotClick(childObj)
  }

  function onAttachSlotSelect(obj)
  {
    if (!checkObj(obj))
      return

    let slotId = obj.getValue()

    setCurrentDecoratorSlot(slotId, ::g_decorator_type.ATTACHABLES)
    updateButtons(::g_decorator_type.ATTACHABLES)
  }

  function onAttachableSlotActivate(obj)
  {
    let value = obj.getValue()
    let childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (!checkObj(childObj))
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

    let prevSlotId = actionObj.getParent().getValue()
    if (decorMenu?.isOpened && slotId == prevSlotId)
      return

    setCurrentDecoratorSlot(slotId, decoratorType)
    currentState = decoratorEditState.SELECT

    if (prevSlotId != slotId)
      actionObj.getParent().setValue(slotId)
    else
      updateButtons(decoratorType)

    let slot = getSlotInfo(slotId, false, decoratorType)
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

    this.msgBox("unit_locked", loc("decals/needToBuyUnit"), [["ok", onOkFunc ]], "ok")
    return false
  }

  function checkCurrentSkin()
  {
    if (::u.isEmpty(previewSkinId) || !skinList)
      return true

    let skinIndex = ::find_in_array(skinList.values, previewSkinId, 0)
    let skinDecorator = skinList.decorators[skinIndex]

    if (skinDecorator.canBuyUnlock(unit))
    {
      let cost = skinDecorator.getCost()
      let priceText = cost.getTextAccordingToBalance()
      let msgText = ::warningIfGold(
        loc("decals/needToBuySkin",
          {purchase = skinDecorator.getName(), cost = priceText}),
        skinDecorator.getCost())
      this.msgBox("skin_locked", msgText,
        [["ok", (@(previewSkinId) function() { buySkin(previewSkinId, cost) })(previewSkinId) ],
        ["cancel", function() {} ]], "ok")
    }
    else
      this.msgBox("skin_locked", loc("decals/skinLocked"), [["ok", function() {} ]], "ok")
    return false
  }

  function checkSlotIndex(slotIdx, decoratorType)
  {
    if (slotIdx < 0)
      return false

    if (slotIdx < decoratorType.getAvailableSlots(unit))
      return true

    if (hasFeature("EnablePremiumPurchase"))
    {
      this.msgBox("no_premium", loc("decals/noPremiumAccount"),
           [["ok", function()
            {
               onOnlineShopPremium()
               saveDecorators(true)
            }],
           ["cancel", function() {} ]], "ok")
    }
    else
    {
      this.msgBox("premium_not_available", loc("charServer/notAvailableYet"),
           [["cancel"]], "cancel")
    }
    return false
  }

  function onAttachableSlotClick(obj)
  {
    if (!checkObj(obj))
      return

    let slotName = ::getObjIdByPrefix(obj, "slot_attach_")
    let slotId = slotName ? slotName.tointeger() : -1

    openDecorationsListForSlot(slotId, obj, ::g_decorator_type.ATTACHABLES)
  }

  function onDecalSlotClick(obj)
  {
    let slotName = ::getObjIdByPrefix(obj, "slot_")
    let slotId = slotName ? slotName.tointeger() : -1
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
    let slotIdx = getCurrentDecoratorSlot(decoratorType)
    let slotInfo = getSlotInfo(slotIdx, false, decoratorType)
    if (slotInfo.isEmpty)
      return

    let decorator = ::g_decorator.getDecorator(slotInfo.decalId, decoratorType)
    currentState = decoratorEditState.REPLACE
    enterEditDecalMode(slotIdx, decorator)
  }

  function generateDecorationsList(slot, decoratorType)
  {
    if (::u.isEmpty(slot)
        || decoratorType == ::g_decorator_type.UNKNOWN
        || (currentState & decoratorEditState.NONE))
      return

    currentType = decoratorType

    decorMenu?.updateHandlerData(currentType, unit, slot.decalId, preSelectDecorator?.id)
    decorMenu?.createCategories()

    showDecoratorsList()

    local selCategoryId = ""
    local selGroupId = ""
    if (preSelectDecorator) {
      selCategoryId = preSelectDecorator.category
      selGroupId = preSelectDecorator.group == "" ? "other" : preSelectDecorator.group
    }
    else if (slot.isEmpty) {
      let path = decorMenu?.getSavedPath()
      selCategoryId = path?[0] ?? ""
      selGroupId = path?[1] ?? ""
    }
    else
    {
      let decal = ::g_decorator.getDecorator(slot.decalId, decoratorType)
      if (decal) {
        selCategoryId = decal.category
        selGroupId = decal.group == "" ? "other" : decal.group
      }
    }

    let isSelected = decorMenu?.selectCategory(selCategoryId, selGroupId)
    if (!isSelected)
      updateButtons(decoratorType)
  }

  function openCollections(decoratorId) {
    openCollectionsWnd({ selectedDecoratorId = decoratorId })
    updateBackButton()
  }

  onEventDecorMenuCollectionIconClick = @(p) openCollections(p.decoratorId)
  onCollectionIconClick = @(obj) openCollections(obj.holderId)

  function onCollectionButtonClick()
  {
    let selectedDecorator = decorMenu?.getSelectedDecor()
    if (!isCollectionItem(selectedDecorator))
      return

    openCollectionsWnd({ selectedDecoratorId = selectedDecorator.id })
    updateBackButton()
  }

  onEventDecorMenuItemSelect = @(_) updateButtons(null, false)
  onEventDecorMenuListHoverChange = @(_) updateBackButton()

  function onDecoratorItemClick(obj) {
    let decorator = decorMenu?.getDecoratorByObj(obj, currentType)
    if (!decorator)
      return
    onEventDecorMenuItemClick({ decorator })
  }

  function onEventDecorMenuItemClick(p) {
    let { decorator } = p
    if (!decoratorPreview && decorator.isOutOfLimit(unit))
      return ::g_popups.add("", loc("mainmenu/decoratorExceededLimit", {limit = decorator.limit}))

    let curSlotIdx = getCurrentDecoratorSlot(currentType)
    let isDecal = currentType == ::g_decorator_type.DECALS
    if (!decoratorPreview && isDecal)
    {
      let isRestrictionShown = showDecoratorAccessRestriction(decorator, unit)
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
      let slotInfo = getSlotInfo(curSlotIdx, false, currentType)
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

  function onEventDecorMenuItemDblClick(p) {
    let decor = p.decorator
    if (!decor.canUse(unit))
      return

    let slotIdx = getCurrentDecoratorSlot(currentType)
    let slotInfo = getSlotInfo(slotIdx, false, currentType)
    if (!slotInfo.isEmpty)
      enterEditDecalMode(slotIdx, decor)
  }

  function onDecalItemDoubleClick(obj) {
    let decorator = decorMenu?.getDecoratorByObj(obj, currentType)
    if (!decorator)
      return

    onEventDecorMenuItemDblClick({ decorator })
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
      if (decorMenu?.isCurCategoryListObjHovered()) {
        decorMenu.collapseOpenedCategory()
        updateBackButton()
        return
      }

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

    let afterSuccessFunc = Callback((@(decorator, afterPurchDo) function() {
      ::update_gamercards()
      decorMenu?.updateSelectedCategory(decorator)
      if (afterPurchDo)
        afterPurchDo()
    })(decorator, afterPurchDo), this)

    decorator.decoratorType.buyFunc(unit.name, decorator.id, cost, afterSuccessFunc)
    return true
  }

  function enterEditDecalMode(slotIdx, decorator)
  {
    if ((currentState & decoratorEditState.EDITING) || !decorator)
      return

    let decoratorType = decorator.decoratorType
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

    let slotInfo = getSlotInfo(getCurrentDecoratorSlot(decoratorType), true, decoratorType)
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

    let decorator = ::g_decorator.getDecorator(editableDecoratorId, currentType)

    if (!save || !decorator)
    {
      currentType.exitEditMode(false, false, Callback(afterStopDecalEdition, this))
      return
    }

    if (previewMode & PREVIEW_MODE.DECORATOR)
      return setDecoratorInSlot(decorator)

    if (decorator.canBuyUnlock(unit))
      return askBuyDecoratorOnExitEditMode(decorator)

    if (decorator.canBuyCouponOnMarketplace(unit))
      return askMarketplaceCouponActionOnExitEditMode(decorator)

    let isRestrictionShown = showDecoratorAccessRestriction(decorator, unit)
    if (isRestrictionShown)
      return

    setDecoratorInSlot(decorator)
  }

  function askBuyDecoratorOnExitEditMode(decorator)
  {
    if (!currentType.exitEditMode(true, false,
              Callback((@(decorator) function() {
                          askBuyDecorator(decorator, function()
                            {
                              ::hangar_save_current_attachables()
                            })
                        })(decorator), this)))
      showFailedInstallPopup(decorator)
  }

  function askMarketplaceCouponActionOnExitEditMode(decorator)
  {
    if (!currentType.exitEditMode(true, false,
              Callback(@() askMarketplaceCouponAction(decorator), this)))
      showFailedInstallPopup(decorator)
  }

  function askBuyDecorator(decorator, afterPurchDo = null)
  {
    let cost = decorator.getCost()
    let msgText = ::warningIfGold(
      loc("shop/needMoneyQuestion_purchaseDecal",
        {purchase = colorize("userlogColoredText", decorator.getName()),
          cost = cost.getTextAccordingToBalance()}),
      decorator.getCost())
    this.msgBox("buy_decorator_on_preview", msgText,
      [["ok", (@(decorator, afterPurchDo) function() {
          currentState = decoratorEditState.PURCHASE
          if (!buyDecorator(decorator, cost, afterPurchDo))
            return forceResetInstalledDecorators()

          ::dmViewer.update()
          onFinishInstallDecoratorOnUnit(true)
        })(decorator, afterPurchDo)],
      ["cancel", onMsgBoxCancel]
      ], "ok", { cancel_fn = onMsgBoxCancel })
  }

  function onMsgBoxCancel() {
    if ((currentState & decoratorEditState.SELECT) == 0)
      onBtnBack()
  }

  function askMarketplaceCouponAction(decorator)
  {
    let inventoryItem = ::ItemsManager.getInventoryItemById(decorator.getCouponItemdefId())
    if (inventoryItem?.canConsume() ?? false)
    {
      inventoryItem.consume(Callback(function(result) {
        if ((result?.success ?? false) == true)
          decorMenu?.updateSelectedCategory(decorator)
      }, this), null)
      return
    }

    let couponItem = ::ItemsManager.findItemById(decorator.getCouponItemdefId())
    if (!(couponItem?.hasLink() ?? false))
      return
    let couponName = colorize("activeTextColor", couponItem.getName())
    this.msgBox("go_to_marketplace", loc("msgbox/find_on_marketplace", { itemName = couponName }), [
        [ "find_on_marketplace", function() { couponItem.openLink(); onBtnBack() } ],
        [ "cancel", onMsgBoxCancel ]
      ], "find_on_marketplace", { cancel_fn = onMsgBoxCancel })
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
      return showFailedInstallPopup(decorator)

    if (currentType == ::g_decorator_type.DECALS)
      ::req_unlock_by_client("decal_applied", false)
  }

  function showFailedInstallPopup(decorator)
  {
    let attachAngle = acos(::hangar_get_attachable_tm()[1].y) * 180.0 / PI
    if (attachAngle >= decorator.maxSurfaceAngle)
      ::g_popups.add("", loc("mainmenu/failedInstallAttachableAngle",
        { angle = attachAngle.tointeger(), allowedAngle = decorator.maxSurfaceAngle }))
    else
      ::g_popups.add("", loc("mainmenu/failedInstallAttachable"))
  }

  function afterStopDecalEdition()
  {
    currentState = decorMenu?.isOpened ? decoratorEditState.SELECT : decoratorEditState.NONE
    updateSceneOnEditMode(false, currentType)
  }

  function installDecorationOnUnit(decorator)
  {
    let save = !!decorator && decorator.isUnlocked() && previewMode != PREVIEW_MODE.DECORATOR
    return currentType.exitEditMode(true, save,
      Callback( function () { onFinishInstallDecoratorOnUnit(true) }, this))
  }

  function onFinishInstallDecoratorOnUnit(isInstalled = false)
  {
    if (!isInstalled)
      return

    currentState = decorMenu?.isOpened ? decoratorEditState.SELECT : decoratorEditState.NONE
    updateSceneOnEditMode(false, currentType, true)
  }

  function onOnlineShopEagles()
  {
    if (hasFeature("EnableGoldPurchase"))
      startOnlineShop("eagles", afterReplenishCurrency, "customization")
    else
      ::showInfoMsgBox(loc("msgbox/notAvailbleGoldPurchase"))
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
    if (!havePremium.value)
      return

    ::update_gamercards()
    updateMainGuiElements()
  }

  function afterReplenishCurrency()
  {
    if (!checkObj(scene))
      return

    updateMainGuiElements()
  }

  function onSkinChange(obj)
  {
    let skinNum = obj.getValue()
    if (!skinList || !(skinNum in skinList.values))
    {
      ::dagor.debug_dump_stack()
      assert(false, "Error: try to set incorrect skin " + skinList + ", value = " + skinNum)
      return
    }

    let skinId = skinList.values[skinNum]
    let access = skinList.access[skinNum]

    if (isUnitOwn && access.isOwn && !previewMode)
    {
      let curSkinId = ::hangar_get_last_skin(unit.name)
      if (!previewSkinId && (skinId == curSkinId || (skinId == "" && curSkinId == "default")))
        return

      saveSeenSuggestedSkin(unit.name, previewSkinId)
      resetUserSkin(false)
      applySkin(skinId)
    }
    else if (access.isDownloadable)
    {
      // Starting skin download...
      showResource(skinId, "skin", Callback(onSkinReadyToShow, this))
    }
    else if (skinId != previewSkinId)
    {
      saveSeenSuggestedSkin(unit.name, previewSkinId)
      resetUserSkin(false)
      applySkin(skinId, true)
    }
  }

  function onSkinReadyToShow(unitId, skinId, result)
  {
    if (!result || !canStartPreviewScene(true, true) ||
      unitId != unit.name || (skinList?.values ?? []).indexof(skinId) == null)
        return

    ::g_decorator.previewedLiveSkinIds.append($"{unitId}/{skinId}")
    ::g_delayed_actions.add(Callback(function() {
      resetUserSkin(false)
      applySkin(skinId, true)
    }, this), 100)
  }

  function onUserSkinChanged(obj)
  {
    let value = obj.getValue()
    let prevValue = ::get_option(::USEROPT_USER_SKIN).value
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
    let cObj = scene.findObject("btn_toggle_damaged")
    if (checkObj(cObj))
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
      ::hangar_set_dm_viewer_mode(obj.getValue() ? DM_VIEWER_EXTERIOR : DM_VIEWER_NONE)
      if (obj.getValue())
      {
        let bObj = scene.findObject("dmg_skin_state")
        if (checkObj(bObj))
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
    let skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
    let previewSkinDecorator = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
    if (!previewSkinDecorator)
      return

    let cost = previewSkinDecorator.getCost()
    let msgText = ::warningIfGold(loc("shop/needMoneyQuestion_purchaseSkin",
                          { purchase = previewSkinDecorator.getName(),
                            cost = cost.getTextAccordingToBalance()
                          }), cost)

    this.msgBox("need_money", msgText,
          [["ok", (@(previewSkinId, cost) function() {
            if (::check_balance_msgBox(cost))
              buySkin(previewSkinId, cost)
          })(previewSkinId, cost)],
          ["cancel", function() {} ]], "ok")
  }

  function buySkin(skinName, cost)
  {
    let afterSuccessFunc = Callback((@(skinName) function() {
        ::update_gamercards()
        applySkin(skinName)
        updateMainGuiElements()
      })(skinName), this)

    ::g_decorator_type.SKINS.buyFunc(unit.name, skinName, cost, afterSuccessFunc)
  }

  function onBtnMarketplaceFindSkin(obj)
  {
    let skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
    let skinDecorator = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
    let item = ::ItemsManager.findItemById(skinDecorator?.getCouponItemdefId())
    if (!item?.hasLink())
      return
    item.openLink()
  }

  function onBtnMarketplaceConsumeCouponSkin(obj)
  {
    let skinId = ::g_unlocks.getSkinId(unit.name, previewSkinId)
    let skinDecorator = ::g_decorator.getDecorator(skinId, ::g_decorator_type.SKINS)
    let itemdefId = skinDecorator?.getCouponItemdefId()
    let inventoryItem = ::ItemsManager.getInventoryItemById(itemdefId)
    if (!inventoryItem?.canConsume())
      return

    let skinName = previewSkinId
    inventoryItem.consume(Callback(function(result) {
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
    if (checkDecalsList && decorMenu?.isOpened && slotId == getCurrentDecoratorSlot(decoratorType))
    {
      let decal = decorMenu.getSelectedDecor()
      if (decal)
        decalId = decal.id
    }

    if (decalId == "" && isValid && decoratorType != null)
    {
      let liveryName = getSelectedBuiltinSkinId()
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
    let afterCloseFunc = (@(owner, unit) function() {
      let newUnitName = getShowedUnitName()
      if (newUnitName == "")
        return setShowUnit(unit)

      if (unit.name != newUnitName)
      {
        ::cur_aircraft_name = newUnitName
        owner.unit = ::getAircraftByName(newUnitName)
        owner.previewSkinId = null
        if (owner && ("initMainParams" in owner) && owner.initMainParams)
          owner.initMainParams.call(owner)
      }
    })(owner, unit)

    saveDecorators(false)
    checkedNewFlight(function() {
      ::gui_start_testflight({ unit = unit, afterCloseFunc })
    })
  }

  function onBuy()
  {
    unitActions.buy(unit, "customization")
  }

  function onBtnMarketplaceFindUnit(obj)
  {
    let item = ::ItemsManager.findItemById(unit.marketplaceItemdefId)
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
    let curSlotIdx = getCurrentDecoratorSlot(currentType)
    let slotInfo = getSlotInfo(curSlotIdx, true, currentType)
    let decorator = ::g_decorator.getDecorator(slotInfo.decalId, currentType)
    enterEditDecalMode(curSlotIdx, decorator)
  }

  function onBtnDeleteDecal()
  {
    let decoratorType = getCurrentFocusedType()
    deleteDecorator(decoratorType, getCurrentDecoratorSlot(decoratorType))
  }

  function onDeleteDecal(obj)
  {
    if (!checkObj(obj))
      return

    let slotName = ::getObjIdByPrefix(obj.getParent(), "slot_")
    let slotId = slotName.tointeger()

    deleteDecorator(::g_decorator_type.DECALS, slotId)
  }

  function onDeleteAttachable(obj)
  {
    if (!checkObj(obj))
      return

    let slotName = ::getObjIdByPrefix(obj.getParent(), "slot_attach_")
    let slotId = slotName.tointeger()

    deleteDecorator(::g_decorator_type.ATTACHABLES, slotId)
  }

  function deleteDecorator(decoratorType, slotId)
  {
    let slotInfo = getSlotInfo(slotId, false, decoratorType)
    this.msgBox("delete_decal", loc(decoratorType.removeDecoratorLocId, {name = decoratorType.getLocName(slotInfo.decalId)}),
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
    let all = decoratorType == ::g_decorator_type.UNKNOWN
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

  function onSecWeaponsInfo(obj)
  {
    weaponryPresetsModal.open({ unit = unit })
  }

  function getTwoSidedState()
  {
    let isTwoSided = ::get_hangar_abs()
    let isOppositeMirrored = ::get_hangar_opposite_mirrored()
    return !isTwoSided ? decalTwoSidedMode.OFF
         : !isOppositeMirrored ? decalTwoSidedMode.ON
         : decalTwoSidedMode.ON_MIRRORED
  }

  function setTwoSidedState(idx)
  {
    let isTwoSided = ::get_hangar_abs()
    let isOppositeMirrored = ::get_hangar_opposite_mirrored()
    let needTwoSided  = idx != decalTwoSidedMode.OFF
    let needOppositeMirrored = idx == decalTwoSidedMode.ON_MIRRORED
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
    let obj = scene.findObject("two_sided_select")
    if (checkObj(obj))
      obj.setValue((obj.getValue() + 1) % obj.childrenCount())
  }

  function onTwoSidedSelect(obj) // TwoSided select
  {
    setTwoSidedState(obj.getValue())
  }

  function onInfo()
  {
    if (hasFeature("WikiUnitInfo"))
      openUrl(format(loc("url/wiki_objects"), unit.name), false, false, "customization_wnd")
    else
      ::showInfoMsgBox(colorize("activeTextColor", ::getUnitName(unit, false)) + "\n" + loc("profile/wiki_link"))
  }

  function clearCurrentDecalSlotAndShow()
  {
    if (!checkObj(scene))
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
    let show = !!(currentState & decoratorEditState.SELECT)

    let slotsObj = scene.findObject(currentType.listId)
    if (checkObj(slotsObj))
    {
      let sel = slotsObj.getValue()
      for (local i = 0; i < slotsObj.childrenCount(); i++)
      {
        let selectedItem = sel == i && show
        slotsObj.getChild(i).highlighted = selectedItem? "yes" : "no"
      }
    }

    ::hangar_notify_decal_menu_visibility(show)
    decorMenu?.show(show)
  }

  function onScreenClick()
  {
    if (currentState == decoratorEditState.NONE)
      return

    if (currentState == decoratorEditState.EDITING)
      return stopDecalEdition(true)

    let curSlotIdx = getCurrentDecoratorSlot(currentType)
    let curSlotInfo = getSlotInfo(curSlotIdx, false, currentType)
    if (curSlotInfo.isEmpty)
      return

    let curSlotDecoratorId = curSlotInfo.decalId
    if (curSlotDecoratorId == "")
      return

    let curSlotDecorator = ::g_decorator.getDecorator(curSlotDecoratorId, currentType)
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
    // clear only when closed by player to can go through test fly with previewed skin
    ::g_decorator.clearLivePreviewParams()
    guiScene.performDelayed(this, base.goBack)
    ::hangar_focus_model(false)
  }

  function onDestroy()
  {
    if (isValid())
      setDmgSkinMode(false)
    ::hangar_show_model_damaged(MDS_ORIGINAL)
    ::hangar_prem_vehicle_view_close()

    if (unit)
    {
      if (currentState & decoratorEditState.EDITING)
      {
        currentType.exitEditMode(false, false)
        currentType.specifyEditableSlot(-1)
      }

      if (previewSkinId)
      {
        saveSeenSuggestedSkin(unit.name, previewSkinId)
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
    let obj = scene.findObject("decal_text_area")
    if (!checkObj(obj))
      return

    local txt = ""
    if (::is_decals_disabled())
    {
      local timeSec = ::get_time_till_decals_disabled()
      if (timeSec == 0)
      {
        let st = penalty.getPenaltyStatus()
        if ("seconds_left" in st)
          timeSec = st.seconds_left
      }

      if (timeSec == 0)
        txt = format(loc("charServer/decal/permanent"))
      else
        txt = format(loc("charServer/decal/timed"), time.hoursToString(time.secondsToHours(timeSec), false))
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
    updateButtons()
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
        let skinBlockName = previewParams.unitName + "/" + previewParams.skinName
        ::g_decorator.previewedLiveSkinIds.append(skinBlockName)
        if (initialUserSkinId != "")
          ::get_user_skins_profile_blk()[unit.name] = ""
        let isForApprove = previewParams?.isForApprove ?? false
        ::g_decorator.approversUnitToPreviewLiveResource = isForApprove ? showedUnit.value : null
        ::g_delayed_actions.add(Callback(function() {
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
        let slot = getSlotInfo(i, false, decoratorType)
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
    let decoratorType = decorator.decoratorType
    if (decoratorType == ::g_decorator_type.SKINS)
    {
      if (unit.name == ::g_unlocks.getPlaneBySkinId(decorator.id))
        applySkin(::g_unlocks.getSkinNameBySkinId(decorator.id))
    }
    else
    {
      if (slotIdx != -1)
      {
        let listObj = scene.findObject(decoratorType.listId)
        if (checkObj(listObj))
        {
          let slotObj = listObj.getChild(slotIdx)
          if (checkObj(slotObj))
            openDecorationsListForSlot(slotIdx, slotObj, decoratorType)
        }
      }
    }
  }
}

//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { debug_dump_stack } = require("dagor.debug")
let time = require("%scripts/time.nut")
let { acos, PI } = require("math")
let penalty = require("penalty")
let { hangar_is_model_loaded, hangar_get_loaded_unit_name,
  hangar_force_reload_model, hangar_focus_model, hangar_set_dm_viewer_mode
} = require("hangar")
let { get_last_skin, mirror_current_decal, get_mirror_current_decal,
  apply_skin, apply_skin_preview, notify_decal_menu_visibility,
  save_current_attachables, hangar_toggle_abs, get_hangar_abs,
  set_hangar_opposite_mirrored, get_hangar_opposite_mirrored, set_tank_camo_scale,
  get_tank_camo_scale_result_value, set_tank_skin_condition, set_tank_camo_rotation,
  show_model_damaged, get_loaded_model_damage_state, can_save_current_skin_template,
  save_current_skin_template, MDS_UNDAMAGED, MDS_DAMAGED, MDS_ORIGINAL,
  get_ship_flag_in_slot, apply_ship_flag, get_default_ship_flag
} = require("unitCustomization")
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
let { getDecorator } = require("%scripts/customization/decorCache.nut")
let { getSkinId, getPlaneBySkinId, getSkinNameBySkinId } = require("%scripts/customization/skinUtils.nut")
let { clearLivePreviewParams, isAutoSkinOn, setAutoSkin, setLastSkin,
  previewedLiveSkinIds, approversUnitToPreviewLiveResource, getSkinsOption
} = require("%scripts/customization/skins.nut")
let { reqUnlockByClient, canDoUnlock } = require("%scripts/unlocks/unlocksModule.nut")
let { set_option, create_option_switchbox } = require("%scripts/options/optionsExt.nut")
let { createSlotInfoPanel } = require("%scripts/slotInfoPanel.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { USEROPT_USER_SKIN, USEROPT_TANK_CAMO_SCALE, USEROPT_TANK_CAMO_ROTATION,
  USEROPT_TANK_SKIN_CONDITION } = require("%scripts/options/optionsExtNames.nut")
let { getUnitName, isUnitGift } = require("%scripts/unit/unitInfo.nut")
let { get_user_skins_profile_blk } = require("blkGetters")
let { decoratorTypes } = require("%scripts/customization/types.nut")

dagui_propid_add_name_id("gamercardSkipNavigation")

enum decoratorEditState {
  NONE     = 0x0001
  SELECT   = 0x0002
  REPLACE  = 0x0004
  ADD      = 0x0008
  PURCHASE = 0x0010
  EDITING  = 0x0020
}

enum decalTwoSidedMode {
  OFF
  ON
  ON_MIRRORED
}

::on_decal_job_complete <- function on_decal_job_complete(taskId) {
  let callback = getTblValue(taskId, decoratorTypes.DECALS.jobCallbacksStack, null)
  if (callback) {
    callback()
    delete decoratorTypes.DECALS.jobCallbacksStack[taskId]
  }

  broadcastEvent("DecalJobComplete", { taskId = taskId })
}

::gui_start_decals <- function gui_start_decals(params = null) {
  if (params?.unit)
    showedUnit(params.unit)
  else if (params?.unitId)
    showedUnit(getAircraftByName(params?.unitId))

  if (!showedUnit.value
      ||
        (hangar_get_loaded_unit_name() == showedUnit.value.name
        && !::is_loaded_model_high_quality()
        && !::check_package_and_ask_download("pkg_main"))
    )
    return

  params = params || {}
  params.backSceneParams <- { globalFunctionName = "gui_start_mainmenu" }
  handlersManager.loadHandler(gui_handlers.DecalMenuHandler, params)
}

::hangar_add_popup <- function hangar_add_popup(text) { // called from client
  ::g_popups.add("", loc(text))
}

::delayed_download_enabled_msg <- function delayed_download_enabled_msg() {
  if (!::g_login.isProfileReceived())
    return
  let skip = loadLocalAccountSettings("skipped_msg/delayedDownloadContent", false)
  if (!skip) {
    ::gui_start_modal_wnd(gui_handlers.SkipableMsgBox,
    {
      parentHandler = handlersManager.getActiveBaseHandler()
      message = loc("msgbox/delayedDownloadContent")
      startBtnText = loc("msgbox/confirmDelayedDownload")
      defaultBtnId = "btn_select"
      onStartPressed = function() {
        ::set_option_delayed_download_content(true)
        saveLocalAccountSettings("delayDownloadContent", true)
      }
      cancelFunc = function() {
        ::set_option_delayed_download_content(false)
        saveLocalAccountSettings("delayDownloadContent", false)
      }
      skipFunc = function(value) {
        saveLocalAccountSettings("skipped_msg/delayedDownloadContent", value)
      }
    })
  }
  else {
    local choosenDDC = loadLocalAccountSettings("delayDownloadContent", true)
    ::set_option_delayed_download_content(choosenDDC)
  }
}

gui_handlers.DecalMenuHandler <- class extends gui_handlers.BaseGuiHandlerWT {
  sceneBlkName = "%gui/customization/customization.blk"
  unit = null
  owner = null

  access_WikiOnline = false
  access_Decals = false
  access_Attachables = false
  access_Flags = false
  access_UserSkins = false
  access_Skins = false
  access_SkinsUnrestrictedPreview = false
  access_SkinsUnrestrictedExport  = false

  editableDecoratorId = null

  skinList = null
  curSlot = 0
  curAttachSlot = 0
  curFlagSlot = 0
  previewSkinId = null

  initialAppliedSkinId = null
  initialUserSkinId = null
  initialUnitId = null

  currentType = decoratorTypes.UNKNOWN

  isLoadingRot = false
  isDecoratorItemUsed = false

  isUnitTank = false
  isUnitShipOrBoat = false
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
  defaultFlag = ""

  function initScreen() {
    this.owner = this
    this.unit = showedUnit.value
    if (!this.unit)
      return this.goBack()
    ::cur_aircraft_name = this.unit.name

    this.access_WikiOnline = hasFeature("WikiUnitInfo")
    this.access_UserSkins = isPlatformPC && hasFeature("UserSkins")
    this.access_SkinsUnrestrictedPreview = hasFeature("SkinsPreviewOnUnboughtUnits")
    this.access_SkinsUnrestrictedExport  = this.access_UserSkins && this.access_SkinsUnrestrictedExport

    this.initialAppliedSkinId   = get_last_skin(this.unit.name)
    this.initialUserSkinId      = get_user_skins_profile_blk()?[this.unit.name] ?? ""

    this.scene.findObject("timer_update").setUserData(this)

    hangar_focus_model(true)

    let unitInfoPanel = createSlotInfoPanel(this.scene, false, "showroom")
    this.registerSubHandler(unitInfoPanel)
    this.unitInfoPanelWeak = unitInfoPanel.weakref()
    if (this.needForceShowUnitInfoPanel)
      this.unitInfoPanelWeak.uncollapse()

    this.decorMenu = decorMenuHandler(this.scene.findObject("decor_menu_container")).weakref()

    this.initPreviewMode()
    this.initMainParams()
    this.showDecoratorsList()

    this.updateDecalActionsTexts()

    loadModel(this.unit.name)

    if (!this.isUnitOwn && !this.previewMode) {
      let skinId = this.unit.getPreviewSkinId()
      if (skinId != "" && skinId != this.initialAppliedSkinId)
        this.applySkin(skinId, true)
    }

    if (this.preSelectDecorator) {
      this.preSelectSlotAndDecorator(this.preSelectDecorator, this.preSelectDecoratorSlot)
      this.preSelectDecorator = null
      this.preSelectDecoratorSlot = -1
    }
  }

  function canRestartSceneNow() {
    return isInArray(this.currentState, [ decoratorEditState.NONE, decoratorEditState.SELECT ])
  }

  function getHandlerRestoreData() {
    let data = {
      openData = {
      }
      stateData = {
        initialAppliedSkinId = this.initialAppliedSkinId
        initialUserSkinId    = this.initialUserSkinId
      }
    }
    return data
  }

  function restoreHandler(stateData) {
    this.initialAppliedSkinId = stateData.initialAppliedSkinId
    this.initialUserSkinId    = stateData.initialUserSkinId
  }

  function initMainParams() {
    this.isUnitOwn = this.unit.isUsable()
    this.isUnitTank = this.unit.isTank()
    this.isUnitShipOrBoat = this.unit.isShipOrBoat()

    this.access_Decals      = !this.previewMode && this.isUnitOwn && decoratorTypes.DECALS.isAvailable(this.unit)
    this.access_Attachables = !this.previewMode && this.isUnitOwn && decoratorTypes.ATTACHABLES.isAvailable(this.unit)
    this.access_Flags = !this.previewMode && this.isUnitOwn && decoratorTypes.FLAGS.isAvailable(this.unit) && this.isUnitShipOrBoat
    this.access_Skins = (this.previewMode & (PREVIEW_MODE.UNIT | PREVIEW_MODE.SKIN)) ? true
      : (this.previewMode & PREVIEW_MODE.DECORATOR) ? false
      : this.isUnitOwn || this.access_SkinsUnrestrictedPreview || this.access_SkinsUnrestrictedExport

    this.updateTitle()

    this.setDmgSkinMode(get_loaded_model_damage_state(this.unit.name) == MDS_DAMAGED)

    let bObj = this.scene.findObject("btn_testflight")
    if (checkObj(bObj)) {
      bObj.setValue(this.unit.unitType.getTestFlightText())
      bObj.findObject("btn_testflight_image")["background-image"] = this.unit.unitType.testFlightIcon
    }

    this.createSkinSliders()
    this.updateMainGuiElements()
  }

  function updateMainGuiElements() {
    if (this.access_Flags)
      this.defaultFlag = get_default_ship_flag() ?? "default"
    this.updateSlotsBlockByType()
    this.updateSkinList()
    this.updateFlagName()
    this.updateAutoSkin()
    this.updateUserSkinList()
    this.updateSkinSliders()
    this.updateUnitStatus()
    this.updatePreviewedDecoratorInfo()
    this.updateButtons()
  }

  function updateTitle() {
    local title = loc(this.isUnitOwn && !this.previewMode ? "mainmenu/showroom" : "mainmenu/btnPreview") + " " + loc("ui/mdash") + " "
    if (!this.previewMode || (this.previewMode & (PREVIEW_MODE.UNIT | PREVIEW_MODE.SKIN)))
      title += getUnitName(this.unit.name)

    if (this.previewMode & PREVIEW_MODE.SKIN) {
      let skinId = getSkinId(this.unit.name, this.previewSkinId)
      let skin = getDecorator(skinId, decoratorTypes.SKINS)
      if (skin)
        title += loc("ui/comma") + loc("options/skin") + " " + colorize(skin.getRarityColor(), skin.getName())
    }
    else if (this.previewMode & PREVIEW_MODE.DECORATOR) {
      let typeText = loc("trophy/unlockables_names/" + this.decoratorPreview.decoratorType.resourceType)
      let nameText = colorize(this.decoratorPreview.getRarityColor(), this.decoratorPreview.getName())
      title += typeText + " " + nameText
    }

    this.setSceneTitle(title)
  }

  function updateDecalActionsTexts() {
    local bObj = null
    let hasKeyboard = isPlatformPC

    //Flip
    let btn_toggle_mirror_text = loc("decals/flip") + (hasKeyboard ? " (F)" : "")
    bObj = this.scene.findObject("btn_toggle_mirror")
    if (checkObj(bObj))
      bObj.setValue(btn_toggle_mirror_text)

    //TwoSided
    let text = loc("decals/twosided") + (hasKeyboard ? " (T)" : "") + loc("ui/colon")
    bObj = this.scene.findObject("two_sided_label")
    if (checkObj(bObj))
      bObj.setValue(text)

    //Size
    bObj = this.scene.findObject("push_to_change_size")
    if (bObj?.isValid() ?? false)
      bObj.setValue(getAxisTextOrAxisName("decal_scale"))

    //Rotate
    bObj = this.scene.findObject("push_to_rotate")
    if (bObj?.isValid() ?? false)
      bObj.setValue(getAxisTextOrAxisName("decal_rotate"))
  }

  function getSelectedBuiltinSkinId() {
    let res = this.previewSkinId || get_last_skin(this.unit.name)
    return res == "" ? "default" : res // get_last_skin() can return empty string.
  }

  function exportSampleUserSkin(_obj) {
    if (!hangar_is_model_loaded())
      return

    if (!can_save_current_skin_template()) {
      let message = format(loc("decals/noUserSkinForCurUnit"), getUnitName(this.unit.name))
      this.msgBox("skin_template_export", message, [["ok", function() {}]], "ok")
      return
    }

    let allowCurrentSkin = this.access_SkinsUnrestrictedExport // true - current skin, false - default skin.
    let success = save_current_skin_template(allowCurrentSkin)

    let templateName = "template_" + this.unit.name
    let message = success ? format(loc("decals/successfulLoadedSkinSample"), templateName) : loc("decals/failedLoadedSkinSample")
    this.msgBox("skin_template_export", message, [["ok", function() {}]], "ok")

    this.updateMainGuiElements()
  }

  function refreshSkinsList(_obj) {
    if (!hangar_is_model_loaded())
      return

    this.updateUserSkinList()
    if (::get_option(USEROPT_USER_SKIN).value > 0)
      hangar_force_reload_model()
  }

  function resetFlagToDefault(_obj) {
    if (!hangar_is_model_loaded())
      return
    apply_ship_flag(this.defaultFlag, true)
    this.updateFlagName()
    this.updateFlagSlots()
  }

  function switchUnit(unitName) {
    this.unit = getAircraftByName(unitName)
    if (this.unit == null) {
      script_net_assert_once("not found loaded model unit", "customization: not found unit after model loaded")
      return this.goBack()
    }
    ::cur_aircraft_name = this.unit.name
    this.initMainParams()
  }

  function onEventHangarModelLoaded(params = {}) {
    if (this.previewMode)
      this.removeAllDecorators(false)

    let { modelName } = params
    if (modelName != this.unit.name)
      this.switchUnit(modelName)
    else
      this.updateMainGuiElements()
    if (hangar_get_loaded_unit_name() == this.unit.name
        && !::is_loaded_model_high_quality())
      ::check_package_and_ask_download("pkg_main", null, null, this, "air_in_hangar", this.goBack)
  }

  function onEventDecalJobComplete(_params) {
    let isInEditMode = this.currentState & decoratorEditState.EDITING
    if (isInEditMode && this.currentType == decoratorTypes.DECALS)
      this.updateDecoratorActionBtnStates()
  }

  function updateAutoSkin() {
    if (!this.access_Skins)
      return

    let isVisible = !this.previewMode && this.isUnitOwn && this.unit.unitType.isSkinAutoSelectAvailable()
    this.showSceneBtn("auto_skin_block", isVisible)
    if (!isVisible)
      return

    let autoSkinId = "auto_skin_control"
    let controlObj = this.scene.findObject(autoSkinId)
    if (checkObj(controlObj)) {
      controlObj.setValue(isAutoSkinOn(this.unit.name))
      return
    }

    let placeObj = this.scene.findObject("auto_skin_place")
    let markup = create_option_switchbox({
      id = autoSkinId
      value = isAutoSkinOn(this.unit.name)
      cb = "onAutoSkinchange"
    })
    this.guiScene.replaceContentFromText(placeObj, markup, markup.len(), this)
  }

  function onAutoSkinchange(obj) {
    setAutoSkin(this.unit.name, obj.getValue())
  }

  function updateSkinList() {
    if (!this.access_Skins)
      return

    this.skinList = getSkinsOption(this.unit.name, true, false, true)
    let curSkinId = this.getSelectedBuiltinSkinId()
    let curSkinIndex = u.find_in_array(this.skinList.values, curSkinId, 0)
    let tooltipParams = this.previewMode ? { showAsTrophyContent = true } : null

    let skinItems = []
    foreach (i, decorator in this.skinList.decorators) {
      let access = this.skinList.access[i]
      let canFindOnMarketplace = !this.previewMode && decorator.canBuyCouponOnMarketplace(this.unit)
      let isUnlocked = decorator.isUnlocked()
      local text = this.skinList.items[i].text
      let image = this.skinList.items[i].image ?? ""
      let images = []
      if (image != "")
        images.append({ image, imageNoMargin = !isUnlocked })
      if (!isUnlocked)
        images.append({ image = "#ui/gameuiskin#locked.svg", imageNoMargin = true })

      if (canFindOnMarketplace)
        text = "".concat(loc("currency/gc/sign"), " ", text)

      if (!access.isVisible)
        text = colorize("comboExpandedLockedTextColor", "(" + loc("worldWar/hided_logs") + ") ") + text

      skinItems.append({
        text = text
        textStyle = this.skinList.items[i].textStyle
        addDiv = DECORATION.getMarkup(decorator.id, UNLOCKABLE_SKIN, tooltipParams)
        images
      })
    }

    this.renewDropright("skins_list", "skins_dropright", skinItems, curSkinIndex, "onSkinChange")
    this.updateSkinTooltip(curSkinId)
  }

  function updateSkinTooltip(skinId) {
    let tooltipObj = this.scene.findObject("skinTooltip")
    tooltipObj.tooltipId = DECORATION.getTooltipId($"{this.unit.name}/{skinId}", UNLOCKABLE_SKIN)
  }

  function isDefaultFlag(currentFlag) {
    return currentFlag == this.defaultFlag || currentFlag == "default"
  }

  function updateFlagName() {
    if (!this.access_Flags)
      return

    let currentFlag = get_ship_flag_in_slot(this.unit.name, this.getSelectedBuiltinSkinId())
    let flagName = this.isDefaultFlag(currentFlag) ?
      loc("flags/defaultFlag") :
      decoratorTypes.FLAGS.getLocName(currentFlag)

    let flagNameObj = this.scene.findObject("flag_name")
    flagNameObj.setValue(flagName)
    flagNameObj["tooltip"] = flagName
  }

  function renewDropright(nestObjId, listObjId, items, index, cb) {
    local nestObj = this.scene.findObject(listObjId)
    local needCreateList = false
    if (!checkObj(nestObj)) {
      needCreateList = true
      nestObj = this.scene.findObject(nestObjId)
      if (!checkObj(nestObj))
        return
    }
    let skinsDropright = ::create_option_combobox(listObjId, items, index, cb, needCreateList)
    if (needCreateList)
      this.guiScene.prependWithBlk(nestObj, skinsDropright, this)
    else
      this.guiScene.replaceContentFromText(nestObj, skinsDropright, skinsDropright.len(), this)
  }

  function updateUserSkinList() {
    ::reload_user_skins()
    let userSkinsOption = ::get_option(USEROPT_USER_SKIN)
    this.renewDropright("user_skins_list", "user_skins_dropright", userSkinsOption.items, userSkinsOption.value, "onUserSkinChanged")
  }

  function createSkinSliders() {
    if (!this.isUnitOwn || (!this.isUnitTank && !this.isUnitShipOrBoat))
      return

    let options = [USEROPT_TANK_CAMO_SCALE,
                     USEROPT_TANK_CAMO_ROTATION]
    if (hasFeature("SpendGold"))
      options.insert(0, USEROPT_TANK_SKIN_CONDITION)

    let view = { isTooltipByHold = showConsoleButtons.value, rows = [] }
    foreach (optType in options) {
      let option = ::get_option(optType)
      view.rows.append({
        id = option.id
        name = "#options/" + option.id
        option = ::create_option_slider(option.id, option.value, option.cb, true, "slider", option)
      })
    }
    let data = handyman.renderCached(("%gui/options/verticalOptions.tpl"), view)
    let slObj = this.scene.findObject("tank_skin_settings")
    if (checkObj(slObj))
      this.guiScene.replaceContentFromText(slObj, data, data.len(), this)

    this.updateSkinSliders()
  }

  function updateSkinSliders() {
    if (!this.isUnitOwn || (!this.isUnitTank && !this.isUnitShipOrBoat))
      return

    let skinIndex = this.skinList?.values.indexof(this.previewSkinId) ?? 0
    let skinDecorator = this.skinList?.decorators[skinIndex]
    let canScaleAndRotate = skinDecorator?.getCouponItemdefId() == null

    let have_premium = havePremium.value
    local option = null

    option = ::get_option(USEROPT_TANK_SKIN_CONDITION)
    let tscId = option.id
    let tscTrObj = this.scene.findObject("tr_" + tscId)
    if (checkObj(tscTrObj)) {
      tscTrObj.inactiveColor = have_premium ? "no" : "yes"
      tscTrObj.tooltip = have_premium ? "" : loc("mainmenu/onlyWithPremium")
      let sliderObj = this.scene.findObject(tscId)
      let value = have_premium ? option.value : option.defVal
      sliderObj.setValue(value)
      this.updateSkinConditionValue(value, sliderObj)
    }

    option = ::get_option(USEROPT_TANK_CAMO_SCALE)
    let tcsId = option.id
    let tcsTrObj = this.scene.findObject("tr_" + tcsId)
    if (checkObj(tcsTrObj)) {
      tcsTrObj.tooltip = canScaleAndRotate ? "" : loc("guiHints/not_available_on_this_camo")
      let sliderObj = this.scene.findObject(tcsId)
      let value = canScaleAndRotate ? option.value : option.defVal
      sliderObj.setValue(value)
      sliderObj.enable(canScaleAndRotate)
      this.onChangeTankCamoScale(sliderObj)
    }

    option = ::get_option(USEROPT_TANK_CAMO_ROTATION)
    let tcrId = option.id
    let tcrTrObj = this.scene.findObject("tr_" + tcrId)
    if (checkObj(tcrTrObj)) {
      tcrTrObj.tooltip = canScaleAndRotate ? "" : loc("guiHints/not_available_on_this_camo")
      let sliderObj = this.scene.findObject(tcrId)
      let value = canScaleAndRotate ? option.value : option.defVal
      sliderObj.setValue(value)
      sliderObj.enable(canScaleAndRotate)
      this.onChangeTankCamoRotation(sliderObj)
    }
  }

  function onChangeTankSkinCondition(obj) {
    if (!checkObj(obj))
      return

    let oldValue = ::get_option(USEROPT_TANK_SKIN_CONDITION).value
    let newValue = obj.getValue()
    if (oldValue == newValue)
      return

    if (!havePremium.value) {
      obj.setValue(oldValue)
      this.guiScene.performDelayed(this, @()
        this.isValid() && this.askBuyPremium(Callback(this.updateSkinSliders, this)))
      return
    }

    this.updateSkinConditionValue(newValue, obj)
  }

  function askBuyPremium(afterCloseFunc) {
    let msgText = loc("msgbox/noEntitlement/PremiumAccount")
    this.msgBox("no_premium", msgText,
         [["ok", @() this.startOnlineShop("premium", afterCloseFunc) ],
         ["cancel", @() null ]], "ok", { checkDuplicateId = true })
  }

  function updateSkinConditionValue(value, obj) {
    let textObj = this.scene.findObject("value_" + (obj?.id ?? ""))
    if (!checkObj(textObj))
      return

    textObj.setValue(((value + 100) / 2).tostring() + "%")
    set_tank_skin_condition(value)
  }

  function onChangeTankCamoScale(obj) {
    if (!checkObj(obj))
      return

    let textObj = this.scene.findObject("value_" + (obj?.id ?? ""))
    if (checkObj(textObj)) {
      let value = obj.getValue()
      set_tank_camo_scale(value / TANK_CAMO_SCALE_SLIDER_FACTOR)
      textObj.setValue((get_tank_camo_scale_result_value() * 100 + 0.5).tointeger().tostring() + "%")
    }
  }

  function onChangeTankCamoRotation(obj) {
    if (!checkObj(obj))
      return

    let textObj = this.scene.findObject("value_" + (obj?.id ?? ""))
    if (checkObj(textObj)) {
      let value = obj.getValue()
      let visualValue = value * 180 / 100
      textObj.setValue((visualValue > 0 ? "+" : "") + visualValue.tostring())
      set_tank_camo_rotation(value)
    }
  }

  function updateAttachablesSlots() {
    if (!this.access_Attachables)
      return

    let view = { isTooltipByHold = showConsoleButtons.value, buttons = [] }
    for (local i = 0; i < decoratorTypes.ATTACHABLES.getMaxSlots(); i++) {
      let button = this.getViewButtonTable(i, decoratorTypes.ATTACHABLES)
      button.id = $"slot_attach_{i}"
      button.onClick = "onAttachableSlotClick"
      button.onDblClick = "onAttachableSlotDoubleClick"
      button.onDeleteClick = "onDeleteAttachable"
      view.buttons.append(button)
    }

    let dObj = this.scene.findObject("attachable_div")
    if (!checkObj(dObj))
      return

    let attachListObj = dObj.findObject("slots_attachable_list")
    if (!checkObj(attachListObj))
      return

    dObj.show(true)
    let data = handyman.renderCached("%gui/commonParts/imageButton.tpl", view)

    this.guiScene.replaceContentFromText(attachListObj, data, data.len(), this)
    attachListObj.setValue(this.curAttachSlot)
  }

  function updateDecalSlots() {
    let view = { isTooltipByHold = showConsoleButtons.value, buttons = [] }
    for (local i = 0; i < decoratorTypes.DECALS.getMaxSlots(); i++) {
      let button = this.getViewButtonTable(i, decoratorTypes.DECALS)
      button.id = $"slot_{i}"
      button.onClick = "onDecalSlotClick"
      button.onDblClick = "onDecalSlotDoubleClick"
      button.onDeleteClick = "onDeleteDecal"
      view.buttons.append(button)
    }

    let dObj = this.scene.findObject("slots_list")
    if (checkObj(dObj)) {
      let data = handyman.renderCached("%gui/commonParts/imageButton.tpl", view)
      this.guiScene.replaceContentFromText(dObj, data, data.len(), this)
    }

    dObj.setValue(this.curSlot)
  }

  function updateFlagSlots() {
    let view = { isTooltipByHold = showConsoleButtons.value, buttons = [] }
    for (local i = 0; i < decoratorTypes.FLAGS.getMaxSlots(); i++) {
      let button = this.getViewButtonTable(i, decoratorTypes.FLAGS)
      button.id = $"slot_flag_{i}"
      button.onClick = "onFlagSlotClick"
      view.buttons.append(button)
    }

    let dObj = this.scene.findObject("flagslots_div")
    if (!checkObj(dObj))
      return

    let flagListObj = dObj.findObject("slots_flag_list")
    if (!checkObj(flagListObj))
      return

    dObj.show(true)
    let data = handyman.renderCached("%gui/commonParts/imageButton.tpl", view)

    this.guiScene.replaceContentFromText(flagListObj, data, data.len(), this)
    flagListObj.setValue(this.curFlagSlot)
  }

  function getViewButtonTable(slotIdx, decoratorType) {
    let canEditDecals = this.isUnitOwn && this.previewSkinId == null
    let slot = this.getSlotInfo(slotIdx, false, decoratorType)
    let decalId = slot.decalId
    let decorator = getDecorator(decalId, decoratorType)
    let slotRatio = clamp(decoratorType.getRatio(decorator), 0.5, 2)
    local buttonTooltip = slot.isEmpty ? loc(decoratorType.emptySlotLocId) : ""
    if (!this.isUnitOwn)
      buttonTooltip = "#mainmenu/decalUnitLocked"
    else if (!canEditDecals)
      buttonTooltip = "#mainmenu/decalSkinLocked"
    else if (!slot.unlocked) {
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
      statusLock = slot.unlocked ? getDecorLockStatusText(decorator, this.unit)
        : hasFeature("EnablePremiumPurchase") ? "noPremium_" + slotRatio
        : "achievement"
      unlocked = slot.unlocked && (!decorator || decorator.isUnlocked())
      emptySlot = slot.isEmpty || !decorator
      image = decoratorType.getImage(decorator)
      rarityColor = decorator?.isRare() ? decorator.getRarityColor() : null
      tooltipText = buttonTooltip
      tooltipId = slot.isEmpty ? null : DECORATION.getTooltipId(decalId, decoratorType.unlockedItemType,
        decoratorType == decoratorTypes.FLAGS && this.isDefaultFlag(decalId) ? { hideUnlockInfo = true } : null)
      tooltipOffset = "1@bw, 1@bh + 0.1@sf"
    }
  }

  onSlotsHoverChange = @() this.updateButtons()

  function updateButtons(decoratorType = null, needUpdateSlotDivs = true) {
    let isGift = isUnitGift(this.unit)
    local canBuyOnline = ::canBuyUnitOnline(this.unit)
    let canBuyNotResearchedUnit = canBuyNotResearched(this.unit)
    let canBuyIngame = !canBuyOnline && (::canBuyUnit(this.unit) || canBuyNotResearchedUnit)
    let canFindUnitOnMarketplace = !canBuyOnline && !canBuyIngame && ::canBuyUnitOnMarketplace(this.unit)

    if (isGift && canUseIngameShop() && getShopItemsTable().len() == 0) {
      //Override for ingameShop.
      //There is rare posibility, that shop data is empty.
      //Because of external error.
      canBuyOnline = false
    }

    local bObj = this.showSceneBtn("btn_buy", canBuyIngame)
    if (canBuyIngame && checkObj(bObj)) {
      let price = canBuyNotResearchedUnit ? this.unit.getOpenCost() : ::getUnitCost(this.unit)
      placePriceTextToButton(this.scene, "btn_buy", loc("mainmenu/btnOrder"), price)

      ::showUnitDiscount(bObj.findObject("buy_discount"), this.unit)
    }

    let bOnlineObj = this.showSceneBtn("btn_buy_online", canBuyOnline)
    if (canBuyOnline && checkObj(bOnlineObj))
      ::showUnitDiscount(bOnlineObj.findObject("buy_online_discount"), this.unit)

    this.showSceneBtn("btn_marketplace_find_unit", canFindUnitOnMarketplace)

    local skinDecorator = null
    local skinCouponItemdefId = null

    if (this.isUnitOwn && this.previewSkinId && this.skinList) {
      let skinIndex = this.skinList.values.indexof(this.previewSkinId) ?? -1
      skinDecorator = this.skinList.decorators?[skinIndex]
      skinCouponItemdefId = skinDecorator?.getCouponItemdefId()
    }

    let canBuySkin = skinDecorator?.canBuyUnlock(this.unit) ?? false
    let canConsumeSkinCoupon = !canBuySkin &&
      (::ItemsManager.getInventoryItemById(skinCouponItemdefId)?.canConsume() ?? false)
    let canFindSkinOnMarketplace = !canBuySkin && !canConsumeSkinCoupon && skinCouponItemdefId != null

    this.showSceneBtn("btn_buy_skin", canBuySkin)
    this.showSceneBtn("hint_btn_buy_skin", canBuySkin)
    if (canBuySkin) {
      let price = skinDecorator.getCost()
      placePriceTextToButton(this.scene, "btn_buy_skin", loc("mainmenu/btnOrder"), price)
      placePriceTextToButton(this.scene, "hint_btn_buy_skin", loc("mainmenu/btnOrder"), price)
    }

    let canDoSkinUnlock = skinDecorator != null && !skinDecorator.isUnlocked()
      && canDoUnlock(skinDecorator.unlockBlk)
    this.showSceneBtn("btn_goto_skin_unlock", canDoSkinUnlock)
    this.showSceneBtn("hint_btn_goto_skin_unlock", canDoSkinUnlock)
    let skinHint = (canBuySkin && canDoSkinUnlock) ? loc("mainmenu/skinHintCanBuyOrUnlock")
      : canBuySkin ? loc("mainmenu/skinHintCanBuy")
      : canDoSkinUnlock ? loc("mainmenu/skinHintCanUnlock")
      : ""
    this.scene.findObject("skin_hint_text").setValue(skinHint)

    let can_testflight = ::isTestFlightAvailable(this.unit) && !this.decoratorPreview
    let can_createUserSkin = can_save_current_skin_template()

    bObj = this.scene.findObject("btn_load_userskin_sample")
    if (checkObj(bObj))
      bObj.inactiveColor = can_createUserSkin ? "no" : "yes"

    let isInEditMode = this.currentState & decoratorEditState.EDITING
    this.updateBackButton()

    if (decoratorType == null)
      decoratorType = this.currentType

    let focusedType = this.getCurrentFocusedType()
    let focusedSlot = this.getSlotInfo(this.getCurrentDecoratorSlot(focusedType), true, focusedType)

    bObj = this.scene.findObject("btn_toggle_damaged")
    let isDmgSkinPreviewMode = checkObj(bObj) && bObj.getValue()

    let usableSkinsCount = (this.skinList?.access ?? []).filter(@(a) a.isOwn).len()

    showObjectsByTable(this.scene, {
          btn_go_to_collection = showConsoleButtons.value && !isInEditMode && this.decorMenu?.isOpened
            && isCollectionItem(this.decorMenu?.getSelectedDecor())

          btn_apply = this.currentState & decoratorEditState.EDITING

          btn_testflight = !isInEditMode && !this.decorMenu?.isOpened && can_testflight
          btn_info       = !isInEditMode && !this.decorMenu?.isOpened && ::isUnitDescriptionValid(this.unit) && !this.access_WikiOnline
          btn_info_online = !isInEditMode && !this.decorMenu?.isOpened && ::isUnitDescriptionValid(this.unit) && this.access_WikiOnline
          btn_sec_weapons    = !isInEditMode && !this.decorMenu?.isOpened &&
            needSecondaryWeaponsWnd(this.unit) && isUnitHaveSecondaryWeapons(this.unit)

          btn_decal_edit   = showConsoleButtons.value && !isInEditMode && !this.decorMenu?.isOpened && !focusedSlot.isEmpty && focusedSlot.unlocked
          btn_decal_delete = showConsoleButtons.value && !isInEditMode && !this.decorMenu?.isOpened && !focusedSlot.isEmpty && focusedSlot.unlocked

          btn_marketplace_consume_coupon_skin = !this.previewMode && canConsumeSkinCoupon
          btn_marketplace_find_skin = !this.previewMode && canFindSkinOnMarketplace

          skins_div = !isInEditMode && !this.decorMenu?.isOpened && this.access_Skins
          user_skins_block = !this.previewMode && this.access_UserSkins
          tank_skin_settings = !this.previewMode && (this.isUnitTank || this.isUnitShipOrBoat)

          previewed_decorator_div  = !isInEditMode && this.decoratorPreview
          previewed_decorator_unit = !isInEditMode && this.decoratorPreview && this.initialUnitId && this.initialUnitId != this.unit?.name

          decor_layout_presets = !isInEditMode && !this.decorMenu?.isOpened && this.isUnitOwn &&
            hasFeature("CustomizationLayoutPresets") && usableSkinsCount > 1 &&
            !this.previewMode && !this.previewSkinId

          dmg_skin_div = hasFeature("DamagedSkinPreview") && !isInEditMode && !this.decorMenu?.isOpened
          dmg_skin_buttons_div = isDmgSkinPreviewMode && (this.unit.isAir() || this.unit.isHelicopter())
    })


    let isVisibleSuggestedSkin = needSuggestSkin(this.unit.name, this.previewSkinId)
    let suggestedSkinObj = this.showSceneBtn("suggested_skin", isVisibleSuggestedSkin)
    if (isVisibleSuggestedSkin) {
      showObjById("btn_suggested_skin_find", canFindSkinOnMarketplace, suggestedSkinObj)
      showObjById("btn_suggested_skin_exchange", canConsumeSkinCoupon, suggestedSkinObj)
      let textArr = [loc("suggested_skin/info")]
      if (canFindSkinOnMarketplace)
        textArr.append(loc("suggested_skin/find"))
      suggestedSkinObj.findObject("suggested_skin_info_text").setValue("\n".join(textArr))
    }

    if (this.unitInfoPanelWeak?.isValid() ?? false)
      this.unitInfoPanelWeak.onSceneActivate(!isInEditMode && !this.decorMenu?.isOpened && !isDmgSkinPreviewMode)

    if (needUpdateSlotDivs)
      this.updateSlotsDivsVisibility(decoratorType)

    let isHangarLoaded = hangar_is_model_loaded()
    ::enableBtnTable(this.scene, {
          decalslots_div     = isHangarLoaded
          slots_list         = isHangarLoaded
          skins_navigator    = isHangarLoaded
          slots_flag_list    = isHangarLoaded
          tank_skin_settings = isHangarLoaded
    })

    this.updateDecoratorActions(isInEditMode, decoratorType)
    this.scene.findObject("gamercard_div")["gamercardSkipNavigation"] = isInEditMode ? "yes" : "no"
    ::update_gamercards()
  }

  function updateBackButton() {
    let bObj = this.scene.findObject("btn_back")
    if (!bObj?.isValid())
      return

    if (this.currentState & decoratorEditState.EDITING) {
      bObj.text = loc("mainmenu/btnCancel")
      bObj["skip-navigation"] = "yes"
      return
    }

    if ((this.currentState & decoratorEditState.SELECT) && showConsoleButtons.value) {
      if (this.decorMenu?.isCurCategoryListObjHovered()) {
        bObj.text = loc("mainmenu/btnCollapse")
        bObj["skip-navigation"] = "no"
        return
      }
    }

    bObj.text = loc("mainmenu/btnBack")
    bObj["skip-navigation"] = "no"
  }

  function isNavigationAllowed() {
    return !(this.currentState & decoratorEditState.EDITING)
  }

  function updateDecoratorActions(show, decoratorType) {
    let hasHints = decoratorType.canResize() || decoratorType.canRotate()
    let hintsObj = this.showSceneBtn("decals_hint", hasHints && show)
    if (hasHints && show && checkObj(hintsObj)) {
      showObjectsByTable(hintsObj, {
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
      this.updateDecoratorActionBtnStates()
  }

  function updateDecoratorActionBtnStates() {
    // TwoSided
    local obj = this.scene.findObject("two_sided_select")
    if (checkObj(obj))
      obj.setValue(this.getTwoSidedState())

    // Flip
    obj = this.scene.findObject("btn_toggle_mirror")
    if (checkObj(obj)) {
      let enabled = get_mirror_current_decal()
      let icon = "#ui/gameuiskin#btn_flip_decal" + (enabled ? "_active" : "") + ".svg"
      let iconObj = obj.findObject("btn_toggle_mirror_img")
      iconObj["background-image"] = icon
      iconObj.getParent().active = enabled ? "yes" : "no"
    }
  }

  function updateSlotsDivsVisibility(decoratorType = null) {
    let inBasicMode = this.currentState & decoratorEditState.NONE
    let showDecalsSlotDiv = this.access_Decals
      && (inBasicMode || (decoratorType == decoratorTypes.DECALS && (this.currentState & decoratorEditState.SELECT)))

    let showAttachableSlotsDiv = this.access_Attachables
      && (inBasicMode || (decoratorType == decoratorTypes.ATTACHABLES && (this.currentState & decoratorEditState.SELECT)))

    let showFlagsSlotDiv = this.access_Flags
      && (inBasicMode || (decoratorType == decoratorTypes.FLAGS && (this.currentState & decoratorEditState.SELECT)))

    showObjectsByTable(this.scene, {
      decalslots_div = showDecalsSlotDiv
      attachable_div = showAttachableSlotsDiv
      flagslots_div = showFlagsSlotDiv
    })
  }

  function updateUnitStatus() {
    let obj = this.scene.findObject("unit_status")
    if (!checkObj(obj))
      return
    let isShow = this.previewMode & (PREVIEW_MODE.UNIT | PREVIEW_MODE.SKIN)
    obj.show(isShow)
    if (!isShow)
      return
    obj.findObject("icon")["background-image"] = this.isUnitOwn ? "ui/gameuiskin#favorite" : "ui/gameuiskin#locked.svg"
    let textObj = obj.findObject("text")
    textObj.setValue(loc(this.isUnitOwn ? "conditions/unitExists" : "weaponry/unit_not_bought"))
    textObj.overlayTextColor = this.isUnitOwn ? "good" : "bad"
  }

  function updatePreviewedDecoratorInfo() {
    if (this.previewMode != PREVIEW_MODE.DECORATOR)
      return

    let isUnitAutoselected = this.initialUnitId && this.initialUnitId != this.unit?.name
    local obj = this.showSceneBtn("previewed_decorator_unit", isUnitAutoselected)
    if (obj && isUnitAutoselected)
      obj.findObject("label").setValue(loc("decoratorPreview/autoselectedUnit", {
          previewUnit = colorize("activeTextColor", getUnitName(this.unit))
          hangarUnit  = colorize("activeTextColor", getUnitName(this.initialUnitId))
        }) + " " + loc("decoratorPreview/autoselectedUnit/desc", {
          preview       = loc("mainmenu/btnPreview")
          customization = loc("mainmenu/btnShowroom")
        }))

    obj = this.showSceneBtn("previewed_decorator", true)
    if (obj) {
      let txtApplyDecorator = loc("decoratorPreview/applyManually/" + this.currentType.resourceType)
      let labelObj = obj.findObject("label")
      labelObj.setValue(txtApplyDecorator + loc("ui/colon"))

      let params = {
        showAsTrophyContent = true
        onClick = "onDecoratorItemClick"
        onDblClick = "onDecalItemDoubleClick"
        onCollectionBtnClick = isCollectionItem(this.decoratorPreview)
          ? "onCollectionIconClick"
          : null
      }
      let view = {
        isTooltipByHold = showConsoleButtons.value,
        buttons = [ getDecorButtonView(this.decoratorPreview, this.unit, params) ]
      }
      let slotsObj = obj.findObject("decorator_preview_div")
      let markup = handyman.renderCached("%gui/commonParts/imageButton.tpl", view)
      this.guiScene.replaceContentFromText(slotsObj, markup, markup.len(), this)
    }
  }

  function onUpdate(_obj, _dt) {
    this.showLoadingRot(!hangar_is_model_loaded())
  }

  function getCurrentDecoratorSlot(decoratorType) {
    if (decoratorType == decoratorTypes.UNKNOWN)
      return -1

    if (decoratorType == decoratorTypes.ATTACHABLES)
      return this.curAttachSlot

    if (decoratorType == decoratorTypes.FLAGS)
      return this.curFlagSlot

    return this.curSlot
  }

  function setCurrentDecoratorSlot(slotIdx, decoratorType) {
    if (decoratorType == decoratorTypes.DECALS)
      this.curSlot = slotIdx
    else if (decoratorType == decoratorTypes.ATTACHABLES)
      this.curAttachSlot = slotIdx
    else if (decoratorType == decoratorTypes.FLAGS)
      this.curFlagSlot = slotIdx
  }

  function onSkinOptionSelect(_obj) {
    if (!checkObj(this.scene))
      return

    this.updateButtons()
  }

  function onDecalSlotSelect(obj) {
    if (!checkObj(obj))
      return

    let slotId = obj.getValue()

    this.setCurrentDecoratorSlot(slotId, decoratorTypes.DECALS)
    this.updateButtons(decoratorTypes.DECALS)
  }

  function onDecalSlotActivate(obj) {
    let value = obj.getValue()
    let childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (checkObj(childObj))
      this.onDecalSlotClick(childObj)
  }

  function onAttachSlotSelect(obj) {
    if (!checkObj(obj))
      return

    let slotId = obj.getValue()

    this.setCurrentDecoratorSlot(slotId, decoratorTypes.ATTACHABLES)
    this.updateButtons(decoratorTypes.ATTACHABLES)
  }

  function onFlagSlotSelect(obj) {
    if (!checkObj(obj))
      return

    let slotId = obj.getValue()

    this.setCurrentDecoratorSlot(slotId, decoratorTypes.FLAGS)
    this.updateButtons(decoratorTypes.FLAGS)
  }

  function onAttachableSlotActivate(obj) {
    let value = obj.getValue()
    let childObj = (value >= 0 && value < obj.childrenCount()) ? obj.getChild(value) : null
    if (!checkObj(childObj))
      return

    this.onAttachableSlotClick(childObj)
  }

  function onDecalSlotCancel(_obj) {
    this.onBtnBack()
  }

  function openDecorationsListForSlot(slotId, actionObj, decoratorType) {
    if (!this.checkCurrentUnit())
      return
    if (!this.checkCurrentSkin())
      return
    if (!this.checkSlotIndex(slotId, decoratorType))
      return

    let prevSlotId = actionObj.getParent().getValue()
    if (this.decorMenu?.isOpened && slotId == prevSlotId)
      return

    this.setCurrentDecoratorSlot(slotId, decoratorType)
    this.currentState = decoratorEditState.SELECT

    if (prevSlotId != slotId)
      actionObj.getParent().setValue(slotId)
    else
      this.updateButtons(decoratorType)

    let slot = this.getSlotInfo(slotId, false, decoratorType)
    if (!slot.isEmpty && decoratorType != decoratorTypes.ATTACHABLES
                      && decoratorType != decoratorTypes.DECALS
                      && decoratorType != decoratorTypes.FLAGS)
      decoratorType.specifyEditableSlot(slotId)

    this.generateDecorationsList(slot, decoratorType)
  }

  function checkCurrentUnit() {
    if (this.isUnitOwn)
      return true

    local onOkFunc = function() {}
    if (::canBuyUnit(this.unit))
      onOkFunc = (@(unit) function() { ::buyUnit(unit) })(this.unit) //-ident-hides-ident

    this.msgBox("unit_locked", loc("decals/needToBuyUnit"), [["ok", onOkFunc ]], "ok")
    return false
  }

  function checkCurrentSkin() {
    if (u.isEmpty(this.previewSkinId) || !this.skinList)
      return true

    let skinIndex = u.find_in_array(this.skinList.values, this.previewSkinId, 0)
    let skinDecorator = this.skinList.decorators[skinIndex]

    if (skinDecorator.canBuyUnlock(this.unit)) {
      let cost = skinDecorator.getCost()
      let priceText = cost.getTextAccordingToBalance()
      let msgText = ::warningIfGold(
        loc("decals/needToBuySkin",
          { purchase = skinDecorator.getName(), cost = priceText }),
        skinDecorator.getCost())
      this.msgBox("skin_locked", msgText,
        [["ok", (@(previewSkinId) function() { this.buySkin(previewSkinId, cost) })(this.previewSkinId) ], //-ident-hides-ident
        ["cancel", function() {} ]], "ok")
    }
    else
      this.msgBox("skin_locked", loc("decals/skinLocked"), [["ok", function() {} ]], "ok")
    return false
  }

  function checkSlotIndex(slotIdx, decoratorType) {
    if (slotIdx < 0)
      return false

    if (slotIdx < decoratorType.getAvailableSlots(this.unit))
      return true

    if (hasFeature("EnablePremiumPurchase")) {
      this.msgBox("no_premium", loc("decals/noPremiumAccount"),
           [["ok", function() {
               this.onOnlineShopPremium()
               this.saveDecorators(true)
            }],
           ["cancel", function() {} ]], "ok")
    }
    else {
      this.msgBox("premium_not_available", loc("charServer/notAvailableYet"),
           [["cancel"]], "cancel")
    }
    return false
  }

  function onAttachableSlotClick(obj) {
    if (!checkObj(obj))
      return

    let slotName = ::getObjIdByPrefix(obj, "slot_attach_")
    let slotId = slotName ? slotName.tointeger() : -1

    this.openDecorationsListForSlot(slotId, obj, decoratorTypes.ATTACHABLES)
  }

  function onDecalSlotClick(obj) {
    let slotName = ::getObjIdByPrefix(obj, "slot_")
    let slotId = slotName ? slotName.tointeger() : -1
    this.openDecorationsListForSlot(slotId, obj, decoratorTypes.DECALS)
  }

  function onFlagSlotClick(obj) {
    if (!checkObj(obj))
      return
    this.openDecorationsListForSlot(0, obj, decoratorTypes.FLAGS)
  }

  function onDecalSlotDoubleClick(_obj) {
    this.onDecoratorSlotDoubleClick(decoratorTypes.DECALS)
  }

  function onAttachableSlotDoubleClick(_obj) {
    this.onDecoratorSlotDoubleClick(decoratorTypes.ATTACHABLES)
  }

  function onDecoratorSlotDoubleClick(decoratorType) {
    let slotIdx = this.getCurrentDecoratorSlot(decoratorType)
    let slotInfo = this.getSlotInfo(slotIdx, false, decoratorType)
    if (slotInfo.isEmpty)
      return
    let decorator = getDecorator(slotInfo.decalId, decoratorType)
    this.currentState = decoratorEditState.REPLACE
    this.enterEditDecalMode(slotIdx, decorator)
  }

  function generateDecorationsList(slot, decoratorType) {
    if (u.isEmpty(slot)
        || decoratorType == decoratorTypes.UNKNOWN
        || (this.currentState & decoratorEditState.NONE))
      return

    this.currentType = decoratorType

    this.decorMenu?.updateHandlerData(this.currentType, this.unit, slot.decalId, this.preSelectDecorator?.id,
      decoratorType.unlockedItemType == UNLOCKABLE_SHIP_FLAG ? [this.defaultFlag] : [] )
    this.decorMenu?.createCategories()

    this.showDecoratorsList()

    local selCategoryId = ""
    local selGroupId = ""
    if (this.preSelectDecorator) {
      selCategoryId = this.preSelectDecorator.category
      selGroupId = this.preSelectDecorator.group == "" ? "other" : this.preSelectDecorator.group
    }
    else if (slot.isEmpty) {
      let path = this.decorMenu?.getSavedPath()
      selCategoryId = path?[0] ?? ""
      selGroupId = path?[1] ?? ""
    }
    else {
      let decal = getDecorator(slot.decalId, decoratorType)
      if (decal) {
        selCategoryId = decal.category
        selGroupId = decal.group == "" ? "other" : decal.group
      }
    }

    let isSelected = this.decorMenu?.selectCategory(selCategoryId, selGroupId)
    if (!isSelected)
      this.updateButtons(decoratorType)
  }

  function openCollections(decoratorId) {
    openCollectionsWnd({ selectedDecoratorId = decoratorId })
    this.updateBackButton()
  }

  onEventDecorMenuCollectionIconClick = @(p) this.openCollections(p.decoratorId)
  onCollectionIconClick = @(obj) this.openCollections(obj.holderId)

  function onCollectionButtonClick() {
    let selectedDecorator = this.decorMenu?.getSelectedDecor()
    if (!isCollectionItem(selectedDecorator))
      return

    openCollectionsWnd({ selectedDecoratorId = selectedDecorator.id })
    this.updateBackButton()
  }

  onEventDecorMenuItemSelect = @(_) this.updateButtons(null, false)
  onEventDecorMenuListHoverChange = @(_) this.updateBackButton()
  onEventDecorMenuFilterCancel = @(_) this.onBtnBack()

  function onDecoratorItemClick(obj) {
    let decorator = this.decorMenu?.getDecoratorByObj(obj, this.currentType)
    if (!decorator)
      return
    this.onEventDecorMenuItemClick({ decorator })
  }

  function onEventDecorMenuItemClick(p) {
    let { decorator } = p
    if (!this.decoratorPreview && decorator.isOutOfLimit(this.unit))
      return ::g_popups.add("", loc("mainmenu/decoratorExceededLimit", { limit = decorator.limit }))

    let curSlotIdx = this.getCurrentDecoratorSlot(this.currentType)
    let isDecal = this.currentType == decoratorTypes.DECALS
    if (!this.decoratorPreview && isDecal) {
      let isRestrictionShown = showDecoratorAccessRestriction(decorator, this.unit)
      if (isRestrictionShown)
        return

      if (decorator.canBuyUnlock(this.unit))
        return this.askBuyDecorator(decorator, @() this.enterEditDecalMode(curSlotIdx, decorator))

      if (decorator.canBuyCouponOnMarketplace(this.unit))
        return this.askMarketplaceCouponAction(decorator)

      if (!decorator.isUnlocked())
        return
    }

    this.isDecoratorItemUsed = true

    if (!this.decoratorPreview && isDecal) {
      //getSlotInfo is too slow for decals (~150ms)(because of code func get_decal_in_slot),
      // so it better to use as last check, so not to worry with lags
      let slotInfo = this.getSlotInfo(curSlotIdx, false, this.currentType)
      if (!slotInfo.isEmpty && decorator.id != slotInfo.decalId) {
        this.currentState = decoratorEditState.REPLACE
        this.currentType.replaceDecorator(curSlotIdx, decorator.id)
        return this.installDecorationOnUnit(decorator)
      }
    }

    this.currentState = decoratorEditState.ADD
    this.enterEditDecalMode(curSlotIdx, decorator)
  }

  function onEventDecorMenuItemDblClick(p) {
    let decor = p.decorator
    if (!decor.canUse(this.unit))
      return

    let slotIdx = this.getCurrentDecoratorSlot(this.currentType)
    let slotInfo = this.getSlotInfo(slotIdx, false, this.currentType)
    if (!slotInfo.isEmpty)
      this.enterEditDecalMode(slotIdx, decor)
  }

  function onDecalItemDoubleClick(obj) {
    let decorator = this.decorMenu?.getDecoratorByObj(obj, this.currentType)
    if (!decorator)
      return

    this.onEventDecorMenuItemDblClick({ decorator })
  }

  function onBtnAccept() {
    this.stopDecalEdition(true)
  }

  function onEventDecalsMenuClosed(_obj) {
    this.onBtnBack()
  }

  function onBtnBack() {
    if (this.currentState & decoratorEditState.NONE)
      return this.goBack()

    if (this.currentState & decoratorEditState.SELECT) {
      if (this.decorMenu?.isCurCategoryListObjHovered()) {
        this.decorMenu.collapseOpenedCategory()
        this.updateBackButton()
        return
      }

      return this.onBtnCloseDecalsMenu()
    }

    this.editableDecoratorId = null
    if (this.currentType == decoratorTypes.ATTACHABLES
        && (this.currentState & (decoratorEditState.REPLACE | decoratorEditState.EDITING | decoratorEditState.PURCHASE)))
      hangar_force_reload_model()
    this.stopDecalEdition()
  }

  function buyDecorator(decorator, cost, afterPurchDo = null) {
    if (!::check_balance_msgBox(decorator.getCost()))
      return false

    decorator.decoratorType.save(this.unit.name, false)

    let afterSuccessFunc = Callback( function() {
      ::update_gamercards()
      this.decorMenu?.updateSelectedCategory(decorator)
      if (afterPurchDo)
        afterPurchDo()
    }, this)

    decorator.decoratorType.buyFunc(this.unit.name, decorator.id, cost, afterSuccessFunc)
    return true
  }

  function enterEditDecalMode(slotIdx, decorator) {
    if ((this.currentState & decoratorEditState.EDITING) || !decorator)
      return

    let decoratorType = decorator.decoratorType
    decoratorType.specifyEditableSlot(slotIdx)

    if (!decoratorType.enterEditMode(decorator.id))
      return

    this.currentState = decoratorEditState.EDITING
    this.editableDecoratorId = decorator.id
    this.updateSceneOnEditMode(true, decoratorType)
  }

  function updateSceneOnEditMode(isInEditMode, decoratorType, contentUpdate = false) {
    if (decoratorType == decoratorTypes.DECALS)
      ::dmViewer.update()

    let slotInfo = this.getSlotInfo(this.getCurrentDecoratorSlot(decoratorType), true, decoratorType)
    if (contentUpdate) {
      this.updateSlotsBlockByType(decoratorType)
      if (this.isDecoratorItemUsed)
        this.generateDecorationsList(slotInfo, decoratorType)
    }

    this.showDecoratorsList()

    this.updateButtons(decoratorType)

    if (!isInEditMode)
      this.isDecoratorItemUsed = false
  }

  function stopDecalEdition(save = false) {
    if (!(this.currentState & decoratorEditState.EDITING))
      return
    let decorator = getDecorator(this.editableDecoratorId, this.currentType)
    if (!save || !decorator) {
      this.currentType.exitEditMode(false, false, Callback(this.afterStopDecalEdition, this))
      return
    }

    if (this.previewMode & PREVIEW_MODE.DECORATOR)
      return this.setDecoratorInSlot(decorator)

    if (decorator.canBuyUnlock(this.unit))
      return this.askBuyDecoratorOnExitEditMode(decorator)

    if (decorator.canBuyCouponOnMarketplace(this.unit))
      return this.askMarketplaceCouponActionOnExitEditMode(decorator)

    let isRestrictionShown = showDecoratorAccessRestriction(decorator, this.unit)
    if (isRestrictionShown)
      return

    this.setDecoratorInSlot(decorator)
    this.updateFlagName()
  }

  function askBuyDecoratorOnExitEditMode(decorator) {
    if (!this.currentType.exitEditMode(true, false,
              Callback( function() {
                          this.askBuyDecorator(decorator, function() {
                              save_current_attachables()
                              if(decorator.decoratorType == decoratorTypes.FLAGS ) {
                                this.updateFlagSlots()
                                this.updateFlagName()
                              }
                            })
                        }, this)))
      this.showFailedInstallPopup(decorator)
  }

  function askMarketplaceCouponActionOnExitEditMode(decorator) {
    if (!this.currentType.exitEditMode(true, false,
              Callback(@() this.askMarketplaceCouponAction(decorator), this)))
      this.showFailedInstallPopup(decorator)
  }

  function askBuyDecorator(decorator, afterPurchDo = null) {
    let cost = decorator.getCost()
    let msgText = ::warningIfGold(
      loc("shop/needMoneyQuestion_purchaseDecal",
        { purchase = colorize("userlogColoredText", decorator.getName()),
          cost = cost.getTextAccordingToBalance() }),
      decorator.getCost())
    this.msgBox("buy_decorator_on_preview", msgText,
      [["ok",  function() {
          this.currentState = decoratorEditState.PURCHASE
          if (!this.buyDecorator(decorator, cost, afterPurchDo))
            return this.forceResetInstalledDecorators()

          ::dmViewer.update()
          this.onFinishInstallDecoratorOnUnit(true)
        }],
      ["cancel", this.onMsgBoxCancel]
      ], "ok", { cancel_fn = this.onMsgBoxCancel })
  }

  function onMsgBoxCancel() {
    if ((this.currentState & decoratorEditState.SELECT) == 0)
      this.onBtnBack()
  }

  function askMarketplaceCouponAction(decorator) {
    let inventoryItem = ::ItemsManager.getInventoryItemById(decorator.getCouponItemdefId())
    if (inventoryItem?.canConsume() ?? false) {
      inventoryItem.consume(Callback(function(result) {
        if ((result?.success ?? false) == true)
          this.decorMenu?.updateSelectedCategory(decorator)
      }, this), null)
      return
    }

    let couponItem = ::ItemsManager.findItemById(decorator.getCouponItemdefId())
    if (!(couponItem?.hasLink() ?? false))
      return
    let couponName = colorize("activeTextColor", couponItem.getName())
    this.msgBox("go_to_marketplace", loc("msgbox/find_on_marketplace", { itemName = couponName }), [
        [ "find_on_marketplace", function() { couponItem.openLink(); this.onBtnBack() } ],
        [ "cancel", this.onMsgBoxCancel ]
      ], "find_on_marketplace", { cancel_fn = this.onMsgBoxCancel })
  }

  function forceResetInstalledDecorators() {
    this.currentType.removeDecorator(this.getCurrentDecoratorSlot(this.currentType), true)
    if (this.currentType == decoratorTypes.ATTACHABLES) {
      hangar_force_reload_model()
    }
    this.afterStopDecalEdition()
  }

  function setDecoratorInSlot(decorator) {
    if (!this.installDecorationOnUnit(decorator))
      return this.showFailedInstallPopup(decorator)

    if (this.currentType == decoratorTypes.DECALS)
      reqUnlockByClient("decal_applied")
  }

  function showFailedInstallPopup(decorator) {
    let attachAngle = acos(::hangar_get_attachable_tm()[1].y) * 180.0 / PI
    if (attachAngle >= decorator.maxSurfaceAngle)
      ::g_popups.add("", loc("mainmenu/failedInstallAttachableAngle",
        { angle = attachAngle.tointeger(), allowedAngle = decorator.maxSurfaceAngle }))
    else
      ::g_popups.add("", loc("mainmenu/failedInstallAttachable"))
  }

  function afterStopDecalEdition() {
    this.currentState = this.decorMenu?.isOpened ? decoratorEditState.SELECT : decoratorEditState.NONE
    this.updateSceneOnEditMode(false, this.currentType)
  }

  function installDecorationOnUnit(decorator) {
    let save = !!decorator && decorator.isUnlocked() && this.previewMode != PREVIEW_MODE.DECORATOR
    return this.currentType.exitEditMode(true, save,
      Callback(function () { this.onFinishInstallDecoratorOnUnit(true) }, this))
  }

  function onFinishInstallDecoratorOnUnit(isInstalled = false) {
    if (!isInstalled)
      return

    this.currentState = this.decorMenu?.isOpened ? decoratorEditState.SELECT : decoratorEditState.NONE
    this.updateSceneOnEditMode(false, this.currentType, true)
  }

  function onOnlineShopEagles() {
    if (hasFeature("EnableGoldPurchase"))
      this.startOnlineShop("eagles", this.afterReplenishCurrency, "customization")
    else
      showInfoMsgBox(loc("msgbox/notAvailbleGoldPurchase"))
  }

  function onOnlineShopLions() {
    this.startOnlineShop("warpoints", this.afterReplenishCurrency)
  }

  function onOnlineShopPremium() {
    this.startOnlineShop("premium", this.checkPremium)
  }

  function checkPremium() {
    if (!havePremium.value)
      return

    ::update_gamercards()
    this.updateMainGuiElements()
  }

  function afterReplenishCurrency() {
    if (!checkObj(this.scene))
      return

    this.updateMainGuiElements()
  }

  function onSkinChange(obj) {
    let skinNum = obj.getValue()
    if (!this.skinList || !(skinNum in this.skinList.values)) {
      debug_dump_stack()
      assert(false, "Error: try to set incorrect skin " + this.skinList + ", value = " + skinNum)
      return
    }

    let skinId = this.skinList.values[skinNum]
    let access = this.skinList.access[skinNum]

    if (this.isUnitOwn && access.isOwn && !this.previewMode) {
      let curSkinId = get_last_skin(this.unit.name)
      if (!this.previewSkinId && (skinId == curSkinId || (skinId == "" && curSkinId == "default")))
        return

      saveSeenSuggestedSkin(this.unit.name, this.previewSkinId)
      this.resetUserSkin(false)
      this.applySkin(skinId)
    }
    else if (access.isDownloadable) {
      // Starting skin download...
      showResource(skinId, "skin", Callback(this.onSkinReadyToShow, this))
    }
    else if (skinId != this.previewSkinId) {
      saveSeenSuggestedSkin(this.unit.name, this.previewSkinId)
      this.resetUserSkin(false)
      this.applySkin(skinId, true)
    }
  }

  onFlagChange = @(_obj) null

  function onSkinReadyToShow(unitId, skinId, result) {
    if (!result || !canStartPreviewScene(true, true) ||
      unitId != this.unit.name || (this.skinList?.values ?? []).indexof(skinId) == null)
        return

    previewedLiveSkinIds.append(getSkinId(unitId, skinId))
    ::g_delayed_actions.add(Callback(function() {
      this.resetUserSkin(false)
      this.applySkin(skinId, true)
    }, this), 100)
  }

  function onUserSkinChanged(obj) {
    let value = obj.getValue()
    let prevValue = ::get_option(USEROPT_USER_SKIN).value
    if (prevValue == value)
      return

    set_option(USEROPT_USER_SKIN, value)
    hangar_force_reload_model()
  }

  function resetUserSkin(needReloadModel = true) {
    if (this.previewMode)
      return

    this.initialUserSkinId = ""
    set_option(USEROPT_USER_SKIN, 0)

    if (needReloadModel)
      hangar_force_reload_model()
    else
      this.updateUserSkinList()
  }

  function applySkin(skinId, previewSkin = false) {
    if (previewSkin)
      apply_skin_preview(skinId)
    else {
      setLastSkin(this.unit.name, skinId, false)
      apply_skin(skinId)
    }

    this.previewSkinId = previewSkin ? skinId : null

    if (!previewSkin) {
      ::save_online_single_job(3210)
      ::save_profile(false)
    }
  }

  function setDmgSkinMode(enable) {
    let cObj = this.scene.findObject("btn_toggle_damaged")
    if (checkObj(cObj))
      cObj.setValue(enable)
  }

  function onToggleDmgSkinState(obj) {
    show_model_damaged(obj.getValue() ? 1 : 0)
  }

  function onToggleDamaged(obj) {
    if (this.unit.isAir() || this.unit.isHelicopter()) {
      hangar_set_dm_viewer_mode(obj.getValue() ? DM_VIEWER_EXTERIOR : DM_VIEWER_NONE)
      if (obj.getValue()) {
        let bObj = this.scene.findObject("dmg_skin_state")
        if (checkObj(bObj))
          bObj.setValue(get_loaded_model_damage_state(this.unit.name))
      }
      else
        show_model_damaged(MDS_ORIGINAL)
    }
    else
      show_model_damaged(obj.getValue() ? MDS_DAMAGED : MDS_UNDAMAGED)

    this.updateButtons()
  }

  function onGotoSkinUnlock() {
    let skinId = getSkinId(this.unit.name, this.previewSkinId)
    ::gui_start_profile({
      initialSheet = "UnlockSkin"
      initSkinId = skinId
    })
  }

  function onBuySkin() {
    let skinId = getSkinId(this.unit.name, this.previewSkinId)
    let previewSkinDecorator = getDecorator(skinId, decoratorTypes.SKINS)
    if (!previewSkinDecorator)
      return

    let cost = previewSkinDecorator.getCost()
    let msgText = ::warningIfGold(loc("shop/needMoneyQuestion_purchaseSkin",
                          { purchase = previewSkinDecorator.getName(),
                            cost = cost.getTextAccordingToBalance()
                          }), cost)

    this.msgBox("need_money", msgText,
          [["ok", function() {
            if (::check_balance_msgBox(cost))
              this.buySkin(this.previewSkinId, cost)
          }],
          ["cancel", function() {} ]], "ok")
  }

  function buySkin(skinName, cost) {
    let afterSuccessFunc = Callback( function() {
        ::update_gamercards()
        this.applySkin(skinName)
        this.updateMainGuiElements()
      }, this)

    decoratorTypes.SKINS.buyFunc(this.unit.name, skinName, cost, afterSuccessFunc)
  }

  function onBtnMarketplaceFindSkin(_obj) {
    let skinId = getSkinId(this.unit.name, this.previewSkinId)
    let skinDecorator = getDecorator(skinId, decoratorTypes.SKINS)
    let item = ::ItemsManager.findItemById(skinDecorator?.getCouponItemdefId())
    if (!item?.hasLink())
      return
    item.openLink()
  }

  function onBtnMarketplaceConsumeCouponSkin(_obj) {
    let skinId = getSkinId(this.unit.name, this.previewSkinId)
    let skinDecorator = getDecorator(skinId, decoratorTypes.SKINS)
    let itemdefId = skinDecorator?.getCouponItemdefId()
    let inventoryItem = ::ItemsManager.getInventoryItemById(itemdefId)
    if (!inventoryItem?.canConsume())
      return

    let skinName = this.previewSkinId
    inventoryItem.consume(Callback(function(result) {
      if (this == null || !result?.success)
        return
      this.applySkin(skinName)
      this.updateMainGuiElements()
    }, this), null)
  }

  function getSlotInfo(slotId, checkDecalsList = false, decoratorType = null) {
    local isValid = 0 <= slotId
    local decalId = ""
    if (checkDecalsList && this.decorMenu?.isOpened && slotId == this.getCurrentDecoratorSlot(decoratorType)) {
      let decal = this.decorMenu.getSelectedDecor()
      if (decal)
        decalId = decal.id
    }

    if (decalId == "" && isValid && decoratorType != null) {
      let liveryName = this.getSelectedBuiltinSkinId()
      decalId = decoratorType.getDecoratorNameInSlot(slotId, this.unit.name, liveryName, false) ?? ""
      if(this.access_Flags && decalId == "default" && decoratorType == decoratorTypes.FLAGS)
        decalId = this.defaultFlag
      isValid = isValid && slotId < decoratorType.getMaxSlots()
    }

    return {
      id = isValid ? slotId : -1
      unlocked = isValid && decoratorType != null && slotId < decoratorType.getAvailableSlots(this.unit)
      decalId = decalId
      isEmpty = !decalId.len()
    }
  }

  function showLoadingRot(flag) {
    if (this.isLoadingRot == flag)
      return

    this.isLoadingRot = flag
    this.scene.findObject("loading_rot").show(flag)

    this.updateMainGuiElements()
  }

  function onTestFlight() {
    if (!::g_squad_utils.canJoinFlightMsgBox({ isLeaderCanJoin = true }))
      return

    // TestFlight wnd can have a Slotbar, where unit can be changed.
    let afterCloseFunc = (@(owner, unit) function() { //-ident-hides-ident
      let newUnitName = getShowedUnitName()
      if (newUnitName == "")
        return setShowUnit(unit)

      if (unit.name != newUnitName) {
        ::cur_aircraft_name = newUnitName
        owner.unit = getAircraftByName(newUnitName)
        owner.previewSkinId = null
        if (owner && ("initMainParams" in owner) && owner.initMainParams)
          owner.initMainParams.call(owner)
      }
    })(this.owner, this.unit)

    this.saveDecorators(false)
    this.checkedNewFlight(function() {
      ::gui_start_testflight({ unit = this.unit, afterCloseFunc })
    })
  }

  function onBuy() {
    unitActions.buy(this.unit, "customization")
  }

  function onBtnMarketplaceFindUnit(_obj) {
    let item = ::ItemsManager.findItemById(this.unit.marketplaceItemdefId)
    if (!(item?.hasLink() ?? false))
      return
    item.openLink()
  }


  function onEventUnitRented(_params) {
    this.initMainParams()
  }

  function onBtnDecoratorEdit() {
    this.currentType = this.getCurrentFocusedType()
    let curSlotIdx = this.getCurrentDecoratorSlot(this.currentType)
    let slotInfo = this.getSlotInfo(curSlotIdx, true, this.currentType)
    let decorator = getDecorator(slotInfo.decalId, this.currentType)
    this.enterEditDecalMode(curSlotIdx, decorator)
  }

  function onBtnDeleteDecal() {
    let decoratorType = this.getCurrentFocusedType()
    this.deleteDecorator(decoratorType, this.getCurrentDecoratorSlot(decoratorType))
  }

  function onDeleteDecal(obj) {
    if (!checkObj(obj))
      return

    let slotName = ::getObjIdByPrefix(obj.getParent(), "slot_")
    let slotId = slotName.tointeger()

    this.deleteDecorator(decoratorTypes.DECALS, slotId)
  }

  function onDeleteAttachable(obj) {
    if (!checkObj(obj))
      return

    let slotName = ::getObjIdByPrefix(obj.getParent(), "slot_attach_")
    let slotId = slotName.tointeger()

    this.deleteDecorator(decoratorTypes.ATTACHABLES, slotId)
  }

  function deleteDecorator(decoratorType, slotId) {
    let slotInfo = this.getSlotInfo(slotId, false, decoratorType)
    this.msgBox("delete_decal", loc(decoratorType.removeDecoratorLocId, { name = decoratorType.getLocName(slotInfo.decalId) }),
    [
      ["ok", function() {
          decoratorType.removeDecorator(slotInfo.id, true)
          ::save_profile(false)

          this.generateDecorationsList(slotInfo, decoratorType)
          this.updateSlotsBlockByType(decoratorType)
          this.updateButtons(decoratorType, false)
        }
      ],
      ["cancel", function() {} ]
    ], "cancel")
  }

  function updateSlotsBlockByType(decoratorType = decoratorTypes.UNKNOWN) {
    let all = decoratorType == decoratorTypes.UNKNOWN
    if (all || decoratorType == decoratorTypes.ATTACHABLES)
      this.updateAttachablesSlots()

    if (all || decoratorType == decoratorTypes.DECALS)
      this.updateDecalSlots()

    if (all || decoratorType == decoratorTypes.FLAGS)
      this.updateFlagSlots()

    this.updatePenaltyText()
  }

  function onDecorLayoutPresets(_obj) {
    decorLayoutPresets.open(this.unit, this.getSelectedBuiltinSkinId())
  }

  function onSecWeaponsInfo(_obj) {
    weaponryPresetsModal.open({ unit = this.unit })
  }

  function getTwoSidedState() {
    let isTwoSided = get_hangar_abs()
    let isOppositeMirrored = get_hangar_opposite_mirrored()
    return !isTwoSided ? decalTwoSidedMode.OFF
         : !isOppositeMirrored ? decalTwoSidedMode.ON
         : decalTwoSidedMode.ON_MIRRORED
  }

  function setTwoSidedState(idx) {
    let isTwoSided = get_hangar_abs()
    let isOppositeMirrored = get_hangar_opposite_mirrored()
    let needTwoSided  = idx != decalTwoSidedMode.OFF
    let needOppositeMirrored = idx == decalTwoSidedMode.ON_MIRRORED
    if (needTwoSided != isTwoSided)
      hangar_toggle_abs()
    if (needOppositeMirrored != isOppositeMirrored)
      set_hangar_opposite_mirrored(needOppositeMirrored)
  }

  function onMirror() { // Flip
    mirror_current_decal()
    this.updateDecoratorActionBtnStates()
  }

  function onTwoSided() { // TwoSided
    let obj = this.scene.findObject("two_sided_select")
    if (checkObj(obj))
      obj.setValue((obj.getValue() + 1) % obj.childrenCount())
  }

  function onTwoSidedSelect(obj) { // TwoSided select
    this.setTwoSidedState(obj.getValue())
  }

  function onInfo() {
    if (hasFeature("WikiUnitInfo"))
      openUrl(format(loc("url/wiki_objects"), this.unit.name), false, false, "customization_wnd")
    else
      showInfoMsgBox(colorize("activeTextColor", getUnitName(this.unit, false)) + "\n" + loc("profile/wiki_link"))
  }

  function clearCurrentDecalSlotAndShow() {
    if (!checkObj(this.scene))
      return

    this.updateSlotsBlockByType()
  }

  function saveDecorators(withProgressBox = false) {
    if (this.previewMode)
      return
    decoratorTypes.DECALS.save(this.unit.name, withProgressBox)
    decoratorTypes.ATTACHABLES.save(this.unit.name, withProgressBox)
    decoratorTypes.FLAGS.save(this.unit.name, withProgressBox)
  }

  function showDecoratorsList() {
    let show = !!(this.currentState & decoratorEditState.SELECT)

    let slotsObj = this.scene.findObject(this.currentType.listId)
    if (checkObj(slotsObj)) {
      let sel = slotsObj.getValue()
      for (local i = 0; i < slotsObj.childrenCount(); i++) {
        let selectedItem = sel == i && show
        slotsObj.getChild(i).highlighted = selectedItem ? "yes" : "no"
      }
    }

    notify_decal_menu_visibility(show)
    this.decorMenu?.show(show)
  }

  function onScreenClick() {
    if(this.currentType.unlockedItemType == UNLOCKABLE_SHIP_FLAG)
      return

    if (this.currentState == decoratorEditState.NONE)
      return

    if (this.currentState == decoratorEditState.EDITING)
      return this.stopDecalEdition(true)

    let curSlotIdx = this.getCurrentDecoratorSlot(this.currentType)
    let curSlotInfo = this.getSlotInfo(curSlotIdx, false, this.currentType)
    if (curSlotInfo.isEmpty)
      return

    let curSlotDecoratorId = curSlotInfo.decalId
    if (curSlotDecoratorId == "")
      return

    let curSlotDecorator = getDecorator(curSlotDecoratorId, this.currentType)
    this.enterEditDecalMode(curSlotIdx, curSlotDecorator)
  }

  function onBtnCloseDecalsMenu() {
    this.currentState = decoratorEditState.NONE
    this.showDecoratorsList()
    this.currentType = decoratorTypes.UNKNOWN
    this.updateButtons()
  }

  function goBack() {
    // clear only when closed by player to can go through test fly with previewed skin
    clearLivePreviewParams()
    this.guiScene.performDelayed(this, base.goBack)
    hangar_focus_model(false)
  }

  function onDestroy() {
    if (this.isValid())
      this.setDmgSkinMode(false)
    show_model_damaged(MDS_ORIGINAL)
    ::hangar_prem_vehicle_view_close()

    if (this.unit) {
      if (this.currentState & decoratorEditState.EDITING) {
        this.currentType.exitEditMode(false, false)
        this.currentType.specifyEditableSlot(-1)
      }

      if (this.previewSkinId) {
        saveSeenSuggestedSkin(this.unit.name, this.previewSkinId)
        this.applySkin(get_last_skin(this.unit.name), true)
        this.previewSkinId = null
        if (this.initialUserSkinId != "")
          get_user_skins_profile_blk()[this.unit.name] = this.initialUserSkinId
      }

      if (this.previewMode) {
        hangar_force_reload_model()
      }
      else {
        this.saveDecorators(false)
        ::save_profile(true)
      }
    }
  }

  function getCurrentFocusedType() {
    if (this.scene.findObject("slots_list").isHovered())
      return decoratorTypes.DECALS
    if (this.scene.findObject("slots_attachable_list").isHovered())
      return decoratorTypes.ATTACHABLES
    if (this.scene.findObject("slots_flag_list").isHovered())
      return decoratorTypes.FLAGS
    return decoratorTypes.UNKNOWN
  }

  function canShowDmViewer() {
    return this.currentState && !(this.currentState & decoratorEditState.EDITING)
  }

  function updatePenaltyText() {
    let obj = this.scene.findObject("decal_text_area")
    if (!checkObj(obj))
      return

    local txt = ""
    if (::is_decals_disabled()) {
      local timeSec = ::get_time_till_decals_disabled()
      if (timeSec == 0) {
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

  function onEventBeforeStartTestFlight(_params) {
    handlersManager.requestHandlerRestore(this, this.getclass())
  }

  function onEventItemsShopUpdate(_params) {
    this.updateDecalSlots()
    this.updateAttachablesSlots()
    this.updateFlagSlots()
    this.updateSkinList()
    this.updateFlagName()
    this.updateButtons()
  }

  function initPreviewMode() {
    if (!this.previewParams)
      return
    if (hangar_get_loaded_unit_name() == this.previewParams.unitName)
      this.removeAllDecorators(false)
    switch (this.previewMode) {
      case PREVIEW_MODE.UNIT:
      case PREVIEW_MODE.SKIN:
        let skinBlockName = this.previewParams.unitName + "/" + this.previewParams.skinName
        previewedLiveSkinIds.append(skinBlockName)
        if (this.initialUserSkinId != "")
          get_user_skins_profile_blk()[this.unit.name] = ""
        let isForApprove = this.previewParams?.isForApprove ?? false
        approversUnitToPreviewLiveResource(isForApprove ? showedUnit.value : null)
        ::g_delayed_actions.add(Callback(function() {
          this.applySkin(this.previewParams.skinName, true)
        }, this), 100)
        break
      case PREVIEW_MODE.DECORATOR:
        this.decoratorPreview = this.previewParams.decorator
        this.currentType = this.decoratorPreview.decoratorType
        break
    }
  }

  function removeAllDecorators(save) {
    foreach (decoratorType in [ decoratorTypes.DECALS, decoratorTypes.ATTACHABLES, decoratorTypes.FLAGS ])
      for (local i = 0; i < decoratorType.getAvailableSlots(this.unit); i++) {
        let slot = this.getSlotInfo(i, false, decoratorType)
        if (!slot.isEmpty)
            decoratorType.removeDecorator(slot.id, save)
      }
  }

  function onEventActiveHandlersChanged(_p) {
    if (!this.isSceneActiveNoModals())
      this.setDmgSkinMode(false)
  }

  function onEventUnitBought(params) {
    this.initMainParams()
    let unitName = params?.unitName
    let boughtUnit = unitName ? getAircraftByName(unitName) : null
    if (!boughtUnit)
      return

    if (!this.isSceneActive())
      return

    this.onTake(boughtUnit, { isNewUnit = true })
  }

  function preSelectSlotAndDecorator(decorator, slotIdx) {
    let decoratorType = decorator.decoratorType
    if (decoratorType == decoratorTypes.SKINS) {
      if (this.unit.name == getPlaneBySkinId(decorator.id))
        this.applySkin(getSkinNameBySkinId(decorator.id))
    }
    else {
      if (slotIdx != -1) {
        let listObj = this.scene.findObject(decoratorType.listId)
        if (checkObj(listObj)) {
          let slotObj = listObj.getChild(slotIdx)
          if (checkObj(slotObj))
            this.openDecorationsListForSlot(slotIdx, slotObj, decoratorType)
        }
      }
    }
  }
}

from "%scripts/dagui_natives.nut" import save_online_single_job, shop_is_weapon_available
from "%scripts/dagui_library.nut" import *
from "%scripts/weaponry/weaponryConsts.nut" import SAVE_WEAPON_JOB_DIGIT, INFO_DETAIL

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock = require("DataBlock")
let { secondary_weapon_camera_mode } = require("hangar")
let { set_weapon_visual } = require("unitCustomization")
let { sortPresetsList, setFavoritePresets, getWeaponryPresetView,
  getWeaponryByPresetInfo, getCustomWeaponryPresetView
} = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_obj } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getLastWeapon, setLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getItemAmount, getItemCost, getItemStatusTbl } = require("%scripts/weaponry/itemInfo.nut")
let { getWeaponItemViewParams } = require("%scripts/weaponry/weaponryVisual.nut")
let { getTierDescTbl, updateWeaponTooltip, getTierTooltipParams
} = require("%scripts/weaponry/weaponryTooltipPkg.nut")
let { weaponsPurchase, canBuyItem } = require("%scripts/weaponry/weaponsPurchase.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilterWidget.nut")
let { appendOnce } = u
let { MAX_PRESETS_NUM, CHAPTER_ORDER, CHAPTER_NEW_IDX, CHAPTER_FAVORITE_IDX,
  CUSTOM_PRESET_PREFIX, isCustomPreset, getDefaultCustomPresetParams
} = require("%scripts/weaponry/weaponryPresets.nut")
let { renameCustomPreset, deleteCustomPreset, getWeaponryCustomPresets
} = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { openEditWeaponryPreset, openEditPresetName } = require("%scripts/weaponry/editWeaponryPreset.nut")
let { isWeaponModsPurchasedOrFree } = require("%scripts/weaponry/modificationInfo.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { promptReqModInstall, needReqModInstall } = require("%scripts/weaponry/checkInstallMods.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { isInFlight } = require("gameplayBinding")
let { addTask } = require("%scripts/tasker.nut")
let { loadModel } = require("%scripts/hangarModelLoadManager.nut")
let { round_by_value } = require("%sqstd/math.nut")
let { openRightClickMenu } = require("%scripts/wndLib/rightClickMenu.nut")
let { getChildInContainers } = require("%sqDagui/guiBhv/bhvInContainersNavigator.nut")

const MY_FILTERS = "weaponry_presets/filters"

let FILTER_OPTIONS = ["Favorite", "Available", 1, 2, 3, 4]

let predifineWndHeightsInTiers = [3.0, 7.0, 13.0]

gui_handlers.weaponryPresetsWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType              = handlerType.BASE
  sceneTplName         = "%gui/weaponry/weaponryPresetsWnd.tpl"
  unit                 = null
  chosenPresetIdx      = null
  curPresetIdx         = null
  curTierIdx           = -1
  chooseMenuList       = null
  presets              = null
  presetsByRanks       = null
  lastWeapon           = null
  presetsMarkup        = null
  presetTextWidth      = 0
  onChangeValueCb      = null
  weaponItemParams     = null
  favoriteArr          = null
  chapterPos           = 0
  initLastWeapon       = null
  presetIdxToChildIdx  = null
  isAllBuyProcess      = false
  totalCost            = null
  multiPurchaseList    = null
  curEdiff             = null
  weaponryByPresetInfo = null
  filterStates         = null
  filterTypes          = null
  filterObj            = null
  myFilters            = null
  customIdx            = 0
  presetNest           = null
  availableWeapons     = null
  presetsHeightInTiers = 0
  tierSize             = 0

  function getSceneTplView() {
    this.weaponryByPresetInfo = getWeaponryByPresetInfo(this.unit, this.chooseMenuList)
    this.tierSize = to_pixels("1@tierIconSize")
    let tiersWidth = this.weaponryByPresetInfo.weaponsSlotCount * this.tierSize
    let freeWidthForText = to_pixels("1@srw - 1@weaponsPresetDescriptionWidth - 1@scrollBarSize") - tiersWidth
    this.presetTextWidth = min(freeWidthForText, to_pixels("1@modPresetTextMaxWidth"))
    this.chapterPos = this.presetTextWidth + 0.5 * tiersWidth
    this.presets = this.weaponryByPresetInfo.presets
    this.favoriteArr = this.weaponryByPresetInfo.favoriteArr
    let unitName = this.unit.name

    this.availableWeapons = this.weaponryByPresetInfo.availableWeapons?.filter(
      @(w) isWeaponModsPurchasedOrFree(unitName, w)
    )

    this.lastWeapon = this.initLastWeapon ?? getLastWeapon(this.unit.name)
    this.presetsMarkup = this.getPresetsMarkup(this.presets)
    this.presetsHeightInTiers = loadLocalAccountSettings("weaponryPrestWndHeightInTiers") ?? 7.0
    return {
      presetsWidth = tiersWidth + this.presetTextWidth
      presetsHeightInTiers = this.presetsHeightInTiers
      chapterPos = this.chapterPos
      presets = this.presetsMarkup
    }
  }

  function initScreen() {
    this.loadHangarModel()
    secondary_weapon_camera_mode(true)
    this.multiPurchaseList = []
    let chpn = this.lastWeapon
    this.chosenPresetIdx = this.presets.findindex(@(w) w.name == chpn) ?? 0
    this.presetNest = this.scene.findObject("presetNest")
    this.setSceneTitle("".concat(loc("modification/category/secondaryWeapon"), " ",
      loc("ui/mdash"), " ", getUnitName(this.unit)))
    this.selectPreset(this.chosenPresetIdx)
    this.updateCustomIdx()
    this.updatePresetsByRanks()
    this.updateMultiPurchaseList()
    move_mouse_on_obj(this.scene.findObject($"presetHeader_{this.chosenPresetIdx}"))

    this.filterObj = this.scene.findObject("filter_nest")
    this.myFilters = loadLocalAccountSettings($"{MY_FILTERS}/{this.unit.name}", DataBlock())
    this.fillFilterTypesList()
    
    if (this.myFilters != null)
      this.updateAllByFilters()

    openPopupFilter({
      scene = this.filterObj
      onChangeFn = this.onFilterCbChange.bindenv(this)
      filterTypesFn = this.getFiltersView.bindenv(this)
      popupAlign = "top"
    })

    showObjById("custom_weapons_available_txt", this.unit.hasWeaponSlots
      && !isInFlight() && !this.unit.isUsable(), this.scene)
    showObjById("custom_weapons_disabled_txt", this.unit.hasWeaponSlots
      && !isInFlight()
      && this.unit.isUsable()
      && !this.isCustomPresetsEditAvailable(), this.scene)
    this.scene.findObject("timer_update")?.setUserData(this)
    this.updateChangeWndHeightButtons()
  }

  function updateCustomIdx() {
    this.customIdx = this.presets.filter(isCustomPreset).reduce(
      @(res, value) max(res, cutPrefix(value.name, CUSTOM_PRESET_PREFIX).tointeger() + 1), 0)
  }

  function updatePresetsByRanks() {
    this.presetsByRanks = {}
    foreach (p in this.presets)
      this.presetsByRanks[p.rank] <- (this.presetsByRanks?[p.rank] ?? []).append(p)
  }

  function getPresetsMarkup(pList) {
    this.presetIdxToChildIdx = {}
    let res = []
    if (pList == null)
      return res
    local curChapterOrd = 0
    foreach (preset in pList) {
      if (curChapterOrd != preset.chapterOrd) {
        curChapterOrd = preset.chapterOrd
        res.append({
          isCollapsable = true
          chapterName = loc($"weapons/purposeType/{CHAPTER_ORDER[curChapterOrd]}")
        })
      }

      let params = this.weaponItemParams ?
        this.weaponItemParams.__merge({ visualDisabled = !preset.isEnabled }) : {}
      params.__update({
          collapsable = true
          showButtons = true
          actionBtnText = this.onChangeValueCb != null ? loc("mainmenu/btnSelect") : null
        })
      let idx = this.presets.findindex(@(p) p.name == preset.name) ?? 0
      this.presetIdxToChildIdx[idx] <- res.len()
      let wpParams = getWeaponItemViewParams($"item_{idx}", this.unit, preset.weaponPreset, params).__update({
        presetTextWidth = this.presetTextWidth
        isTypeNone = preset.purposeType == "NONE"
        tiersView = preset.tiersView.map(@(t) {
          tierId        = t.tierId
          img           = t?.img ?? ""
          tierTooltipId = !showConsoleButtons.value ? t?.tierTooltipId : null
          isActive      = t?.isActive || "img" in t
        })
      })
      res.append({
        presetId  = idx
        chosen = idx == this.chosenPresetIdx ? "yes" : "no"
        weaponryItem = wpParams

      })
    }

    return res
  }

  function selectPreset(presetIdx, isForced = false) {
    if (this.curPresetIdx == presetIdx && !isForced)
      return

    if (!this.presetNest?.isValid())
      return

    local childIdx = this.presetIdxToChildIdx?[this.curPresetIdx]
    if (childIdx != null)
      this.presetNest.getChild(childIdx).selected = "no"

    let row = this.scene.findObject($"tiersNest_{this.curPresetIdx}")
    if (row?.isValid())
      row.setValue(-1)

    this.curPresetIdx = presetIdx
    childIdx = this.presetIdxToChildIdx?[presetIdx]
    if (childIdx != null) {
      let obj = this.presetNest.getChild(childIdx)
      obj.selected = "yes"
      obj.scrollToView()
    }

    this.setSelectedWeaponVisual()

    this.updateDesc()
    this.updateButtons()
  }

  function setSelectedWeaponVisual() {
    if (this.curPresetIdx != null && (this.curPresetIdx in this.presets))
      set_weapon_visual(this.unit.name, this.presets[this.curPresetIdx].name)
    else
      this.setChosenWeaponVisual()
  }
  setChosenWeaponVisual = @() set_weapon_visual(this.unit.name, this.lastWeapon)

  function selectTier(tierIdx) {
    this.curTierIdx = tierIdx
    this.updateTierDesc()
  }

  function onPresetRename() {
    let curPreset = this.presets[this.curPresetIdx]
    let presetId = curPreset.name
    let presetUnit = this.unit
    let okFunc = @(newName) renameCustomPreset(presetUnit, presetId, newName)
    openEditPresetName(this.presets[this.curPresetIdx].customNameText, okFunc)
  }

  function updatePreset(presetId) {
    let preset = getWeaponryCustomPresets(this.unit).findvalue(@(p) p.name == presetId)
    if (preset == null)
      return

    let presetView = getWeaponryPresetView(this.unit, preset, this.favoriteArr, this.availableWeapons)
    let presetIdx = this.weaponryByPresetInfo.presets.findindex(@(w) w.name == presetId)
    if (presetIdx == null)
      this.weaponryByPresetInfo.presets.append(presetView)
    else
      this.weaponryByPresetInfo.presets[presetIdx] = presetView

    this.presets = this.weaponryByPresetInfo.presets
    this.updatePresetsByRanks()
    this.presets.sort(sortPresetsList)
    this.updateAllByFilters()
    this.selectPreset(this.presets.findindex(@(w) w.name == presetId))
  }

  function onPresetSelect(obj) {
    this.selectPreset(obj.presetId.tointeger())
  }

  function onCellSelect(obj) {
    let value = obj.getValue()
    let cellObj = getChildInContainers(obj, value)
    if (!cellObj?.isValid() || (cellObj?.presetId == null && cellObj?.tierId == null)) {
      this.selectPreset(null)
      this.selectTier(null)
      return
    }
    if (cellObj?.presetId) {
      this.selectPreset(cellObj?.presetId.tointeger())
      this.selectTier(-1)
      return
    }

    let tier = cellObj.tierId.tointeger()
    let presetId = cellObj.getParent().presetId.tointeger()
    this.selectPreset(presetId)
    this.selectTier(tier)
  }

  function onPresetUnhover(obj) {
    if (showConsoleButtons.value)
      obj.setValue(-1)
  }

  function getTierDeskMarkup() {
    if (this.curTierIdx < 0 || this.curPresetIdx == null)
      return ""
    let item = this.presets[this.curPresetIdx]
    let weaponry = item.tiersView?[this.curTierIdx].weaponry
    if (!weaponry)
      return ""

    let tooltipParams = getTierTooltipParams(weaponry, item.name, this.curTierIdx).__update({
      narrowPenetrationTable = true 
    })
    return handyman.renderCached(("%gui/weaponry/weaponsPresetTooltip.tpl"),
      getTierDescTbl(this.unit, tooltipParams))
  }

  function updateTierDesc() {
    let descObj = this.scene.findObject("tierDesc")
    let data = this.getTierDeskMarkup()
    this.guiScene.replaceContentFromText(descObj, data, data.len(), null)
  }

  function onModItemDblClick(_obj) {
    let idx = this.curPresetIdx
    let params = u.search(this.presetsMarkup, @(i) i?.presetId == idx)
    if (params?.weaponryItem.actionBtnCanShow != "no")
      this.onModActionBtn()
  }

  function onModActionBtn(_obj = null) {
    if (this.curPresetIdx == null)
      return

    this.doItemAction(this.presets[this.curPresetIdx].weaponPreset)
  }

  function onAltModAction(_obj) {
    if (this.curPresetIdx == null)
      return
    this.onBuy(this.presets[this.curPresetIdx].weaponPreset)
  }

  function doItemAction(item) {
    this.guiScene.playSound("check")
    if (this.onChangeValueCb) {
      this.onChangeValueCb(item)
      this.updateChoosenWeapon()
    }
    else {
      let amount = getItemAmount(this.unit, item)
      if (getLastWeapon(this.unit.name) == item.name || !amount) {
        if (item.cost <= 0)
          return
        return this.onBuy(item)
      }

      if (needReqModInstall(this.unit, item)) {
        promptReqModInstall(this.unit, item)
        return
      }

      setLastWeapon(this.unit.name, item.name)
      ::check_secondary_weapon_mods_recount(this.unit)
      this.checkSaveBulletsAndDo()
    }
    this.guiScene.performDelayed(this, @()this.goBack())
  }

  function onBuy(item) {
    if (!shop_is_weapon_available(this.unit.name, item.name, false, true))
      return
    this.checkSaveBulletsAndDo(Callback(function() { 
      weaponsPurchase(this.unit, { modItem = item, open = false })
    }, this))
  }

  function updateChoosenWeapon() {
    local childIdx = this.presetIdxToChildIdx?[this.chosenPresetIdx]
    if (childIdx != null) {
      let preset = this.presetsMarkup[childIdx]
      preset.weaponryItem.actionBtnText = loc("mainmenu/btnSelect")
      this.presetNest.getChild(childIdx).chosen = "no"
    }

    let newChoosenPreset = getLastWeapon(this.unit.name)
    this.chosenPresetIdx = this.presets.findindex(@(w) w.name == newChoosenPreset)
    childIdx = this.presetIdxToChildIdx?[this.chosenPresetIdx]
    if (childIdx != null)
      this.presetNest.getChild(childIdx).chosen = "yes"

    this.lastWeapon = newChoosenPreset
    this.updateButtons()
  }

  function checkSaveBulletsAndDo(func = null) {
    local needSave = false
    if (this.lastWeapon != "" && this.lastWeapon != getLastWeapon(this.unit.name)) {
      log($"force cln_update due lastWeapon '{this.lastWeapon}' != {getLastWeapon(this.unit.name)}")
      needSave = true
      this.updateChoosenWeapon()
    }

    if (needSave) {
      this.taskId = save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      if (this.taskId >= 0 && func) {
        let cb = u.isFunction(func) ? Callback(func, this) : func
        addTask(this.taskId, { showProgressBox = true }, cb)
      }
    }
    else if (func)
      func()
    return true
  }

  function updateDesc() {
    let descObj = this.scene.findObject("desc")
    if (this.curPresetIdx == null) {
      this.guiScene.replaceContentFromText(descObj, "", 0, this)
      return
    }
    updateWeaponTooltip(descObj, this.unit, this.presets[this.curPresetIdx].weaponPreset, this, {
      curEdiff = this.curEdiff
      detail = INFO_DETAIL.FULL
      needDescInArrayForm = true
      markupFileName = "%gui/weaponry/weaponsPresetTooltip.tpl"
      showOnlyNamesAndSpecs = true
    })
  }

  function getPresetActions() {
    if (this.curPresetIdx == null || !this.isCustomPresetsEditAvailable())
      return []

    let canCopyCurPreset = this.presets.filter(isCustomPreset).len() < MAX_PRESETS_NUM
      && this.presets[this.curPresetIdx].isEnabled
    let canEditCurPreset = isCustomPreset(this.presets[this.curPresetIdx])

    return [
      { 
        text = loc("msgbox/btn_rename")
        show = canEditCurPreset
        action = @() this.onPresetRename()
      }
      { 
        text = loc("msgbox/btn_edit")
        show = canEditCurPreset
        action = @() this.onPresetEdit()
      }
      { 
        text = loc("gblk/saveError/copy")
        show = canCopyCurPreset
        action = @() this.onPresetCopy()
      }
      { 
        text = loc("msgbox/btn_delete")
        show = canEditCurPreset
        action = @() this.onPresetDelete()
      }
    ].filter(@(a) a.show)
  }

  function onPresetMenuOpen() {
    openRightClickMenu(this.getPresetActions(), this)
  }

  function onPresetActionsMenuOpen() {
    let actions = this.getPresetActions()
    if (actions.len() == 1)
      actions[0].action.call(this)
    else
      openRightClickMenu(actions, this)
  }

  isCustomPresetsAvailable = @() this.unit.hasWeaponSlots  && this.availableWeapons.len() > 0
    && hasFeature("WeaponryCustomPresets")

  isCustomPresetsEditAvailable = @() this.isCustomPresetsAvailable()
     && !isInFlight() && this.unit.isUsable()

  function updateButtons() {
    let isAvailable = this.isCustomPresetsEditAvailable()
    let wndObj = this.scene.findObject("presetsModalWnd")

    showObjById("newPresetBtn", isAvailable
      && this.presets.filter(isCustomPreset).len() < MAX_PRESETS_NUM, wndObj)

    if (this.curPresetIdx == null) {
      showObjById("actionBtn", false, wndObj)
      showObjById("altActionBtn", false, wndObj)
      showObjById("favoriteBtn", false, wndObj)
      showObjById("openPresetMenuBtn", false, wndObj)
      return
    }

    let curPreset = this.presets[this.curPresetIdx]
    let actions = this.getPresetActions()
    let isVisibleActionsButton = actions.len() > 0
    let bObj = showObjById("openPresetMenuBtn", isVisibleActionsButton, wndObj)
    if (isVisibleActionsButton) {
      if (actions.len() == 1)
        bObj.setValue(actions[0].text)
      else
        bObj.setValue(loc("msgbox/presetActions"))
    }

    let idx = this.curPresetIdx
    let params = u.search(this.presetsMarkup, @(i) i?.presetId == idx)
    let btnText = params?.weaponryItem.actionBtnText ?? ""
    let canBuy = this.presets[idx].weaponPreset.cost > 0
    let actionBtnObj = showObjById("actionBtn", btnText != ""
      && (idx != this.chosenPresetIdx || canBuy), wndObj)
    if (btnText != "" && actionBtnObj?.isValid())
      actionBtnObj.setValue(btnText)
    let altBtnText = params?.weaponryItem.altBtnBuyText ?? ""
    let altActionBtnObj = showObjById("altActionBtn", altBtnText != "", wndObj)
    if (altBtnText != "" && altActionBtnObj?.isValid()) {
      altActionBtnObj.setValue(altBtnText)
      altActionBtnObj.tooltip = params?.weaponryItem.altBtnTooltip ?? ""
    }
    let favoriteBtnObj = showObjById("favoriteBtn", true, wndObj)
    favoriteBtnObj.setValue(loc(curPreset.chapterOrd != 1
      ? "mainmenu/btnFavorite" : "mainmenu/btnFavoriteUnmark"))
  }

  function updateAll(pList = null) {
    if (this.isAllBuyProcess)
      return

    if (!this.presetNest?.isValid())
      return

    this.presetsMarkup = this.getPresetsMarkup(pList ?? this.presets)
    let data = handyman.renderCached("%gui/weaponry/weaponryPreset.tpl", {
      chapterPos = this.chapterPos
      presets = this.presetsMarkup
    })
    this.guiScene.replaceContentFromText(this.presetNest, data, data.len(), this)
    
    local firstIdx = this.presetIdxToChildIdx.findindex(@(_) true)
    this.selectPreset(this.chosenPresetIdx in this.presetIdxToChildIdx ? this.chosenPresetIdx : firstIdx, true)

    
    let popupObj = this.filterObj.findObject("filter_popup")
    if (!popupObj?.isValid())
      return

    let fObj = popupObj.findObject("f_Favorite")
    let aObj = popupObj.findObject("f_Available")
    if (fObj?.isValid()) {
      fObj.setValue(this.isFavoritesExist() && this.filterStates.findindex(@(p) p == "f_Favorite") != null)
      fObj.enable(this.isFavoritesExist())
    }
    if (aObj?.isValid()) {
      aObj.setValue(this.isAvailablesExist() && this.filterStates.findindex(@(p) p == "f_Available") != null)
      aObj.enable(this.isAvailablesExist())
    }
  }

  function onEventWeaponPurchased(_p) { this.updateAll(); this.updateMultiPurchaseList() }

  function onCollapse(obj) {
    let itemObj = obj?.collapse_header ? obj : obj.getParent()
    let listObj = itemObj?.isValid() ? itemObj.getParent() : null
    if (!listObj?.isValid() || !itemObj?.collapse_header)
      return

    itemObj.collapsing = "yes"
    let isShow = itemObj?.collapsed == "yes"
    let listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++) {
      let child = listObj.getChild(i)
      if (!found) {
        if (child?.collapsing == "yes") {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else {
        if (child?.collapse_header)
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect) {
      let indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes) {
        let child = listObj.getChild(idx)
        if (!child?.collapse_header && child.isEnabled()) {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }
  }

  function onChangeFavorite(_obj) {
    let preset = this.presets[this.curPresetIdx]
    let isFavorite = preset.chapterOrd == CHAPTER_FAVORITE_IDX
    let chapterOrd = !isFavorite ? CHAPTER_FAVORITE_IDX
      : isCustomPreset(preset) ? CHAPTER_NEW_IDX
      : CHAPTER_ORDER.findindex(@(p) p == preset.purposeType)
    if (isFavorite) {
      let idx = this.favoriteArr.findindex(@(id) id == preset.name)
      if (idx != null)
        this.favoriteArr.remove(idx)
    }
    else
      this.favoriteArr.append(preset.name)
    setFavoritePresets(this.unit.name, this.favoriteArr)
    preset.chapterOrd = chapterOrd
    this.presets.sort(sortPresetsList)
    this.updateAllByFilters()
  }

  function getFiltersView() {
    let view = { checkbox = [] }
    foreach (key, inst in this.filterTypes)
      view.checkbox.append({
        id = inst.id
        idx = inst.idx
        text = inst.text
        isDisable = inst.isDisable
        value = !inst.isDisable && this.filterStates.findindex(@(v) v == key) != null
      })
    view.checkbox.sort(@(a, b) a.idx <=> b.idx)
    return [view]
  }

  isFavoritesExist = @() this.favoriteArr.len() > 0
  isAvailablesExist = @() this.presets.filter(@(p) p.isEnabled).len() > 0

  function fillFilterTypesList() {
    this.filterStates = this.myFilters ? this.myFilters % "array" : []
    this.filterTypes = {}
    foreach (idx, key in FILTER_OPTIONS) {
      let isRank = type(key) != "string"
      if ((isRank && !this.presetsByRanks?[key]))
        continue

      let id = $"f_{key}"
      this.filterTypes[id] <- {
        id    = id
        idx   = idx
        isDisable = (key == FILTER_OPTIONS[0] && !this.isFavoritesExist())
          || (key == FILTER_OPTIONS[1] && !this.isAvailablesExist())
        text  = isRank ? $"{loc("conditions/rank")} {get_roman_numeral(key)}"
          : loc($"mainmenu/only{key}")
      }
    }
  }

  function updateAllByFilters() {
    local isFavorite = false
    local isAvailable = false
    local pList = []
    
    
    foreach (inst in this.filterStates) {
      if (inst != "f_Favorite" && inst != "f_Available") {
        let p = this.presetsByRanks?[inst.split("f_")[1].tointeger()]
        if (p != null)
         pList.extend(p)
      }
      else {
        isFavorite = inst == "f_Favorite" || isFavorite
        isAvailable = inst == "f_Available" || isAvailable
      }
    }

    if (pList.len() == 0 || !isFavorite || !isAvailable) {
      this.presets = this.weaponryByPresetInfo.presets
      
      pList = pList.len() == 0 ? (clone this.presets) : pList
    }
    if (isFavorite || isAvailable) {
      
      let isExistFavorites = this.isFavoritesExist()
      let isExistAvailables = this.isAvailablesExist()
      let filterFunc = @(p)
        (!isFavorite || !isExistFavorites || p.chapterOrd == CHAPTER_FAVORITE_IDX)
          && (!isAvailable || !isExistAvailables || p.isEnabled)
      pList = pList.filter(filterFunc)
      this.presets = this.presets.filter(filterFunc)
    }

    let chpn = this.lastWeapon
    this.chosenPresetIdx = this.presets.findindex(@(w) w.name == chpn)
    pList.sort(sortPresetsList)
    this.updateAll(pList)
  }

  function onFilterCbChange(objId, _tName, value) {
    let isReset = objId == RESET_ID
    foreach (key, inst in this.filterTypes) {
      if (!isReset && inst.id != objId)
        continue

      if (value)
        appendOnce(key, this.filterStates)
      else {
        let idx = this.filterStates.findindex(@(v) v == key)
        if (idx != null)
          this.filterStates.remove(idx)
      }
    }

    this.updateAllByFilters()
    saveLocalAccountSettings($"{MY_FILTERS}/{this.unit.name}", this.filterStates)
  }

  function editWeaponryPreset(preset) {
    let presetsNest = this.scene.findObject("presets_nest")
    set_weapon_visual(this.unit.name, "")
    openEditWeaponryPreset({
      unit = this.unit
      originalPreset = preset
      preset = deep_clone(preset)
      availableWeapons = this.availableWeapons
      favoriteArr = this.favoriteArr
      parentSize = presetsNest?.getSize()
      parentPos = presetsNest?.getPosRC()
      afterClose = Callback(this.setSelectedWeaponVisual, this)
    })
  }

  editNewPreset = @(newPreset) this.editWeaponryPreset(
    getCustomWeaponryPresetView(this.unit, newPreset, this.favoriteArr, this.availableWeapons))

  function onPresetNew() {
    this.editNewPreset(getDefaultCustomPresetParams(this.customIdx))
  }

  function onPresetCopy() {
    let newPreset = getDefaultCustomPresetParams(this.customIdx)
    newPreset.tiers <- u.copy(this.presets[this.curPresetIdx].tiers)
    this.editNewPreset(newPreset)
  }

  function onPresetDelete() {
    let curPreset = this.presets?[this.curPresetIdx]
    if (curPreset == null)
      return

    let curUnit = this.unit
    this.msgBox("question_delete_preset",
      loc("msgbox/genericRequestDelete", { item = curPreset.customNameText }),
      [
        ["delete", @() deleteCustomPreset(curUnit, curPreset.name)],
        ["cancel", function() {} ]
      ], "cancel")
  }

  function onPresetEdit() {
    let curPreset = this.presets?[this.curPresetIdx]
    if (curPreset != null)
      this.editWeaponryPreset(curPreset)
  }

  
  function updateBuyAllBtn() {
    let isShow = this.multiPurchaseList.len() > 0
    if (isShow)
      placePriceTextToButton(this.scene, "btn_buyAll", loc("mainmenu/btnBuyAll"), this.totalCost)

    showObjById("btn_buyAll", isShow, this.scene)
  }

  onBuyAll = @() this.buyAll()
  onEventProfileUpdated = @ (_p) this.updateBuyAllBtn()

  function updateMultiPurchaseList() {
    if (this.isAllBuyProcess || !hasFeature("BuyAllPresets"))
      return

    this.multiPurchaseList = []
    this.totalCost = Cost()
    foreach (preset in this.presets) {
      let weaponPreset = preset.weaponPreset
      let statusTbl = getItemStatusTbl(this.unit, weaponPreset)
      if (!shop_is_weapon_available(this.unit.name, preset.name, false, true) || !statusTbl.canBuyMore)
        continue

      this.multiPurchaseList.append(weaponPreset)
      this.totalCost += getItemCost(this.unit, weaponPreset).multiply(statusTbl.maxAmount - statusTbl.amount)
    }

    this.updateBuyAllBtn()
  }

  function buyAll() {
    if (!this.multiPurchaseList.len()) {
      this.isAllBuyProcess = false
      save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      this.updateAll()
      this.updateMultiPurchaseList()
      return
    }

    if (!canBuyItem(this.totalCost, this.unit))
      return

    let item = this.multiPurchaseList.pop()
    let statusTbl = getItemStatusTbl(this.unit, item)
    this.totalCost -= getItemCost(this.unit, item).multiply(statusTbl.maxAmount - statusTbl.amount)
    this.isAllBuyProcess = true
    weaponsPurchase(this.unit, { modItem = item, open = false, silent = true, isAllPresetPurchase = true,
      afterSuccessfullPurchaseCb = Callback(@() this.buyAll(), this) })
  }

  onTierClick = @() null

  function onEventCustomPresetChanged(p) {
    let { unitName, presetId } = p
    if (unitName != this.unit.name)
      return

    this.updatePreset(presetId)
    this.updateCustomIdx()
  }

  function onEventCustomPresetRemoved(p) {
    let { unitName, presetId } = p
    if (unitName != this.unit.name)
      return

    let presetIdx = this.weaponryByPresetInfo.presets.findindex(@(w) w.name == presetId)
    if (presetIdx == null)
      return

    this.weaponryByPresetInfo.presets.remove(presetIdx)
    this.presets = this.weaponryByPresetInfo.presets
    this.updatePresetsByRanks()
    if (this.chosenPresetIdx == presetIdx) {
      this.curPresetIdx = null
      setLastWeapon(this.unit.name, this.presets[0].weaponPreset.name)
      ::check_secondary_weapon_mods_recount(this.unit)
      this.checkSaveBulletsAndDo()
    }
    this.updateAllByFilters()
    this.updateCustomIdx()
  }

  function onDestroy() {
    this.setChosenWeaponVisual()
    secondary_weapon_camera_mode(false)
  }

  loadHangarModel = @() loadModel(this.unit.name)

  getHeightInTiers = @(height) round_by_value(height.tofloat()/this.tierSize, 0.01)

  function saveWindowHeight(heightInTiers = null) {
    if (heightInTiers == null) {
      let height = this.scene.findObject("presets_nest").getSize()[1]
      heightInTiers = this.getHeightInTiers(height)
    }
    if (this.presetsHeightInTiers == heightInTiers)
      return
    this.presetsHeightInTiers = heightInTiers
    saveLocalAccountSettings("weaponryPrestWndHeightInTiers", heightInTiers)
    this.updateChangeWndHeightButtons(heightInTiers)
  }

  onUpdate = @(_obj, _dt) this.saveWindowHeight()

  function changeWndHeight(isInc) {
    let presetsNest = this.scene.findObject("presets_nest")
    let curSize = presetsNest.getSize()
    let curHeightInTier = this.getHeightInTiers(curSize[1])
    local newHeightInTier = null
    if (isInc)
      newHeightInTier = predifineWndHeightsInTiers.findvalue(@(v) v > curHeightInTier)
    else {
      let suitableHeigthsInTier = predifineWndHeightsInTiers.filter(@(v) v < curHeightInTier)
      if (suitableHeigthsInTier.len() > 0)
        newHeightInTier = suitableHeigthsInTier.top()
    }
    if (newHeightInTier == null)
      return

    presetsNest.size = $"{curSize[0]}, {newHeightInTier * this.tierSize}"
    this.saveWindowHeight(newHeightInTier)
  }

  function moveMouseToVisibleObj(obj, objIdFallback) {
    this.guiScene.applyPendingChanges(false)
    if (!obj.isVisible())
      obj = this.scene.findObject(objIdFallback)
    move_mouse_on_obj(obj)
  }

  function onDecreaseWndHeight(obj) {
    this.changeWndHeight(false)
    this.moveMouseToVisibleObj(obj, "increaseWndHeightBtn")
  }

  function onIncreaseWndHeightBtn(obj) {
    this.changeWndHeight(true)
    this.moveMouseToVisibleObj(obj, "decreaseWndHeightBtn")
  }

  function updateChangeWndHeightButtons(heightInTiers = null) {
    if (heightInTiers == null)
      heightInTiers = this.getHeightInTiers(this.scene.findObject("presets_nest").getSize()[1])
    showObjById("increaseWndHeightBtn", predifineWndHeightsInTiers.findindex(@(v) v > heightInTiers) != null, this.scene)
    showObjById("decreaseWndHeightBtn", predifineWndHeightsInTiers.findindex(@(v) v < heightInTiers) != null, this.scene)
  }
}

gui_handlers.weaponryPresetsModal <- class (gui_handlers.weaponryPresetsWnd) {
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/weaponry/weaponryPresetsModal.tpl"

  function getSceneTplView() {
    return base.getSceneTplView().__update({
      headerText = " ".concat(loc("modification/category/secondaryWeapon"),
        loc("ui/mdash"), getUnitName(this.unit))
    })
  }

  loadHangarModel = @() null
  updateChangeWndHeightButtons= @(_ = null) null
}
//checked for plus_string
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { Cost } = require("%scripts/money.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let DataBlock = require("DataBlock")
let { sortPresetsList, setFavoritePresets, getWeaponryPresetView,
  getWeaponryByPresetInfo, getCustomWeaponryPresetView
} = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getLastWeapon, setLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { getItemAmount, getItemCost, getItemStatusTbl } = require("%scripts/weaponry/itemInfo.nut")
let { getWeaponItemViewParams } = require("%scripts/weaponry/weaponryVisual.nut")
let { getTierDescTbl, updateWeaponTooltip, getTierTooltipParams
} = require("%scripts/weaponry/weaponryTooltipPkg.nut")
let { weaponsPurchase, canBuyItem } = require("%scripts/weaponry/weaponsPurchase.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { RESET_ID, openPopupFilter } = require("%scripts/popups/popupFilter.nut")
let { appendOnce } = u
let { MAX_PRESETS_NUM, CHAPTER_ORDER, CHAPTER_NEW_IDX, CHAPTER_FAVORITE_IDX,
  CUSTOM_PRESET_PREFIX, isCustomPreset, getDefaultCustomPresetParams
} = require("%scripts/weaponry/weaponryPresets.nut")
let { renameCustomPreset, deleteCustomPreset, getWeaponryCustomPresets
} = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { openEditWeaponryPreset, openEditPresetName } = require("%scripts/weaponry/editWeaponryPreset.nut")
let { isModAvailableOrFree } = require("%scripts/weaponry/modificationInfo.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { promptReqModInstall, needReqModInstall } = require("%scripts/weaponry/checkInstallMods.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

const MY_FILTERS = "weaponry_presets/filters"

let FILTER_OPTIONS = ["Favorite", "Available", 1, 2, 3, 4]

gui_handlers.weaponryPresetsModal <- class extends gui_handlers.BaseGuiHandlerWT {
  wndType              = handlerType.MODAL
  sceneTplName         = "%gui/weaponry/weaponryPresetsModal.tpl"
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
  chosenPresetName     = null
  customIdx            = 0
  presetNest           = null
  availableWeapons     = null

  function getSceneTplView() {
    this.weaponryByPresetInfo = getWeaponryByPresetInfo(this.unit, this.chooseMenuList)
    let tiersWidth = to_pixels("".concat(this.weaponryByPresetInfo.weaponsSlotCount, "@tierIconSize"))
    let iconWidth = showConsoleButtons.value ? to_pixels("1@cIco") : 0
    let tiersAndDescWidth = to_pixels("".concat(
      "1@narrowTooltipWidth+4@blockInterval+2@scrollBarSize+2@frameHeaderPad"))
        + tiersWidth + iconWidth
    this.presetTextWidth = min(to_pixels("1@srw") - tiersAndDescWidth,
      to_pixels("1@modPresetTextMaxWidth"))
    let wndWidth = tiersAndDescWidth + this.presetTextWidth
    this.chapterPos = this.presetTextWidth + 0.5 * tiersWidth + iconWidth
    this.presets = this.weaponryByPresetInfo.presets
    this.favoriteArr = this.weaponryByPresetInfo.favoriteArr
    let unitName = this.unit.name
    this.availableWeapons = this.weaponryByPresetInfo.availableWeapons?.filter(
      @(w) w?.reqModification == null || isModAvailableOrFree(unitName, w.reqModification))
    this.lastWeapon = this.initLastWeapon ?? getLastWeapon(this.unit.name)
    this.chosenPresetName = this.lastWeapon
    this.presetsMarkup = this.getPresetsMarkup(this.presets)
    return {
      headerText = "".concat(loc("modification/category/secondaryWeapon"), " ",
        loc("ui/mdash"), " ", getUnitName(this.unit))
      wndWidth
      chapterPos = this.chapterPos
      presets = this.presetsMarkup
      isShowConsoleBtn = showConsoleButtons.value
    }
  }

  function initScreen() {
    this.multiPurchaseList = []
    let chpn = this.chosenPresetName
    this.chosenPresetIdx = this.presets.findindex(@(w) w.name == chpn) ?? 0
    this.presetNest = this.scene.findObject("presetNest")
    this.selectPreset(this.chosenPresetIdx)
    this.updateCustomIdx()
    this.updatePresetsByRanks()
    this.updateMultiPurchaseList()
    ::move_mouse_on_obj(this.scene.findObject($"presetHeader_{this.chosenPresetIdx}"))

    this.filterObj = this.scene.findObject("filter_nest")
    this.myFilters = loadLocalAccountSettings($"{MY_FILTERS}/{this.unit.name}", DataBlock())
    this.fillFilterTypesList()
    // No need to update items if no stored filters for current unit
    if (this.myFilters != null)
      this.updateAllByFilters()

    openPopupFilter({
      scene = this.filterObj
      onChangeFn = this.onFilterCbChange.bindenv(this)
      filterTypes = this.getFiltersView()
      popupAlign = "top"
    })

    this.showSceneBtn("custom_weapons_available_txt", this.unit.hasWeaponSlots
      && !::is_in_flight() && !this.unit.isUsable())
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

    this.updateDesc()
    this.updateButtons()
  }

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
    let presetId = obj.presetId.tointeger()
    let value = obj.getValue()

    if (value < 0) {
      if (presetId == this.curPresetIdx) {
        this.selectPreset(null)
        this.selectTier(null)
      }
      return
    }

    this.selectPreset(presetId)
    this.selectTier(value - 1)
  }

  function onPresetUnhover(obj) {
    if (showConsoleButtons.value)
      obj.setValue(-1)
  }

  function updateTierDesc() {
    local data = ""
    let descObj = this.scene.findObject("tierDesc")
    if (this.curTierIdx >= 0 && this.curPresetIdx != null) {
      let item = this.presets[this.curPresetIdx]
      let weaponry = item.tiersView?[this.curTierIdx].weaponry
      data = weaponry ? handyman.renderCached(("%gui/weaponry/weaponTooltip.tpl"),
        getTierDescTbl(this.unit, getTierTooltipParams(weaponry, item.name, this.curTierIdx))) : ""
    }
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
    if (this.onChangeValueCb)
      this.onChangeValueCb(item)
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
    if (!::shop_is_weapon_available(this.unit.name, item.name, false, true))
      return
    this.checkSaveBulletsAndDo(Callback(function() { //-param-hides-param
      weaponsPurchase(this.unit, { modItem = item, open = false })
    }, this))
  }

  function checkSaveBulletsAndDo(func = null) {
    local needSave = false
    if (this.lastWeapon != "" && this.lastWeapon != getLastWeapon(this.unit.name)) {
      log($"force cln_update due lastWeapon '{this.lastWeapon}' != {getLastWeapon(this.unit.name)}")
      needSave = true
      this.lastWeapon = getLastWeapon(this.unit.name)
    }

    if (needSave) {
      this.taskId = ::save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      if (this.taskId >= 0 && func) {
        let cb = u.isFunction(func) ? Callback(func, this) : func
        ::g_tasker.addTask(this.taskId, { showProgressBox = true }, cb)
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
    })
  }

  function getPresetActions() {
    if (this.curPresetIdx == null || !this.isCustomPresetsEditAvailable())
      return []

    let canCopyCurPreset = this.presets.filter(isCustomPreset).len() < MAX_PRESETS_NUM
      && this.presets[this.curPresetIdx].isEnabled
    let canEditCurPreset = isCustomPreset(this.presets[this.curPresetIdx])

    return [
      { // rename
        text = loc("msgbox/btn_rename")
        show = canEditCurPreset
        action = @() this.onPresetRename()
      }
      { // edit
        text = loc("msgbox/btn_edit")
        show = canEditCurPreset
        action = @() this.onPresetEdit()
      }
      { // copy
        text = loc("gblk/saveError/copy")
        show = canCopyCurPreset
        action = @() this.onPresetCopy()
      }
      { // delete
        text = loc("msgbox/btn_delete")
        show = canEditCurPreset
        action = @() this.onPresetDelete()
      }
    ].filter(@(a) a.show)
  }

  function onPresetMenuOpen() {
    ::gui_right_click_menu(this.getPresetActions(), this)
  }

  function onPresetActionsMenuOpen() {
    let actions = this.getPresetActions()
    if (actions.len() == 1)
      actions[0].action.call(this)
    else
      ::gui_right_click_menu(actions, this)
  }

  isCustomPresetsAvailable = @() this.unit.hasWeaponSlots  && this.availableWeapons.len() > 0
    && hasFeature("WeaponryCustomPresets")

  isCustomPresetsEditAvailable = @() this.isCustomPresetsAvailable()
     && !::is_in_flight() && this.unit.isUsable()

  function updateButtons() {
    let isAvailable = this.isCustomPresetsEditAvailable()
    this.showSceneBtn("newPresetBtn", isAvailable
      && this.presets.filter(isCustomPreset).len() < MAX_PRESETS_NUM)

    if (this.curPresetIdx == null) {
      this.showSceneBtn("actionBtn", false)
      this.showSceneBtn("altActionBtn", false)
      this.showSceneBtn("favoriteBtn", false)
      this.showSceneBtn("openPresetMenuBtn", false)
      return
    }

    let curPreset = this.presets[this.curPresetIdx]
    let actions = this.getPresetActions()
    let isVisibleActionsButton = actions.len() > 0
    let bObj = this.showSceneBtn("openPresetMenuBtn", isVisibleActionsButton)
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
    let actionBtnObj = this.showSceneBtn("actionBtn", btnText != ""
      && (idx != this.chosenPresetIdx || canBuy))
    if (btnText != "" && actionBtnObj?.isValid())
      actionBtnObj.setValue(btnText)
    let altBtnText = params?.weaponryItem.altBtnBuyText ?? ""
    let altActionBtnObj = this.showSceneBtn("altActionBtn", altBtnText != "")
    if (altBtnText != "" && altActionBtnObj?.isValid()) {
      altActionBtnObj.setValue(altBtnText)
      altActionBtnObj.tooltip = params?.weaponryItem.altBtnTooltip ?? ""
    }
    let favoriteBtnObj = this.showSceneBtn("favoriteBtn", true)
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
      isShowConsoleBtn = showConsoleButtons.value
    })
    this.guiScene.replaceContentFromText(this.presetNest, data, data.len(), this)
    // Select chosen or first preset
    local firstIdx = this.presetIdxToChildIdx.findindex(@(_) true)
    this.selectPreset(this.chosenPresetIdx in this.presetIdxToChildIdx ? this.chosenPresetIdx : firstIdx, true)

    // Enable/disable filter options depends on whether filtering result exist.
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
    // All presets have been filtered by rank an placed into presetsByRanks
    // to avoid excess job by each checkbox choice.
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
      // Get all presets if no rank choosen
      pList = pList.len() == 0 ? (clone this.presets) : pList
    }
    if (isFavorite || isAvailable) {
      // Ignore filtering if stored filter has no result for current unit presets.
      let isExistFavorites = this.isFavoritesExist()
      let isExistAvailables = this.isAvailablesExist()
      let filterFunc = @(p)
        (!isFavorite || !isExistFavorites || p.chapterOrd == CHAPTER_FAVORITE_IDX)
          && (!isAvailable || !isExistAvailables || p.isEnabled)
      pList = pList.filter(filterFunc)
      this.presets = this.presets.filter(filterFunc)
    }

    let chpn = this.chosenPresetName
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
    saveLocalAccountSettings($"{MY_FILTERS}/{this.unit.name}",
      ::build_blk_from_container(this.filterStates))
  }

  editWeaponryPreset = @(preset) openEditWeaponryPreset({
    unit = this.unit
    originalPreset = preset
    preset = deep_clone(preset)
    availableWeapons = this.availableWeapons
    favoriteArr = this.favoriteArr
  })

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

  // DEVELOPERS OPTION ONLY
  function updateBuyAllBtn() {
    let isShow = this.multiPurchaseList.len() > 0
    if (isShow)
      placePriceTextToButton(this.scene, "btn_buyAll", loc("mainmenu/btnBuyAll"), this.totalCost)

    this.showSceneBtn("btn_buyAll", isShow)
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
      if (!::shop_is_weapon_available(this.unit.name, preset.name, false, true) || !statusTbl.canBuyMore)
        continue

      this.multiPurchaseList.append(weaponPreset)
      this.totalCost += getItemCost(this.unit, weaponPreset).multiply(statusTbl.maxAmount - statusTbl.amount)
    }

    this.updateBuyAllBtn()
  }

  function buyAll() {
    if (!this.multiPurchaseList.len()) {
      this.isAllBuyProcess = false
      ::save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
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
      setLastWeapon(this.unit.name, this.presets[0].weaponPreset.name)
      ::check_secondary_weapon_mods_recount(this.unit)
      this.checkSaveBulletsAndDo()
    }
    this.updateAllByFilters()
    this.updateCustomIdx()
  }
}

return {
  open = function(params) {
    handlersManager.loadHandler(gui_handlers.weaponryPresetsModal, params)
  }
}
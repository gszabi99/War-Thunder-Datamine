local { TIERS_NUMBER, CHAPTER_ORDER, CHAPTER_FAVORITE_IDX,
  sortPresetLists, setFavoritePresets, getWeaponryByPresetInfo
} = require("scripts/weaponry/weaponryPresetsParams.nut")
local { getLastWeapon, setLastWeapon,
  getWeaponDisabledMods } = require("scripts/weaponry/weaponryInfo.nut")
local { getModificationName } = require("scripts/weaponry/bulletsInfo.nut")
local { getItemAmount, getItemCost, getItemStatusTbl } = require("scripts/weaponry/itemInfo.nut")
local { getWeaponItemViewParams } = require("scripts/weaponry/weaponryVisual.nut")
local { getTierDescTbl, updateWeaponTooltip, getTierTooltipParams
} = require("scripts/weaponry/weaponryTooltipPkg.nut")
local { weaponsPurchase, canBuyItem } = require("scripts/weaponry/weaponsPurchase.nut")
local { placePriceTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
local { openPopupFilter } = require("scripts/popups/popupFilter.nut")
local { appendOnce } = require("sqStdLibs/helpers/u.nut")

const MY_FILTERS = "weaponry_presets/filters"
local FILTER_OPTIONS = ["Favorite", "Available", 1, 2, 3, 4]

class ::gui_handlers.weaponryPresetsModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType              = handlerType.MODAL
  sceneTplName         = "gui/weaponry/weaponryPresetsModal"
  unit                 = null
  chosenPresetIdx      = null
  curPresetIdx         = null
  curTierIdx           = -1
  presetsList          = null
  chooseMenuList       = null
  presets              = null
  presetsByRanks       = null
  lastWeapon           = null
  presetsMarkup        = null
  collapsedPresets     = []
  presetTextWidth      = 0
  onChangeValueCb      = null
  weaponItemParams     = null
  favoriteArr          = null
  chapterPos           = 0
  wndWidth             = 0
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

  function getSceneTplView()
  {
    local tiersWidth = ::to_pixels("".concat(TIERS_NUMBER, "@tierIconSize"))
    local iconWidth = ::show_console_buttons ? ::to_pixels("1@cIco") : 0
    local tiersAndDescWidth = ::to_pixels("".concat(
      "1@narrowTooltipWidth+4@blockInterval+2@scrollBarSize+2@frameHeaderPad"))
        + tiersWidth + iconWidth
    presetTextWidth = ::min(::to_pixels("1@srw") - tiersAndDescWidth,
      ::to_pixels("1@modPresetTextMaxWidth"))
    wndWidth = tiersAndDescWidth + presetTextWidth
    chapterPos = presetTextWidth + 0.5 * tiersWidth + iconWidth
    weaponryByPresetInfo = getWeaponryByPresetInfo(unit, chooseMenuList)
    presets = weaponryByPresetInfo.presets
    favoriteArr = weaponryByPresetInfo.favoriteArr
    presetsList = weaponryByPresetInfo.presetsList
    lastWeapon = initLastWeapon ?? getLastWeapon(unit.name)
    chosenPresetName = lastWeapon
    presetsMarkup = getPresetsMarkup(presets)
    return {
      headerText = "".concat(::loc("modification/category/secondaryWeapon"), " ",
        ::loc("ui/mdash"), " ", ::getUnitName(unit))
      wndWidth = wndWidth
      chapterPos = chapterPos
      presets = presetsMarkup
      isShowConsoleBtn = ::show_console_buttons
    }
  }

  function initScreen()
  {
    local chpn = chosenPresetName
    chosenPresetIdx = presetsList.findindex(@(w) w.name == chpn) ?? 0
    selectPreset(chosenPresetIdx)
    updatePresetsByRanks()
    updateMultiPurchaseList()
    ::move_mouse_on_obj(scene.findObject($"presetHeader_{chosenPresetIdx}"))

    filterObj = scene.findObject("filter_nest")
    myFilters = ::load_local_account_settings($"{MY_FILTERS}/{unit.name}", ::DataBlock())
    fillFilterTypesList()
    // No need to update items if no stored filters for current unit
    if (myFilters != null)
      updateAllByFilters()

    openPopupFilter({
      scene = filterObj
      onChangeFn = onFilterCbChange.bindenv(this)
      filterTypes = getFiltersView()
      isTop = true
    })
  }

  function updatePresetsByRanks() {
    presetsByRanks = {}
    foreach(p in presets)
      presetsByRanks[p.rank] <- (presetsByRanks?[p.rank] ?? []).append(p)
  }

  function getPresetsMarkup(pList) {
    presetIdxToChildIdx = {}
    local res = []
    if (pList == null)
      return res
    local curChapterOrd = 0
    foreach (preset in pList) {
      if (curChapterOrd != preset.chapterOrd) {
        curChapterOrd = preset.chapterOrd
        res.append({
          isCollapsable = true
          chapterName = ::loc($"weapons/purposeType/{CHAPTER_ORDER[curChapterOrd]}")
        })
      }

      local params = weaponItemParams ?
        weaponItemParams.__merge({visualDisabled = !preset.isEnabled}) : {}
      params.__update({
          collapsable = true
          showButtons = true
          actionBtnText = onChangeValueCb != null ? ::loc("mainmenu/btnSelect") : null
        })
      local idx = presets.findindex(@(p) p.id == preset.id)
      presetIdxToChildIdx[idx] <- res.len()
      res.append({
        presetId = idx
        chosen = idx == chosenPresetIdx ? "yes" : "no"
        weaponryItem = getWeaponItemViewParams($"item_{idx}", unit, presetsList[idx], params)
          .__update({
            presetTextWidth = presetTextWidth
            isTypeNone = preset.purposeType == "NONE"
            tiers = presetsList[idx].tiers.map(@(t) {
              tierId        = t.tierId
              img           = t?.img ?? ""
              tierTooltipId = !::show_console_buttons ? t?.tierTooltipId : null
              isActive      = "img" in t
            })
          })
      })
    }

    return res
  }

  function selectPreset(presetIdx, isForced = false) {
    if (curPresetIdx == presetIdx && !isForced)
    {
      updateDesc()
      return
    }

    local nestObj = scene.findObject("presetNest")
    local childIdx = presetIdxToChildIdx?[curPresetIdx]
    if (childIdx != null)
      nestObj.getChild(childIdx).selected = "no"

    local row = scene.findObject($"tiersNest_{curPresetIdx}")
    if (row?.isValid())
      row.setValue(-1)

    curPresetIdx = presetIdx
    childIdx = presetIdxToChildIdx?[presetIdx]
    if (childIdx != null)
      nestObj.getChild(childIdx).selected = "yes"

    updateDesc()
  }

  function selectTier(tierIdx) {
    curTierIdx = tierIdx
    updateTierDesc()
  }

  function onPresetSelect(obj)
  {
    selectPreset(obj.presetId.tointeger())
  }

  function onCellSelect(obj)
  {
    local presetId = obj.presetId.tointeger()
    local value = obj.getValue()
    if (value < 0) {
      if (presetId == curPresetIdx) {
        selectPreset(null)
        selectTier(null)
      }
      return
    }

    selectPreset(presetId)
    selectTier(value - 1)
  }

  function onPresetUnhover(obj) {
    if (::show_console_buttons)
      obj.setValue(-1)
  }

  function updateTierDesc()
  {
    local data = ""
    local descObj = scene.findObject("tierDesc")
    if (curTierIdx >= 0 && curPresetIdx != null)
    {
      local item = presetsList[curPresetIdx]
      local weaponry = item.tiers?[curTierIdx].weaponry
      data = weaponry ? ::handyman.renderCached(("gui/weaponry/weaponTooltip"),
        getTierDescTbl(unit, getTierTooltipParams(weaponry, item.name, curTierIdx))) : ""
    }
    guiScene.replaceContentFromText(descObj, data, data.len())
  }

  function onModItemDblClick(obj)
  {
    local idx = curPresetIdx
    local params = ::u.search(presetsMarkup, @(i) i?.presetId == idx)
    if (params?.weaponryItem.actionBtnCanShow != "no")
      onModActionBtn()
  }

  function onModActionBtn(obj = null)
  {
    if (curPresetIdx == null)
      return

    doItemAction(presetsList[curPresetIdx])
  }

  function onAltModAction(obj)
  {
    if (curPresetIdx == null)
      return
    onBuy(presetsList[curPresetIdx])
  }

  function doItemAction(item)
  {
    guiScene.playSound("check")
    if (onChangeValueCb)
      onChangeValueCb(item)
    else
    {
      local amount = getItemAmount(unit, item)
      if(getLastWeapon(unit.name) == item.name || !amount)
      {
        if (item.cost <= 0)
          return
        return onBuy(item)
      }

      local disabledMods = getWeaponDisabledMods(unit, item)
      if (disabledMods.len() > 0)
      {
        showReqModsMsg(disabledMods)
        return
      }

      setLastWeapon(unit.name, item.name)
      ::check_secondary_weapon_mods_recount(unit)
      checkSaveBulletsAndDo()
    }
    guiScene.performDelayed(this, @()goBack())
  }

  function showReqModsMsg(disabledMods)
  {
    local aUnit = unit
    local modNames = disabledMods.map(@(n) ::colorize("userlogColoredText", getModificationName(aUnit, n)))
    local text = ::loc("weaponry/require_mod_install", {
      modNames = ::loc("ui/colon").join(modNames)
      numMods = disabledMods.len()
    })
    local onOk = ::Callback(@() installMods(disabledMods), this)
    ::scene_msg_box("activate_wager_message_box", null, text, [["yes", onOk], ["no"]], "yes")
  }

  function installMods(disabledMods)
  {
    local aUnit = unit
    local onSuccess = ::Callback(function() {
      disabledMods.each(@(n) ::updateAirAfterSwitchMod(aUnit, n))
      ::broadcastEvent("ModificationChanged")
    }, this)

    local taskId = enable_modifications(unit.name, disabledMods, true)
    ::g_tasker.addTask(taskId, { showProgressBox = true }, onSuccess)
  }

  function onBuy(item)
  {
    if (!::shop_is_weapon_available(unit.name, item.name, false, true))
      return
    checkSaveBulletsAndDo(::Callback((@(unit, item) function() {
      weaponsPurchase(unit, {modItem = item, open = false})
    })(unit, item), this))
  }

  function checkSaveBulletsAndDo(func = null)
  {
    local needSave = false
    if (lastWeapon != "" && lastWeapon != getLastWeapon(unit.name))
    {
      dagor.debug($"force cln_update due lastWeapon '{lastWeapon}' != {getLastWeapon(unit.name)}")
      needSave = true
      lastWeapon = getLastWeapon(unit.name)
    }

    if (needSave)
    {
      taskId = ::save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      if (taskId >= 0 && func)
      {
        local cb = ::u.isFunction(func) ? ::Callback(func, this) : func
        ::g_tasker.addTask(taskId, {showProgressBox = true}, cb)
      }
    }
    else if (func)
      func()
    return true
  }

  function updateDesc()
  {
    local descObj = scene.findObject("desc")
    if (curPresetIdx == null)
    {
      guiScene.replaceContentFromText(descObj, "", 0, this)
      showSceneBtn("actionBtn", false)
      showSceneBtn("altActionBtn", false)
      showSceneBtn("favoriteBtn", false)
      return
    }
    updateWeaponTooltip(descObj, unit, presetsList[curPresetIdx], this, {
      curEdiff = curEdiff
      detail = INFO_DETAIL.FULL
    })
    local idx = curPresetIdx
    local params = ::u.search(presetsMarkup, @(i) i?.presetId == idx)
    local btnText = params?.weaponryItem.actionBtnText ?? ""
    local canBuy = presetsList[idx].cost > 0
    local actionBtnObj = showSceneBtn("actionBtn", btnText != ""
      && (idx != chosenPresetIdx || canBuy))
    if (btnText != "" && actionBtnObj?.isValid())
      actionBtnObj.setValue(btnText)
    local altBtnText = params?.weaponryItem.altBtnBuyText ?? ""
    local altActionBtnObj = showSceneBtn("altActionBtn", altBtnText != "")
    if (altBtnText != "" && altActionBtnObj?.isValid())
    {
      altActionBtnObj.setValue(altBtnText)
      altActionBtnObj.tooltip = params?.weaponryItem.altBtnTooltip ?? ""
    }
    local favoriteBtnObj = showSceneBtn("favoriteBtn", true)
    favoriteBtnObj.setValue(::loc(presetsList[curPresetIdx].chapterOrd != 1
      ? "mainmenu/btnFavorite" : "mainmenu/btnFavoriteUnmark"))
  }

  function updateAll(pList = null)
  {
    if (isAllBuyProcess)
      return

    local presetObj = scene.findObject("presetNest")
    if (!presetObj?.isValid())
      return

    presetsMarkup = getPresetsMarkup(pList ?? presets)
    local data = ::handyman.renderCached("gui/weaponry/weaponryPreset", {
      chapterPos = chapterPos
      presets = presetsMarkup
      isShowConsoleBtn = ::show_console_buttons
    })
    guiScene.replaceContentFromText(presetObj, data, data.len(), this)
    // Select chosen or first preset
    local firstIdx = null
    foreach (idx, v in presetIdxToChildIdx){
      firstIdx = idx
      break
    }
    selectPreset(chosenPresetIdx in presetIdxToChildIdx ? chosenPresetIdx : firstIdx, true)

    // Enable/disable filter options depends on whether filtering result exist.
    local popupObj = filterObj.findObject("filter_popup")
    if (!popupObj?.isValid())
      return

    local fObj = popupObj.findObject("f_Favorite")
    local aObj = popupObj.findObject("f_Available")
    if (fObj?.isValid()) {
      fObj.setValue(isFavoritesExist() && filterStates.findindex(@(p) p == "f_Favorite") != null)
      fObj.enable(isFavoritesExist())
    }
    if (aObj?.isValid()) {
      aObj.setValue(isAvailablesExist() && filterStates.findindex(@(p) p == "f_Available") != null)
      aObj.enable(isAvailablesExist())
    }
  }

  function onEventWeaponPurchased(p) { updateAll(); updateMultiPurchaseList() }

  function onCollapse(obj)
  {
    local itemObj = obj?.collapse_header ? obj : obj.getParent()
    local listObj = itemObj?.isValid() ? itemObj.getParent() : null
    if (!listObj?.isValid() || !itemObj?.collapse_header)
      return

    itemObj.collapsing = "yes"
    local isShow = itemObj?.collapsed == "yes"
    local listLen = listObj.childrenCount()
    local selIdx = listObj.getValue()
    local headerIdx = -1
    local needReselect = false

    local found = false
    for (local i = 0; i < listLen; i++)
    {
      local child = listObj.getChild(i)
      if (!found)
      {
        if (child?.collapsing == "yes")
        {
          child.collapsing = "no"
          child.collapsed  = isShow ? "no" : "yes"
          headerIdx = i
          found = true
        }
      }
      else
      {
        if (child?.collapse_header)
          break
        child.show(isShow)
        child.enable(isShow)
        if (!isShow && i == selIdx)
          needReselect = true
      }
    }

    if (needReselect)
    {
      local indexes = []
      for (local i = selIdx + 1; i < listLen; i++)
        indexes.append(i)
      for (local i = selIdx - 1; i >= 0; i--)
        indexes.append(i)

      local newIdx = -1
      foreach (idx in indexes)
      {
        local child = listObj.getChild(idx)
        if (!child?.collapse_header && child.isEnabled())
        {
          newIdx = idx
          break
        }
      }
      selIdx = newIdx != -1 ? newIdx : headerIdx
      listObj.setValue(selIdx)
    }

    if (collapsedPresets && !::u.isEmpty(itemObj?.id))
    {
      local idx = ::find_in_array(collapsedPresets, itemObj.id)
      if (isShow && idx != -1)
        collapsedPresets.remove(idx)
      else if (!isShow && idx == -1)
        collapsedPresets.append(itemObj.id)
    }
  }

  function onChangeFavorite(obj)
  {
    local preset = presets[curPresetIdx]
    local isFavorite = preset.chapterOrd == CHAPTER_FAVORITE_IDX
    local chapterOrd = isFavorite
      ? CHAPTER_ORDER.findindex(@(p) p == preset.purposeType) : CHAPTER_FAVORITE_IDX
    if (isFavorite)
    {
      local idx = favoriteArr.findindex(@(id) id == preset.id)
      if (idx != null)
        favoriteArr.remove(idx)
    }
    else
      favoriteArr.append(preset.id)
    setFavoritePresets(unit.name, favoriteArr)
    preset.chapterOrd = chapterOrd
    presetsList[curPresetIdx].chapterOrd = chapterOrd
    sortPresetLists([presets, presetsList])
    updateAllByFilters()
  }

  function getFiltersView() {
    local view = { checkbox = []}
    foreach(key, inst in filterTypes)
      view.checkbox.append({
        id = inst.id
        idx = inst.idx
        text = inst.text
        isDisable = inst.isDisable
        value = !inst.isDisable && filterStates.findindex(@(v) v == key) != null
      })
    view.checkbox.sort(@(a,b) a.idx <=> b.idx)
    return [view]
  }

  isFavoritesExist = @() favoriteArr.len() > 0
  isAvailablesExist = @() presets.filter(@(p) p.isEnabled).len() > 0

  function fillFilterTypesList() {
    filterStates = myFilters ? myFilters % "array" : []
    filterTypes = {}
    foreach(idx, key in FILTER_OPTIONS) {
      local isRank = typeof(key) != "string"
      if ((isRank && !presetsByRanks?[key]))
        continue

      local id = $"f_{key}"
      filterTypes[id] <- {
        id    = id
        idx   = idx
        isDisable = (key == FILTER_OPTIONS[0] && !isFavoritesExist())
          || (key == FILTER_OPTIONS[1] && !isAvailablesExist())
        text  = isRank ? $"{::loc("conditions/rank")} {::get_roman_numeral(key)}"
          : ::loc($"mainmenu/only{key}")
      }
    }
  }

  function updateAllByFilters() {
    local isFavorite = false
    local isAvailable = false
    local pList = []
    // All presets have been filtered by rank an placed into presetsByRanks
    // to avoid excess job by each checkbox choice.
    foreach (inst in filterStates) {
      if (inst != "f_Favorite" && inst != "f_Available") {
        local p = presetsByRanks?[inst.split("f_")[1].tointeger()]
        if (p != null)
         pList.extend(p)
      } else {
        isFavorite = inst == "f_Favorite" || isFavorite
        isAvailable = inst == "f_Available" || isAvailable
      }
    }

    if (pList.len() == 0 || !isFavorite || !isAvailable) {
      presets = weaponryByPresetInfo.presets
      presetsList = weaponryByPresetInfo.presetsList
      // Get all presets if no rank choosen
      pList = pList.len() == 0 ? presets : pList
    }
    if (isFavorite || isAvailable) {
      // Ignore filtering if stored filter has no result for current unit presets.
      local isExistFavorites = isFavoritesExist()
      local isExistAvailables = isAvailablesExist()
      local filterFunc = @(p)
        (!isFavorite || !isExistFavorites || p.chapterOrd == CHAPTER_FAVORITE_IDX)
          && (!isAvailable || !isExistAvailables || p.isEnabled)
      pList = pList.filter(filterFunc)
      presets = presets.filter(filterFunc)
      presetsList = presetsList.filter(filterFunc)
    }

    sortPresetLists([pList])
    local chpn = chosenPresetName
    chosenPresetIdx = presetsList.findindex(@(w) w.name == chpn)
    updateAll(pList)
  }

  function onFilterCbChange(objId, tName, value) {
    if (value)
      appendOnce(objId, filterStates)
    else {
      local idx = filterStates.findindex(@(v) v == objId)
      if (idx != null)
        filterStates.remove(idx)
    }

    updateAllByFilters()
    ::save_local_account_settings($"{MY_FILTERS}/{unit.name}",
      ::build_blk_from_container(filterStates))
  }

  // DEVELOPERS OPTION ONLY
  function updateBuyAllBtn()
  {
    local isShow = multiPurchaseList.len() > 0
    if (isShow)
      placePriceTextToButton(scene, "btn_buyAll", ::loc("mainmenu/btnBuyAll"), totalCost)

    showSceneBtn("btn_buyAll", isShow)
  }

  onBuyAll = @() buyAll()
  onEventProfileUpdated = @ (p) updateBuyAllBtn()

  function updateMultiPurchaseList()
  {
    multiPurchaseList = []
    if (isAllBuyProcess || !::has_feature("BuyAllPresets"))
      return

    totalCost = ::Cost()
    foreach (item in presetsList)
    {
      local statusTbl = getItemStatusTbl(unit, item)
      if (!::shop_is_weapon_available(unit.name, item.name, false, true) || !statusTbl.canBuyMore)
        continue

      multiPurchaseList.append(item)
      totalCost += getItemCost(unit, item).multiply(statusTbl.maxAmount - statusTbl.amount)
    }

    updateBuyAllBtn()
  }

  function buyAll()
  {
    if (!multiPurchaseList.len())
    {
      isAllBuyProcess = false
      ::save_online_single_job(SAVE_WEAPON_JOB_DIGIT)
      updateAll()
      updateMultiPurchaseList()
      return
    }

    if (!canBuyItem(totalCost, unit))
      return

    local item = multiPurchaseList.pop()
    local statusTbl = getItemStatusTbl(unit, item)
    totalCost -= getItemCost(unit, item).multiply(statusTbl.maxAmount - statusTbl.amount)
    isAllBuyProcess = true
    weaponsPurchase(unit, {modItem = item, open = false, silent = true, isAllPresetPurchase = true,
      afterSuccessfullPurchaseCb = ::Callback(@() buyAll(), this)})
  }
}

return {
  open = function(params)
  {
    ::handlersManager.loadHandler(::gui_handlers.weaponryPresetsModal, params)
  }
}
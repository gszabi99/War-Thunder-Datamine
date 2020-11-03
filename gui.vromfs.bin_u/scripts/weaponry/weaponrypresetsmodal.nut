local { TIERS_NUMBER,
        CHAPTER_ORDER,
        CHAPTER_FAVORITE_IDX,
        sortPresetLists,
        setFavoritePresets,
        getWeaponryByPresetInfo } = require("scripts/weaponry/weaponryPresetsParams.nut")
local { getLastWeapon,
        setLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local { getItemAmount } = require("scripts/weaponry/itemInfo.nut")
local { getTierDescTbl,
        getWeaponItemViewParams,
        updateWeaponTooltip } = require("scripts/weaponry/weaponryVisual.nut")

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
  weaponryByPresetInfo = null
  lastWeapon           = null
  presetsMarkup        = null
  collapsedPresets     = []
  chapterCount         = 0
  presetTextWidth      = 0
  isWorldWarUnit       = false
  onChangeValueCb      = null
  weaponItemParams     = null
  favoriteArr          = null
  chapterPos           = 0
  wndWidth             = 0

  presetIdxToChildIdx  = null

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
    favoriteArr = weaponryByPresetInfo.favoriteArr
    presetsList = weaponryByPresetInfo.presetsList
    lastWeapon = !isWorldWarUnit ?
      getLastWeapon(unit.name) : ::g_world_war.get_last_weapon_preset(unit.name)
    local lw = lastWeapon
    chosenPresetIdx = presetsList.findindex(@(w) w.name == lw) ?? 0
    presetsMarkup = getPresetsMarkup()
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
    selectPreset(chosenPresetIdx)
    ::move_mouse_on_obj(scene.findObject($"presetHeader_{chosenPresetIdx}"))
  }

  function getPresetsMarkup()
  {
    presetIdxToChildIdx = {}
    local res = []
    local curChapterOrd = 0
    foreach (idx, preset in weaponryByPresetInfo.presets)
    {
      if (curChapterOrd != preset.chapterOrd && preset.purposeType != "NONE")
      {
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
          selected = idx == chosenPresetIdx
          showButtons = true
          actionBtnText = onChangeValueCb != null ? ::loc("mainmenu/btnSelect") : null
        })
      presetIdxToChildIdx[idx] <- res.len()
      res.append({
        presetId = idx
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

  function selectPreset(presetIdx) {
    if (curPresetIdx == presetIdx)
      return

    local nestObj = scene.findObject("presetNest")
    local childIdx = presetIdxToChildIdx?[curPresetIdx]
    if (childIdx != null)
      nestObj.getChild(childIdx).selected = "no"

    local row = scene.findObject($"tiersNest_{curPresetIdx}")
    if (::check_obj(row))
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
        getTierDescTbl(unit, weaponry, item.name, curTierIdx)) : ""
    }
    guiScene.replaceContentFromText(descObj, data, data.len())
  }

  function onModItemDblClick(obj)
  {
    local idx = curPresetIdx
    local itemParams = ::u.search(presetsMarkup, @(i) i?.presetId == idx)
    if (itemParams?.weaponryItem.actionBtnCanShow != "no")
      onModActionBtn()
  }

  function onModActionBtn(obj = null)
  {
    if (curPresetIdx == null)
      return
    chosenPresetIdx = curPresetIdx
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
      setLastWeapon(unit.name, item.name)
      ::check_secondary_weapon_mods_recount(unit)
      checkSaveBulletsAndDo()
    }
    guiScene.performDelayed(this, @()goBack())
  }

  function onBuy(item)
  {
    if (!::shop_is_weapon_available(unit.name, item.name, false, true))
      return
    checkSaveBulletsAndDo(::Callback((@(unit, item) function() {
      ::WeaponsPurchase(unit, {modItem = item, open = false})
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
    updateWeaponTooltip(descObj, unit, presetsList[curPresetIdx], this, {detail = INFO_DETAIL.FULL})
    local idx = curPresetIdx
    local itemParams = ::u.search(presetsMarkup, @(i) i?.presetId == idx)
    local btnText = itemParams?.weaponryItem.actionBtnText ?? ""
    local actionBtnObj = showSceneBtn("actionBtn", btnText != "" && idx != chosenPresetIdx)
    if (btnText != "" && ::check_obj(actionBtnObj))
      actionBtnObj.setValue(btnText)
    local altBtnText = itemParams?.weaponryItem.altBtnBuyText ?? ""
    local altActionBtnObj = showSceneBtn("altActionBtn", altBtnText != "")
    if (altBtnText != "" && ::check_obj(altActionBtnObj))
    {
      altActionBtnObj.setValue(altBtnText)
      altActionBtnObj.tooltip = itemParams?.weaponryItem.altBtnTooltip ?? ""
    }
    local favoriteBtnObj = showSceneBtn("favoriteBtn", true)
    favoriteBtnObj.setValue(::loc(presetsList[curPresetIdx].chapterOrd != 1
      ? "mainmenu/btnFavorite" : "mainmenu/btnFavoriteUnmark"))
  }

  function updateAllItems()
  {
    presetsMarkup = getPresetsMarkup()
    local data = ::handyman.renderCached("gui/weaponry/weaponryPreset", {
        wndWidth = wndWidth
        chapterPos = chapterPos
        presets = presetsMarkup
        isShowConsoleBtn = ::show_console_buttons
      })
    local presetObj = scene.findObject("presetNest")
    if (!::check_obj(presetObj))
      return
    guiScene.replaceContentFromText(presetObj, data, data.len(), this)
    selectPreset(curPresetIdx)
  }

  function onEventWeaponPurchased(params) { updateAllItems() }
  function onEventUnitWeaponChanged(params) { updateAllItems() }

  function onCollapse(obj)
  {
    local itemObj = obj?.collapse_header ? obj : obj.getParent()
    local listObj = ::check_obj(itemObj) ? itemObj.getParent() : null
    if (!::check_obj(listObj) || !itemObj?.collapse_header)
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
    local preset = weaponryByPresetInfo.presets[curPresetIdx]
    local isSelected = preset.chapterOrd == CHAPTER_FAVORITE_IDX
    local chapterOrd = isSelected
      ? CHAPTER_ORDER.findindex(@(p) p == preset.purposeType) : CHAPTER_FAVORITE_IDX
    if (isSelected)
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
    sortPresetLists([weaponryByPresetInfo.presets, presetsList])
    updateAllItems()
  }
}

return {
  open = function(params)
  {
    ::handlersManager.loadHandler(::gui_handlers.weaponryPresetsModal, params)
  }
}
local { TIERS_NUMBER,
        getTiers,
        getWeaponryByPresetInfo } = require("scripts/weaponry/weaponryPresetsParams.nut")
local { getLastWeapon,
        setLastWeapon,
        getSecondaryWeaponsList } = require("scripts/weaponry/weaponryInfo.nut")
local { getItemAmount } = require("scripts/weaponry/itemInfo.nut")
local { getWeaponItemViewParams,
        updateWeaponTooltip } = require("scripts/weaponry/weaponryVisual.nut")

class ::gui_handlers.weaponryPresetsModal extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType              = handlerType.MODAL
  sceneTplName         = "gui/weaponry/weaponryPresetsModal"
  unit                 = null
  chosenPresetIdx      = null
  curPresetIdx         = null
  presetsList          = null
  weaponryByPresetInfo = null
  lastWeapon           = null
  presetsMarkup        = null
  collapsedPresets     = []
  chapterCount         = 0
  presetTextWidth      = 0

  function getSceneTplView()
  {
    local tiersAndDescWidth = ::to_pixels(
      "".concat(TIERS_NUMBER,
        "@tierIconSize+1@narrowTooltipWidth+6@blockInterval+2@scrollBarSize+2@frameHeaderPad"))
    presetTextWidth = ::min(::to_pixels("1@srw") - tiersAndDescWidth,
      ::to_pixels("1@modPresetTextMaxWidth"))
    presetsList = getSecondaryWeaponsList(unit).sort(@(a, b)
      a.chapterOrd <=> b.chapterOrd
      || b.isEnabled <=> a.isEnabled
      || b.isDefault <=> a.isDefault)
    weaponryByPresetInfo = getWeaponryByPresetInfo(unit, presetsList)
    lastWeapon = getLastWeapon(unit.name)
    local lw = lastWeapon
    chosenPresetIdx = presetsList.findindex(@(w) w.name == lw) ?? 0
    presetsMarkup = getPresetsMarkup()
    return {
      headerText = "".concat(::loc("modification/category/secondaryWeapon"), " ",
        ::loc("ui/mdash"), " ", ::getUnitName(unit))
      wndWidth = tiersAndDescWidth + presetTextWidth
      presets = presetsMarkup
    }
  }

  function initScreen()
  {
    curPresetIdx = chosenPresetIdx
    selectCurrentPreset()
  }

  function getPresetsMarkup()
  {
    local res = []
    local curType = ""
    foreach (idx, preset in weaponryByPresetInfo.presets)
    {
      if (curType != preset.presetPurposeType && preset.presetPurposeType != "NONE")
      {
        curType = preset.presetPurposeType
        res.append({
          isCollapsable = true
          purposeTypeName = ::loc($"weapons/purposeType/{ preset.presetPurposeType }")
        })
      }

      res.append({
        presetId = idx
        weaponryItem = getWeaponItemViewParams($"item_{idx}", unit, presetsList[idx],
          {
            collapsable = true
            selected = idx == chosenPresetIdx
            showButtons = true
          }).__update({
              presetTextWidth = presetTextWidth
              tiers = getTiers(unit, preset, weaponryByPresetInfo.weaponrySizes)
            })
      })
    }

    return res
  }

  function onItemSelect(obj)
  {
    local listObj = obj.getChild(obj.getValue())
    if (!listObj)
      return
    curPresetIdx = listObj.presetId != "" ? listObj.presetId.tointeger() : -1
    listObj.select()
    updateDesc()
  }

  function selectCurrentPreset()
  {
    local nestObj = scene.findObject("presetNest")
    for (local i=0; i < nestObj.childrenCount(); i++)
    {
      local obj = nestObj.getChild(i)
      if (obj.presetId == curPresetIdx.tostring())
      {
        nestObj.setValue(i)
        obj.select()
        return
      }
    }
    restoreFocus()
  }

  function onModItemClick(obj)
  {
    curPresetIdx = obj.presetId.tointeger()
    selectCurrentPreset()
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
    chosenPresetIdx = curPresetIdx
    local item = presetsList[curPresetIdx]
    doItemAction(item)
  }

  function onAltModAction(obj)
  {
    onBuy(presetsList[curPresetIdx])
  }

  function doItemAction(item)
  {
    local amount = getItemAmount(unit, item)
    if(getLastWeapon(unit.name) == item.name || !amount)
    {
      if (item.cost <= 0)
        return
      return onBuy(item)
    }

    ::play_gui_sound("check")
    setLastWeapon(unit.name, item.name)
    ::check_secondary_weapon_mods_recount(unit)
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

  function checkSaveBulletsAndDo(func)
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
    if (::check_obj(descObj))
      if (curPresetIdx < 0)
      {
        guiScene.replaceContentFromText(descObj, "", 0, this)
        showSceneBtn("actionBtn", false)
        showSceneBtn("altActionBtn", false)
        return
      }
    updateWeaponTooltip(descObj, unit, presetsList[curPresetIdx], this)
    local idx = curPresetIdx
    local itemParams = ::u.search(presetsMarkup, @(i) i?.presetId == idx)
    local btnText = itemParams?.weaponryItem.actionBtnText ?? ""
    local actionBtnObj =  showSceneBtn("actionBtn", btnText != "")
    if (btnText != "" && ::check_obj(actionBtnObj))
      actionBtnObj.setValue(btnText)
    local altBtnText = itemParams?.weaponryItem.altBtnBuyText ?? ""
    local altActionBtnObj = showSceneBtn("altActionBtn", altBtnText != "")
    if (altBtnText != "" && ::check_obj(altActionBtnObj))
    {
      altActionBtnObj.setValue(altBtnText)
      altActionBtnObj.tooltip = itemParams?.weaponryItem.altBtnTooltip ?? ""
    }
  }

  function updateAllItems()
  {
    presetsMarkup = getPresetsMarkup()
    local data = ::handyman.renderCached("gui/weaponry/weaponryPreset",
      {presets = presetsMarkup})
    local presetObj = scene.findObject("presetNest")
    if (!::check_obj(presetObj))
      return
    guiScene.replaceContentFromText(presetObj, data, data.len(), this)
    selectCurrentPreset()
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
}

return {
  open = function(params)
  {
    ::handlersManager.loadHandler(::gui_handlers.weaponryPresetsModal, params)
  }
}
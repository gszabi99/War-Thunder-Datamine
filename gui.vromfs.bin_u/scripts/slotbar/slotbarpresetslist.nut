::SlotbarPresetsList <- class
{
  scene = null
  ownerWeak = null
  maxPresets = 0
  curPresetsData = null //to avoid updates when no changes

  NULL_PRESET_DATA = { isEnabled = false, title = "" } //const

  constructor(handler)
  {
    ownerWeak = handler.weakref()
    if (!::checkObj(ownerWeak.scene))
      return
    scene = ownerWeak.scene.findObject("slotbar-presetsPlace")
    if (!::checkObj(scene))
      return

    scene.show(true)
    maxPresets = ::slotbarPresets.getTotalPresetsCount()
    curPresetsData = array(maxPresets, NULL_PRESET_DATA)
    local view = {
      presets = array(maxPresets, null)
      isSmallFont = ::is_low_width_screen()
    }
    local blk = ::handyman.renderCached(("gui/slotbar/slotbarPresets"), view)
    scene.getScene().replaceContentFromText(scene, blk, blk.len(), this)
    update()

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT)
  }

  function destroy()
  {
    if (!isValid())
      return
    scene.getScene().replaceContentFromText(scene, "", 0, null)
    scene = null
  }

  function isValid()
  {
    return ::checkObj(scene)
  }

  function getCurCountry()
  {
    return ownerWeak ? ownerWeak.getCurSlotbarCountry() : ""
  }

  function getPresetsData()
  {
    local curPresetIdx = getCurPresetIdx()
    local res = ::u.mapAdvanced(::slotbarPresets.list(getCurCountry()),
      @(l, idx, ...) {
        title = l.title
        isEnabled = l.enabled || idx == curPresetIdx //enable current preset for list
      })

    res.resize(maxPresets, NULL_PRESET_DATA)
    return res
  }

  function update()
  {
    if(::is_small_screen)
      return

    local listObj = getListObj()
    if (!listObj)
      return

    local newPresetsData = getPresetsData()
    local curPresetIdx = getCurPresetIdx()
    local hasVisibleChanges = curPresetIdx != listObj.getValue()
    for(local i = 0; i < maxPresets; i++)
      if (updatePresetObj(listObj.getChild(i), curPresetsData[i], newPresetsData[i]))
        hasVisibleChanges = true

    curPresetsData = newPresetsData
    if (!hasVisibleChanges)
      return

    if (curPresetIdx >= 0)
      listObj.setValue(curPresetIdx)
    updateSizes(true)
  }

  function updatePresetObj(obj, wasData, newData)
  {
    if (::u.isEqual(wasData, newData))
      return false

    local isEnabled = newData.isEnabled
    showObj(obj, isEnabled)
    if (!isEnabled)
      return wasData.isEnabled

    obj.findObject("tab_text").setValue(newData.title)
    return true
  }

  function showObj(obj, needShow)
  {
    obj.show(needShow)
    obj.enable(needShow)
  }

  _lastListWidth = 0
  function updateSizes(needFullRecount = false)
  {
    scene.getScene().applyPendingChanges(false)
    local listObj = getListObj()
    local availWidth = listObj.getSize()[0]
    if (!needFullRecount && _lastListWidth == availWidth)
      return

    _lastListWidth = availWidth
    availWidth -= listObj.findObject("btn_slotbar_presets").getSize()[0]

    //count all sizes
    local widthList = []
    local totalWidth = 0
    for(local i = 0; i < maxPresets; i++)
    {
      local width = 0
      if (curPresetsData[i].isEnabled)
        width = listObj.getChild(i).getSize()[0]
      totalWidth += width
      widthList.append(width)
    }

    //update all items visibility
    local curPresetIdx = getCurPresetIdx()
    for(local i = maxPresets - 1; i >= 0; i--)
      if (curPresetsData[i].isEnabled)
      {
        local isVisible = totalWidth <= availWidth || i == curPresetIdx
        showObj(listObj.getChild(i), isVisible)
        if (!isVisible)
          totalWidth -= widthList[i]
      }
  }

  function getCurPresetIdx() //current choosen preset
  {
    return ::slotbarPresets.getCurrent(getCurCountry(), 0)
  }

  function getSelPresetIdx() //selected preset in view
  {
    local listObj = getListObj()
    if (!listObj)
      return getCurPresetIdx()

    local value = listObj.getValue()
    if (value < 0 || value >= (listObj.childrenCount() -1)) //last index is button 'presets'
      return -1
    return value
  }

  function isPresetChanged()
  {
    local idx = getSelPresetIdx()
    return idx != getCurPresetIdx()
  }

  function applySelect()
  {
    if (!::slotbarPresets.canLoad(true, getCurCountry()))
      return update()

    local idx = getSelPresetIdx()
    if (idx < 0)
    {
      update()
      return ::gui_choose_slotbar_preset(ownerWeak)
    }

    if (("canPresetChange" in ownerWeak) && !ownerWeak.canPresetChange())
      return

    ::slotbarPresets.load(idx)
    update()
  }

  function onPresetChange()
  {
    if ((ownerWeak?.getSlotbar().slotbarOninit ?? false) || !isPresetChanged())
      return

    checkChangePresetAndDo(applySelect)
  }

  function checkChangePresetAndDo(action)
  {
    ::queues.checkAndStart(
      ::Callback(function()
      {
        ::g_squad_utils.checkSquadUnreadyAndDo(
          ::Callback(function()
          {
             if (!("beforeSlotbarChange" in ownerWeak))
               return action()

             ownerWeak.beforeSlotbarChange(
               ::Callback(action, this),
               ::Callback(update, this)
             )
          }, this),
          ::Callback(update, this),
          ownerWeak?.shouldCheckCrewsReady)
      }, this),
      ::Callback(update, this),
      "isCanModifyCrew"
    )
  }

  function onSlotsChoosePreset(obj)
  {
    checkChangePresetAndDo(function () {
      ::gui_choose_slotbar_preset(ownerWeak)
    })
  }

  function onEventSlotbarPresetLoaded(p)
  {
    update()
  }

  function onEventSlotbarPresetsChanged(p)
  {
    update()
  }

  function onEventVoiceChatOptionUpdated(p)
  {
    updateSizes(true)
  }

  function onEventClanChanged(p)
  {
    updateSizes(true)
  }

  function onEventSquadStatusChanged(p)
  {
    scene.getScene().performDelayed(this, function()
    {
      if (isValid())
        updateSizes()
    })
  }

  function getListObj()
  {
    if (!::checkObj(scene))
      return null
    local obj = scene.findObject("slotbar-presetsList")
    if (::checkObj(obj))
      return obj
    return null
  }

  function getPresetsButtonObj()
  {
    if (scene == null)
      return null
    local obj = scene.findObject("btn_slotbar_presets")
    if (::checkObj(obj))
      return obj
    return null
  }

  /**
   * Returns list child object if specified preset is in slotbar
   * list or "Presets" button object if preset not found.
   */
  function getListChildByPresetIdx(presetIdx)
  {
    local listObj = getListObj()
    if (listObj == null)
      return null
    if (presetIdx < 0 || listObj.childrenCount() <= presetIdx)
      return null
    local childObj = listObj.getChild(presetIdx)
    if (::checkObj(childObj))
      return childObj
    return null
  }
}

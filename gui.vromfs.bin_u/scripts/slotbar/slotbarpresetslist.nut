from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")

::SlotbarPresetsList <- class
{
  scene = null
  ownerWeak = null
  maxPresets = 0
  curPresetsData = null //to avoid updates when no changes

  NULL_PRESET_DATA = { isEnabled = false, title = "" } //const

  constructor(handler)
  {
    this.ownerWeak = handler.weakref()
    if (!checkObj(this.ownerWeak.scene))
      return
    this.scene = this.ownerWeak.scene.findObject("slotbar-presetsPlace")
    if (!checkObj(this.scene))
      return

    this.scene.show(true)
    this.maxPresets = ::slotbarPresets.getTotalPresetsCount()
    this.curPresetsData = array(this.maxPresets, this.NULL_PRESET_DATA)
    let view = {
      presets = array(this.maxPresets, null)
      isSmallFont = ::is_low_width_screen()
    }
    let blk = ::handyman.renderCached(("%gui/slotbar/slotbarPresets.tpl"), view)
    this.scene.getScene().replaceContentFromText(this.scene, blk, blk.len(), this)
    this.update()

    ::subscribe_handler(this, ::g_listener_priority.DEFAULT)
  }

  function destroy()
  {
    if (!this.isValid())
      return
    this.scene.getScene().replaceContentFromText(this.scene, "", 0, null)
    this.scene = null
  }

  function isValid()
  {
    return checkObj(this.scene)
  }

  function getCurCountry()
  {
    return this.ownerWeak ? this.ownerWeak.getCurSlotbarCountry() : ""
  }

  function getPresetsData()
  {
    let curPresetIdx = this.getCurPresetIdx()
    let res = ::u.mapAdvanced(::slotbarPresets.list(this.getCurCountry()),
      @(l, idx, ...) {
        title = l.title
        isEnabled = l.enabled || idx == curPresetIdx //enable current preset for list
      })

    res.resize(this.maxPresets, this.NULL_PRESET_DATA)
    return res
  }

  function update()
  {
    if(isSmallScreen)
      return

    let listObj = this.getListObj()
    if (!listObj)
      return

    let newPresetsData = this.getPresetsData()
    let curPresetIdx = this.getCurPresetIdx()
    local hasVisibleChanges = curPresetIdx != listObj.getValue()
    for(local i = 0; i < this.maxPresets; i++)
      if (this.updatePresetObj(listObj.getChild(i), this.curPresetsData[i], newPresetsData[i]))
        hasVisibleChanges = true

    this.curPresetsData = newPresetsData
    if (!hasVisibleChanges)
      return

    if (curPresetIdx >= 0)
      listObj.setValue(curPresetIdx)
    this.updateSizes(true)
  }

  function updatePresetObj(obj, wasData, newData)
  {
    if (::u.isEqual(wasData, newData))
      return false

    let isEnabled = newData.isEnabled
    this.showObj(obj, isEnabled)
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
    this.scene.getScene().applyPendingChanges(false)
    let listObj = this.getListObj()
    local availWidth = listObj.getSize()[0]
    if (!needFullRecount && this._lastListWidth == availWidth)
      return

    this._lastListWidth = availWidth
    availWidth -= listObj.findObject("btn_slotbar_presets").getSize()[0]

    //count all sizes
    let widthList = []
    local totalWidth = 0
    for(local i = 0; i < this.maxPresets; i++)
    {
      local width = 0
      if (this.curPresetsData[i].isEnabled)
        width = listObj.getChild(i).getSize()[0]
      totalWidth += width
      widthList.append(width)
    }

    //update all items visibility
    let curPresetIdx = this.getCurPresetIdx()
    for(local i = this.maxPresets - 1; i >= 0; i--)
      if (this.curPresetsData[i].isEnabled)
      {
        let isVisible = totalWidth <= availWidth || i == curPresetIdx
        this.showObj(listObj.getChild(i), isVisible)
        if (!isVisible)
          totalWidth -= widthList[i]
      }
  }

  function getCurPresetIdx() //current choosen preset
  {
    return ::slotbarPresets.getCurrent(this.getCurCountry(), 0)
  }

  function getSelPresetIdx() //selected preset in view
  {
    let listObj = this.getListObj()
    if (!listObj)
      return this.getCurPresetIdx()

    let value = listObj.getValue()
    if (value < 0 || value >= (listObj.childrenCount() -1)) //last index is button 'presets'
      return -1
    return value
  }

  function isPresetChanged()
  {
    let idx = this.getSelPresetIdx()
    return idx != this.getCurPresetIdx()
  }

  function applySelect()
  {
    if (!::slotbarPresets.canLoad(true, this.getCurCountry()))
      return this.update()

    let idx = this.getSelPresetIdx()
    if (idx < 0)
    {
      this.update()
      return ::gui_choose_slotbar_preset(this.ownerWeak)
    }

    if (("canPresetChange" in this.ownerWeak) && !this.ownerWeak.canPresetChange())
      return

    ::slotbarPresets.load(idx)
    this.update()
  }

  function onPresetChange()
  {
    if ((this.ownerWeak?.getSlotbar().slotbarOninit ?? false) || !this.isPresetChanged())
      return

    this.checkChangePresetAndDo(this.applySelect)
  }

  function checkChangePresetAndDo(action)
  {
    ::queues.checkAndStart(
      Callback(function()
      {
        ::g_squad_utils.checkSquadUnreadyAndDo(
          Callback(function()
          {
             if (!("beforeSlotbarChange" in this.ownerWeak))
               return action()

             this.ownerWeak.beforeSlotbarChange(
               Callback(action, this),
               Callback(this.update, this)
             )
          }, this),
          Callback(this.update, this),
          this.ownerWeak?.shouldCheckCrewsReady)
      }, this),
      Callback(this.update, this),
      "isCanModifyCrew"
    )
  }

  function onSlotsChoosePreset(_obj)
  {
    this.checkChangePresetAndDo(function () {
      ::gui_choose_slotbar_preset(this.ownerWeak)
    })
  }

  function onEventSlotbarPresetLoaded(_p)
  {
    this.update()
  }

  function onEventSlotbarPresetsChanged(_p)
  {
    this.update()
  }

  function onEventVoiceChatOptionUpdated(_p)
  {
    this.updateSizes(true)
  }

  function onEventClanChanged(_p)
  {
    this.updateSizes(true)
  }

  function onEventSquadStatusChanged(_p)
  {
    this.scene.getScene().performDelayed(this, function()
    {
      if (this.isValid())
        this.updateSizes()
    })
  }

  function getListObj()
  {
    if (!checkObj(this.scene))
      return null
    let obj = this.scene.findObject("slotbar-presetsList")
    if (checkObj(obj))
      return obj
    return null
  }

  function getPresetsButtonObj()
  {
    if (this.scene == null)
      return null
    let obj = this.scene.findObject("btn_slotbar_presets")
    if (checkObj(obj))
      return obj
    return null
  }

  /**
   * Returns list child object if specified preset is in slotbar
   * list or "Presets" button object if preset not found.
   */
  function getListChildByPresetIdx(presetIdx)
  {
    let listObj = this.getListObj()
    if (listObj == null)
      return null
    if (presetIdx < 0 || listObj.childrenCount() <= presetIdx)
      return null
    let childObj = listObj.getChild(presetIdx)
    if (checkObj(childObj))
      return childObj
    return null
  }
}

import "%sqStdLibs/helpers/u.nut" as u
from "%sqStdLibs/helpers/subscriptions.nut" import subscribe_handler
from "dagor.localize" import doesLocTextExist
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isSmallScreen } = require("%scripts/clientState/touchScreen.nut")
let { checkSquadUnreadyAndDo } = require("%scripts/squads/squadUtils.nut")
let { is_low_width_screen } = require("%scripts/options/safeAreaMenu.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")
let { openSlotbarPresetSettings } = require("%scripts/slotbar/slotbarPresets/slotbarPresetsSettingsWnd.nut")
let { MAX_COUNTRY_PRESETS_AMOUNT, canLoadSlotbarPreset, loadSlotbarPreset } = require("%scripts/slotbar/slotbarPresets.nut")
let { getCurrentPresetIdx } = require("%scripts/slotbar/slotbarPresetsState.nut")
let { getGameModeById } = require("%scripts/gameModes/gameModeManagerState.nut")
let { isShowModes, isShowTitles, isShowRatings, isAbbreviateModes, isAutoAbbreviation, getPresetsDataByCountry } = require("%scripts/slotbar/slotbarPresets/slotbarPresetsUtils.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { openSlotbarPresetsListEditWnd } = require("%scripts/slotbar/slotbarPresets/slotbarPresetsEdit.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

const MAX_AUTO_TABS_WIDTH_K = 3

let autoAbbrTypes = {
  max = { gmShowType = "full", name = true }
  mid = { gmShowType = "abbr", name = true }
  min = { gmShowType = "abbr", name = false }
  none = {}
}

let SlotbarPresetsList = class {
  scene = null
  ownerWeak = null
  maxPresets = 0
  curPresetsData = null 
  NULL_PRESET_DATA = { isEnabled = false, title = "" } 
  slotbarWidgetHandler = null
  hoveredPresetIdx = null
  isSlotbarPresetsEditWndOpened = false

  constructor(handler) {
    this.ownerWeak = handler.weakref()
    if (!checkObj(this.ownerWeak.scene))
      return
    this.scene = this.ownerWeak.scene.findObject("slotbar-presetsPlace")
    if (!checkObj(this.scene))
      return

    this.scene.show(true)
    this.maxPresets = MAX_COUNTRY_PRESETS_AMOUNT
    this.curPresetsData = array(this.maxPresets, this.NULL_PRESET_DATA)
    let view = {
      presets = array(this.maxPresets, null)
      isSmallFont = is_low_width_screen()
      isGamepad = showConsoleButtons.get()
    }
    let blk = handyman.renderCached(("%gui/slotbar/slotbarPresets.tpl"), view)
    this.scene.getScene().replaceContentFromText(this.scene, blk, blk.len(), this)
    this.update()

    subscribe_handler(this, g_listener_priority.DEFAULT)
  }

  function destroy() {
    if (!this.isValid())
      return
    this.scene.getScene().replaceContentFromText(this.scene, "", 0, null)
    this.scene = null
  }

  function isValid() {
    return checkObj(this.scene)
  }

  function getPresetsData() {
    let res = getPresetsDataByCountry(profileCountrySq.get())
    res.resize(this.maxPresets, this.NULL_PRESET_DATA)
    return res
  }

  function getPresetsTabsWidth(listObj) {
    local res = 0
    for (local i = 0; i < listObj.childrenCount(); i++) {
      let tab = listObj.getChild(i)
      if (!tab.isVisible())
        continue
      res += tab.getSize()[0]
    }
    return res
  }

  function selectAbbreviationMode(listObj, curPresetsData, newPresetsData) {
    let maxAutoTabsWidth = MAX_AUTO_TABS_WIDTH_K * listObj.getSize()[0]

    for (local i = 0; i < this.maxPresets; i++)
      this.updatePresetObj(listObj.getChild(i), curPresetsData[i], newPresetsData[i], true, i, autoAbbrTypes.max)

    this.scene.getScene().applyPendingChanges(false)

    if (this.getPresetsTabsWidth(listObj) > maxAutoTabsWidth) {
      for (local i = 0; i < this.maxPresets; i++)
        this.updatePresetObj(listObj.getChild(i), curPresetsData[i], newPresetsData[i], true, i, autoAbbrTypes.mid)
      this.scene.getScene().applyPendingChanges(false)
    }

    if (this.getPresetsTabsWidth(listObj) > maxAutoTabsWidth)
      for (local i = 0; i < this.maxPresets; i++)
        this.updatePresetObj(listObj.getChild(i), curPresetsData[i], newPresetsData[i], true, i, autoAbbrTypes.min)
  }

  function update(forceUpdate = false) {
    if (isSmallScreen)
      return

    let listObj = this.getListObj()
    if (!listObj)
      return

    let newPresetsData = this.getPresetsData()
    let curPresetIdx = this.getCurPresetIdx()
    local hasVisibleChanges = curPresetIdx != listObj.getValue()

    if (!isAutoAbbreviation()) {
      for (local i = 0; i < this.maxPresets; i++)
        if (this.updatePresetObj(listObj.getChild(i), this.curPresetsData[i], newPresetsData[i], forceUpdate, i))
          hasVisibleChanges = true
    }
    else {
      this.selectAbbreviationMode(listObj, this.curPresetsData, newPresetsData)
      hasVisibleChanges = true
    }

    this.curPresetsData = newPresetsData
    if (!hasVisibleChanges)
      return

    this.scene.getScene().applyPendingChanges(false)
    if (curPresetIdx >= 0) {
      listObj.setValue(curPresetIdx)
      listObj.getChild(curPresetIdx).scrollToView()
    }
  }

  function getAbbreviationModeName(gm) {
    let { id = null, defAbbreviateLocId = null } = gm
    if (id == null)
      return ""

    let abbrLocId = $"slotbarPresetsAbreviaton/{id}"
    if (doesLocTextExist(abbrLocId))
      return loc(abbrLocId)

    return doesLocTextExist(defAbbreviateLocId) ? loc(defAbbreviateLocId) : ""
  }

  function createPresetTitleData(presetData, autoAbbrData = autoAbbrTypes.none) {
    let autoAbbr = autoAbbrData != autoAbbrTypes.none

    let isShowBRInTab = autoAbbr || isShowRatings()
    let isShowNameInTab = autoAbbr || isShowTitles()
    let isShowGMInTab = autoAbbr || isShowModes()
    let isAbbreviateGMInTab = !autoAbbr ? isAbbreviateModes() : autoAbbrData.gmShowType == "abbr"
    let gm = getGameModeById(presetData.gameModeId)

    let modeName = !isShowGMInTab ? ""
      : isAbbreviateGMInTab ? this.getAbbreviationModeName(gm)
      : (gm?.getText() ?? "")

    return {
      presetName = isShowNameInTab ? presetData.title : ""
      presetGameMode = modeName
      presetBR = isShowBRInTab ? presetData.br : ""
    }
  }

  function updatePresetObj(obj, wasData, newData, forceUpdate, presetIdx, autoAbbrType = autoAbbrTypes.none) {
    if (!forceUpdate && u.isEqual(wasData, newData))
      return false

    let isEnabled = newData.isEnabled
    this.showObj(obj, isEnabled)
    if (!isEnabled)
      return wasData.isEnabled

    let presetTitleData = this.createPresetTitleData(newData, autoAbbrType)
    presetTitleData.each(@(value, key) obj.findObject(key).setValue(value))
    obj["presetIdx"] = presetIdx
    return true
  }

  function showObj(obj, needShow) {
    obj.show(needShow)
    obj.enable(needShow)
  }

  function getCurPresetIdx() { 
    return getCurrentPresetIdx(profileCountrySq.get(), 0)
  }

  function getSelPresetIdx() { 
    let listObj = this.getListObj()
    if (!listObj)
      return this.getCurPresetIdx()

    let value = listObj.getValue()
    if (value < 0 || value >= listObj.childrenCount())
      return -1
    return value
  }

  function isPresetChanged(presetIdx = null) {
    let idx = presetIdx ?? this.getSelPresetIdx()
    return idx != this.getCurPresetIdx()
  }

  function applySelect(newIdx = null) {
    if (!canLoadSlotbarPreset(true, profileCountrySq.get()))
      return this.update()

    let idx = newIdx ?? this.getSelPresetIdx()
    if (idx < 0)
      return this.update()

    if (("canPresetChange" in this.ownerWeak) && !this.ownerWeak.canPresetChange())
      return

    loadSlotbarPreset(idx)
    this.update()
  }

  function onPresetChange() {
    this.tryChangePreset()
  }

  function isTabChosen(obj) {
    let isSelected = obj?["chosen"] ?? "no"
    return isSelected == "yes" ? true : false
  }

  function onPresetHover(obj) {
    let presetIdx = obj.presetIdx.tointeger()
    if (this.hoveredPresetIdx == presetIdx)
      return
    let isCurrentPreset = this.isTabChosen(obj)
    if (isCurrentPreset)
      return
    this.hoveredPresetIdx = presetIdx
    this.slotbarWidgetHandler?.previewPreset(this.hoveredPresetIdx)
  }

  function onPresetUnHover(obj) {
    let presetIdx = obj.presetIdx.tointeger()
    if (this.hoveredPresetIdx != presetIdx)
      return
    this.hoveredPresetIdx = -1
    this.slotbarWidgetHandler?.previewPreset(null)
  }

  function tryChangePreset(presetIdx = null) {
    if ((this.ownerWeak?.getSlotbar().slotbarOninit ?? false) || !this.isPresetChanged(presetIdx))
      return

    this.checkChangePresetAndDo(@() this.applySelect(presetIdx))
  }

  function checkChangePresetAndDo(action) {
    checkQueueAndStart(
      Callback(function() {
        checkSquadUnreadyAndDo(
          Callback(function() {
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

  function setSlotbarPresetsEditWndOpened(value) {
    this.isSlotbarPresetsEditWndOpened = value
  }

  function getSlotbarPresetsEditWndOpened() {
    return this.isSlotbarPresetsEditWndOpened
  }

  function onSlotsChoosePreset(obj) {
    this.checkChangePresetAndDo(@() openSlotbarPresetsListEditWnd(obj, this))
  }

  function onPresetsShowSettings(obj) {
    openSlotbarPresetSettings(obj, this.ownerWeak)
  }

  function onEventSlotbarPresetLoaded(_p) {
    this.update()
  }

  function onEventSlotbarPresetsChanged(_p) {
    this.update()
  }

  function onEventGameModesUpdated(_p) {
    this.update(true)
  }

  function onEventSlotbarPresetSettingsChanged(_p) {
    this.update(true)
  }

  function onEventCurrentGameModeIdChanged(_p) {
    this.update(true)
  }

  function getListObj() {
    if (!checkObj(this.scene))
      return null
    let obj = this.scene.findObject("slotbarPresetsList")
    if (checkObj(obj))
      return obj
    return null
  }

  function getPresetsButtonObj() {
    if (this.scene == null)
      return null
    let obj = this.scene.findObject("btnPresets")
    if (checkObj(obj))
      return obj
    return null
  }

  



  function getListChildByPresetIdx(presetIdx) {
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

  function setSlotbarWidgetHandler(handler) {
    this.slotbarWidgetHandler = handler.weakref()
  }
}

function getSlotbarPresetsList(handler) {
  return handler.rootHandlerWeak ? handler.rootHandlerWeak.presetsListWeak : handler.presetsListWeak
}

function setSlotbarPresetsListAvailable(handler, isAvailable) {
  if (isAvailable) {
    if (handler.presetsListWeak)
      handler.presetsListWeak.update()
    else
      handler.presetsListWeak = SlotbarPresetsList(handler).weakref()
  }
  else if (handler.presetsListWeak)
    handler.presetsListWeak.destroy()
}


return {
  SlotbarPresetsList
  getSlotbarPresetsList
  setSlotbarPresetsListAvailable
}

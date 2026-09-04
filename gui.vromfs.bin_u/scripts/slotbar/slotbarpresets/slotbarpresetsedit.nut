from "string" import format
from "%sqStdLibs/helpers/u.nut" import isEqual
from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getDaguiObjAabb, select_editbox } = require("%scripts/sqDagui/daguiUtil.nut")
let { getPresetsDataByCountry } = require("%scripts/slotbar/slotbarPresets/slotbarPresetsUtils.nut")
let { getGameModeById } = require("%scripts/gameModes/gameModeManagerState.nut")
let { getCurrentPresetIdx } = require("%scripts/slotbar/slotbarPresetsState.nut")
let { getDefaultPresetName } = require("%scripts/slotbar/slotbarPresetsHelpers.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { canEraseSlotbarPreset, canCreateSlotbarPreset, createSlotbarPreset, copySlotbarPreset, eraseSlotbarPreset,
  moveSlotbarPreset, renameSlotbarPreset } = require("%scripts/slotbar/slotbarPresets.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

const MAX_NEW_PRESET_NAME_LEN = 16

let SlotbarPresetsListEdit = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/slotbar/slotbarPresets/slotbarPresetsEdit.blk"

  initialButton = null
  ownerWeak = null
  presetsList = null
  addNewPresetState = false
  presets = null
  newPresetDefaultName = ""
  presetsOrder = []
  editPresetsObjectHeight = 0
  draggedObject = null
  draggedObjectLastPos = -1
  marginRight = 0
  minWindowWidth = 0

  function initScreen() {
    if (this.ownerWeak)
      this.ownerWeak = this.ownerWeak.weakref()
    this.setSlotbarPresetsEditWndOpened(true)
    this.editPresetsObjectHeight = to_pixels("1@editPresetsItemHeight")
    this.marginRight = to_pixels("2@blockInterval")
    this.minWindowWidth = to_pixels("587@sf/@pf")

    this.presetsList = this.scene.findObject("presetsList")
    this.fillPresets()
    this.updateObjectsPositions()
    this.tuneAddNewPresetEditBox()
  }

  function tuneAddNewPresetEditBox() {
    let addNewPresetEditBox = this.getAddNewPresetEditBox()
    addNewPresetEditBox["max-len"] = $"{MAX_NEW_PRESET_NAME_LEN}"
  }

  function fillPresets() {
    let country = profileCountrySq.get()
    this.presets = getPresetsDataByCountry(country)
    let currentPresetIdx = getCurrentPresetIdx(country, 0)
    let dragDisabled = this.presets.len() > 1 ? "no" : "yes"
    let isGamepadMode = showConsoleButtons.get()

    let presets = this.presets.map(@(preset, idx) {
      idx = idx.tostring()
      presetName = preset.title
      presetGameMode = getGameModeById(preset.gameModeId)?.getText() ?? ""
      presetBR = preset.br
      isPresetSelected = currentPresetIdx == idx ? "yes" : "no"
      dragDisabled
      cantRemovePreset = !canEraseSlotbarPreset()
      state = "ready"
      isGamepadMode
    })

    let data = handyman.renderCached("%gui/slotbar/slotbarPresets/presetEditItem.tpl", { presets })
    this.guiScene.replaceContentFromText(this.presetsList, data, data.len(), this)
    this.presetsList["height"] = $"{this.editPresetsObjectHeight * presets.len()}"
    this.presetsList["isClicksAvailable"] = "yes"
    this.presetsOrder = array(presets.len()).map(@(idx, _v) idx)
    this.updateWindowWidth()
  }

  function updateWindowWidth() {
    local maxPresetWidth = 0
    for (local i = 0; i < this.presetsList.childrenCount(); i++) {
      let presetObj = this.presetsList.getChild(i)
      maxPresetWidth = max(maxPresetWidth, presetObj.findObject("readyState").getSize()[0])
    }

    if (maxPresetWidth + this.marginRight > this.minWindowWidth)
      this.scene.findObject("wndFrame")["width"] = $"{maxPresetWidth + this.marginRight}"
  }

  function updateObjectsPositions() {
    this.guiScene.applyPendingChanges(false)

    let initialButtonPos = this.initialButton.getPosRC()
    let initialButtonSize = this.initialButton.getSize()

    let btnCloseObj = this.scene.findObject("btnClose")
    btnCloseObj["pos"] = $"{initialButtonPos[0]}, {initialButtonPos[1]}"
    btnCloseObj["size"] = $"{initialButtonSize[0]}, {initialButtonSize[1]}"

    let wndFrameObj = this.scene.findObject("wndFrame")
    let wndFrameObjSize = wndFrameObj.getSize()
    let interval = to_pixels("2@blockInterval")
    wndFrameObj["pos"] = $"{initialButtonPos[0]}, {initialButtonPos[1] - wndFrameObjSize[1] - interval}"
  }

  getAddNewPresetEditBox = @() this.scene.findObject("addNewPresetEditBox")

  setAddNewPresetCompState = @(state) this.scene.findObject("addNewPresetComp").state = state
  setAddNewPresetCompEnabled = @(enable) this.scene.findObject("addNewPresetComp")["enable"] = enable ? "yes" : "no"

  function onAddNewPresetClick() {
    this.addNewPresetState = true
    this.setAddNewPresetCompState("edit")
    this.setPresetsEnabled(false)
    let addNewPresetEditBox = this.getAddNewPresetEditBox()
    select_editbox(addNewPresetEditBox)
    this.newPresetDefaultName = getDefaultPresetName(this.presets.len())
    addNewPresetEditBox.setValue(this.newPresetDefaultName)
  }

  function onConfirmAddingNewPreset() {
    let addNewPresetEditBox = this.getAddNewPresetEditBox()
    let newPresetName = addNewPresetEditBox.getValue().strip()

    if (canCreateSlotbarPreset())
      createSlotbarPreset(newPresetName == "" ? null : newPresetName)
    else
      this.showNotAllowedMessage()

    this.onCancelAddingNewPreset()
  }

  function onAddNewPresetEditCancelEdit() {
    let addNewPresetEditBox = this.getAddNewPresetEditBox()
    let value = addNewPresetEditBox.getValue()
    if (value != "" && value != this.newPresetDefaultName) {
      addNewPresetEditBox.setValue("")
      return
    }
    this.onCancelAddingNewPreset()
  }

  function clearNewPresetEditBox() {
    let addNewPresetEditBox = this.getAddNewPresetEditBox()
    addNewPresetEditBox.setValue("")
  }

  function onCancelAddingNewPreset() {
    this.setAddNewPresetCompState("ready")
    this.addNewPresetState = false
    this.setPresetsEnabled(true)
    this.clearNewPresetEditBox()
  }

  function setSlotbarPresetsEditWndOpened(value) {
    this.ownerWeak?.setSlotbarPresetsEditWndOpened(value)
  }

  function goBack() {
    if (this.addNewPresetState) {
      this.onCancelAddingNewPreset()
      return
    }

    this.setSlotbarPresetsEditWndOpened(false)

    this.guiScene.performDelayed(this, function() {
      handlersManager.destroyHandler(this)
      handlersManager.clearInvalidHandlers()
    })
  }

  function showNotAllowedMessage() {
    showInfoMsgBox(format(loc("weaponry/action_not_allowed"), loc("shop/slotbarPresetsMax")))
  }

  function getCurrentPresetObject() {
    return this.presetsList.getChild(this.presetsList.getValue())
  }

  function onPresetItemClick(obj) {
    if (this.addNewPresetState || this.presetsList["isClicksAvailable"] == "no")
      return

    let presetIdx = obj.getValue() ?? obj.presetIdx.tointeger()
    this.ownerWeak?.tryChangePreset(presetIdx)
  }

  getDraggedObjectPos = @() this.draggedObject?.getPosRC()[1] ?? -1

  function getPresetObjects() {
    let childrenCount = this.presetsList.childrenCount()
    let res = []
    for (local i = 0; i < childrenCount; i++)
      res.append(this.presetsList.getChild(i))

    return res
  }

  function getPresetObjectsSortedByPos() {
    let res = this.getPresetObjects()
    return res.sort(@(p1, p2) p1.getPosRC()[1] <=> p2.getPosRC()[1])
  }

  function onPresetMoveStart(obj) {
    this.draggedObject = obj
    this.draggedObjectLastPos = this.getDraggedObjectPos()
    this.draggedObject.bringOnTop()
    this.draggedObject["buttonsDisabled"] = "yes"
    this.presetsList["isDragProcess"] = "yes"
  }

  function checkNeedProcessing() {
    if (this.draggedObject == null || this.getDraggedObjectPos() == this.draggedObjectLastPos)
      return false

    this.draggedObjectLastPos = this.getDraggedObjectPos()
    return true
  }

  function getIntersectionObject() {
    let objects = this.getPresetObjectsSortedByPos()
    foreach (object in objects) {
      if (this.draggedObject.isEqual(object))
        continue

      let objectAabb = getDaguiObjAabb(object)
      let draggedObjectAabb = getDaguiObjAabb(this.draggedObject)

      let deltaDir = (objectAabb.pos[1] < draggedObjectAabb.pos[1]) ? 1 : -1
      let delta = objectAabb.size[1] + deltaDir * (objectAabb.pos[1] - draggedObjectAabb.pos[1])

      if (delta < objectAabb.size[1] && delta > objectAabb.size[1] / 2)
        return object
    }
    return null
  }

  function onPresetMove() {
    if (!this.checkNeedProcessing())
      return

    let object = this.getIntersectionObject()
    if (object == null)
      return

    let presets = this.getPresetObjectsSortedByPos()

    let draggedObj = this.draggedObject
    let draggedObjIdx = presets.findindex(@(p) p.presetIdx == draggedObj.presetIdx)
    let objectIdx = presets.findindex(@(p) p.presetIdx == object.presetIdx)

    presets.swap(objectIdx, draggedObjIdx)

    let newPresetsOrder = presets.map(@(v) v.presetIdx.tointeger())
    if (isEqual(this.presetsOrder, newPresetsOrder))
      return

    this.presetsOrder.replace(newPresetsOrder)

    foreach(idx, presetObj in presets)
      if (!this.draggedObject.isEqual(presetObj))
        presetObj.pos = $"0, {idx * this.editPresetsObjectHeight}"
  }

  function onPresetMoveEnd() {
    this.presetsList["isDragProcess"] = "no"
    if (!this.draggedObject?.isValid())
      return

    let presets = this.getPresetObjectsSortedByPos()
    let draggedObjectIndex = this.draggedObject.presetIdx.tointeger()
    this.draggedObject = null

    let newDraggedObjectIndex = presets.findindex(@(p) p.presetIdx.tointeger() == draggedObjectIndex) ?? draggedObjectIndex
    if (draggedObjectIndex == newDraggedObjectIndex) {
      this.fillPresets()
      return
    }

    moveSlotbarPreset(draggedObjectIndex, newDraggedObjectIndex - draggedObjectIndex)
  }

  function getPresetObjectByIdx(idx) {
    return this.presetsList.findObject($"preset_{idx}")
  }

  function setPresetObjectState(presetObject, state) {
    presetObject["state"] = state
  }

  function setPresetsEnabled(enabled, excludedPresetObj = null) {
    this.presetsList["isClicksAvailable"] = enabled ? "yes" : "no"
    let presets = this.getPresetObjects()
    presets.each(function(presetObj) {
      presetObj["dragDisabled"] = enabled ? "no" : "yes"
      if (excludedPresetObj == null || !presetObj.isEqual(excludedPresetObj))
        presetObj["enable"] = enabled ? "yes" : "no"
    })
  }

  function onCopyPreset(obj) {
    if (canCreateSlotbarPreset())
      copySlotbarPreset(this.presets[obj.presetIdx.tointeger()])
    else
      this.showNotAllowedMessage()
  }

  function onRenamePreset(obj) {
    let presetObject = this.getPresetObjectByIdx(obj.presetIdx)
    this.setPresetObjectState(presetObject, "rename")
    this.setPresetsEnabled(false, presetObject)
    this.setAddNewPresetCompEnabled(false)

    let editBox = presetObject.findObject("renamePresetEditBox")
    select_editbox(editBox)
    let presetName = this.presets[obj.presetIdx.tointeger()].title
    editBox.setValue(presetName)
    editBox["max-len"] = $"{MAX_NEW_PRESET_NAME_LEN}"
  }

  function onConfirmRenamePreset(obj) {
    let presetObject = this.getPresetObjectByIdx(obj.presetIdx)
    let editBox = presetObject.findObject("renamePresetEditBox")
    let presetIdx = presetObject.presetIdx.tointeger()
    let newPresetName = editBox.getValue().strip()
    if (newPresetName == "")
      return

    this.setAddNewPresetCompEnabled(true)
    if (renameSlotbarPreset(presetIdx, newPresetName))
      return

    this.setPresetObjectState(presetObject, "ready")
    this.setPresetsEnabled(true)
  }

  function onRemovePreset(obj) {
    let presetObject = this.getPresetObjectByIdx(obj.presetIdx)
    this.setPresetObjectState(presetObject, "remove")
    this.setPresetsEnabled(false, presetObject)
    this.setAddNewPresetCompEnabled(false)
  }

  function onCancelEditPreset(obj) {
    let presetObject = this.getPresetObjectByIdx(obj.presetIdx)
    this.setPresetObjectState(presetObject, "ready")
    this.setPresetsEnabled(true)
    this.setAddNewPresetCompEnabled(true)
  }

  function onConfirmRemovePreset(obj) {
    let presetObject = this.getPresetObjectByIdx(obj.presetIdx)
    let presetIdx = presetObject.presetIdx.tointeger()
    eraseSlotbarPreset(presetIdx)
    this.setAddNewPresetCompEnabled(true)
    this.setPresetsEnabled(true)
  }

  function onEventSlotbarPresetLoaded(_p) {
    this.fillPresets()
    this.updateObjectsPositions()
  }

  function onEventSlotbarPresetsChanged(_p) {
    this.fillPresets()
    this.updateObjectsPositions()
  }

  function onEventGameModesUpdated(_p) {
    this.fillPresets()
    this.updateObjectsPositions()
  }

  function onEventSlotbarPresetSettingsChanged(_p) {
    this.fillPresets()
    this.updateObjectsPositions()
  }

  function onEventCurrentGameModeIdChanged(_p) {
    this.fillPresets()
    this.updateObjectsPositions()
  }

  function onEditBoxUnhover(obj) {
    obj.deSelect()
  }
}
register_gui_handler("SlotbarPresetsListEdit", SlotbarPresetsListEdit)

function closeSlotbarPresetsListEditWnd() {
  let handler = handlersManager.findHandlerClassInScene(SlotbarPresetsListEdit)
  if (handler == null)
    return

  handler.setSlotbarPresetsEditWndOpened(false)
  handlersManager.destroyHandler(handler)
  handlersManager.clearInvalidHandlers()
}

profileCountrySq.subscribe(@(_c) closeSlotbarPresetsListEditWnd())

return {
  openSlotbarPresetsListEditWnd = @(initialButton, owner)
    handlersManager.loadHandler(SlotbarPresetsListEdit, {initialButton, ownerWeak = owner })
  closeSlotbarPresetsListEditWnd
}

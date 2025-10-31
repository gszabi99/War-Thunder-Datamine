from "%scripts/dagui_library.nut" import *

let DataBlock = require("DataBlock")
let { abs } = require("math")
let { register_command } = require("console")
let { getUnitExtraData, saveUnitExtraData } = require("chard")

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { getShortcutText } = require("%scripts/controls/controlsVisual.nut")
let { getDaguiObjAabb } = require("%sqDagui/daguiUtil.nut")
let { gatherShipDamageControlData, hasShipDamageControl } = require("%scripts/damageControl/damageControlModule.nut")

register_command(
  function () {
    handlersManager.loadHandler(gui_handlers.DamageControlWnd, { unitName = "us_destroyer_clemson_litchfield"})
  },
  "ui.debug_damage_control")

const PRESETS_COUNT = 3

let fullActionName = {
  r = "repair"
  e = "extinguish"
  u = "unwater"
}

let shortActionName = {
  repair = "r"
  extinguish = "e"
  unwater = "u"
}

let descriptionsLocKeys = {
  repair = {
    title = "ship/damageControlRepairText"
    specsText = "ship/damageControlSpecActionRepairText"
  }
  extinguish = {
    title = "ship/damageControlExtinguishText"
    specsText = "ship/damageControlSpecActionExtinguishText"
  }
  unwater = {
    title = "ship/damageControlUnwateringText"
    specsText = "ship/damageControlSpecActionUnwaterText"
  }
}

let presetShortcuts = ["ID_SHIP_DAMAGE_CONTROL_PRESET_1", "ID_SHIP_DAMAGE_CONTROL_PRESET_2", "ID_SHIP_DAMAGE_CONTROL_PRESET_3"]

function convertAabbToRect(aabb) {
  return {
    x = aabb.pos[0]
    y = aabb.pos[1]
    r = aabb.pos[0] + aabb.size[0]
    b = aabb.pos[1] + aabb.size[1]
  }
}

function isIntersects(rect1, rect2) {
  if (rect1.x > rect2.r || rect1.r < rect2.x || rect1.y > rect2.b || rect1.b < rect2.y)
    return false
  return true
}

function distanceOfCenters(rect1, rect2) {
  let cx1 = (rect1.x + rect1.r) / 2
  let cx2 = (rect2.x + rect2.r) / 2
  return abs(cx2 - cx1)
}

function findIntersectsObj(draggedPresetRect, presets) {
  let objs = presets
    .filter(@(p) isIntersects(draggedPresetRect, p.dropTargetObjRect))
    .map(@(p) p.__update({ dist = distanceOfCenters(draggedPresetRect, p.dropTargetObjRect) }))
    .sort(@(p1, p2) p1.dist <=> p2.dist)

  return objs.len() > 0 ? objs[0] : null
}

gui_handlers.DamageControlWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName         = "%gui/damageControl/damageControl.tpl"
  unitName             = null
  presets              = null
  currentPresetIndex   = -1
  draggedPreset = null
  currentPresetNestObj = null
  dropTargetObj = null

  fixedPresets = [
    { set = [], type = "repair", num = 1, },
    { set = [], type = "repair", num = 2 },
    { set = [], type = "extinguish", num = 1 },
    { set = [], type = "extinguish", num = 2 },
    { set = [], type = "unwater", num = 1 },
    { set = [], type = "unwater", num = 2 },
  ]

  actionWeights = null

  function initScreen() {
    this.presets = DataBlock()
    this.presets.setFrom(getUnitExtraData(this.unitName, "ship_dc_presets"))

    for (local i = 0; i < PRESETS_COUNT; i++)
      this.presets[$"preset{i + 1}"] = this.presets?[$"preset{i + 1}"] ?? ""

    this.scene.findObject("noSelectedPresets").setValue(loc("ship/notSelectedPreset"))
    this.updateCurrentPresets()

    this.currentPresetNestObj = this.scene.findObject("currentPresetNest")
  }

  function getSceneTplView() {
    return {
      fixedPresetView = this.createFixedPresets()
      currentPresetView = this.createCurrentPresets()
    }
  }

  function createCurrentPresets() {
    let presetsData = []
    for (local i = 0; i < PRESETS_COUNT; i++) {
      presetsData.append({
        presetNumber = $"preset{i + 1}"
        shortcut = this.getShortcutById(presetShortcuts[i])
        lastCurrentPreset = i == PRESETS_COUNT - 1
      })
    }
    return presetsData
  }

  function updateCurrentPresets() {
    for (local i = 0; i < PRESETS_COUNT; i++) {
      let image = this.createPresetImage(this.presets[$"preset{i + 1}"])
      let presetNumber = $"preset{i + 1}"
      let obj = this.scene.findObject(presetNumber)
      this.guiScene.replaceContentFromText(obj, image, image.len(), this)
    }
  }

  function createPresetImage(presetString = "") {
    if (presetString == "")
      return "activeText { text:t='＋'; valign:t='center'; halign:t='center'; bigBoldFont:t='yes'}"
    local res = [];
    local iconLayer = "iconLayer {position:t='absolute'; css-hier-invalidate:t='yes'; background-image:t='{0}'; {1}}"
    local place = 0
    for (local i = 0; i < presetString.len(); i++) {
      let action = presetString.slice(i, i + 1)
      if (!"eur".contains(action))
        continue
      let image = this.getIconByAction(fullActionName[action])
      let params = this.getParamsByPlace(place)
      res.append(iconLayer.subst(image, params))
      place++
    }

    return " ".join(res)
  }

  function getParamsByPlace(place) {
    if (place == 0)
      return "size:t='0.58pw, 0.58ph'; background-svg-size:t='0.58pw, 0.58ph'; pos:t='0.5pw - 0.5w, 0'"
    if (place == 1)
      return "size:t='0.41pw, 0.41ph'; background-svg-size:t='0.41pw, 0.41ph'; pos:t='0.04pw, 0.96ph - h'"

    return "size:t='0.41pw, 0.41ph'; background-svg-size:t='0.41pw, 0.41ph'; pos:t='0.96pw - w, 0.96ph - h'"
  }

  function getShortcutById(shortcutId) {
    local shortcut = getShortcutText({
      shortcuts = getShortcuts([ shortcutId ])
      shortcutId = 0
      cantBeEmpty = false
      colored = true
    })
    shortcut = (shortcut != "") ? shortcut : loc("#hotkeys/{0}".subst(shortcutId))
    return shortcut
  }

  function getIconByAction(action) {
    local res = ""
    if (action == "extinguish" )
      res = "manual_ship_extinguisher"
    else if ( action == "unwater")
      res = "unwatering"
    else if ( action == "repair")
      res = "ship_tool_kit"
    return "#ui/gameuiskin#{0}".subst(res)
  }

  function createFixedPresets() {
    let { sets, weights } = gatherShipDamageControlData(this.unitName)
    this.actionWeights = weights

    let fixedPresetsData = []
    for (local idx = 0; idx < this.fixedPresets.len(); idx++) {
      let preset = this.fixedPresets[idx]
      preset.set.clear()
      let set = sets.getBlockByName($"set{idx + 1}")
      for (local n = 0; n < 3; n++)
        preset.set.append(set[$"n{n + 1}"])

      let presetData = { actionsView = [], lastPreset = false, presetIdx = idx }
      for (local i = 0; i < preset.set.len(); i++) {
        let image = this.getIconByAction(preset.set[i])
        presetData.actionsView.append({
          image
          lastAction = i == preset.set.len() - 1
        })
      }
      fixedPresetsData.append(presetData)
      presetData.lastPreset = [5, 6].contains(fixedPresetsData.len())
    }
    return fixedPresetsData
  }

  function createPresetDescription(set) {
    let actionType = set[0]
    let actionTitle = loc(descriptionsLocKeys[actionType].title)
    return loc("ship/damageControlActionPrioritet", { action = actionTitle })
  }

  function createPresetSpecs(set) {
    let specsText = []
    for (local i = 0; i < set.len(); i++) {
      let action = set[i]
      let isFirstAction = i == 0
      let data = {
        color = isFirstAction ? "@goodTextColor" : "@redMenuButtonColor"
        k = this.actionWeights[i]
        action = loc(descriptionsLocKeys[action].specsText)
      }
      specsText.append(loc("ship/damageControlSpec", data))
    }

    return "\n".join(specsText)
  }

  function updatePresetDescription() {
    let presetNameObj = this.scene.findObject("presetName")
    let descriptionNameObj = this.scene.findObject("presetDescription")
    let noSelectedPresetsObj = this.scene.findObject("noSelectedPresets")
    let damageControlSpecsObj = this.scene.findObject("damageControlSpecs")
    let presetDescriptionDivObj = this.scene.findObject("presetDescriptionDiv")

    if (this.currentPresetIndex == -1) {
      presetNameObj.setValue("")
      noSelectedPresetsObj.show(true)
      presetDescriptionDivObj.show(false)
      return
    }

    let preset = this.fixedPresets[this.currentPresetIndex]
    presetNameObj.setValue(loc($"ship/{preset.type}_priority", { num = preset.num }))
    noSelectedPresetsObj.show(false)
    presetDescriptionDivObj.show(true)
    descriptionNameObj.setValue(this.createPresetDescription(preset.set))
    damageControlSpecsObj.setValue(this.createPresetSpecs(preset.set))
  }

  function onPresetSelect(obj) {
    this.currentPresetIndex = obj.getValue()
    this.updatePresetDescription()
    this.updateButtons()
  }

  function onSelectFor(obj) {
    if (this.currentPresetIndex == -1)
      return

    this.setPreset(obj.presetId)
  }

  function getPresetShortId(presetIndex) {
    let set = this.fixedPresets[presetIndex].set
    return "".join(set.map(@(a) shortActionName[a]))
  }

  function setPreset(presetNumber) {
    local swaped = false
    let currentPresetId = this.getPresetShortId(this.currentPresetIndex)
    for (local i = 0; i < this.presets.paramCount(); i++) {
      let key = this.presets.getParamName(i)
      let preset = this.presets.getParamValue(i)
      if (preset == currentPresetId) {
        this.presets[key] = this.presets[presetNumber]
        this.presets[presetNumber] = currentPresetId
        swaped = true
        break
      }
    }

    if (!swaped)
      this.presets[presetNumber] = currentPresetId
    this.updateCurrentPresets()
    saveUnitExtraData(this.unitName, "ship_dc_presets", this.presets)
  }

  function updateButtons() {
    let isButtonsDisabled = this.currentPresetIndex == -1
    this.currentPresetNestObj["buttonsDisabled"] = isButtonsDisabled ? "yes" : "no"
  }

  function onPresetDragStart(obj) {
    if (this.draggedPreset != null)
      return
    this.guiScene.performDelayed(this, function() {
      this.draggedPreset = obj.getClone(this.scene, this)
      this.draggedPreset.pos = ", ".join(obj.getPosRC())
      this.draggedPreset.dragging = "yes"
    })
  }

  function onPresetDrop(_obj) {
    if (this.draggedPreset == null)
      return

    this.currentPresetIndex = this.draggedPreset["presetIdx"].tointeger()
    this.guiScene.performDelayed(this, function() {
      this.guiScene.destroyElement(this.draggedPreset)
      this.draggedPreset = null
    })
    this.clearDropTarget()

    if (this.dropTargetObj == null)
      return

    this.setPreset(this.dropTargetObj.id)
  }

  function clearDropTarget() {
    for (local i = 0; i < this.currentPresetNestObj.childrenCount(); i++) {
      let presetObj = this.currentPresetNestObj.getChild(i)
      let dropTargetObj = presetObj.getChild(1)
      dropTargetObj["dropTarget"] = "no"
    }
  }

  function onPresetMove(_obj) {
    if (this.draggedPreset == null)
      return

    let presets = []
    for (local i = 0; i < this.currentPresetNestObj.childrenCount(); i++) {
      let presetObj = this.currentPresetNestObj.getChild(i)
      let dropTargetObj = presetObj.getChild(1)
      presets.append({
        dropTargetObj
        dropTargetObjRect = convertAabbToRect(getDaguiObjAabb(dropTargetObj))
      })
    }
    let draggedPresetRect = convertAabbToRect(getDaguiObjAabb(this.draggedPreset))
    let intersectedObj = findIntersectsObj(draggedPresetRect, presets)
    this.clearDropTarget()
    if (intersectedObj == null) {
      this.dropTargetObj = null
      return
    }

    intersectedObj.dropTargetObj["dropTarget"] = "yes"
    this.dropTargetObj = intersectedObj.dropTargetObj
  }
}

return {
  showDamageControl = function(unit) {
    if (unit == null || !unit.isShipOrBoat() || !hasShipDamageControl(unit.name))
      return
    handlersManager.loadHandler(gui_handlers.DamageControlWnd, { unitName = unit.name })
  }
}

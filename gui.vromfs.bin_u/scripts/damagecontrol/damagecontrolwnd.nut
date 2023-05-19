//checked for plus_string
//checked for explicitness
#no-root-fallback
#explicit-this

from "%scripts/dagui_library.nut" import *
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { register_command } = require("console")
let { getUnitExtraData, saveUnitExtraData } = require("chard")
let DataBlock = require("DataBlock")

register_command(
  function () {
    let unit = getAircraftByName("us_destroyer_clemson_litchfield")
    ::handlersManager.loadHandler(::gui_handlers.DamageControlWnd, { unit })
  },
  "ui.debug_damage_control")

const PRESETS_COUNT = 3

::gui_handlers.DamageControlWnd <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneTplName         = "%gui/damageControl/damageControl.tpl"
  unit                 = null
  presets              = null
  currentPresetId      = ""
  fixedPresets = [
    { set = "reu" name = "ship/repair_priority" num = 1 },
    { set = "rue" name = "ship/repair_priority" num = 2 },
    { set = "eru" name = "ship/extinguising_priority" num = 1 },
    { set = "eur" name = "ship/extinguising_priority" num = 2 },
    { set = "ure" name = "ship/unwatering_priority" num = 1 },
    { set = "uer" name = "ship/unwatering_priority" num = 2 },
  ]

  function initScreen() {
    this.presets = DataBlock()
    this.presets.setFrom(getUnitExtraData(this.unit.name, "ship_dc_presets"))

    for (local i = 0; i < PRESETS_COUNT; i++)
      this.presets[$"preset{i + 1}"] = this.presets?[$"preset{i + 1}"] ?? ""

    this.updateCurrentPresets()
  }

  function getSceneTplView() {
    return {
      isShowConsoleBtn = ::show_console_buttons
      fixedPresetView = this.createFixedPresets()
      buttons = this.createSelectButtons()
      currentPresetView = this.createCurrentPresets()
    }
  }

  function createCurrentPresets() {
    let presetsData = []
    for (local i = 0; i < PRESETS_COUNT; i++) {
      presetsData.append({
        presetNumber = $"preset{i + 1}"
        shortcut = this.getShortcutById($"ID_SHIP_DAMAGE_CONTROL_PRESET_{i + 1}")
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
      return ""
    local res = [];
    local iconLayer = "iconLayer {position:t='absolute'; css-hier-invalidate:t='yes'; background-image:t='{0}'; {1}}"
    local place = 0
    for (local i = 0; i < presetString.len(); i++) {
      let action = presetString.slice(i, i + 1)
      if (!"eur".contains(action))
        continue
      let image = this.getIconByAction(action)
      let params = this.getParamsByPlace(place)
      res.append(iconLayer.subst(image, params))
      place++
    }

    return " ".join(res)
  }

  function getParamsByPlace(place) {
    if (place == 0)
      return "size:t='0.8pw, 0.8ph'; background-svg-size:t='0.8pw, 0.8ph'; pos:t='0, 0'"
    if (place == 1)
      return "size:t='0.25pw, 0.25ph'; background-svg-size:t='0.25pw, 0.25ph'; pos:t='0.55pw - 0.5w, ph - 1.5h'"

    return "size:t='0.25pw, 0.25ph'; background-svg-size:t='0.25pw, 0.25ph'; pos:t='0.68pw, ph - 1.5h'"
  }

  function getShortcutById(shortcutId) {
     local shortcut = ::get_shortcut_text({
      shortcuts = ::get_shortcuts([ shortcutId ])
      shortcutId = 0
      cantBeEmpty = false
      colored = false
    })
    shortcut = (shortcut != "") ? shortcut : loc("#hotkeys/{0}".subst(shortcutId))
    return shortcut
  }

  function getIconByAction(action) {
    local res = ""
    switch (action) {
      case "e":
        res = "manual_ship_extinguisher"
        break

      case "u":
        res = "unwatering"
        break

      case "r":
        res = "ship_tool_kit"
        break
    }
    return "#ui/gameuiskin#{0}".subst(res)
  }

  function createFixedPresets() {
    let fixedPresetsData = []
    foreach (preset in this.fixedPresets) {
      let presetData = {
        presetName = loc(preset.name, { num = preset.num })
        actionsView = []
        hasBottomGap = preset.num == 2
      }
      for (local i = 0; i < preset.set.len(); i++) {
        let action = preset.set.slice(i, i + 1)
        let image = this.getIconByAction(action)
        presetData.actionsView.append({ img = image lastAction = i == preset.set.len() - 1 })
      }
      fixedPresetsData.append(presetData)
    }
    return fixedPresetsData
  }

  function createSelectButtons() {
    let buttons = []
    for (local i = 0; i < PRESETS_COUNT; i++) {
      let buttonData = {
        presetNumber = "preset{0}".subst(i + 1)
        shortcut = this.getShortcutById($"ID_SHIP_DAMAGE_CONTROL_PRESET_{i + 1}")
      }
      buttons.append(buttonData)
    }
    return buttons
  }

  function onSelect(obj) {
    this.currentPresetId = this.fixedPresets?[obj.getValue()].set ?? ""
  }

  function onSelectFor(obj) {
    if (this.currentPresetId == "")
      return

    this.setPreset(obj.forPresetId)
  }

  function setPreset(presetNumber) {
    local swaped = false
    for (local i = 0; i < this.presets.paramCount(); i++) {
      let key = this.presets.getParamName(i)
      let preset = this.presets.getParamValue(i)
      if (preset == this.currentPresetId) {
        this.presets[key] = this.presets[presetNumber]
        this.presets[presetNumber] = this.currentPresetId
        swaped = true
        break
      }
    }

    if (!swaped)
      this.presets[presetNumber] = this.currentPresetId
    this.updateCurrentPresets()
    saveUnitExtraData(this.unit.name, "ship_dc_presets", this.presets)
  }
}

return {
  showDamageControl = function(unit) {
    if (unit != null && unit.isShipOrBoat())
      ::handlersManager.loadHandler(::gui_handlers.DamageControlWnd, { unit })
  }
}

from "%scripts/dagui_library.nut" import *
let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { EditWeaponryPresetsModal } = require("%scripts/weaponry/editWeaponryPreset.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getTierIcon } = require("%scripts/weaponry/weaponryPresetsParams.nut")

local handlerClass = class (EditWeaponryPresetsModal) {
  afterModalDestroyFunc = null

  function initScreen() {
    showObjById("cancelBtn", false, this.scene)
    showObjById("btn_back", false, this.scene)
    this.scene.findObject("headerTxt").setValue(
    $"{loc("edit/secondary_weapons/old_preset_invalid_title")} {colorize("badTextColorDark", getUnitName(this.unit))}")
    base.initScreen()
  }

  function getSceneTplView() {
    let tiersWidth = this.originalPreset.weaponsSlotCount * to_pixels("1@tierIconSize")
    let freeWidthForText = to_pixels("1@srw - 1@weaponsPresetDescriptionWidth - 1@scrollBarSize") - tiersWidth
    let oldPresetLeftMargin = min(freeWidthForText, to_pixels("1@modPresetTextMaxWidth"))

    
    
    
    let brokenPresetByTier = {}
    foreach (t in (this.originalPreset.brokenTiers ?? [])) {
      let brokenTierId = this.availableWeapons.findvalue(@(w) w.slot == t.slot)?.tier
      if (brokenTierId != null) {
        let sameWeapon = this.availableWeapons.findvalue(
          @(w) w.presetId == t.preset && (w.tier not in brokenPresetByTier))
        brokenPresetByTier[brokenTierId] <- {
          img = !!sameWeapon ? getTierIcon(sameWeapon, sameWeapon?.bullets ?? 1)
            : "#ui/gameuiskin#custom_preset"
        }
      }
    }

    return {
      blurSize = $"{this.parentSize?[0] ?? "sw"}, {this.parentSize?[1] ?? "sh"}"
      blurPos = this.parentPos != null ? " ,".join(this.parentPos) : null
      presets = this.getPresetMarkup()
      showOldPreset = true
      oldPreset = {
        tiersView = this.originalPreset.tiersView.map(@(t) {
          tierId        = t.tierId
          img           = t?.img ?? brokenPresetByTier?[t.tierId].img ?? ""
          tierTooltipId = !showConsoleButtons.get() ? t?.tierTooltipId : null
          isActive      = t?.isActive || "img" in t
          isBroken      = t.tierId in brokenPresetByTier
        })
        oldPresetLeftMargin
      }
    }
  }

  onPresetSave = @() this.goBack()

  function updateButtons() {
    showObjById("cancelBtn", false, this.scene)
    base.updateButtons()
  }

  function afterModalDestroy() {
    if (this.afterModalDestroyFunc)
      this.afterModalDestroyFunc()
  }

  function goBack() {
    this.savePreset()
    this.guiScene.performDelayed(this, function() {
      handlersManager.destroyHandler(this)
      handlersManager.clearInvalidHandlers()

      this.onModalWndDestroy()
    })
  }
}

register_gui_handler("FixWeaponryPresetsModal", handlerClass)

let openFixWeaponryPresets = @(params) handlersManager.loadHandler(handlerClass, params)

return {
  openFixWeaponryPresets
}

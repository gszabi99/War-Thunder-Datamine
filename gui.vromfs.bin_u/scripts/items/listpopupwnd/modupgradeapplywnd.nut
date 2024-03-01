from "%scripts/dagui_natives.nut" import get_modification_level, calculate_mod_or_weapon_effect_with_level
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let weaponryEffects = require("%scripts/weaponry/weaponryEffects.nut")
let { getInventoryList } = require("%scripts/items/itemsManager.nut")

gui_handlers.ModUpgradeApplyWnd <- class (gui_handlers.ItemsListWndBase) {
  sceneTplName = "%gui/items/modUpgradeApplyWnd.tpl"

  unit = null
  mod = null

  static function open(unitToActivate, modToActivate, wndAlignObj = null, wndAlign = ALIGN.TOP) {
    local list = getInventoryList(itemType.MOD_UPGRADE)
    list = list.filter(@(item) item.canActivateOnMod(unitToActivate, modToActivate))
    if (!list.len()) {
      showInfoMsgBox(loc("msg/noUpgradeItemsForMod"))
      return
    }
    handlersManager.loadHandler(gui_handlers.ModUpgradeApplyWnd,
    {
      unit = unitToActivate
      mod = modToActivate
      itemsList = list
      alignObj = wndAlignObj
      align = wndAlign
    })
  }

  function initScreen() {
    base.initScreen()

    let newLevel = get_modification_level(this.unit.name, this.mod.name) + 1
    calculate_mod_or_weapon_effect_with_level(this.unit.name, this.mod.name, newLevel, true, this,
      function(effect, ...) {
        if (this.isValid())
          this.showEffects(effect)
      },
      null)
  }

  function showEffects(effect) {
    this.scene.findObject("effects_wait_icon").show(false)
    this.scene.findObject("effects_text").setValue(
      weaponryEffects.getDesc(this.unit, effect?.withLevel ?? {}, { needComment = false }))
    this.guiScene.applyPendingChanges(false)
    this.updateWndAlign()
  }

  function onActivate() {
    this.curItem.activateOnMod(this.unit, this.mod, Callback(this.goBack, this))
  }
}
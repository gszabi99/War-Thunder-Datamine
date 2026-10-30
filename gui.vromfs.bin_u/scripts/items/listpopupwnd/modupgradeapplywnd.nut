from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/items/listPopupWnd/itemsListWndBase.nut" import ItemsListWndBase
from "%scripts/items/itemsManagerModule.nut" import getInventoryList
from "%scripts/dagui_natives.nut" import get_modification_level
from "%scripts/unit/unitCalcRequests.nut" import calculateModOrWeaponEffectWithLevel
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemType

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let weaponryEffects = require("%scripts/weaponry/weaponryEffects.nut")

let ModUpgradeApplyWnd = class (ItemsListWndBase) {
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
    handlersManager.loadHandler(get_gui_handler("ModUpgradeApplyWnd"),
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
    calculateModOrWeaponEffectWithLevel(this.unit.name, this.mod.name, newLevel, true,
      Callback(this.showEffects, this))
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
register_gui_handler("ModUpgradeApplyWnd", ModUpgradeApplyWnd)

return freeze({ ModUpgradeApplyWnd })

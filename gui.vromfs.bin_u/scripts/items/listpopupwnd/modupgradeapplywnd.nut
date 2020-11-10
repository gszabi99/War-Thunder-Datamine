local weaponryEffects = require("scripts/weaponry/weaponryEffects.nut")

class ::gui_handlers.ModUpgradeApplyWnd extends ::gui_handlers.ItemsListWndBase
{
  sceneTplName = "gui/items/modUpgradeApplyWnd"

  unit = null
  mod = null

  static function open(unitToActivate, modToActivate, wndAlignObj = null, wndAlign = AL_ORIENT.TOP)
  {
    local list = ::ItemsManager.getInventoryList(itemType.MOD_UPGRADE)
    list = ::u.filter(list, @(item) item.canActivateOnMod(unitToActivate, modToActivate))
    if (!list.len())
    {
      ::showInfoMsgBox(::loc("msg/noUpgradeItemsForMod"))
      return
    }
    ::handlersManager.loadHandler(::gui_handlers.ModUpgradeApplyWnd,
    {
      unit = unitToActivate
      mod = modToActivate
      itemsList = list
      alignObj = wndAlignObj
      align = wndAlign
    })
  }

  function initScreen()
  {
    base.initScreen()

    local newLevel = ::get_modification_level(unit.name, mod.name) + 1
    ::calculate_mod_or_weapon_effect_with_level(unit.name, mod.name, newLevel, true, this,
      function(effect, ...) {
        if (isValid())
          showEffects(effect)
      },
      null)
  }

  function showEffects(effect)
  {
    scene.findObject("effects_wait_icon").show(false)
    scene.findObject("effects_text").setValue(
      weaponryEffects.getDesc(unit, effect?.withLevel ?? {}, { needComment = false }))
    guiScene.applyPendingChanges(false)
    updateWndAlign()
  }

  function onActivate()
  {
    curItem.activateOnMod(unit, mod, ::Callback(goBack, this))
  }
}
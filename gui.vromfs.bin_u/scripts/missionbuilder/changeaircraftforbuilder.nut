from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_handlers.changeAircraftForBuilder <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/shop/shopTakeAircraft.blk"
  shopAir = null

  function initScreen()
  {
     this.createSlotbar(
       {
         showNewSlot = false,
         showEmptySlot = false,
         hasActions = false,
         afterSlotbarSelect = updateButtons,
         slotbarBehavior = "posNavigator",
         needFullSlotBlock = true
         onSlotDblClick = Callback(@(_crew) onApply(), this)
         onSlotActivate = Callback(@(_crew) onApply(), this)
       },
       "take-aircraft-slotbar"
     )

     let textObj = this.scene.findObject("take-aircraft-text")
     textObj.top = "1@titleLogoPlateHeight + 1@frameHeaderHeight"
     textObj.setValue(loc("mainmenu/missionBuilderNotAvailable"))

     let air = this.getCurSlotUnit()
     showedUnit(air)
     updateButtons()
  }

  function onTakeCancel()
  {
    showedUnit(shopAir)
    this.goBack()
  }

  function onApply()
  {
    if (showedUnit.value?.isAir() ?? false)
      return ::gui_start_builder()

    this.msgBox("not_available", loc(showedUnit.value != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"),
      [["ok"]], "ok")
  }

  function updateButtons()
  {
    this.scene.findObject("btn_set_air").inactiveColor =
      (showedUnit.value?.isAir() ?? false) ? "no"
      : "yes"
  }
}
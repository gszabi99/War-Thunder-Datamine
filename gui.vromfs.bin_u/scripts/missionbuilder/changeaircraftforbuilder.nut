//checked for plus_string
from "%scripts/dagui_library.nut" import *


let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

gui_handlers.changeAircraftForBuilder <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/shop/shopTakeAircraft.blk"
  shopAir = null

  function initScreen() {
     this.createSlotbar(
       {
         showNewSlot = false,
         showEmptySlot = false,
         hasActions = false,
         afterSlotbarSelect = this.updateButtons,
         slotbarBehavior = "posNavigator",
         needFullSlotBlock = true
         onSlotDblClick = Callback(@(_crew) this.onApply(), this)
         onSlotActivate = Callback(@(_crew) this.onApply(), this)
       },
       "take-aircraft-slotbar"
     )

     let textObj = this.scene.findObject("take-aircraft-text")
     textObj.top = "1@titleLogoPlateHeight + 1@frameHeaderHeight"
     textObj.setValue(loc("mainmenu/missionBuilderNotAvailable"))

     let air = this.getCurSlotUnit()
     showedUnit(air)
     this.updateButtons()
  }

  function onTakeCancel() {
    showedUnit(this.shopAir)
    this.goBack()
  }

  function onApply() {
    if (showedUnit.value?.isAir() ?? false)
      return ::gui_start_builder()

    this.msgBox("not_available", loc(showedUnit.value != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"),
      [["ok"]], "ok")
  }

  function updateButtons() {
    this.scene.findObject("btn_set_air").inactiveColor =
      (showedUnit.value?.isAir() ?? false) ? "no"
      : "yes"
  }
}
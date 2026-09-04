from "%scripts/dagui_library.nut" import *

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { guiStartBuilder } = require("%scripts/missions/startMissionsList.nut")

let changeAircraftForBuilder = class (BaseGuiHandlerWT) {
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
     showedUnit.set(air)
     this.updateButtons()
  }

  function onTakeCancel() {
    showedUnit.set(this.shopAir)
    this.goBack()
  }

  function onApply() {
    if (showedUnit.get()?.isAir() ?? false)
      return guiStartBuilder()

    this.msgBox("not_available", loc(showedUnit.get() != null ? "msg/builderOnlyForAircrafts" : "events/empty_crew"),
      [["ok"]], "ok")
  }

  function updateButtons() {
    this.scene.findObject("btn_set_air").inactiveColor =
      (showedUnit.get()?.isAir() ?? false) ? "no"
      : "yes"
  }
}
register_gui_handler("changeAircraftForBuilder", changeAircraftForBuilder)

return { changeAircraftForBuilder }

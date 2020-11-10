class ::gui_handlers.changeAircraftForBuilder extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/shop/shopTakeAircraft.blk"
  shopAir = null

  function initScreen()
  {
     createSlotbar(
       {
         showNewSlot = false,
         showEmptySlot = false,
         hasActions = false,
         afterSlotbarSelect = updateButtons,
         slotbarBehavior = "posNavigator",
         needFullSlotBlock = true
         onSlotDblClick = ::Callback(@(crew) onApply(), this)
         onSlotActivate = ::Callback(@(crew) onApply(), this)
       },
       "take-aircraft-slotbar"
     )

     local textObj = scene.findObject("take-aircraft-text")
     textObj.top = "1@titleLogoPlateHeight + 1@frameHeaderHeight"
     textObj.setValue(::loc("mainmenu/missionBuilderNotAvailable"))

     local air = getCurSlotUnit()
     ::show_aircraft = air
     updateButtons()
  }

  function onTakeCancel()
  {
    ::show_aircraft = shopAir
    goBack()
  }

  function onApply()
  {
    if (::show_aircraft && ::show_aircraft.isAir())
      return ::gui_start_builder()

    msgBox("not_available", ::loc("msg/builderOnlyForAircrafts"),
      [["ok", function() {} ]], "ok", { cancel_fn = function() {}})
  }

  function updateButtons()
  {
    scene.findObject("btn_set_air").inactiveColor =
      (::show_aircraft && ::show_aircraft.isAir()) ? "no"
      : "yes"
  }
}
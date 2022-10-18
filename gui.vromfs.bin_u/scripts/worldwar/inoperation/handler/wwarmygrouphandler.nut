from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

::WwArmyGroupHandler <- class
{
  group = null
  scene = null

  armyView = null

  constructor(v_placeObj, v_group = null)
  {
    if (!checkObj(v_placeObj))
      return

    if (!v_group || !v_group.isValid())
      return

    scene = v_placeObj
    group = v_group
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function updateSelectedStatus()
  {
    if (!checkObj(scene))
      return

    let viewObj = scene.findObject(group.getView().getId())
    if (!checkObj(viewObj))
      return

    local isSelectedGroupArmy = false
    foreach (armyName in ::ww_get_selected_armies_names())
      if (group.isMyArmy(::g_world_war.getArmyByName(armyName)))
      {
        isSelectedGroupArmy = true
        break
      }

    viewObj.selected = isSelectedGroupArmy? "yes" : "no"
  }

  function onEventWWMapArmySelected(_params)
  {
    updateSelectedStatus()
  }

  function onEventWWMapClearSelection(_params)
  {
    if (!checkObj(scene))
      return

    let viewObj = scene.findObject(group.getView().getId())
    if (!checkObj(viewObj))
      return

    viewObj.selected = "no"
  }
}

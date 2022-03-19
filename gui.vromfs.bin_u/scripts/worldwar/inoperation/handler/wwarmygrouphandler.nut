class ::WwArmyGroupHandler
{
  group = null
  scene = null

  armyView = null

  constructor(_placeObj, _group = null)
  {
    if (!::checkObj(_placeObj))
      return

    if (!_group || !_group.isValid())
      return

    scene = _placeObj
    group = _group
    ::subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function updateSelectedStatus()
  {
    if (!::checkObj(scene))
      return

    local viewObj = scene.findObject(group.getView().getId())
    if (!::checkObj(viewObj))
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

  function onEventWWMapArmySelected(params)
  {
    updateSelectedStatus()
  }

  function onEventWWMapClearSelection(params)
  {
    if (!::checkObj(scene))
      return

    local viewObj = scene.findObject(group.getView().getId())
    if (!::checkObj(viewObj))
      return

    viewObj.selected = "no"
  }
}

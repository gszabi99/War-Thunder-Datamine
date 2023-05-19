//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")

::WwArmyGroupHandler <- class {
  group = null
  scene = null

  armyView = null

  constructor(v_placeObj, v_group = null) {
    if (!checkObj(v_placeObj))
      return

    if (!v_group || !v_group.isValid())
      return

    this.scene = v_placeObj
    this.group = v_group
    subscribe_handler(this, ::g_listener_priority.DEFAULT_HANDLER)
  }

  function updateSelectedStatus() {
    if (!checkObj(this.scene))
      return

    let viewObj = this.scene.findObject(this.group.getView().getId())
    if (!checkObj(viewObj))
      return

    local isSelectedGroupArmy = false
    foreach (armyName in ::ww_get_selected_armies_names())
      if (this.group.isMyArmy(::g_world_war.getArmyByName(armyName))) {
        isSelectedGroupArmy = true
        break
      }

    viewObj.selected = isSelectedGroupArmy ? "yes" : "no"
  }

  function onEventWWMapArmySelected(_params) {
    this.updateSelectedStatus()
  }

  function onEventWWMapClearSelection(_params) {
    if (!checkObj(this.scene))
      return

    let viewObj = this.scene.findObject(this.group.getView().getId())
    if (!checkObj(viewObj))
      return

    viewObj.selected = "no"
  }
}

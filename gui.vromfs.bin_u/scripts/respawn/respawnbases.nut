//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { getAvailableRespawnBases } = require("guiRespawn")
let RespawnBase = require("%scripts/respawn/respawnBase.nut")

local respawnBases = {
  MAP_ID_NOTHING = RespawnBase.MAP_ID_NOTHING
  selectedBaseData = null //null when not inited for current mission. reset every battle

  function getSelectedBase() {
    return this.selectedBaseData?.respBase
  }

  function getRespawnBasesData(unit) {
    let res = {
      hasRespawnBases = false
      canChooseRespawnBase = false
      basesList = []
      selBase = null
    }

    let rbs = getAvailableRespawnBases(unit.tags)
    if (!rbs.len())
      return res

    res.hasRespawnBases = true
    res.canChooseRespawnBase = true
    let lastSelectedBase = this.getSelectedBase()
    local defaultBase = null
    foreach (_idx, id in rbs) {
      let rb = RespawnBase(id)
      res.basesList.append(rb)
      if (rb.isEqual(lastSelectedBase))
        res.selBase = rb
      if (!defaultBase || (rb.isDefault <=> defaultBase.isDefault) > 0)
        defaultBase = rb
    }

    let autoSelectedBase = RespawnBase(defaultBase.id, true)
    res.basesList.insert(0, autoSelectedBase)
    if (!res.selBase)
      res.selBase = autoSelectedBase
    return res
  }

  function selectBase(unit, respawnBase) {
    if (respawnBase)
      this.selectedBaseData = {
        unit = unit
        respBase = respawnBase
      }
    else
      this.selectedBaseData = null
  }

  function resetSelectedBase() {
    this.selectedBaseData = null
  }

  function onEventLoadingStateChange(_p) {
    if (!::is_in_flight())
      this.resetSelectedBase()
  }
}

::subscribe_handler(respawnBases, ::g_listener_priority.DEFAULT_HANDLER)
return respawnBases
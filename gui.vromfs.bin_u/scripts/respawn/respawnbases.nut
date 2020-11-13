local RespawnBase = ::require("scripts/respawn/respawnBase.nut")

local respawnBases = {
  MAP_ID_NOTHING = RespawnBase.MAP_ID_NOTHING
  selectedBaseData = null //null when not inited for current mission. reset every battle

  function getSelectedBase()
  {
    return selectedBaseData?.respBase
  }

  function getRespawnBasesData(unit)
  {
    local res = {
      hasRespawnBases = false
      canChooseRespawnBase = false
      basesList = []
      selBase = null
    }

    local rbs = ::get_available_respawn_bases(unit.tags)
    if (!rbs.len())
      return res

    res.hasRespawnBases = true
    res.canChooseRespawnBase = true
    local lastSelectedBase = getSelectedBase()
    local defaultBase = null
    foreach(idx, id in rbs)
    {
      local rb = RespawnBase(id)
      res.basesList.append(rb)
      if (rb.isEqual(lastSelectedBase))
        res.selBase = rb
      if (!defaultBase || (rb.isDefault <=> defaultBase.isDefault) > 0)
        defaultBase = rb
    }

    local autoSelectedBase = RespawnBase(defaultBase.id, true)
    res.basesList.insert(0, autoSelectedBase)
    if (!res.selBase)
      res.selBase = autoSelectedBase
    return res
  }

  function selectBase(unit, respawnBase)
  {
    if (respawnBase)
      selectedBaseData = {
        unit = unit
        respBase = respawnBase
      }
    else
      selectedBaseData = null
  }

  function resetSelectedBase()
  {
    selectedBaseData = null
  }

  function onEventLoadingStateChange(p)
  {
    if (!::is_in_flight())
      resetSelectedBase()
  }
}

::subscribe_handler(respawnBases, ::g_listener_priority.DEFAULT_HANDLER)
return respawnBases
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { getRespawnBaseNameById, isDefaultRespawnBase } = require("guiRespawn")

let MAP_SELECT_NOTHING = -1

local RespawnBase = class
{
  id = -1
  name = ""
  mapId = MAP_SELECT_NOTHING
  isRandom = false
  isDefault = false
  isMapSelectable = false
  isAutoSelected = false

  static MAP_ID_NOTHING = MAP_SELECT_NOTHING

  constructor(v_id, v_isAutoSelected = false)
  {
    id = v_id
    isAutoSelected = v_isAutoSelected
    name = getRespawnBaseNameById(id)
    isRandom = name == "missions/random_spawn" || name == "missions/ground_spawn_random"
    isDefault = isDefaultRespawnBase(id)
    isMapSelectable = !isRandom && !isAutoSelected
    mapId = !isRandom ? id : MAP_ID_NOTHING
  }

  function getTitle()
  {
    local res = (name == "") ? loc("missions/spawn_number", { number = id + 1 }) : loc(name)
    if (isAutoSelected)
      res = loc("missions/auto_spawn", { spawn = res })
    return res
  }

  function isEqual(respBase)
  {
    return respBase != null && isAutoSelected == respBase.isAutoSelected && id == respBase.id
  }
}

::u.registerClass("RespawnBase", RespawnBase, @(b1, b2) b1.isEqual(b2))

return RespawnBase
//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { getRespawnBaseNameById, isDefaultRespawnBase } = require("guiRespawn")

let MAP_SELECT_NOTHING = -1

local RespawnBase = class {
  id = -1
  name = ""
  mapId = MAP_SELECT_NOTHING
  isRandom = false
  isDefault = false
  isMapSelectable = false
  isAutoSelected = false

  static MAP_ID_NOTHING = MAP_SELECT_NOTHING

  constructor(v_id, v_isAutoSelected = false) {
    this.id = v_id
    this.isAutoSelected = v_isAutoSelected
    this.name = getRespawnBaseNameById(this.id)
    this.isRandom = this.name == "missions/random_spawn" || this.name == "missions/ground_spawn_random"
    this.isDefault = isDefaultRespawnBase(this.id)
    this.isMapSelectable = !this.isRandom && !this.isAutoSelected
    this.mapId = !this.isRandom ? this.id : this.MAP_ID_NOTHING
  }

  function getTitle() {
    local res = (this.name == "") ? loc("missions/spawn_number", { number = this.id + 1 }) : loc(this.name)
    if (this.isAutoSelected)
      res = loc("missions/auto_spawn", { spawn = res })
    return res
  }

  function isEqual(respBase) {
    return respBase != null && this.isAutoSelected == respBase.isAutoSelected && this.id == respBase.id
  }
}

::u.registerClass("RespawnBase", RespawnBase, @(b1, b2) b1.isEqual(b2))

return RespawnBase
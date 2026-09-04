from "%sqstd/string.nut" import startsWith
from "guiRespawn" import getRespawnBaseNameById, isDefaultRespawnBase, isGroundRespawnBaseById, isRandomRespawnBaseById
from "%scripts/dagui_library.nut" import *

local RespawnBase = class {
  id = -1
  name = ""
  isRandom = false
  isDefault = false
  isGround = false
  isMapSelectable = false
  isAutoSelected = false
  isSquadRespawnBase = false
  isZoneRespawnBase = false
  isSavedForSlot = false
  canSelect = true
  isAvailable = true

  constructor(v_id, v_isAutoSelected = false, v_isSquadRespawnBase = false, v_isZoneRespawnBase = false) {
    this.id = v_id
    this.isAutoSelected = v_isAutoSelected
    this.isSquadRespawnBase = v_isSquadRespawnBase
    this.isZoneRespawnBase = v_isZoneRespawnBase
    if (v_isSquadRespawnBase || v_isZoneRespawnBase)
      return

    this.name = getRespawnBaseNameById(this.id)
    this.isRandom = isRandomRespawnBaseById(this.id)
    this.isDefault = isDefaultRespawnBase(this.id)
    this.isGround = isGroundRespawnBaseById(this.id)
    this.isMapSelectable = !this.isRandom && !this.isAutoSelected
  }

  function getTitle() {
    local res = (this.name == "") ? loc("missions/spawn_number", { number = this.id + 1 }) : loc(this.name)
    if (this.isAutoSelected)
      res = loc("missions/auto_spawn", { spawn = res })
    return res
  }

  function isSpawnIsAirfiled() {
    let spawnLocSubName = this.name.split("/")?[1] ?? ""
    if (spawnLocSubName == "")
      return false
    return startsWith(spawnLocSubName, "airfield")
  }

  function fillRespawnBaseData(params) {
    foreach (key, value in params)
      if (key in this)
        this[key] = value
  }
  isEmpty = @() false
  _typeof = @() "RespawnBase"
}

RespawnBase.isEqual <- function(other) {
  return other instanceof RespawnBase
    && this.isAutoSelected == other.isAutoSelected
    && this.isZoneRespawnBase == other.isZoneRespawnBase
    && this.id == other.id
    && this.isAvailable == other.isAvailable
}

return RespawnBase
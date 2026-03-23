from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { startsWith } = require("%sqstd/string.nut")
let { getRespawnBaseNameById, isDefaultRespawnBase, isGroundRespawnBaseById,
  isRandomRespawnBaseById } = require("guiRespawn")

local RespawnBase = class {
  id = -1
  name = ""
  isRandom = false
  isDefault = false
  isGround = false
  isMapSelectable = false
  isAutoSelected = false
  isSquadRespawnBase = false
  isAvailable = true

  constructor(v_id, v_isAutoSelected = false, v_isSquadRespawnBase = false) {
    this.id = v_id
    this.isAutoSelected = v_isAutoSelected
    this.isSquadRespawnBase = v_isSquadRespawnBase
    if (v_isSquadRespawnBase)
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

  function isEqual(respBase) {
    return respBase != null
      && this.isAutoSelected == respBase.isAutoSelected
      && this.id == respBase.id
      && this.isAvailable == respBase.isAvailable
  }

  function isSpawnIsAirfiled() {
    let spawnLocSubName = this.name.split("/")?[1] ?? ""
    if (spawnLocSubName == "")
      return false
    return startsWith(spawnLocSubName, "airfield")
  }

  function fillSquadRespawnBase(params) {
    this.name = params.name
    this.isAvailable = params.isAvailable
  }
}

u.registerClass("RespawnBase", RespawnBase, @(b1, b2) b1.isEqual(b2))

return RespawnBase
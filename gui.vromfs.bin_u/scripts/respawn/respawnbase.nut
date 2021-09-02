local MAP_SELECT_NOTHING = -1

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

  constructor(_id, _isAutoSelected = false)
  {
    id = _id
    isAutoSelected = _isAutoSelected
    name = ::get_respawn_base_name_by_id(id)
    isRandom = name == "missions/random_spawn" || name == "missions/ground_spawn_random"
    isDefault = ::is_default_respawn_base(id)
    isMapSelectable = !isRandom && !isAutoSelected
    mapId = !isRandom ? id : MAP_ID_NOTHING
  }

  function getTitle()
  {
    local res = (name == "") ? ::loc("missions/spawn_number", { number = id + 1 }) : ::loc(name)
    if (isAutoSelected)
      res = ::loc("missions/auto_spawn", { spawn = res })
    return res
  }

  function isEqual(respBase)
  {
    return respBase != null && isAutoSelected == respBase.isAutoSelected && id == respBase.id
  }
}

return RespawnBase
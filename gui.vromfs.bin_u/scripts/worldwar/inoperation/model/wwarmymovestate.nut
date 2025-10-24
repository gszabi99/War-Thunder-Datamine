let { enumsAddTypes, enumsGetCachedType } = require("%sqStdLibs/helpers/enums.nut")

let wwArmyMoveStateType = {
  types = []
  cache = {
    byName = {}
  }

  template = {
    isMove = false
    name = ""
  }
}


enumsAddTypes(wwArmyMoveStateType, {
  ES_UNKNOWN = {
    isMove = false
  }
  ES_WAIT_FOR_PATH = {
    isMove = false
  }
  ES_WRONG_PATH = {
    isMove = false
  }
  ES_PATH_PASSED = {
    isMove = false
  }
  ES_MOVING_BY_PATH = {
    isMove = true
  }
  ES_STOPED = {
    isMove = false
  }
}, null, "name")

wwArmyMoveStateType.getMoveParamsByName <- function getMoveParamsByName(name) {
  return enumsGetCachedType("name", name, wwArmyMoveStateType.cache.byName, this, this.ES_UNKNOWN)
}

return {
  wwArmyMoveStateType
}
from "%scripts/dagui_library.nut" import *
let enums = require("%sqStdLibs/helpers/enums.nut")

let objectiveStatus = {
  types = []
  cache = {
    byCode = {}
  }
  template = {
    code = -1
    name = ""
    missionObjImg = ""
    wwMissionObjImg = ""
  }
}

enums.addTypes(objectiveStatus, {
  DELAYED = {
    code = MISSION_OBJECTIVE_STATUS_DELAYED
    name = "delayed"
  }
  RUNNING = {
    code = MISSION_OBJECTIVE_STATUS_IN_PROGRESS
    name = "running"
    missionObjImg = "#ui/gameuiskin#icon_primary.svg"
    wwMissionObjImg = "#ui/gameuiskin#icon_primary.svg"
  }
  SUCCEED = {
    code = MISSION_OBJECTIVE_STATUS_COMPLETED
    name = "succeed"
    missionObjImg = "#ui/gameuiskin#icon_primary_success.svg"
    wwMissionObjImg = "#ui/gameuiskin#favorite"
  }
  FAILED = {
    code = MISSION_OBJECTIVE_STATUS_FAILED
    name = "failed"
    missionObjImg = "#ui/gameuiskin#icon_primary_fail.svg"
    wwMissionObjImg = "#ui/gameuiskin#icon_primary_fail.svg"
  }
  UNKNOWN = {
    name = "unknown"
  }
})

function getObjectiveStatusByCode(statusCode) {
  return enums.getCachedType("code", statusCode, objectiveStatus.cache.byCode,
  objectiveStatus, objectiveStatus.UNKNOWN)
}

return {
  objectiveStatus
  getObjectiveStatusByCode
}
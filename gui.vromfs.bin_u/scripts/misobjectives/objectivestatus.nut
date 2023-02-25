//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this


let enums = require("%sqStdLibs/helpers/enums.nut")
::g_objective_status <- {
  types = []
}

::g_objective_status.template <- {
  code = -1
  name = ""
  missionObjImg = ""
  wwMissionObjImg = ""
}

enums.addTypesByGlobalName("g_objective_status", {
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
    wwMissionObjImg = "#ui/gameuiskin#favorite.png"
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

::g_objective_status.getObjectiveStatusByCode <- function getObjectiveStatusByCode(statusCode) {
  return enums.getCachedType("code", statusCode, ::g_objective_status_cache.byCode,
    ::g_objective_status, ::g_objective_status.UNKNOWN)
}

::g_objective_status_cache <- {
  byCode = {}
}

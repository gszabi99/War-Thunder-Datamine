from "%sqDagui/daguiNativeApi.nut" import *

let enums = require("%sqStdLibs/helpers/enums.nut")
let elemEvents = require("%sqDagui/elemUpdater/elemUpdaterEvents.nut")

let modelType = {
  types = []
}

modelType.template <- {
  id = "" 

  init = function() {}

  makeFullPath = function(relativePath) {
    relativePath.insert(0, this.id)
    return relativePath
  }
  notify = @(relativePath) elemEvents.notifyChanged(this.makeFullPath(relativePath))
}

modelType.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable, @() this.init(), "id")
}

modelType.addTypes({
  EMPTY = {}
})


modelType.get <- @(typeId) this?[typeId] ?? this.EMPTY

return modelType
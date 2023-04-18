#explicit-this
#no-root-fallback

let enums = require("%sqStdLibs/helpers/enums.nut")
let elemEvents = require("%sqDagui/elemUpdater/elemUpdaterEvents.nut")

let modelType = {
  types = []
}

modelType.template <- {
  id = "" //filled automatically by typeName. so unique

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

//save get type by id. return EMPTY if not found
modelType.get <- @(typeId) this?[typeId] ?? this.EMPTY

return modelType
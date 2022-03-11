local enums = require("sqStdlibs/helpers/enums.nut")
local elemEvents = require("sqDagui/elemUpdater/elemUpdaterEvents.nut")

local modelType = {
  types = []
}

modelType.template <- {
  id = "" //filled automatically by typeName. so unique

  init = function() {}

  makeFullPath = function(relativePath)
  {
    relativePath.insert(0, id)
    return relativePath
  }
  notify = @(relativePath) elemEvents.notifyChanged(makeFullPath(relativePath))
}

modelType.addTypes <- function(typesTable)
{
  enums.addTypes(this, typesTable, @() init(), "id")
}

modelType.addTypes({
  EMPTY = {}
})

//save get type by id. return EMPTY if not found
modelType.get <- @(typeId) this?[typeId] ?? EMPTY

return modelType
local enums = require("sqStdlibs/helpers/enums.nut")

local callbacks = {
  types = []
}

local cbTbl = {}

callbacks.template <- {
  id = "" //filled automatically by typeName
  cbName = "" // filled automatically
  onCb = @(params) null
  paramsKey = "actionData"
  getParamsMarkup = @(params) ::format("%s:t='%s';", paramsKey, ::save_to_json(params))
  cbFromObj = @(obj) onCb(obj, ::check_obj(obj) ? ::parse_json(obj?[paramsKey] ?? "") : {})
}

callbacks.addTypes <- function(typesTable)
{
  enums.addTypes(this, typesTable,
    function() {
      cbName = "::gcb." + id
      ::dagor.assertf(!(id in cbTbl), "globalCallbacks: Found duplicating id: " + id)
      cbTbl[id] <- cbFromObj.bindenv(this)
    },
    "id")
}

callbacks.addTypes({
  EMPTY = {}
})

callbacks.get <- @(typeId) this?[typeId] ?? EMPTY

::gcb <- cbTbl

return callbacks

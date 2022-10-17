let { format } = require("string")
let enums = require("%sqStdLibs/helpers/enums.nut")

let callbacks = {
  types = []
}

let cbTbl = {}

callbacks.template <- {
  id = "" //filled automatically by typeName
  cbName = "" // filled automatically
  onCb = @(obj, params) null
  paramsKey = "actionData"
  getParamsMarkup = @(params) format("%s:t='%s';", paramsKey, ::save_to_json(params))
  cbFromObj = @(obj) onCb(obj, obj?.isValid() && (obj?[paramsKey] ?? "") != "" ? ::parse_json(obj[paramsKey]) : {})
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

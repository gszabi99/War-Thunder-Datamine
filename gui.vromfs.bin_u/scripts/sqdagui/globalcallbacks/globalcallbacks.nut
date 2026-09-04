import "%sqStdLibs/helpers/enums.nut" as enums
from "dagui" import set_markup_scope
from "json" import object_to_json_string, parse_json
from "%scripts/sqDagui/daguiNativeApi.nut" import *

let callbacks = {
  types = []
}




const PARAMS_KEY = "actionData"
let getGcbName = @(id) $"gcb.{id}"
let getGcbParamsMarkup = @(params) $"{PARAMS_KEY}:t='{object_to_json_string(params, false)}';"

let cbTbl = {}

callbacks.template <- {
  id = "" 
  cbName = "" 
  onCb = @(_obj, _params) null
  paramsKey = PARAMS_KEY
  cbFromObj = @(obj) this.onCb(obj, obj?.isValid() && (obj?[this.paramsKey] ?? "") != "" ? parse_json(obj[this.paramsKey]) : {})
}

callbacks.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable,
    function() {
      this.cbName = getGcbName(this.id)
      assert(!(this.id in cbTbl), $"globalCallbacks: Found duplicating id: {this.id}")
      cbTbl[this.id] <- this.cbFromObj.bindenv(this)
    },
    "id")
}

callbacks.getGcbName <- getGcbName
callbacks.getGcbParamsMarkup <- getGcbParamsMarkup

let EMPTY = {}

callbacks.addTypes({
  EMPTY
})

callbacks.get <- @(typeId) this?[typeId] ?? EMPTY
callbacks.getCbFunc <- @(id) cbTbl[id]



set_markup_scope("gcb", cbTbl)

return callbacks

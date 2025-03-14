from "%sqDagui/daguiNativeApi.nut" import *

let enums = require("%sqStdLibs/helpers/enums.nut")
let { assertf } = require("dagor.debug")
let { object_to_json_string, parse_json } = require("json")
let { dynamic_content } = require("%sqstd/analyzer.nut")

let callbacks = {
  types = []
}

let cbTbl = {}

callbacks.template <- {
  id = "" 
  cbName = "" 
  onCb = @(_obj, _params) null
  paramsKey = "actionData"
  getParamsMarkup = @(params) $"{this.paramsKey}:t='{object_to_json_string(params, false)}';"
  cbFromObj = @(obj) this.onCb(obj, obj?.isValid() && (obj?[this.paramsKey] ?? "") != "" ? parse_json(obj[this.paramsKey]) : {})
}

callbacks.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable,
    function() {
      this.cbName = $"::gcb.{this.id}"
      assertf(!(this.id in cbTbl), $"globalCallbacks: Found duplicating id: {this.id}")
      cbTbl[this.id] <- this.cbFromObj.bindenv(this)
    },
    "id")
}

let EMPTY = {}

callbacks.addTypes({
  EMPTY
})

callbacks.get <- @(typeId) this?[typeId] ?? EMPTY

::gcb <- cbTbl

return dynamic_content(callbacks)

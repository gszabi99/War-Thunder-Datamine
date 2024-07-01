from "%sqDagui/daguiNativeApi.nut" import *

let enums = require("%sqStdLibs/helpers/enums.nut")
let elemModelType = require("%sqDagui/elemUpdater/elemModelType.nut")
let { object_to_json_string, parse_json } = require("json")

let viewType = {
  types = []
}

viewType.template <- {
  id = "" //filled automatically by typeName. so unique
  model = elemModelType.EMPTY

  bhvParamsToString = function(params) {
    params.viewId <- this.id
    return object_to_json_string(params, false)
  }

  createMarkup = @(_params) ""
  updateView = @(_obj, _bhvConfig) null
}

viewType.addTypes <- function(typesTable) {
  enums.addTypes(this, typesTable, null, "id")
}

viewType.addTypes({
  EMPTY = {}
})

//save get type by id. return EMPTY if not found
viewType.get <- @(typeId) this?[typeId] ?? this.EMPTY

viewType.buildBhvConfig <- function(params) {
  local tbl = (type(params) == "table") ? params : null
  local vt = this.get(tbl?.viewId ?? params)
  if (type(params) == "string")
    tbl = vt == this.EMPTY ? parse_json(params) : { viewId = params }

  if (!tbl?.viewId)
    return null

  vt = this.get(tbl.viewId)
  let res = tbl
  res.viewType <- vt
  if (!res?.subscriptions)
    res.subscriptions <- []
  return res
}

return viewType
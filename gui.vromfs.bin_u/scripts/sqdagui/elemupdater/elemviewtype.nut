import "%sqStdLibs/helpers/enums.nut" as enums
from "json" import object_to_json_string, parse_json
from "%scripts/sqDagui/daguiNativeApi.nut" import *
from "types" import Table, String

let elemModelType = require("%scripts/sqDagui/elemUpdater/elemModelType.nut")

let viewType = {
  types = []
}

viewType.template <- {
  id = "" 
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


viewType.get <- @(typeId) this?[typeId] ?? this.EMPTY

viewType.buildBhvConfig <- function(params) {
  local tbl = (params instanceof Table) ? params : null
  local vt = this.get(tbl?.viewId ?? params)
  if (params instanceof String)
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
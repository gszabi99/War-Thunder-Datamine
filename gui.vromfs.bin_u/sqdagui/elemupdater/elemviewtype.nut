local enums = ::require("sqStdlibs/helpers/enums.nut")
local elemModelType = ::require("sqDagui/elemUpdater/elemModelType.nut")

local viewType = {
  types = []
}

viewType.template <- {
  id = "" //filled automatically by typeName. so unique
  model = elemModelType.EMPTY

  bhvParamsToString = function(params)
  {
    params.viewId <- id
    return ::save_to_json(params)
  }

  createMarkup = @(params) ""
  updateView = @(obj, bhvConfig) null
}

viewType.addTypes <- function(typesTable)
{
  enums.addTypes(this, typesTable, null, "id")
}

viewType.addTypes({
  EMPTY = {}
})

//save get type by id. return EMPTY if not found
viewType.get <- @(typeId) this?[typeId] ?? EMPTY

viewType.buildBhvConfig <- function(params) {
  local tbl = (type(params)=="table") ? params : null
  local vt = get(tbl?.viewId ?? params)
  if (type(params)=="string")
    tbl = vt == EMPTY ? ::parse_json(params) : { viewId = params }

  if (!tbl?.viewId)
    return null

  vt = get(tbl.viewId)
  local res = tbl
  res.viewType <- vt
  if (!res?.subscriptions)
    res.subscriptions <- []
  return res
}

return viewType
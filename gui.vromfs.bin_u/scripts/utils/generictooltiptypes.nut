//-file:plus-string
from "%scripts/dagui_library.nut" import *
let { format } = require("string")
let { addTypes } = require("%sqStdLibs/helpers/enums.nut")

let tooltipTypes = {
  types = []
}

tooltipTypes.template <- {
  typeName = "" //added automatically by type name

  _buildId = function(id, params = null) {
    let t = params ? clone params : {}
    t.ttype <- this.typeName
    t.id    <- id
    return ::save_to_json(t)
  }
  //full params list depend on specific type
  getTooltipId = function(id, params = null, _p2 = null, _p3 = null) {
    return this._buildId(id, params)
  }
  getMarkup = @(id, params = null, p2 = null, p3 = null)
    format(@"title:t='$tooltipObj'
      tooltipObj {
        tooltipId:t='%s'
        display:t='hide'
        on_tooltip_open:t='onGenericTooltipOpen'
        on_tooltip_close:t='onTooltipObjClose'
      }",
      this.getTooltipId(id, params, p2, p3))

  getTooltipContent = function(_id, _params) { return "" }
  isCustomTooltipFill = false //if true, need to use fillTooltip instead of getTooltipContent
  fillTooltip = function(_obj, _handler, _id, _params) { //return isSucceed
    return false
  }
  onClose = @(_obj) null
}

function addTooltipTypes(tTypes) {
  addTypes(tooltipTypes, tTypes, null, "typeName")
  return tTypes.map(@(_, id) tooltipTypes[id])
}

addTooltipTypes({
  EMPTY = {
  }
})

function getTooltipType(typeName) {
  let res = tooltipTypes?[typeName]
  return type(res) == "table" ? res : this.EMPTY
}

return {
  addTooltipTypes
  getTooltipType
}
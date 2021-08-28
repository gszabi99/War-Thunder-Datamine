from "%darg/ui_imports.nut" import *
from "ecs" import *

local {getValFromObj, compValToString} = require("attrUtil.nut")

local function fieldReadOnly(params = {}) {
  local {obj, path, eid, comp_name} = params
  local val = path==null ? obsolete_dbg_get_comp_val(eid, comp_name) : getValFromObj(obj, path)
  local valText = compValToString(val)

  return {
    rendObj = ROBJ_DTEXT
    size = [flex(), SIZE_TO_CONTENT]
    text = valText
    margin = fsh(0.5)
  }
}


return fieldReadOnly

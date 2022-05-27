from "%darg/ui_imports.nut" import *
from "ecs" import *

let {getValFromObj, compValToString} = require("attrUtil.nut")

let function fieldReadOnly(params = {}) {
  let {path, eid, comp_name} = params
  let val = path==null ? _dbg_get_comp_val_inspect(eid, comp_name) : getValFromObj(eid, comp_name, path)
  let valText = compValToString(val)

  return {
    rendObj = ROBJ_DTEXT
    size = [flex(), SIZE_TO_CONTENT]
    text = valText
    margin = fsh(0.5)
  }
}


return fieldReadOnly

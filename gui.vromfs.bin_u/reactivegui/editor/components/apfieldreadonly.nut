local {getValFromObj, compValToString} = require("attrUtil.nut")

local function fieldReadOnly(params = {}) {
  local {obj, path, eid, comp_name} = params
  local val = path==null ? ::ecs.get_comp_val(eid, comp_name) : getValFromObj(obj, path)
  local valText = compValToString(val)

  return {
    rendObj = ROBJ_DTEXT
    size = [flex(), SIZE_TO_CONTENT]
    text = valText
    margin = sh(0.5)
  }
}


return fieldReadOnly

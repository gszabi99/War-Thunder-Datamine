from "%darg/ui_imports.nut" import *

let { compValToString } = require("attrUtil.nut")

function fieldReadOnly(desc) {
  let { value } = desc
  let text = Computed(@() compValToString(value.get()))
  return @() {
    watch = text
    rendObj = ROBJ_TEXT
    size = FLEX_H
    text = text.get()
    margin = fsh(0.5)
  }
}

return fieldReadOnly

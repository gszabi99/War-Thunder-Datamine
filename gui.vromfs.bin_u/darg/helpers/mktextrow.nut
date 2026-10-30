




















from "%darg/ui_imports.nut" import *
from "types" import String, Array

function mkTextRow(fullText, mkText, replaceTable): array {
  let plainTextSubsts = replaceTable.filter(@(v) v instanceof String)
  if (plainTextSubsts.len() > 0) {
    fullText = fullText.subst(plainTextSubsts)
    replaceTable = replaceTable.filter(@(v) !(v instanceof String))
  }
  local res = [fullText]
  foreach(id, comp in replaceTable) {
    let key = "".concat("{", id, "}")
    let curList = res
    res = []
    foreach(text in curList) {
      if (!(text instanceof String)) {
        res.append(text)
        continue
      }
      local nextIdx = 0
      local idx = text.indexof(key)
      while (idx != null) {
        if (idx > nextIdx)
          res.append(text.slice(nextIdx, idx))
        if (comp instanceof Array)
          res.extend(comp)
        else
          res.append(comp)
        nextIdx = idx + key.len()
        idx = text.indexof(key, nextIdx)
      }
      if (nextIdx < text.len())
        res.append(text.slice(nextIdx))
    }
  }
  return res.map(@(t) t instanceof String ? mkText(t) : t)
}

return mkTextRow
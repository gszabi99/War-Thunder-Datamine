




















from "types" import String, Array
function mkTextRow(fullText, mkText, replaceTable): array {
  local res = [fullText]
  foreach(key, comp in replaceTable) {
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
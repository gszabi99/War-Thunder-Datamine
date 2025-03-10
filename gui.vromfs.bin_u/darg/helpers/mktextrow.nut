




















function mkTextRow(fullText, mkText, replaceTable) {
  local res = [fullText]
  foreach(key, comp in replaceTable) {
    let curList = res
    res = []
    foreach(text in curList) {
      if (type(text) != "string") {
        res.append(text)
        continue
      }
      local nextIdx = 0
      local idx = text.indexof(key)
      while (idx != null) {
        if (idx > nextIdx)
          res.append(text.slice(nextIdx, idx))
        if (type(comp) == "array")
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
  return res.map(@(t) type(t) == "string" ? mkText(t) : t)
}

return mkTextRow
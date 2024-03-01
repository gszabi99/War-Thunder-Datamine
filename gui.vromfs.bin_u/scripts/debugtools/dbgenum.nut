from "%scripts/dagui_library.nut" import *

let { format } = require("string")
let stdMath = require("%sqstd/math.nut")

function getEnumValName(strEnumName, enumTable, value, skipSynonyms = false) {
  let names = []
  foreach (constName, constVal in enumTable)
    if (constVal == value) {
      names.append(format("%s.%s", strEnumName, constName))
      if (skipSynonyms)
        break
    }
  return " || ".join(names)
}

function bitMaskToSstring(enumTable, mask) {
  local res = ""
  foreach (constName, constVal in enumTable)
    if (stdMath.number_of_set_bits(constVal) == 1 && (constVal & mask)) {
      res += (res.len() ? " | " : "") + constName
      mask = mask & ~constVal //ignore duplicates
    }
  return res
}

return {
  getEnumValName
  bitMaskToSstring
}
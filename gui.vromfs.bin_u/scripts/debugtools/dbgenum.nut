//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { format } = require("string")
let stdMath = require("%sqstd/math.nut")

let function getEnumValName(strEnumName, value, skipSynonyms = false) {
  assert(type(strEnumName) == "string", "strEnumName must be enum name as a string")
  let constants = getconsttable()
  let enumTable = (strEnumName in constants) ? constants[strEnumName] : {}
  local name = ""
  foreach (constName, constVal in enumTable)
    if (constVal == value) {
      name += (name.len() ? " || " : "") + format("%s.%s", strEnumName, constName)
      if (skipSynonyms)
        break
    }
  return name
}

let function bitMaskToSstring(strEnumName, mask) {
  assert(type(strEnumName) == "string", "strEnumName must be enum name as a string")
  let enumTable = getconsttable()?[strEnumName] ?? {}
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
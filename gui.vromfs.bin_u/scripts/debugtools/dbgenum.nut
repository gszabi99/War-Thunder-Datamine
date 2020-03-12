local stdMath = require("std/math.nut")

::getEnumValName <- function getEnumValName(strEnumName, value, skipSynonyms=false)
{
  ::dagor.assertf(typeof(strEnumName) == "string", "strEnumName must be enum name as a string")
  local constants = getconsttable()
  local enumTable = (strEnumName in constants) ? constants[strEnumName] : {}
  local name = ""
  foreach (constName, constVal in enumTable)
    if (constVal == value)
    {
      name += (name.len() ? " || " : "") + format("%s.%s", strEnumName, constName)
      if (skipSynonyms) break
    }
  return name
}

::bit_mask_to_string <- function bit_mask_to_string(strEnumName, mask)
{
  ::dagor.assertf(typeof(strEnumName) == "string", "strEnumName must be enum name as a string")
  local enumTable = ::getconsttable()?[strEnumName] ?? {}
  local res = ""
  foreach (constName, constVal in enumTable)
    if (stdMath.number_of_set_bits(constVal) == 1 && (constVal & mask))
    {
      res += (res.len() ? " | " : "") + constName
      mask = mask & ~constVal //ignore duplicates
    }
  return res
}
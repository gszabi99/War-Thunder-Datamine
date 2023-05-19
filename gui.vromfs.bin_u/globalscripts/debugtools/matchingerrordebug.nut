let { format } =  require("string")
let { register_command } = require("console")
let mErrors = require("matching.errors")
let { console_print } = require("%globalScripts/logs.nut")
let { hexStringToInt } =  require("%sqstd/string.nut")

register_command(function() {
  let res = []
  foreach(id, v in mErrors)
    if (type(v) == "integer")
      res.append({ id, v = v & 0xFFFFFFFF })
  return console_print("\n".join(
    res.sort(@(a, b) a.v <=> b.v)
      .map(@(i) $"{format("0x%X", i.v)} = {i.id}")))
}, "matching.errorsList")

register_command(function(value) {
  local intValue = type(value) == "integer" ? value
    : type(value) == "string" ? hexStringToInt(value)
    : null
  if (intValue == null)
    return console_print("need integer or string param")

  intValue = intValue | 0xFFFFFFFF00000000
  foreach(k, v in mErrors)
    if (type(v) == intValue)
      return console_print(k)
  return console_print("not found")
}, "matching.getErrorNameByValue")
let { Watched } = require("frp")
let { ndbWrite, ndbRead, ndbExists } = require("nestdb")

let list = {}

let function mkHardWatched(key, defValue = null) {
  if (list?[key] != null) {
    assert(false, $"hardWatched: duplicate name: {key}")
    return list[key]
  }

  local val = defValue
  if (ndbExists(key))
    val = ndbRead(key)
  else
    ndbWrite(key, val)

  let res = Watched(val)
  res.subscribe(@(v) ndbWrite(key, v))
  list[key] <- res.weakref()
  return res
}

return mkHardWatched
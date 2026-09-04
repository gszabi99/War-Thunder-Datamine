from "logs.nut" import logerr
from "dagor.localize" import loc, doesLocTextExist
from "types" import String

let reportedMissingLocKeys = {}

function loc_checked(key, ...) {
  let hasDefault = vargv.findindex(@(v) v instanceof String) != null
  if (!hasDefault && !doesLocTextExist(key)) {
    if (reportedMissingLocKeys?[key] == null) {
      logerr($"SQ [LANG] error: no key '{key}' in localization table")
      reportedMissingLocKeys[key] <- key
    }
  }
  return loc.acall([null, key].extend(vargv))
}

return {
  loc_checked
}


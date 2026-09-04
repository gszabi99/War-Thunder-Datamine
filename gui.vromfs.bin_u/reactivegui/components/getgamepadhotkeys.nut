import "%rGui/components/parseDargHotkeys.nut" as parseDargHotkeys
from "%rGui/globals/ui_library.nut" import *
from "types" import Array, String

function gamepadHotkeys(hotkeys, skipDescription = null) {
  if (hotkeys == null || !(hotkeys instanceof Array) || hotkeys.len() == 0)
    return ""

  if (skipDescription != null)
    hotkeys = hotkeys.filter(@(v) (v?[1]?.description?.skip ?? false) == skipDescription)

  hotkeys = hotkeys.map(@(v) v instanceof String ? v : v[0])
    .filter(@(v) v instanceof String)
    .map(@(v) parseDargHotkeys(v))
    .reduce(@(a, b) a.extend(b?.gamepad ?? []), [])
  return hotkeys?[0] ?? ""
}

return gamepadHotkeys

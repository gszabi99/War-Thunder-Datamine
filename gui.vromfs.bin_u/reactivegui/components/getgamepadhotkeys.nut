from "%rGui/globals/ui_library.nut" import *

let parseDargHotkeys = require("%rGui/components/parseDargHotkeys.nut")

function gamepadHotkeys(hotkeys, skipDescription = null) {
  if (hotkeys == null || type(hotkeys) != "array" || hotkeys.len() == 0)
    return ""

  if (skipDescription != null)
    hotkeys = hotkeys.filter(@(v) (v?[1]?.description?.skip ?? false) == skipDescription)

  hotkeys = hotkeys.map(@(v) type(v) == "string" ? v : v[0])
    .filter(@(v) type(v) == "string")
    .map(@(v) parseDargHotkeys(v))
    .reduce(@(a, b) a.extend(b?.gamepad ?? []), [])
  return hotkeys?[0] ?? ""
}

return gamepadHotkeys

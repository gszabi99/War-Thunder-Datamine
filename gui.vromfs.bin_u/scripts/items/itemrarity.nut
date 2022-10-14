from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

const ITEM_RARITY_DEFAULT = 1
const ITEM_RARITY_COLOR_DEFAULT = "f1f1d6"

let collection = {}

local Rarity = class {
  isRare = false
  value  = ITEM_RARITY_DEFAULT
  colorValue = ITEM_RARITY_COLOR_DEFAULT
  color  = ITEM_RARITY_COLOR_DEFAULT
  tag    = null

  constructor(v_value, v_color) {
    isRare = v_value > ITEM_RARITY_DEFAULT
    value  = isRare ? v_value : ITEM_RARITY_DEFAULT
    colorValue = isRare && !::u.isEmpty(v_color) ? v_color : ITEM_RARITY_COLOR_DEFAULT
    color  = $"#{colorValue}"
    updateTag()
  }

  function updateTag() {
    tag = isRare ? colorize(color, loc("item/rarity" + value)) : null
  }

  _cmp = @(other) value <=> other.value
  _tostring = @() "Rarity " + value
}

local get = function(value = null, color = null) {
  value = value || ITEM_RARITY_DEFAULT
  if (!(value in collection))
    collection[value] <- Rarity(value, color)
  return collection[value]
}

let onGameLocalizationChanged = function() {
  foreach (r in collection)
    r.updateTag()
}

::add_event_listener("GameLocalizationChanged", @(p) onGameLocalizationChanged(),
  null, ::g_listener_priority.CONFIG_VALIDATION)

return {
  get = get
}

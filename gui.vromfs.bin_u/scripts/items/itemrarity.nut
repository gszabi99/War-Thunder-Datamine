//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")

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
    this.isRare = v_value > ITEM_RARITY_DEFAULT
    this.value  = this.isRare ? v_value : ITEM_RARITY_DEFAULT
    this.colorValue = this.isRare && !u.isEmpty(v_color) ? v_color : ITEM_RARITY_COLOR_DEFAULT
    this.color  = $"#{this.colorValue}"
    this.updateTag()
  }

  function updateTag() {
    this.tag = this.isRare ? colorize(this.color, loc("item/rarity" + this.value)) : null
  }

  _cmp = @(other) this.value <=> other.value
  _tostring = @() "Rarity " + this.value
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

add_event_listener("GameLocalizationChanged", @(_p) onGameLocalizationChanged(),
  null, ::g_listener_priority.CONFIG_VALIDATION)

return {
  get = get
}

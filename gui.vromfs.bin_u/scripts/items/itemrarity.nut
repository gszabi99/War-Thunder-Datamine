const ITEM_RARITY_DEFAULT = 1
const ITEM_RARITY_COLOR_DEFAULT = "f1f1d6"

local collection = {}

local Rarity = class {
  isRare = false
  value  = ITEM_RARITY_DEFAULT
  color  = ITEM_RARITY_COLOR_DEFAULT
  tag    = null

  constructor(_value, _color) {
    isRare = _value > ITEM_RARITY_DEFAULT
    value  = isRare ? _value : ITEM_RARITY_DEFAULT
    color  = "#" + (isRare && !::u.isEmpty(_color) ? _color : ITEM_RARITY_COLOR_DEFAULT)
    updateTag()
  }

  function updateTag() {
    tag = isRare ? ::colorize(color, ::loc("item/rarity" + value)) : null
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

local onGameLocalizationChanged = function() {
  foreach (r in collection)
    r.updateTag()
}

::add_event_listener("GameLocalizationChanged", @(p) onGameLocalizationChanged(),
  null, ::g_listener_priority.CONFIG_VALIDATION)

return {
  get = get
}

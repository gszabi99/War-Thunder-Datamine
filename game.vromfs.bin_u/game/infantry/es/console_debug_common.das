module console_debug_common shared

require ecs
require daslib/strings_boost
require Unit
require HeroManager
require DagorConsole




def try_get_hero_cmd_param(inputs : array<string>&; index : int)
  let hero = get_controlled_hero()
  var heroEid = hero != null ? hero.eid :  INVALID_ENTITY_ID
  if length(inputs) > index && inputs[index] |> strip() != ""
    
    var res : ConversionResult
    var ofs : int
    let input = uint(inputs[index], res, ofs)
    if res == ConversionResult.ok && ofs == length(inputs[index])
      heroEid = EntityId(input)
    else
      console_print("Failed to parse hero eid param from '{inputs[index]}', using controlled hero eid {heroEid}")
  return heroEid

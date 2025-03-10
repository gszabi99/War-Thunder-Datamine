from "%scripts/dagui_natives.nut" import item_get_personal_discount_for_mod, item_get_personal_discount_for_skill_points, item_get_personal_discount_for_specialization, item_get_personal_discount_for_unit, item_get_personal_discount_for_weapon, item_get_personal_discount_for_exp_convert, item_get_personal_discount_for_unlock
from "%scripts/dagui_library.nut" import *



let getMethodByCategory = {
  aircrafts = function (path) {
    if (path.len() == 2)
      return item_get_personal_discount_for_unit(path[1])
    if (path.len() != 4)
      return 0
    let cat = path[2]
    if (cat == "weapons")
      return item_get_personal_discount_for_weapon(path[1], path[3])
    if (cat == "mods")
      return item_get_personal_discount_for_mod(path[1], path[3])
    if (cat == "specialization") {
      local spec = -1
      if (path[3] == "spec_expert")
        spec = 0
      if (path[3] == "spec_ace")
        spec = 1
      if (spec != -1)
        return item_get_personal_discount_for_specialization(path[1], spec)
    }
    return 0
  }
  unlocks = function (path) {
    if (path.len() != 2)
      return 0
    return item_get_personal_discount_for_unlock(path[1])
  }
  skills = function (path) {
    if (path.len() != 3)
      return 0
    return item_get_personal_discount_for_skill_points(path[2], path[1])
  }
  exp_to_gold_rate = function (path) {
    if (path.len() != 2)
      return 0
    return item_get_personal_discount_for_exp_convert(path[1])
  }
}

let getDiscountByPath = function(path) {
  if (path.len() == 0)
    return 0

  let method = getMethodByCategory?[path[0]]
  if (type(method) == "function")
    return method(path)
  return 0
}

return {
  getDiscountByPath = getDiscountByPath
}
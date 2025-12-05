import "%sqstd/ecs.nut" as ecs
from "%rGui/globals/ui_library.nut" import *
import "console" as console

let { EventPlayerOwnedUnitChanged, EventPlayerControlledUnitChanged, EventArmorInfoChanged
} = require("dasevents")
let { add_event_listener } = require("%sqStdLibs/helpers/subscriptions.nut")

let armorState = Watched({})

ecs.register_es("human_armor_changed_es",
  {
    [[EventPlayerOwnedUnitChanged, EventPlayerControlledUnitChanged, EventArmorInfoChanged,
      "onInit", "onChange"]] =
      function(_eid, comp) {
        armorState.set(comp.armor_ui__info.getAll())
      }
  },
  {
    comps_track = [["armor_ui__info", ecs.TYPE_OBJECT]]
    comps_rq = ["hero"],
  },
  {
    tags = "gameClient"
  }
)

add_event_listener("BattleEnded", @(_) armorState.set({}))
add_event_listener("PlayerQuitMission", @(_) armorState.set({}))


console.register_command(@(part, damage_val = 1.0) armorState.mutate(@(v) v[part] <- { value = damage_val }), "debug.armor.set_damage")
console.register_command(@(damage_val = 1.0) armorState.mutate(function(v) {
  v["helmet"] <- { value = damage_val }
  v["vest"] <- { value = damage_val }
  v["groin"] <- { value = damage_val }
  v["shoulder_L"] <- { value = damage_val }
  v["rear_plate"] <- { value = damage_val }
  v["side_plate_R"] <- { value = damage_val }
  v["side_plate_L"] <- { value = damage_val }
  v["front_plate"] <- { value = damage_val }
  v["groin_plate"] <- { value = damage_val }
  v["shoulder_R"] <- { value = damage_val }
  v["neck"] <- { value = damage_val }
}), "debug.armor.set_damage_all")

console.register_command(@(part) armorState.mutate(@(v) v.$rawdelete(part) ), "debug.armor.delete_part")
console.register_command(@() armorState.mutate(@(v) v.clear() ), "debug.armor.delete_all_parts")

return { armorState }
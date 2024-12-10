from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *

let is_in_clan = @() clan_get_my_clan_id() != "-1"

return {
  is_in_clan
}
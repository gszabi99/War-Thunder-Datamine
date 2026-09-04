from "blkGetters" import get_settings_blk
from "dagor.system" import get_arg_value_by_name

let setBlk = get_settings_blk()
let disableNetwork = setBlk?.debug.disableNetwork ?? get_arg_value_by_name("disableNetwork") ?? false

let shouldDisableMenu = (disableNetwork && (setBlk?.debug.disableMenu ?? false))
  || (setBlk?.benchmarkMode ?? false)
  || (setBlk?.viewReplay ?? false)

return {
  disableNetwork
  shouldDisableMenu
  isOfflineMenu = disableNetwork && !shouldDisableMenu
}

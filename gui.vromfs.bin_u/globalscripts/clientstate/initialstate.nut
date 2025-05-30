let { get_settings_blk } = require("blkGetters")
let { get_arg_value_by_name } = require("dagor.system")

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

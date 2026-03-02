let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")

return {
  type = CONTROL_TYPE.SHORTCUT

  checkAssign = true
  reqInMouseAim = null
  needShowInHelp = false

  isHidden = false
  shortcutId = -1
}

from "%scripts/controls/controlsConsts.nut" import CONTROL_TYPE

return freeze({
  type = CONTROL_TYPE.SHORTCUT

  checkAssign = true
  reqInMouseAim = null
  needShowInHelp = false

  isHidden = false
  shortcutId = -1
})

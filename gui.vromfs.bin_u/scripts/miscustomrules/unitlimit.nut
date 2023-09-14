//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { getRoleText, getUnitRoleIcon } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitClassTypeByExpClass } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")

::g_unit_limit_classes <- {
}

::g_unit_limit_classes.LimitBase <- class {
  name = ""
  respawnsLeft = 0
  distributed = ::RESPAWNS_UNLIMITED
  presetInfo = null
  nameLocId = null

  constructor(v_name, v_respawnsLeft, params = {}) {
    this.name = v_name
    this.respawnsLeft = v_respawnsLeft
    this.distributed = params?.distributed ?? ::RESPAWNS_UNLIMITED
    this.presetInfo = params?.presetInfo
    this.nameLocId = params?.nameLocId
  }

  function isSame(unitLimit) {
    return this.name == unitLimit.name && this.getclass() == unitLimit.getclass()
  }

  function getRespawnsLeftText() {
    return this.respawnsLeft == ::RESPAWNS_UNLIMITED ? loc("options/resp_unlimited") : this.respawnsLeft
  }

  function getText() {
    return this.name
  }
}

::g_unit_limit_classes.LimitByUnitName <- class extends ::g_unit_limit_classes.LimitBase {
  function getText() {
    let unitName = this.nameLocId != null ? loc(this.nameLocId) : getUnitName(this.name)
    local res = unitName + loc("ui/colon") + colorize("activeTextColor", this.getRespawnsLeftText())
    let weaponPresetIconsText = ::get_weapon_icons_text(
      this.name, getTblValue("weaponPresetId", this.presetInfo)
    )

    if (!u.isEmpty(weaponPresetIconsText))
      res += loc("ui/parentheses/space", {
        text = weaponPresetIconsText + getTblValue("teamUnitPresetAmount", this.presetInfo, 0)
      })

    if (this.distributed != null && this.distributed != ::RESPAWNS_UNLIMITED) {
      local text = this.distributed > 0 ? colorize("userlogColoredText", this.distributed) : this.distributed
      if (!u.isEmpty(weaponPresetIconsText))
        text += loc("ui/parentheses/space", {
          text = weaponPresetIconsText + getTblValue("userUnitPresetAmount", this.presetInfo, 0)
        })
      res += " + " + text
    }

    return res
  }
}

::g_unit_limit_classes.LimitByUnitRole <- class extends ::g_unit_limit_classes.LimitBase {
  function getText() {
    let fontIcon = colorize("activeTextColor", getUnitRoleIcon(this.name))
    return fontIcon + getRoleText(this.name) + loc("ui/colon") + colorize("activeTextColor", this.getRespawnsLeftText())
  }
}

::g_unit_limit_classes.LimitByUnitExpClass <- class extends ::g_unit_limit_classes.LimitBase {
  function getText() {
    let expClassType = getUnitClassTypeByExpClass(this.name)
    let fontIcon = colorize("activeTextColor", expClassType.getFontIcon())
    return fontIcon + expClassType.getName() + loc("ui/colon") + colorize("activeTextColor", this.getRespawnsLeftText())
  }
}

::g_unit_limit_classes.ActiveLimitByUnitExpClass <- class extends ::g_unit_limit_classes.LimitBase {
  function getText() {
    let expClassType = getUnitClassTypeByExpClass(this.name)
    let fontIcon = colorize("activeTextColor", expClassType.getFontIcon())
    local amountText = ""
    if (this.distributed == ::RESPAWNS_UNLIMITED || this.respawnsLeft == ::RESPAWNS_UNLIMITED)
      amountText = colorize("activeTextColor", this.getRespawnsLeftText())
    else {
      let color = (this.distributed < this.respawnsLeft) ? "userlogColoredText" : "activeTextColor"
      amountText = colorize(color, this.distributed) + "/" + this.getRespawnsLeftText()
    }
    return loc("multiplayer/active_at_once", { nameOrIcon = fontIcon }) + loc("ui/colon") + amountText
  }
}

::g_unit_limit_classes.LimitByUnitType <- class extends ::g_unit_limit_classes.LimitBase {
  function getText() {
    let unitType = unitTypes[this.name]
    let fontIcon = colorize("activeTextColor", unitType.fontIcon)
    return fontIcon + unitType.getArmyLocName() + loc("ui/colon") + colorize("activeTextColor", this.getRespawnsLeftText())
  }
}
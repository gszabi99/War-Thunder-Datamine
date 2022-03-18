let { getRoleText, getUnitRoleIcon } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitClassTypeByExpClass } = require("%scripts/unit/unitClassType.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")

::g_unit_limit_classes <- {
}

::g_unit_limit_classes.LimitBase <- class
{
  name = ""
  respawnsLeft = 0
  distributed = ::RESPAWNS_UNLIMITED
  presetInfo = null
  nameLocId = null

  constructor(_name, _respawnsLeft, params = {})
  {
    name = _name
    respawnsLeft = _respawnsLeft
    distributed = params?.distributed ?? ::RESPAWNS_UNLIMITED
    presetInfo = params?.presetInfo
    nameLocId = params?.nameLocId
  }

  function isSame(unitLimit)
  {
    return name == unitLimit.name && getclass() == unitLimit.getclass()
  }

  function getRespawnsLeftText()
  {
    return respawnsLeft == ::RESPAWNS_UNLIMITED ? ::loc("options/resp_unlimited") : respawnsLeft
  }

  function getText()
  {
    return name
  }
}

::g_unit_limit_classes.LimitByUnitName <- class extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    let unitName = nameLocId != null ? ::loc(nameLocId) : ::getUnitName(name)
    local res = unitName + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
    let weaponPresetIconsText = ::get_weapon_icons_text(
      name, ::getTblValue("weaponPresetId", presetInfo)
    )

    if (!::u.isEmpty(weaponPresetIconsText))
      res += ::loc("ui/parentheses/space", {
        text = weaponPresetIconsText + ::getTblValue("teamUnitPresetAmount", presetInfo, 0)
      })

    if (distributed != null && distributed != ::RESPAWNS_UNLIMITED)
    {
      local text = distributed > 0 ? ::colorize("userlogColoredText", distributed) : distributed
      if (!::u.isEmpty(weaponPresetIconsText))
        text += ::loc("ui/parentheses/space", {
          text = weaponPresetIconsText + ::getTblValue("userUnitPresetAmount", presetInfo, 0)
        })
      res += " + " + text
    }

    return res
  }
}

::g_unit_limit_classes.LimitByUnitRole <- class extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    let fontIcon = ::colorize("activeTextColor", getUnitRoleIcon(name))
    return fontIcon + getRoleText(name) + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
  }
}

::g_unit_limit_classes.LimitByUnitExpClass <- class extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    let expClassType = getUnitClassTypeByExpClass(name)
    let fontIcon = ::colorize("activeTextColor", expClassType.getFontIcon())
    return fontIcon + expClassType.getName() + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
  }
}

::g_unit_limit_classes.ActiveLimitByUnitExpClass <- class extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    let expClassType = getUnitClassTypeByExpClass(name)
    let fontIcon = ::colorize("activeTextColor", expClassType.getFontIcon())
    local amountText = ""
    if (distributed == ::RESPAWNS_UNLIMITED || respawnsLeft == ::RESPAWNS_UNLIMITED)
      amountText = ::colorize("activeTextColor", getRespawnsLeftText())
    else
    {
      let color = (distributed < respawnsLeft) ? "userlogColoredText" : "activeTextColor"
      amountText = ::colorize(color, distributed) + "/" + getRespawnsLeftText()
    }
    return ::loc("multiplayer/active_at_once", { nameOrIcon = fontIcon }) + ::loc("ui/colon") + amountText
  }
}

::g_unit_limit_classes.LimitByUnitType <- class extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    let unitType = unitTypes[name]
    let fontIcon = ::colorize("activeTextColor", unitType.fontIcon)
    return fontIcon + unitType.getArmyLocName() + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
  }
}
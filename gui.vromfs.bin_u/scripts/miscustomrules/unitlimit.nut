local { getRoleText, getUnitRoleIcon } = require("scripts/unit/unitInfoTexts.nut")
local { getUnitClassTypeByExpClass } = require("scripts/unit/unitClassType.nut")

::g_unit_limit_classes <- {
}

class ::g_unit_limit_classes.LimitBase
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

class ::g_unit_limit_classes.LimitByUnitName extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local unitName = nameLocId != null ? ::loc(nameLocId) : ::getUnitName(name)
    local res = unitName + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
    local weaponPresetIconsText = ::get_weapon_icons_text(
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

class ::g_unit_limit_classes.LimitByUnitRole extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local fontIcon = ::colorize("activeTextColor", getUnitRoleIcon(name))
    return fontIcon + getRoleText(name) + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
  }
}

class ::g_unit_limit_classes.LimitByUnitExpClass extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local expClassType = getUnitClassTypeByExpClass(name)
    local fontIcon = ::colorize("activeTextColor", expClassType.getFontIcon())
    return fontIcon + expClassType.getName() + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
  }
}

class ::g_unit_limit_classes.ActiveLimitByUnitExpClass extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local expClassType = getUnitClassTypeByExpClass(name)
    local fontIcon = ::colorize("activeTextColor", expClassType.getFontIcon())
    local amountText = ""
    if (distributed == ::RESPAWNS_UNLIMITED || respawnsLeft == ::RESPAWNS_UNLIMITED)
      amountText = ::colorize("activeTextColor", getRespawnsLeftText())
    else
    {
      local color = (distributed < respawnsLeft) ? "userlogColoredText" : "activeTextColor"
      amountText = ::colorize(color, distributed) + "/" + getRespawnsLeftText()
    }
    return ::loc("multiplayer/active_at_once", { nameOrIcon = fontIcon }) + ::loc("ui/colon") + amountText
  }
}

class ::g_unit_limit_classes.LimitByUnitType extends ::g_unit_limit_classes.LimitBase
{
  function getText()
  {
    local unitType = ::g_unit_type[name]
    local fontIcon = ::colorize("activeTextColor", unitType.fontIcon)
    return fontIcon + unitType.getArmyLocName() + ::loc("ui/colon") + ::colorize("activeTextColor", getRespawnsLeftText())
  }
}
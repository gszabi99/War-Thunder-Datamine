class ::WwArmyOwner
{
  side         = null
  country      = null
  armyGroupIdx = null

  constructor(blk = null)
  {
    clear()
    update(blk)
  }

  function update(blk)
  {
    if (!blk)
      return

    side         = ::ww_side_name_to_val(::getTblValue("side", blk, ""))
    country      = ::getTblValue("country",      blk, "")
    armyGroupIdx = ::getTblValue("armyGroupIdx", blk, -1)
  }

  function clear()
  {
    side         = ::SIDE_NONE
    country      = ""
    armyGroupIdx = -1
  }

  function isValid()
  {
    return side != ::SIDE_NONE && country != "" && armyGroupIdx >= 0
  }

  function getCountry() { return country }

  function getArmyGroupIdx() { return armyGroupIdx }

  function getSide() { return side }
}

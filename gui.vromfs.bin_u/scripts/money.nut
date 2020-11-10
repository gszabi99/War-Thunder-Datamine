/*
  universal money format
  monye =
  {
    wp   = 0;
    gold = 0;
    frp  = 0; - free research points
    rp   = 0; - reserach points
    sap  = 0; - sqadron activity points
    mType = money_type.none; - cost or balance (defined in enum)
  }

  API

  EXPANDING
    When you add new noteble values, add their names ton __data_fields array.
    This need for optimize comparison.
*/

global enum money_type {
  none,
  cost,
  balance
}

enum money_color {
  NEUTRAL  = 0,
  BAD      = 1,
  GOOD     = 2
}

::zero_money <- null //instance of Money, which equals zero.

::Money <- class {
  wp   = 0
  gold = 0
  frp  = 0
  rp   = 0
  sap  = 0
  mType = money_type.none

  //privat
  __data_fields = ["gold", "wp", "frp", "rp", "sap"]

  constructor(type_in = money_type.cost, wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0, sap_in = 0)
  {
    wp   = wp_in || 0
    gold = gold_in || 0
    frp  = frp_in || 0
    rp   = rp_in || 0
    sap  = sap_in || 0
    mType = type_in
  }
}

Money.setFrp <- function setFrp(value)
{
  frp = value
  return this
}

Money.setRp <- function setRp(value)
{
  rp = value
  return this
}

Money.setSap <- function setSap(value)
{
  sap = value
  return this
}

Money.setFromTbl <- function setFromTbl(tbl = null)
{
  wp = tbl?.wp ?? 0
  gold = tbl?.gold ?? 0
  rp = tbl?.rp ?? 0
  frp = tbl?.exp ?? tbl?.frp ?? 0
  sap = tbl?.sap ?? 0
  return this
}

Money.isZero <- function isZero()
{
  return !wp && !gold && !frp && !rp && !sap
}

//Math methods
Money._add <- function _add(that)
{
  local newClass = this.getclass()
  return newClass(this.wp + that.wp,
                  this.gold + that.gold,
                  this.frp + that.frp,
                  this.rp + that.rp,
                  this.sap + that.sap)
}

Money._sub <- function _sub(that)
{
  local newClass = this.getclass()
  return newClass(this.wp - that.wp,
                  this.gold - that.gold,
                  this.frp - that.frp,
                  this.rp - that.rp,
                  this.sap - that.sap)
}

Money.multiply <- function multiply(multiplier)
{
  wp   = (multiplier * wp   + 0.5).tointeger()
  gold = (multiplier * gold + 0.5).tointeger()
  frp  = (multiplier * frp  + 0.5).tointeger()
  rp   = (multiplier * rp   + 0.5).tointeger()
  sap  = (multiplier * sap   + 0.5).tointeger()
  return this
}

Money.__impl_cost_to_balance_cmp <- function __impl_cost_to_balance_cmp(balance, cost)
{
  local res = 0
  foreach (key in __data_fields)
  {
    if (cost[key] <= 0)
      continue
    if (balance[key] < cost[key])
      return -1
    if (balance[key] > cost[key])
      res = 1
  }
  return res
}

Money._cmp <- function _cmp(that)
{
  if (this.mType == money_type.balance && that.mType == money_type.cost)
    return __impl_cost_to_balance_cmp(this, that)

  if (this.mType == money_type.cost && that.mType == money_type.balance)
    return __impl_cost_to_balance_cmp(that, this) * -1

  foreach(key in __data_fields)
    if (this[key] != that[key])
      return this[key] > that[key] ? 1 : -1
  return 0
}

//String methods
Money._tostring <- function _tostring()
{
  return __impl_get_text()
}

Money.toStringWithParams <- function toStringWithParams(params)
{
  return __impl_get_text(params)
}

Money.getTextAccordingToBalance <- function getTextAccordingToBalance()
{
  return __impl_get_text({needCheckBalance = true})
}

Money.getUncoloredText <- function getUncoloredText()
{
  return __impl_get_text({isColored = false})
}

Money.getUncoloredWpText <- function getUncoloredWpText()
{
  return this.__impl_get_wp_text(false)
}

Money.getColoredWpText <- function getColoredWpText()
{
  return this.__impl_get_wp_text(true)
}

Money.getGoldText <- function getGoldText(colored, checkBalance)
{
  return this.__impl_get_gold_text(colored, checkBalance)
}

Money.__check_color <- function __check_color(value, colorIdx)
{
  if (colorIdx == money_color.BAD)
    return "<color=@badTextColor>" + value + "</color>"
  if (colorIdx == money_color.GOOD)
    return "<color=@goodTextColor>" + value + "</color>"
  return value
}

Money.__get_wp_color_id <- function __get_wp_color_id()   { return money_color.NEUTRAL }
Money.__get_gold_color_id <- function __get_gold_color_id() { return money_color.NEUTRAL }
Money.__get_frp_color_id <- function __get_frp_color_id()  { return money_color.NEUTRAL }
Money.__get_rp_color_id <- function __get_rp_color_id()   { return money_color.NEUTRAL }
Money.__get_sap_color_id <- function __get_sap_color_id()   { return money_color.NEUTRAL }

Money.__impl_get_wp_text <- function __impl_get_wp_text(colored = true, checkBalance = false, needIcon = true)
{
  local color_id = (checkBalance && colored)? __get_wp_color_id() : money_color.NEUTRAL
  local sign = needIcon? ::loc(colored ? "warpoints/short/colored" : "warpoints/short") : ""
  return __check_color(::g_language.decimalFormat(wp), color_id) + sign
}

Money.__impl_get_gold_text <- function __impl_get_gold_text(colored = true, checkBalance = false, needIcon = true)
{
  local color_id = (checkBalance && colored)? __get_gold_color_id() : money_color.NEUTRAL
  local sign = needIcon? ::loc(colored ? "gold/short/colored" : "gold/short") : ""
  return __check_color(::g_language.decimalFormat(gold), color_id) + sign
}

Money.__impl_get_frp_text <- function __impl_get_frp_text(colored = true, checkBalance = false, needIcon = true)
{
  local color_id = (checkBalance && colored)? __get_frp_color_id() : money_color.NEUTRAL
  local sign = needIcon? ::loc(colored ? "currency/freeResearchPoints/sign/colored" : "currency/freeResearchPoints/sign") : ""
  return __check_color(::g_language.decimalFormat(frp), color_id) + sign
}

Money.__impl_get_rp_text <- function __impl_get_rp_text(colored = true, checkBalance = false, needIcon = true)
{
  local color_id = (checkBalance && colored)? __get_rp_color_id() : money_color.NEUTRAL
  local sign = needIcon? ::loc(colored ? "currency/researchPoints/sign/colored" : "currency/researchPoints/sign") : ""
  return __check_color(::g_language.decimalFormat(rp), color_id) + sign
}

Money.__impl_get_sap_text <- function __impl_get_sap_text(colored = true, checkBalance = false, needIcon = true)
{
  local color_id = (checkBalance && colored)? __get_sap_color_id() : money_color.NEUTRAL
  local sign = needIcon? ::loc(colored ? "currency/squadronActivity/colored" : "currency/squadronActivity") : ""
  return __check_color(::g_language.decimalFormat(sap), color_id) + sign
}

Money.__impl_get_text <- function __impl_get_text(params = null)
{
  local text = ""
  local isColored = params?.isColored ?? true
  local needCheckBalance = params?.needCheckBalance ?? false
  local needIcon = params?.needIcon ?? true

  if (gold != 0 || params?.isGoldAlwaysShown)
    text += __impl_get_gold_text(isColored, needCheckBalance, needIcon)
  if (wp != 0 || params?.isWpAlwaysShown)
    text += ((text == "") ? "" : ", ") + __impl_get_wp_text(isColored, needCheckBalance, needIcon)
  if (frp != 0 || params?.isFrpAlwaysShown)
    text += ((text == "") ? "" : ", ") + __impl_get_frp_text(isColored, needCheckBalance, needIcon)
  if (rp != 0 || params?.isRpAlwaysShown)
    text += ((text == "") ? "" : ", ") + __impl_get_rp_text(isColored, needCheckBalance, needIcon)
  if (sap != 0 || params?.isSapAlwaysShown)
    text += ((text == "") ? "" : ", ") + __impl_get_sap_text(isColored, needCheckBalance, needIcon)
  return text
}

::Balance <- class extends Money
{
  mType = money_type.balance

  constructor(wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0, sap_in = 0)
  {
    base.constructor(money_type.balance, wp_in, gold_in, frp_in, rp_in, sap_in)
  }

  function __get_color_id_by_value(value)
  {
    return (value < 0) ? money_color.BAD : (value > 0) ? money_color.GOOD : money_color.NEUTRAL
  }

  function __get_wp_color_id()   { return __get_color_id_by_value(wp) }
  function __get_gold_color_id() { return __get_color_id_by_value(gold) }
  function __get_frp_color_id()  { return __get_color_id_by_value(frp) }
  function __get_rp_color_id()   { return __get_color_id_by_value(rp) }
  function __get_sap_color_id()   { return __get_color_id_by_value(sap) }
}

::Cost <- class extends Money
{
  mType = money_type.cost

  constructor(wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0, sap_in = 0)
  {
    base.constructor(money_type.cost, wp_in, gold_in, frp_in, rp_in, sap_in)
  }

  function __get_wp_color_id()
  {
    return ::get_cur_rank_info().wp >= wp ? money_color.NEUTRAL : money_color.BAD
  }

  function __get_gold_color_id()
  {
    return ::get_cur_rank_info().gold >= gold ? money_color.NEUTRAL : money_color.BAD
  }

  function __get_frp_color_id()
  {
    return ::get_cur_rank_info().exp >= frp ? money_color.NEUTRAL : money_color.BAD
  }
}

::zero_money = ::Money(money_type.none)

::u.registerClass("Money", ::Money, @(m1, m2) m1 <= m2 && m1 >= m2, @(m) m.isZero())
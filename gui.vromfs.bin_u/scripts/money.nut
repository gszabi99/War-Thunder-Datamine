from "%scripts/dagui_natives.nut" import get_cur_rank_info
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let { decimalFormat } = require("%scripts/langUtils/textFormat.nut")




















let money_type = {
  none = 0
  cost = 1
  balance = 2
}

enum money_color {
  NEUTRAL  = 0,
  BAD      = 1,
  GOOD     = 2
}

let __data_fields = ["gold", "wp", "frp", "rp", "sap"]

function __impl_cost_to_balance_cmp(balance, cost) {
  local res = 0
  foreach (key in __data_fields) {
    if (cost[key] <= 0)
      continue
    if (balance[key] < cost[key])
      return -1
    if (balance[key] > cost[key])
      res = 1
  }
  return res
}

function __check_color(value, colorIdx) {
  if (colorIdx == money_color.BAD)
    return $"<color=@badTextColor>{value}</color>"
  if (colorIdx == money_color.GOOD)
    return $"<color=@goodTextColor>{value}</color>"
  return value
}

function __get_color_id_by_value(value) {
  return (value < 0) ? money_color.BAD : (value > 0) ? money_color.GOOD : money_color.NEUTRAL
}

let Money = class {
  wp   = 0
  gold = 0
  frp  = 0
  rp   = 0
  sap  = 0
  mType = money_type.none

  constructor(type_in = money_type.cost, wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0, sap_in = 0) {
    this.wp   = wp_in ?? 0
    this.gold = gold_in ?? 0
    this.frp  = frp_in ?? 0
    this.rp   = rp_in ?? 0
    this.sap  = sap_in ?? 0
    this.mType = type_in
  }

  function setFrp(value) {
    this.frp = value
    return this
  }

  function setRp(value) {
    this.rp = value
    return this
  }

  function setSap(value) {
    this.sap = value
    return this
  }

  function setGold(value) {
    this.gold = value
    return this
  }

  function setFromTbl(tbl = null) {
    this.wp = tbl?.wp ?? 0
    this.gold = tbl?.gold ?? 0
    this.rp = tbl?.rp ?? 0
    this.frp = tbl?.exp ?? tbl?.frp ?? 0
    this.sap = tbl?.sap ?? 0
    return this
  }

  function isZero() {
    return !this.wp && !this.gold && !this.frp && !this.rp && !this.sap
  }

  
  function _add(that) {
    let newClass = this.getclass()
    return newClass(this.wp + that.wp,
                    this.gold + that.gold,
                    this.frp + that.frp,
                    this.rp + that.rp,
                    this.sap + that.sap)
  }

  function _sub(that) {
    let newClass = this.getclass()
    return newClass(this.wp - that.wp,
                    this.gold - that.gold,
                    this.frp - that.frp,
                    this.rp - that.rp,
                    this.sap - that.sap)
  }

  function multiply(multiplier) {
    this.wp   = (multiplier * this.wp   + 0.5).tointeger()
    this.gold = (multiplier * this.gold + 0.5).tointeger()
    this.frp  = (multiplier * this.frp  + 0.5).tointeger()
    this.rp   = (multiplier * this.rp   + 0.5).tointeger()
    this.sap  = (multiplier * this.sap   + 0.5).tointeger()
    return this
  }


  function _cmp(that) {
    if (this.mType == money_type.balance && that.mType == money_type.cost)
      return __impl_cost_to_balance_cmp(this, that)

    if (this.mType == money_type.cost && that.mType == money_type.balance)
      return __impl_cost_to_balance_cmp(that, this) * -1

    foreach (key in __data_fields)
      if (this[key] != that[key])
        return this[key] > that[key] ? 1 : -1
    return 0
  }

  
  function _tostring() {
    return this.__impl_get_text()
  }

  function toStringWithParams(params) {
    return this.__impl_get_text(params)
  }

  function toPlainText(params = null) {
    return this.__impl_get_plain_text(params)
  }

  function getTextAccordingToBalance() {
    return this.__impl_get_text({ needCheckBalance = true })
  }

  function getUncoloredText() {
    return this.__impl_get_text({ isColored = false })
  }

  function getUncoloredWpText() {
    return this.__impl_get_wp_text(false)
  }

  function getColoredWpText() {
    return this.__impl_get_wp_text(true)
  }

  function getGoldText(colored, checkBalance) {
    return this.__impl_get_gold_text(colored, checkBalance)
  }

  function __get_wp_color_id()   { return money_color.NEUTRAL }
  function __get_gold_color_id() { return money_color.NEUTRAL }
  function __get_frp_color_id()  { return money_color.NEUTRAL }
  function __get_rp_color_id()   { return money_color.NEUTRAL }
  function __get_sap_color_id()   { return money_color.NEUTRAL }

  function __impl_get_wp_text(colored = true, checkBalance = false, needIcon = true) {
    let color_id = (checkBalance && colored) ? this.__get_wp_color_id() : money_color.NEUTRAL
    let sign = needIcon ? loc(colored ? "warpoints/short/colored" : "warpoints/short") : ""
    return "".concat(__check_color(decimalFormat(this.wp), color_id), sign)
  }

  function __impl_get_gold_text(colored = true, checkBalance = false, needIcon = true) {
    let color_id = (checkBalance && colored) ? this.__get_gold_color_id() : money_color.NEUTRAL
    let sign = needIcon ? loc(colored ? "gold/short/colored" : "gold/short") : ""
    return "".concat(__check_color(decimalFormat(this.gold), color_id), sign)
  }

  function __impl_get_frp_text(colored = true, checkBalance = false, needIcon = true) {
    let color_id = (checkBalance && colored) ? this.__get_frp_color_id() : money_color.NEUTRAL
    let sign = needIcon ? loc(colored ? "currency/freeResearchPoints/sign/colored" : "currency/freeResearchPoints/sign") : ""
    return "".concat(__check_color(decimalFormat(this.frp), color_id), sign)
  }

  function __impl_get_rp_text(colored = true, checkBalance = false, needIcon = true) {
    let color_id = (checkBalance && colored) ? this.__get_rp_color_id() : money_color.NEUTRAL
    let sign = needIcon ? loc(colored ? "currency/researchPoints/sign/colored" : "currency/researchPoints/sign") : ""
    return "".concat(__check_color(decimalFormat(this.rp), color_id), sign)
  }

  function __impl_get_sap_text(colored = true, checkBalance = false, needIcon = true) {
    let color_id = (checkBalance && colored) ? this.__get_sap_color_id() : money_color.NEUTRAL
    let sign = needIcon ? loc(colored ? "currency/squadronActivity/colored" : "currency/squadronActivity") : ""
    return "".concat(__check_color(decimalFormat(this.sap), color_id), sign)
  }

  function __impl_get_text(params = null) {
    local text = ""
    let isColored = params?.isColored ?? true
    let needCheckBalance = params?.needCheckBalance ?? false
    let needIcon = params?.needIcon ?? true
    if (this.gold != 0 || params?.isGoldAlwaysShown)
      text = "".concat(text, this.__impl_get_gold_text(isColored, needCheckBalance, needIcon))
    if (this.wp != 0 || params?.isWpAlwaysShown)
      text = ((text == "") ? "" : ", ").concat(text, this.__impl_get_wp_text(isColored, needCheckBalance, needIcon))
    if (this.frp != 0 || params?.isFrpAlwaysShown)
      text = ((text == "") ? "" : ", ").concat(text, this.__impl_get_frp_text(isColored, needCheckBalance, needIcon))
    if (this.rp != 0 || params?.isRpAlwaysShown)
      text = ((text == "") ? "" : ", ").concat(text, this.__impl_get_rp_text(isColored, needCheckBalance, needIcon))
    if (this.sap != 0 || params?.isSapAlwaysShown)
      text = ((text == "") ? "" : ", ").concat(text, this.__impl_get_sap_text(isColored, needCheckBalance, needIcon))
    return text
  }

  function __impl_get_plain_text(params = null) {
    local text = ""
    if (this.gold != 0 || params?.isGoldAlwaysShown)
      text = "".concat(text, " ".concat(this.gold, loc("money/goldText")))
    if (this.wp != 0 || params?.isWpAlwaysShown)
      text = ((text == "") ? "" : ", ").concat(text, " ".concat(this.wp, loc("money/wpText")))
    if (this.frp != 0 || params?.isFrpAlwaysShown)
      text = ((text == "") ? "" : ", ").concat(text, " ".concat(this.frp, loc("money/frpText")))
    if (this.rp != 0 || params?.isRpAlwaysShown)
      text = ((text == "") ? "" : ", ").concat(text, " ".concat(this.rp, loc("money/rpText")))
    if (this.sap != 0 || params?.isSapAlwaysShown)
      text = ((text == "") ? "" : ", ").concat(text, " ".concat(this.sap, loc("money/sapText")))
    return text
  }
}

let Balance = class (Money) {
  mType = money_type.balance

  constructor(wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0, sap_in = 0) {
    base.constructor(money_type.balance, wp_in, gold_in, frp_in, rp_in, sap_in)
  }

  function __get_wp_color_id()   { return __get_color_id_by_value(this.wp) }
  function __get_gold_color_id() { return __get_color_id_by_value(this.gold) }
  function __get_frp_color_id()  { return __get_color_id_by_value(this.frp) }
  function __get_rp_color_id()   { return __get_color_id_by_value(this.rp) }
  function __get_sap_color_id()   { return __get_color_id_by_value(this.sap) }
}

let Cost = class (Money) {
  mType = money_type.cost

  constructor(wp_in = 0, gold_in = 0, frp_in = 0, rp_in = 0, sap_in = 0) {
    base.constructor(money_type.cost, wp_in, gold_in, frp_in, rp_in, sap_in)
  }

  function __get_wp_color_id() {
    return get_cur_rank_info().wp >= this.wp ? money_color.NEUTRAL : money_color.BAD
  }

  function __get_gold_color_id() {
    return get_cur_rank_info().gold >= this.gold ? money_color.NEUTRAL : money_color.BAD
  }

  function __get_frp_color_id() {
    return get_cur_rank_info().exp >= this.frp ? money_color.NEUTRAL : money_color.BAD
  }
}

let zero_money = Money(money_type.none)

u.registerClass("Money", Money, @(m1, m2) m1 <= m2 && m1 >= m2, @(m) m.isZero())

return {
  money_type
  Money
  Balance
  Cost
  zero_money
}

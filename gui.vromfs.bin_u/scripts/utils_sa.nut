from "%scripts/dagui_library.nut" import *

let { format } = require("string")

function getAmountAndMaxAmountText(amount, maxAmount, showMaxAmount = false) {
  let amountText = []
  if (maxAmount > 1 || showMaxAmount) {
    amountText.append(amount)
    if (showMaxAmount && maxAmount > 1)
      amountText.append("/", maxAmount)
  }
  return "".join(amountText)
}


function colorTextByValues(text, val1, val2, useNeutral = true, useGood = true) {
  local color = ""
  if (val1 >= val2) {
    if (val1 == val2 && useNeutral)
      color = "activeTextColor"
    else if (useGood)
      color = "goodTextColor"
  }
  else
    color = "badTextColor"

  if (color == "")
    return text

  return format("<color=@%s>%s</color>", color, text)
}


function get_flush_exp_text(exp_value) {
  if (exp_value == null || exp_value < 0)
    return ""
  let rpPriceText = "".concat(exp_value, loc("currency/researchPoints/sign/colored"))
  let coloredPriceText = colorTextByValues(rpPriceText, exp_value, 0)
  return format(loc("mainmenu/availableFreeExpForNewResearch"), coloredPriceText)
}

return {
  getAmountAndMaxAmountText
  colorTextByValues
  get_flush_exp_text
}
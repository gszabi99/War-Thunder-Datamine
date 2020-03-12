local enums = ::require("sqStdlibs/helpers/enums.nut")
::g_order_award_mode <- {
  types = []
}

g_order_award_mode._addMultTextPart <- function _addMultTextPart(currentText, awardValue, signLocId)
{
  if (awardValue > 0)
  {
    if (currentText.len() > 0)
      currentText += " "
    currentText += ::colorize("activeTextColor", "x" + awardValue) + ::loc(signLocId)
  }
  return currentText
}

g_order_award_mode._getAwardTextByDifficultyCost <- function _getAwardTextByDifficultyCost(difficulty, orderItem)
{
  local cost = ::Cost()
  cost.wp = orderItem.awardWpByDifficulty[difficulty]
  cost.gold = orderItem.awardGoldByDifficulty[difficulty]
  cost.frp = orderItem.awardXpByDifficulty[difficulty]
  return cost.getUncoloredText()
}

g_order_award_mode._getAwardTextByDifficultyMultipliers <- function _getAwardTextByDifficultyMultipliers(difficulty, orderItem)
{
  local text = ""
  text = ::g_order_award_mode._addMultTextPart(text, orderItem.awardWpByDifficulty[difficulty],
    "warpoints/short/colored")
  text = ::g_order_award_mode._addMultTextPart(text, orderItem.awardXpByDifficulty[difficulty],
    "currency/freeResearchPoints/sign/colored")
  text = ::g_order_award_mode._addMultTextPart(text, orderItem.awardGoldByDifficulty[difficulty],
    "gold/short/colored")
  return text
}

::g_order_award_mode.template <- {
  getAwardTextByDifficulty = function(difficulty, orderItem) { return "" }
}

enums.addTypesByGlobalName("g_order_award_mode", {
  RAW = {
    name = "awardModeRaw"
    getAwardTextByDifficulty = ::g_order_award_mode._getAwardTextByDifficultyCost
  }

  MULTIPLY_PROGRESS = {
    name = "awardModeMulProgress"
    getAwardTextByDifficulty = ::g_order_award_mode._getAwardTextByDifficultyCost
  }

  MULTIPLY_AWARD = {
    name = "awardModeMulAward"
    getAwardTextByDifficulty = ::g_order_award_mode._getAwardTextByDifficultyMultipliers
  }

  UNKNOWN = {
    name = "awardModeUnknown"
  }
})

g_order_award_mode.getAwardModeByOrderParams <- function getAwardModeByOrderParams(orderParams)
{
  foreach (awardMode in ::g_order_award_mode.types)
    if (::u.isTable(awardMode) && ::getTblValue(awardMode.name, orderParams, false))
      return awardMode
  return UNKNOWN
}

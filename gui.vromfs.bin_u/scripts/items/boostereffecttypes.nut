from "%scripts/dagui_library.nut" import *

let { Cost } = require("%scripts/money.nut")

let boosterEffectType = {
  RP = {
    name = "xpRate"
    currencyMark = loc("currency/researchPoints/sign/colored")
    currencyText = "money/rpText"
    abbreviation = "xp"
    checkBooster = @(booster) this.getValue(booster) != 0
    getValue = @(booster) booster?.xpRate ?? 0
    getText = function(value, colored = false, showEmpty = true) {
      if (value == 0 && !showEmpty)
        return ""
      return Cost().setRp(value).toStringWithParams({ isColored = colored })
    }
    getCurrencyMark = @(plainText = false) plainText ? loc(this.currencyText) : this.currencyMark
  }
  WP = {
    name = "wpRate"
    currencyMark = loc("warpoints/short/colored")
    currencyText = "money/wpText"
    abbreviation = "wp"
    checkBooster = @(booster) this.getValue(booster) != 0
    getValue = @(booster) booster?.wpRate ?? 0
    getText = function(value, colored = false, showEmpty = true) {
      if (value == 0 && !showEmpty)
        return ""
      return Cost(value).toStringWithParams({ isWpAlwaysShown = true, isColored = colored })
    }
    getCurrencyMark = @(plainText = false) plainText ? loc(this.currencyText) : this.currencyMark
  }
}

return {
  boosterEffectType
}

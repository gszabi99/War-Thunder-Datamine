from "%scripts/dagui_library.nut" import *

let sourcesConfig = {
  noBonus = {
    textColor = "@commonTextColor"
  }
  premAcc = {
    textColor = "@chapterUnlockedColor"
    hasPlus = true
    icon = "#ui/gameuiskin#item_type_premium.svg"
  }
  premMod = {
    textColor = "@chapterUnlockedColor"
    hasPlus = true
    icon = "#ui/gameuiskin#item_type_talisman.svg"
    iconWidth = "0.95@sIco"
  }
  booster = {
    textColor = "@linkTextColor"
    hasPlus = true
    icon = "#ui/gameuiskin#item_type_boosters.svg"
  }
  prevUnitEfficiency = {
    textColor = "@userlogColoredText"
    hasPlus = true
  }
  skillBonus = {
    textColor = "@chapterUnlockedColor"
    hasPlus = true
    iconWidth = "0.95@sIco"
  }
}

function getRewardSources(values, params = {}) {
  let { noBonus, premAcc, booster, premMod = 0, skillBonus = 0, skillBonusLevel = 0, currencySign = ""} = values
  let { isPlainText = false, regularFont = false, currencyImg = null } = params
  let delimiter = isPlainText ? " " : ""

  if (premAcc + booster + premMod + skillBonus == 0)
    return [
      {
        text = $"{noBonus}{delimiter}{currencySign}"
        textColor = "@activeTextColor"
        regularFont
      }
    ]

  return [
    {
      text = noBonus
      regularFont
    }
    {
      text = premAcc
      prefix = "money/premiumText"
      regularFont
    }.__update(sourcesConfig.premAcc)
    {
      text = booster
      prefix = "item/rateBooster"
      regularFont
    }.__update(sourcesConfig.booster)
    {
      text = premMod
      prefix = "multiAward/type/premExpMul"
      regularFont
    }.__update(sourcesConfig.premMod)
    {
      text = skillBonus
      prefix = "expSkillBonus"
      icon = $"#ui/gameuiskin#skill_bonus_level_{skillBonusLevel}.svg"
      regularFont
    }.__update(sourcesConfig.skillBonus)
    {
      text = $"{delimiter}={delimiter}{noBonus + premAcc + booster + premMod + skillBonus}{delimiter}{currencySign}"
      textColor = "@activeTextColor"
      regularFont
      currencyImg
      currencyImgSize = regularFont ? "1@sIco, 1@sIco" : null
    }
  ].filter(@(c) !!c.text)
}

return {
  sourcesConfig
  NO_BONUS             = sourcesConfig.noBonus
  PREM_ACC             = sourcesConfig.premAcc
  PREM_MOD             = sourcesConfig.premMod
  BOOSTER              = sourcesConfig.booster
  PREV_UNIT_EFFICIENCY = sourcesConfig.prevUnitEfficiency
  SKILL_BONUS          = sourcesConfig.skillBonus
  getRewardSources
}

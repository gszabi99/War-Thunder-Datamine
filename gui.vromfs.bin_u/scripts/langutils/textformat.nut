from "%sqstd/textFormatByLang.nut" import getDecimalFormat, getShortTextFromNum

let { langWithCommaDelimiters, getCurLangShortName, currentLanguageW } = require("%scripts/langUtils/language.nut")

let curLangFunctions = {}
function updateByLang(lang) {
  curLangFunctions.decimalFormat <- getDecimalFormat(lang)
  curLangFunctions.shortTextFromNum <- getShortTextFromNum(lang)
}
updateByLang(currentLanguageW.get())
currentLanguageW.subscribe(updateByLang)




function floatToText(value, digits = 2) {
  let curLoc = getCurLangShortName()
  let delimiter = langWithCommaDelimiters.contains(curLoc) ? "," : "."

  const startPosition = 2 
  let valueDecimals = (value % 1).tostring().slice(startPosition, startPosition + digits)
  return "".concat(value.tointeger(), delimiter, valueDecimals)
}

return {
  decimalFormat = @(num) curLangFunctions.decimalFormat(num)
  shortTextFromNum = @(num) curLangFunctions.shortTextFromNum(num)
  floatToText
}
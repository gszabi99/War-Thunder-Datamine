let { currentLanguageW } = require("language.nut")
let { getDecimalFormat, getShortTextFromNum } = require("%sqstd/textFormatByLang.nut")

let curLangFunctions = {}
function updateByLang(lang) {
  curLangFunctions.decimalFormat <- getDecimalFormat(lang)
  curLangFunctions.shortTextFromNum <- getShortTextFromNum(lang)
}
updateByLang(currentLanguageW.value)
currentLanguageW.subscribe(updateByLang)

return {
  decimalFormat = @(num) curLangFunctions.decimalFormat(num)
  shortTextFromNum = @(num) curLangFunctions.shortTextFromNum(num)
}
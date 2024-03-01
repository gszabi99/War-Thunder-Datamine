let { processHypenationsCN, processHypenationsJP } = require("dagor.localize")
let { getLocalLanguage } = require("language")

return function wordHyphenation(text, language = null) {
  let lang = (language ?? getLocalLanguage()).tolower()
  if (lang.contains("chinese"))
    return processHypenationsCN(text)
  if (lang.contains("japanese"))
    return processHypenationsJP(text)
  return text
}

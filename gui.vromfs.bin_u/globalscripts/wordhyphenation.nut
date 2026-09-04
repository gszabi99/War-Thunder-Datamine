from "dagor.localize" import processHypenationsCN, processHypenationsJP
from "language" import getLocalLanguage

return function wordHyphenation(text, language = null) {
  let lang = (language ?? getLocalLanguage()).tolower()
  if (lang.contains("chinese"))
    return processHypenationsCN(text)
  if (lang.contains("japanese"))
    return processHypenationsJP(text)
  return text
}

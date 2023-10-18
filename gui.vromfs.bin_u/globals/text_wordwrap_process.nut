let { getCurrentLanguage,  processHypenationsCN = @(text) text, processHypenationsJP = @(text) text } = require("dagor.localize")

function text_wordwrap_process(text){
  let lang = getCurrentLanguage().tolower()
  if (lang.contains("chinese"))
    return processHypenationsCN(text)
  else if (lang.contains("japanese"))
    return processHypenationsJP(text)
  else
    return text
}
return {text_wordwrap_process}
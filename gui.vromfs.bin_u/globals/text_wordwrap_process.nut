let { processHypenationsCN = @(text) text, processHypenationsJP = @(text) text } = require("dagor.localize")
let { getLocalLanguage } = require("language")

function text_wordwrap_process(text){
  let lang = getLocalLanguage().tolower()
  if (lang.contains("chinese"))
    return processHypenationsCN(text)
  else if (lang.contains("japanese"))
    return processHypenationsJP(text)
  else
    return text
}
return {text_wordwrap_process}
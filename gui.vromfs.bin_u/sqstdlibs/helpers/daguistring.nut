from "%sqstd/string.nut" import clearBorderSymbols

function [pure] stripTags(str:string): string {
  if (!str.len())
    return ""
  return str.replace("~", "~~").replace("\"", "~\"").replace("\r", "~r").replace("\n", "~n").replace("\'", "~\'")
}

function [pure] clearBorderSymbolsMultiline(str:string) {
  return clearBorderSymbols(str, [" ", 0x0A.tochar(), 0x0D.tochar()])
}

return freeze({
  stripTags
  clearBorderSymbolsMultiline
})

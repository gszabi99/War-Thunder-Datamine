from "%globalScripts/logs.nut" import *
let utf8 = require("utf8")

let whitespaceCharsAllowed = [ "\u0020" "\u00A0" ] 




let whitespaceCharsForbidden = "\u0009\u000A\u000B\u000C\u000D\u001C\u0085\u00AD\u034F\u061C\u070F\u115F\u1160\u1680\u17B4\u17B5\u180B\u180C\u180D\u180E\u180F\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u200B\u200C\u200D\u200E\u200F\u2028\u2029\u202A\u202B\u202C\u202D\u202E\u202F\u205F\u2060\u2061\u2062\u2063\u2064\u2065\u2066\u2067\u2068\u2069\u206A\u206B\u206C\u206D\u206E\u206F\u2800\u3000\u3164\uFE00\uFE01\uFE02\uFE03\uFE04\uFE05\uFE06\uFE07\uFE08\uFE09\uFE0A\uFE0B\uFE0C\uFE0D\uFE0E\uFE0F\uFEFF\uFFA0\uFFF0\uFFF1\uFFF2\uFFF3\uFFF4\uFFF5\uFFF6\uFFF7\uFFF8"




let barelyVisibleCharRanges = [
  [ "\u02B0", "\u036F" ],
  [ "\u064B", "\u0660" ],
  [ "\u0674", "\u0674" ],
  [ "\u0E38", "\u0E3A" ],
  [ "\u0E47", "\u0E4E" ],
]

function getUnicodeCharsArray(str) {
  let res = []
  let utfStr = utf8(str)
  for (local i = 0; i < utfStr.charCount(); i++) {
    let char = utfStr.slice(i, i + 1)
    res.append(char)
  }
  return res
}

function isClearlyVisibleChar(c) {
  if (c <= "\u00FF")
    return (("a" <= c && c <= "z") || ("A" <= c && c <= "Z") || ("0" <= c && c <= "9")
      || [ "#" "$" "%" "&" "(" ")" "?" "@" "[" "]" "{" "}" "£" "¥" "§" "©" "®" "µ" "¶" "¼" "½" "¾" "¿" ].contains(c)
      || ("\u00C0" <= c && c <= "\u00D6") || ("\u00D8" <= c && c <= "\u00F6") || ("\u00F8" <= c && c <= "\u00FF"))
  if (c > "\uFFFF")
    return false
  foreach (range in barelyVisibleCharRanges)
    if (range[0] <= c && c <= range[1])
      return false
  return true
}




function isNameNormallyVisible(name) {
  let charsArray = getUnicodeCharsArray(name)
  if (charsArray.findindex(@(c) whitespaceCharsForbidden.contains(c)) != null)
    return false
  return charsArray.findindex(isClearlyVisibleChar) != null
}

let clearAllWhitespace = @(name) "".join(getUnicodeCharsArray(name)
  .filter(@(c) !whitespaceCharsAllowed.contains(c) && !whitespaceCharsForbidden.contains(c)))

return {
  isNameNormallyVisible
  clearAllWhitespace
  getUnicodeCharsArray
}

from "auth_wt" import getCountryCode
from "%globalScripts/logs.nut" import *

//
// Dirty Words checker.
//
// Usage:
// checkPhrase("Полный пиздец, почему-то не работают блядские закрылки!")
// Result: "Полный ******, почему-то не работают ******** закрылки!"
// checkPhrase("Why did you fucking shot me, bastard?")
// Result: "Why did you ******* shot me, *******?"
// checkPhrase("何かがおかしい慰安婦フラップが壊れています")
// Result: "何かがおかしい******フラップが壊れています"
//

let regexp2 = require("regexp2")
let utf8 = require("utf8")

local debugLogFunc = null

local dict = {
  excludesdata    = null
  excludescore    = null
  foulcore        = null
  fouldata        = null
  badphrases      = null
  badcombination  = null
}

local dictAsian = {
  badsegments     = null
}

let toRegexpFunc = {
  default = @(str) regexp2(str)
  badcombination = @(str) regexp2("".concat("(", "\\s".join(str.split(" ").filter(@(w) w != "")), ")"))
}

// Collect language tables
local function init(langSources) {
  let myLocation = getCountryCode()
  foreach (varName, _val in dict) {
    dict[varName] = []
    let mkRegexp = toRegexpFunc?[varName] ?? toRegexpFunc.default
    foreach (source in langSources) {
      foreach (_i, vSrc in (source?[varName] ?? [])) {
        local v
        let tVSrc = type(vSrc)
        if (tVSrc == "string")
          v = mkRegexp(vSrc)
        else if (tVSrc == "table") {
          if (("region" in vSrc) && !vSrc.region.contains(myLocation))
            continue
          v = clone vSrc
          if ("value" in v)
            v.value = mkRegexp(v.value)
          if ("arr" in v)
            v.arr = v.arr.map(@(av) mkRegexp(av))
         }
        else
          assert(false, "Wrong var type in DirtyWordsFilter config")
        dict[varName].append(v)
      }
    }
  }

  foreach (varName, _val in dictAsian) {
    local res = {}
    local sources = langSources.map(@(v) v?[varName] ?? {}).sort(@(a, b) b.len() <=> a.len())
    foreach (src in sources) {
      if (res.len() == 0)
        res = src
      else
        foreach (k, v in src)
          if (!(k in res))
            res[k] <- v
          else
            res[k].extend(v.filter(@(value) !res[k].contains(value)))
    }
    dictAsian[varName] = res
  }

  foreach (source in langSources)
    source.clear()
}

local alphabet = {
  upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯABCDEFGHIJKLMNOPQRSTUVWXYZ",
  lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюяabcdefghijklmnopqrstuvwxyz"
};


local preparereplace = [
  {
    pattern = regexp2(@"[\'\-\+\;\.\,\*\?\(\)]")
    replace = " "
  },
  {
    pattern = regexp2(@"[\!\:\_]")
    replace = " "
  }
];


local prepareex = regexp2("(а[х]?)|(в)|([вмт]ы)|(д[ао])|(же)|(за)")


local prepareword = [
  {
    pattern = regexp2("ё")
    replace = "е"
  },
  {
    pattern = regexp2(@"&[Ee][Uu][Mm][Ll];")
    replace = "е"
  },
  {
    pattern = regexp2("&#203;")
    replace = "е"
  },
  {
    pattern = regexp2(@"&[Cc][Ee][Nn][Tt];")
    replace = "с"
  },
  {
    pattern = regexp2("&#162;")
    replace = "с"
  },
  {
    pattern = regexp2("&#120;")
    replace = "х"
  },
  {
    pattern = regexp2("&#121;")
    replace = "у"
  },
  {
    pattern = regexp2(@"\|\/\|")
    replace = "и"
  },
  {
    pattern = regexp2(@"3[\.\,]14[\d]{0,}")
    replace = "пи"
  },
  {
    pattern = regexp2(@"[\'\-\+\;\.\,\*\?\(\)]")
    replace = ""
  },
  {
    pattern = regexp2(@"[\!\:\_]")
    replace = ""
  },
  {
    pattern = regexp2(@"[u]{3,}")
    replace = "u"
  }
];


local preparewordwhile = {
  pattern = regexp2(@"(.)\\1\\1")
  replace = "\\1\\1"
}

local function preparePhrase(text) {
  local phrase = text
  local buffer = ""

  foreach (p in preparereplace)
    phrase = p.pattern.replace(p.replace, phrase)

  local words = phrase.split(" ")

  local out = []

  foreach (w in words) {
    if (w.len() < 3 && ! prepareex.match(w)) {
      buffer += w
    }
    else {
      if (buffer != "") {
        out.append(buffer)
        buffer = ""
      }

      out.append(w)
    }
  }

  if (buffer != "")
    out.append(buffer)

  return out
}

local function prepareWord(word) {
  // convert to lower
  word = (utf8(word).strtr(alphabet.upper, alphabet.lower)).strip()

  // replaces
  foreach (p in prepareword)
    word = p.pattern.replace(p.replace, word)

  local post = null

  while (word != post) {
    post = word
    word = preparewordwhile.pattern.replace(preparewordwhile.replace, word)
  }

  return word
}

local function checkRegexps(word, regexps, accuse) {
  foreach (reg in regexps)
    if ((reg?.value ?? reg).match(word)) {
      debugLogFunc?($"DirtyWordsFilter: Word \"{word}\" matched pattern \"{(reg?.value ?? reg).pattern()}\"")
      return !accuse
    }
  return accuse
}

// Checks that one word is correct.
local function checkWord(word) {
  word = prepareWord(word)

  local status = true
  local fl = utf8(word).slice(0, 1)

  if (status)
    status = checkRegexps(word, dict.foulcore, true)

  if (status)
    foreach (section in dict.fouldata)
      if (section.key == fl)
        status = checkRegexps(word, section.arr, true)

  if (status)
    status = checkRegexps(word, dict.badphrases, true)

  if (!status)
    status = checkRegexps(word, dict.excludescore, false)

  if (!status)
    foreach (section in dict.excludesdata)
      if (section.key == fl)
        status = checkRegexps(word, section.arr, false)

  return status
}

local function getUnicodeCharsArray(str) {
  local res = []
  local utfStr = utf8(str)
  for (local i = 0; i < utfStr.charCount(); i++) {
    local char = utfStr.slice(i, i + 1)
    res.append(char)
  }
  return res
}

local function getMaskedWord(w, maskChar = "*") {
  return "".join(array(utf8(w).charCount(), maskChar))
}

// Returns corrected version of phrase.
local function checkPhrase(text) {
  local phrase = text

  // In Asian languages, there is no spaces to separate words.
  local maskChars = null
  local charsArray = getUnicodeCharsArray(phrase)
  foreach (char in charsArray) {
    foreach (segment in (dictAsian.badsegments?[char] ?? [])) {
      if (!phrase.contains(segment))
        continue
      debugLogFunc?($"DirtyWordsFilter: Phrase contains segment \"{segment}\"")

      local utfPhrase = utf8(phrase)
      maskChars = maskChars ?? array(utfPhrase.charCount(), false)
      local length = utf8(segment).charCount()
      local startIdx = 0
      while (true) {
        local idx = utfPhrase.indexof(segment, startIdx)
        if (idx == null)
          break
        for (local i = idx; i < idx + length; i++)
          maskChars[i] = true
        startIdx = idx + length
      }
    }
  }
  if (maskChars != null)
    phrase = "".join(charsArray.map(@(c, i) maskChars[i] ? "**" : c))

  local lowerPhrase = phrase.tolower()
  //To match a whole combination of words
  foreach (pattern in dict.badcombination)
    if (pattern.match(lowerPhrase)) {
      debugLogFunc?($"DirtyWordsFilter: Phrase matched pattern \"{pattern.pattern()}\"")
      let word = pattern.multiExtract("\\1", lowerPhrase)?[0] ?? ""
      phrase = pattern.replace(getMaskedWord(word), lowerPhrase)
      lowerPhrase = phrase.tolower()
    }

  local words = preparePhrase(phrase)

  foreach (w in words)
    if (!checkWord(w))
      phrase = regexp2(w).replace(getMaskedWord(w), phrase)

  return phrase
}

// Checks that phrase is correct.
local function isPhrasePassing(text) {
  return checkPhrase(text) == text
}

// Set debug logging func to enable debug mode, or null to disable it.
local function setDebugLogFunc(funcOrNull) {
  debugLogFunc = funcOrNull
}

// This func is for binding a text checking console command, like:
// register_command(@(text) debugDirtyWordsFilter(text, console_print), "debug.dirty_words_filter")
function debugDirtyWordsFilter(text, temporaryDebugLogFunc) {
  let isPassing = isPhrasePassing(text)
  local prevLogFunc = null
  if (!isPassing) {
    prevLogFunc = debugLogFunc
    debugLogFunc = temporaryDebugLogFunc
  }
  let censoredResult = checkPhrase(text)
  if (!isPassing)
    debugLogFunc = prevLogFunc
  temporaryDebugLogFunc("".concat(isPassing ? "(CLEAN)" : "(DIRTY)", " \"", censoredResult, "\""))
}

return {
  init
  checkPhrase
  isPhrasePassing
  setDebugLogFunc
  debugDirtyWordsFilter
}

from "%globalScripts/logs.nut" import *
import regexp2
import utf8
from "string" import format
from "auth_wt" import getCountryCode
from "language" import getLocalLanguage
from "%sqstd/string.nut" import utf8ToLower, utf8CharToInt
from "nameVisibility.nut" import isNameNormallyVisible, clearAllWhitespace, getUnicodeCharsArray















local debugLogFunc = null

let dict = {
  excludesdata    = null
  excludescore    = null
  foulcore        = null
  fouldata        = null
  badphrases      = null
  forbiddennames  = null
  badcombination  = null
}

let dictAsian = {
  badsegments           = {}
  forbiddennamesegments = {}
}

local pendingDict = null
local pendingDictAsian = null

let similarCharsMapsByAlphabet = []

let toRegexpFunc = {
  default = @(str) regexp2(str)
  badcombination = @(str) regexp2("".concat("(", "\\s".join(str.split(" ").filter(@(w) w != "")), ")"))
}

function updateAsianDict(lookupTbl, upd) {
  foreach (k, v in upd) {
    if (k not in lookupTbl)
      lookupTbl[k] <- []
    lookupTbl[k].extend(v.filter(@(w) !lookupTbl[k].contains(w)))
  }
}


function init(langSources) {
  let myLocation = getCountryCode()
  let myLanguage = getLocalLanguage()
  let isMyLocationKnown = myLocation != "" 
  pendingDict = null
  pendingDictAsian = null

  foreach (varName, _val in dict) {
    dict[varName] = []
    let mkRegexp = toRegexpFunc?[varName] ?? toRegexpFunc.default
    foreach (source in langSources) {
      foreach (vSrc in (source?[varName] ?? [])) {
        local v
        local hasRegions = false
        let tVSrc = type(vSrc)
        if (tVSrc == "string")
          v = mkRegexp(vSrc)
        else if (tVSrc == "table") {
          let { langs = null, regions = null } = vSrc
          if (langs != null && !langs.contains(myLanguage))
            continue
          hasRegions = regions != null
          if (hasRegions && isMyLocationKnown && !regions.contains(myLocation))
            continue
          v = clone vSrc
          if ("value" in v)
            v.value = mkRegexp(v.value)
          if ("arr" in v)
            v.arr = v.arr.map(@(av) mkRegexp(av))
         }
        else
          assert(false, "Wrong var type in DirtyWordsFilter config")

        let isPending = hasRegions && !isMyLocationKnown
        if (!isPending)
          dict[varName].append(v)
        else {
          pendingDict = pendingDict ?? {}
          if (varName not in pendingDict)
            pendingDict[varName] <- []
          pendingDict[varName].append(v)
        }
      }
    }
  }

  foreach (varName, collection in dictAsian) {
    collection.clear()
    foreach (source in langSources) {
      foreach (cfg in (source?[varName] ?? {})) {
        let { langs = null, regions = null, list = {} } = cfg
        if (langs != null && !langs.contains(myLanguage))
          continue
        let hasRegions = regions != null
        if (hasRegions && isMyLocationKnown && !regions.contains(myLocation))
          continue
        let isPending = hasRegions && !isMyLocationKnown
        if (!isPending)
          updateAsianDict(collection, list)
        else {
          pendingDictAsian = pendingDictAsian ?? {}
          if (varName not in pendingDictAsian)
            pendingDictAsian[varName] <- []
          pendingDictAsian[varName].append(cfg)
        }
      }
    }
  }

  similarCharsMapsByAlphabet.clear()
  foreach (source in langSources) {
    let { similarChars = null } = source
    if (similarChars != null && !similarCharsMapsByAlphabet.contains(similarChars))
      similarCharsMapsByAlphabet.append(similarChars)
  }
}

function continueInitAfterLogin() {
  let myLocation = getCountryCode()
  if (myLocation == "")
    return
  if (pendingDict != null) {
    foreach (varName, val in pendingDict)
      foreach (v in val)
        if (v.regions.contains(myLocation))
          dict[varName].append(v)
    pendingDict = null
  }
  if (pendingDictAsian != null) {
    foreach (varName, val in pendingDictAsian)
      foreach (v in val)
        if (v.regions.contains(myLocation))
          updateAsianDict(dictAsian[varName], v.list)
    pendingDictAsian = null
  }
}

let preparereplace = [
  {
    pattern = regexp2(@"[\'\-\+\;\.\,\*\?\(\)]")
    replace = " "
  },
  {
    pattern = regexp2(@"[\!\:\_]")
    replace = " "
  }
];


let prepareex = regexp2("(а[х]?)|(в)|([вмт]ы)|(д[ао])|(же)|(за)")


let prepareword = [
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


let preparewordwhile = {
  pattern = regexp2(@"(.)\\1\\1")
  replace = "\\1\\1"
}

function preparePhrase(text) {
  local phrase = text
  let buffer = []

  foreach (p in preparereplace)
    phrase = p.pattern.replace(p.replace, phrase)

  let words = phrase.split(" ")

  let out = []

  foreach (w in words) {
    if (w.len() < 3 && ! prepareex.match(w)) {
      buffer.append(w)
    }
    else {
      if (buffer.len()) {
        out.append("".join(buffer))
        buffer.clear()
      }

      out.append(w)
    }
  }

  if (buffer.len())
    out.append("".join(buffer))

  return out
}

function prepareWord(word) {
  
  word = utf8ToLower(word.strip())

  
  foreach (p in prepareword)
    word = p.pattern.replace(p.replace, word)

  local post = null

  while (word != post) {
    post = word
    word = preparewordwhile.pattern.replace(preparewordwhile.replace, word)
  }

  return word
}

function checkRegexps(word, regexps, accuse) {
  foreach (reg in regexps)
    if ((reg?.value ?? reg).match(word)) {
      debugLogFunc?($"DirtyWordsFilter: Word \"{word}\" matched pattern \"{(reg?.value ?? reg).pattern()}\"")
      return !accuse
    }
  return accuse
}


function checkWordInternal(word, isName) {
  word = prepareWord(word)

  local status = true
  let fl = utf8(word).slice(0, 1)

  if (status)
    status = checkRegexps(word, dict.foulcore, true)

  if (status)
    foreach (section in dict.fouldata)
      if (section.key == fl)
        status = checkRegexps(word, section.arr, true)

  if (status)
    status = checkRegexps(word, dict.badphrases, true)

  if (status && isName)
    status = checkRegexps(word, dict.forbiddennames, true)

  if (!status)
    status = checkRegexps(word, dict.excludescore, false)

  if (!status)
    foreach (section in dict.excludesdata)
      if (section.key == fl)
        status = checkRegexps(word, section.arr, false)

  return status
}

function checkWord(word, isName) {
  let isPassed = checkWordInternal(word, isName)
  if (!isPassed || !isName)
    return isPassed

  let checkedNames = [ word ]
  let nameU = utf8(word)
  let nameChars = []
  for (local idx = 0; idx < nameU.charCount(); idx++)
    nameChars.append(nameU.slice(idx, idx + 1))
  foreach (alphabet in similarCharsMapsByAlphabet) {
    let tryName = "".join(nameChars.map(@(ch) alphabet?[ch] ?? ch))
    if (checkedNames.contains(tryName))
      continue
    if (!checkWordInternal(tryName, isName))
      return false
    checkedNames.append(tryName)
  }
  return true
}

let toCharcodeStr = @(c) format("\\u%04X", utf8CharToInt(c))
let stringToUtf8CharCodesStr = @(str) "".join(getUnicodeCharsArray(str).map(toCharcodeStr))

function getMaskedWord(w, maskChar = "*") {
  return "".join(array(utf8(w).charCount(), maskChar))
}

function checkPhraseInternal(text, isName) {
  local phrase = text

  
  
  local maskChars = null
  let charsArray = getUnicodeCharsArray(phrase)
  foreach (char in charsArray) {
    let segmentsLists = [
      dictAsian.badsegments?[char] ?? []
      isName ? (dictAsian.forbiddennamesegments?[char] ?? []) : []
    ]
    foreach (segmentsList in segmentsLists) {
      foreach (segment in segmentsList) {
        if (!phrase.contains(segment))
          continue
        debugLogFunc?($"DirtyWordsFilter: Phrase contains segment \"{segment}\"")

        let utfPhrase = utf8(phrase)
        maskChars = maskChars ?? array(utfPhrase.charCount(), false)
        let length = utf8(segment).charCount()
        local startIdx = 0
        while (true) {
          let idx = utfPhrase.indexof(segment, startIdx)
          if (idx == null)
            break
          for (local i = idx; i < idx + length; i++) 
            maskChars[i] = true
          startIdx = idx + length
        }
      }
    }
  }
  if (maskChars != null)
    phrase = "".join(charsArray.map(@(c, i) maskChars[i] ? "**" : c))

  local lowerPhrase = utf8ToLower(phrase)
  
  foreach (pattern in dict.badcombination)
    if (pattern.match(lowerPhrase)) {
      debugLogFunc?($"DirtyWordsFilter: Phrase matched pattern \"{pattern.pattern()}\"")
      let word = pattern.multiExtract("\\1", lowerPhrase)?[0] ?? ""
      phrase = pattern.replace(getMaskedWord(word), lowerPhrase)
      lowerPhrase = utf8ToLower(phrase)
    }

  let words = preparePhrase(phrase)

  foreach (w in words)
    if (!checkWord(w, isName))
      phrase = regexp2(w).replace(getMaskedWord(w), phrase)

  return phrase
}


let checkPhrase = @(text) checkPhraseInternal(text, false)


let isPhrasePassing = @(text) checkPhrase(text) == text


let checkName = function(name) {
  if (!isNameNormallyVisible(name)) {
    debugLogFunc?($"DirtyWordsFilter: Name visibility tricks detected: \"{stringToUtf8CharCodesStr(name)}\"")
    return getMaskedWord(name)
  }
  let noWhitespaceName = clearAllWhitespace(name)
  let stringsToCheck = [ noWhitespaceName ]
  if (name != noWhitespaceName)
    stringsToCheck.append(name)
  foreach (str in stringsToCheck)
    if (checkPhraseInternal(str, true) != str)
      return getMaskedWord(name)
  return name
}


let isNamePassing = @(name) name != "" && checkName(name) == name


function setDebugLogFunc(funcOrNull) {
  debugLogFunc = funcOrNull
}




function debugDirtyWordsFilter(text, isName, temporaryDebugLogFunc) {
  let isPassing = (isName ? isNamePassing : isPhrasePassing)(text)
  local prevLogFunc = null
  if (!isPassing) {
    prevLogFunc = debugLogFunc
    debugLogFunc = temporaryDebugLogFunc
  }
  let censoredResult = (isName ? checkName : checkPhrase)(text)
  if (!isPassing)
    debugLogFunc = prevLogFunc
  temporaryDebugLogFunc("".concat(isPassing ? "(CLEAN)" : "(DIRTY)", " \"", censoredResult, "\""))
}

return {
  init
  continueInitAfterLogin
  checkPhrase
  isPhrasePassing
  checkName
  isNamePassing
  clearAllWhitespace
  setDebugLogFunc
  debugDirtyWordsFilter
}

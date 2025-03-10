from "%scripts/dagui_natives.nut" import get_language, set_language, get_localization_blk_copy
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { eventbus_subscribe } = require("eventbus")
let DataBlock = require("DataBlock")
let { getLocalLanguage } = require("language")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { split_by_chars } = require("string")
let { register_command } = require("console")
let { isPlatformSony, isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
let { registerRespondent } = require("scriptRespondent")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")

let steamLanguages = freeze({
  English = "english"
  French = "french"
  Italian = "italian"
  German = "german"
  Spanish = "spanish"
  Russian = "russian"
  Polish = "polish"
  Czech = "czech"
  Turkish = "turkish"
  Chinese = "schinese"
  Japanese = "japanese"
  Portuguese = "portuguese"
  Ukrainian = "ukrainian"
  Hungarian = "hungarian"
  Korean = "koreana"
  TChinese = "tchinese"
  HChinese = "schinese"
})

function getEmptyLangInfo() {
  let langInfo = {
    id = "empty"
    title = "empty"
    icon = ""
    chatId = ""
    isMainChatId = true
    hasUnitSpeech = false
  }
  return langInfo
}

local needCheckLangPack = false
let langsByChatId = {}
let langsListForInventory = {}
local currentLanguage = null
let currentLanguageW = Watched(currentLanguage)
let curLangShortName = Watched("")
local currentSteamLanguage = ""
local isListInited = false

let langsList = []
let langsById = {}


function getLanguageName() {
  return currentLanguage
}

function getCurLangShortName() {
  return curLangShortName.value
}

let isChineseHarmonized = @() getLanguageName() == "HChinese" 

function isChineseVersion() {
  let language = getLanguageName()
  return language == "Chinese"
    || language == "TChinese"
    || language == "Korean"
}

let canSwitchGameLocalization = @() !isPlatformSony && !isPlatformXboxOne && !isChineseHarmonized()

function _addLangOnce(id, icon = null, chatId = null, hasUnitSpeech = null, isDev = false) {
  if (id in langsById)
    return

  let langInfo = getEmptyLangInfo()
  langInfo.id = id
  langInfo.title = "".concat(isDev ? "[DEV] " : "", loc($"language/{id}"))
  langInfo.icon = icon || ""
  langInfo.chatId = chatId || "en"
  langInfo.isMainChatId = true
  langInfo.hasUnitSpeech = !!hasUnitSpeech

  langsList.append(langInfo)
  langsById[id] <- langInfo

  if (chatId && !(chatId in langsByChatId))
    langsByChatId[chatId] <- langInfo
  else
    langInfo.isMainChatId = false
}

function checkInitList() {
  if (isListInited)
    return
  isListInited = true

  langsList.clear()
  langsById.clear()
  langsByChatId.clear()
  langsListForInventory.clear()

  let locBlk = DataBlock()
  get_localization_blk_copy(locBlk)
  let ttBlk = locBlk?.text_translation ?? DataBlock()
  let existingLangs = ttBlk % "lang"

  let gameLocalizationBlk = GUI.get()?.game_localization
  let preset = getCurCircuitOverride("gameLocalization", gameLocalizationBlk?["default"] ?? DataBlock())
  for (local l = 0; l < preset.blockCount(); l++) {
    let lang = preset.getBlock(l)
    if (isInArray(lang.id, existingLangs))
      _addLangOnce(lang.id, lang.icon, lang.chatId, lang.hasUnitSpeech)
  }

  if (is_dev_version()) {
    if (gameLocalizationBlk != null)
      for (local p = 0; p < gameLocalizationBlk.blockCount(); p++) {
        let devPreset = gameLocalizationBlk.getBlock(p)
        for (local l = 0; l < devPreset.blockCount(); l++) {
          let lang = devPreset.getBlock(l)
          _addLangOnce(lang.id, lang.icon, lang.chatId, lang.hasUnitSpeech, true)
        }
      }

    foreach (langId in existingLangs)
      _addLangOnce(langId)
  }

  let curLangId = getLanguageName()
  _addLangOnce(curLangId)

  let inventoryBlk = locBlk?.inventory_abbreviated_languages_table ?? DataBlock()
  for (local l = 0; l < inventoryBlk.paramCount(); ++l) {
    let param = inventoryBlk.getParamValue(l)
    if (type(param) != "string")
      continue

    let abbrevName = inventoryBlk.getParamName(l)
    langsListForInventory[param] <- abbrevName
  }
}


function getLangInfoById(id) {
  checkInitList()
  return langsById?[id]
}

function getCurLangInfo() {
  return getLangInfoById(currentLanguage)
}

function onChangeLanguage() {
  currentSteamLanguage = steamLanguages?[currentLanguage] ?? "english"
  currentLanguageW(currentLanguage)
}

function saveLanguage(langName) {
  if (currentLanguage == langName)
    return
  currentLanguage = langName
  curLangShortName(loc("current_lang"))
  onChangeLanguage()
}

saveLanguage(getLocalLanguage())

function setGameLocalization(langId, reloadScene = false, suggestPkgDownload = false, isForced = false) {
  if (langId == currentLanguage && !isForced)
    return

  handlersManager.shouldResetFontsCache = true
  setSystemConfigOption("language", langId)
  set_language(langId)
  saveLanguage(langId)

  if (suggestPkgDownload)
    needCheckLangPack = true

  let handler = handlersManager.getActiveBaseHandler()
  if (reloadScene && handler)
    handler.fullReloadScene()
  else
    handlersManager.markfullReloadOnSwitchScene()

  broadcastEvent("GameLocalizationChanged")
  currentLanguageW(currentLanguage)
}

function reload() {
  setGameLocalization(currentLanguage, true, false, true)
}

function getGameLocalizationInfo() {
  checkInitList()
  return langsList
}

function getLangInfoByChatId(chatId) {
  checkInitList()
  return langsByChatId?[chatId]
}















function getLocTextFromConfig(config, id = "text", defaultValue = null) {
  local res = null
  let key = $"{id}_{curLangShortName.value}"
  if (key in config)
    res = config[key]
  else
    res = config?[id] ?? res 

  if (type(res) != "string")
    return defaultValue || id

  if (res.len() > 1 && res.slice(0, 1) == "#")
    return loc(res.slice(1))
  return res
}

function isAvailableForCurLang(block) {
  if (!(block?.showForLangs ?? false))
    return true

  let availableForLangs = split_by_chars(block.showForLangs, ";")
  return availableForLangs.contains(getLanguageName())
}

let getCurrentSteamLanguage = @() currentSteamLanguage


eventbus_subscribe("on_language_changed", function on_language_changed(...) {
  saveLanguage(get_language())
})

registerRespondent("get_current_steam_language", getCurrentSteamLanguage)

let g_language = {
  getCurLangInfo
  setGameLocalization
  reload
  getGameLocalizationInfo
  getLangInfoByChatId
  getLocTextFromConfig
  isAvailableForCurLang
  getCurrentSteamLanguage
  getEmptyLangInfo

  langsList
  langsById
  getLanguageName
  getCurLangShortName
  function onEventNewSceneLoaded(_p) {
    if (!needCheckLangPack)
      return

    ::check_localization_package_and_ask_download()
    needCheckLangPack = false
  }

  function onEventInitConfigs(_p) {
    isListInited = false
  }

  currentLanguageW
  curLangShortName
  isChineseHarmonized
  isChineseVersion
  canSwitchGameLocalization
}

subscribe_handler(g_language, g_listener_priority.DEFAULT_HANDLER)

register_command(@() reload(), "ui.language_reload")

return g_language

from "%scripts/dagui_library.nut" import *
from "%scripts/langUtils/language.nut" import setGameLocalization
from "dagor.time" import get_time_msec
from "dagor.workcycle" import defer, resetTimeout
from "language" import getLocalLanguage

const STUCK_TIMEOUT_MSEC = 20000
const RELOAD_TIMEOUT_MSEC = 10000

let job = mkHardPersist("langUtils.langJobs")("job", {})
let jobTypes = {}
let loadLang = getLocalLanguage()



function registerLangJob(id, runLang, finish) {
  jobTypes[id] <- { runLang, finish }
}


function touchLangJob() {
  if ("id" in job)
    job.activeMsec = get_time_msec()
}

let isJobAlive = @() "id" in job && get_time_msec() - job.activeMsec < STUCK_TIMEOUT_MSEC
let isLangJobRunning = @(id = null) isJobAlive() && (id == null || job.id == id)



let reloadUnsafeWork = {}

function setReloadUnsafeWork(id, isRunning) {
  if (isRunning)
    reloadUnsafeWork[id] <- true
  else if (id in reloadUnsafeWork)
    reloadUnsafeWork.$rawdelete(id)
}

let isReloadUnsafeWork = @(id) id in reloadUnsafeWork

let isLoadedWith = @(lang) lang == loadLang && lang == getLocalLanguage()

function finishJob() {
  let { id, initialLang, data } = job
  job.clear()
  log($"[LangJob] {id}: finish")
  try {
    jobTypes?[id].finish(data)
  }
  catch (e) {
    logerr($"[LangJob] {id}: finish failed: {e}")
  }
  if (!isLoadedWith(initialLang))
    setGameLocalization(initialLang, true, false, true)
}

function onReloadMissing() {
  
  let leftMsec = RELOAD_TIMEOUT_MSEC - (get_time_msec() - job.activeMsec)
  if (leftMsec > 0)
    return resetTimeout(0.001 * leftMsec, onReloadMissing)
  logerr($"[LangJob] {job.id}: no script reload after the switch to {job.curLang}, the job stops")
  finishJob()
}


function switchLangWithReload(lang) {
  setGameLocalization(lang, true, false, true)
  resetTimeout(0.001 * RELOAD_TIMEOUT_MSEC, onReloadMissing)
}

let switchToNextLang

function runLang(lang) {
  let { id, uid, data } = job
  let runJobLang = jobTypes?[id].runLang
  if (runJobLang == null || lang != getLocalLanguage()) {
    logerr($"[LangJob] {id}: cannot run for {lang}")
    return finishJob()
  }

  log($"[LangJob] {id}: run for {lang}")
  function onDone() {
    if (job?.uid != uid || job?.curLang != lang)
      return
    job.$rawdelete("curLang")
    touchLangJob()
    defer(switchToNextLang)
  }

  try {
    runJobLang(lang, data, onDone)
  }
  catch (e) {
    logerr($"[LangJob] {id}: failed for {lang}: {e}")
    onDone()
  }
}

switchToNextLang = function() {
  if (job.langs.len() == 0)
    return finishJob()

  let lang = job.langs.pop()
  job.curLang <- lang
  touchLangJob()
  if (isLoadedWith(lang))
    return runLang(lang)
  switchLangWithReload(lang)
}

function continueJob() {
  if ("curLang" in job)
    runLang(job.curLang)
  else if ("id" in job)
    switchToNextLang()
}


function startLangJob(id, langs, data) {
  if (isJobAlive()) {
    logerr($"[LangJob] {id} refused: {job.id} runs")
    return false
  }
  if (reloadUnsafeWork.len() > 0) {
    logerr($"[LangJob] {id} refused: a script reload would drop {", ".join(reloadUnsafeWork.keys())}")
    return false
  }

  let initialLang = job?.initialLang ?? getLocalLanguage()
  if ("id" in job)
    log($"[LangJob] {job.id} is stuck, {id} replaces it")
  let now = get_time_msec()
  job.clear()
  job.__update({ id, uid = now, activeMsec = now, initialLang, langs = clone langs, data })
  defer(switchToNextLang)
  return true
}

if ("id" in job)
  defer(continueJob)

return freeze({
  registerLangJob
  startLangJob
  touchLangJob
  isLangJobRunning
  setReloadUnsafeWork
  isReloadUnsafeWork
})

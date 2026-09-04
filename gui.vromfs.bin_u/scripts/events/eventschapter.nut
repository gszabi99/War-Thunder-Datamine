from "%sqStdLibs/helpers/subscriptions.nut" import add_event_listener
from "%scripts/dagui_library.nut" import *
from "%scripts/events/eventsConsts.nut" import EVENT_TYPE

let { GAME_LOCALIZATION_CHANGED } = require("%scripts/crossModuleEvents.nut")
let { getEvent, getEventDiffCode, getEventsList } = require("%scripts/events/eventsState.nut")
let { getEventNameText } = require("%scripts/events/eventTexts.nut")
let { getEventUiSortPriority, getEventsChapter, isEventVisibleInEventsWindow } = require("%scripts/events/eventDisplay.nut")

let EventChapter = class {
  name = ""
  eventIds = []
  sortValid = true
  sortPriority = -1

  constructor(chapter_id) {
    this.name = chapter_id
    this.eventIds = []
    this.update()
  }

  function getLocName() {
    return loc($"events/chapter/{this.name}")
  }

  function getEvents() {
    if (!this.sortValid) {
      this.sortValid = true
      this.eventIds.sort(this.sortChapterEvents)
    }
    return this.eventIds
  }

  function getSortPriority() {
    if (this.sortPriority == -1)
      this.updateSortPriority()
    return this.sortPriority
  }

  function updateSortPriority() {
    this.sortPriority = 0
    foreach (eventName in this.getEvents()) {
      let event = getEvent(eventName)
      if (event)
        this.sortPriority = max(this.sortPriority, getEventUiSortPriority(event))
    }
  }

  function isEmpty() {
    return this.eventIds.len() == 0
  }

  function update() {
    this.eventIds = getEventsList(EVENT_TYPE.ANY, (@(name) function (event) { 
      return getEventsChapter(event) == name
             && isEventVisibleInEventsWindow(event)
    })(this.name))
    this.sortValid = false
    this.sortPriority = -1
  }

  function sortChapterEvents(eventId1, eventId2) { 
    let event1 = getEvent(eventId1)
    let event2 = getEvent(eventId2)
    if (event1 == null && event2 == null)
      return 0
    return (!!event1 <=> !!event2)
        || (getEventUiSortPriority(event2) <=> getEventUiSortPriority(event1))
        || (getEventDiffCode(event1) <=> getEventDiffCode(event2))
        || (getEventNameText(event1) <=> getEventNameText(event2))
        || event1.name <=> event2.name
  }
}

let EventChaptersManager = class {
  chapters = []
  chapterIndexByName = {}

  constructor() {
    this.chapters = []
    this.chapterIndexByName = {}

    add_event_listener(GAME_LOCALIZATION_CHANGED, this.onEventGameLocalizationChanged, this)
  }

  




  function updateChapters() {
    let eventsList = getEventsList(EVENT_TYPE.ANY, isEventVisibleInEventsWindow)

    foreach (eventName in eventsList) {
      let event = getEvent(eventName)
      if (event == null)
        continue
      let chapterId = getEventsChapter(event)
      if (!this.getChapter(chapterId))
        this.addChapter(chapterId)
    }

    foreach (chapter in this.chapters)
      chapter.update()

    for (local i = this.chapters.len() - 1; i >= 0; i--)
      if (this.chapters[i].getEvents().len() == 0)
        this.deleteChapter(this.chapters[i].name)

    this.sortChapters()
  }

  function getChapter(chapter_name) {
    let chapterIndex = this.chapterIndexByName?[chapter_name] ?? -1
    return chapterIndex < 0 ? null : this.chapters[chapterIndex]
  }

  function sortChapters() {
    this.chapters.sort(@(a, b) b.getSortPriority() <=> a.getSortPriority()
      || a.name <=> b.name)
    this.reindexChapters()
  }

  function addChapter(chapter_name) {
    this.chapters.append(EventChapter(chapter_name))
    this.sortChapters()
  }

  function deleteChapter(chapter_name) {
    this.chapters.remove(this.chapterIndexByName[chapter_name])
    this.sortChapters()
  }

  function reindexChapters() {
    this.chapterIndexByName.clear()
    foreach (idx, chapter in this.chapters)
      this.chapterIndexByName[chapter.name] <- idx
  }

  function getChapters() {
    return this.chapters
  }

  function onEventGameLocalizationChanged(_params) {
    foreach (chapter in this.chapters)
      chapter.sortValid = false
  }
}

let eventChaptersManager = EventChaptersManager()

return { eventChaptersManager }

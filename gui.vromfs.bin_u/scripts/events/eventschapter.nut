from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

::EventChapter <- class
{
  name = ""
  eventIds = []
  sortValid = true
  sortPriority = -1

  constructor(chapter_id)
  {
    this.name = chapter_id
    this.eventIds = []
    this.update()
  }

  function getLocName()
  {
    return loc("events/chapter/" + this.name)
  }

  function getEvents()
  {
    if (!this.sortValid)
    {
      this.sortValid = true
      this.eventIds.sort(this.sortChapterEvents)
    }
    return this.eventIds
  }

  function getSortPriority()
  {
    if(this.sortPriority == -1)
      this.updateSortPriority()
    return this.sortPriority
  }

  function updateSortPriority()
  {
    this.sortPriority = 0
    foreach (eventName in this.getEvents())
    {
      let event = ::events.getEvent(eventName)
      if (event)
        this.sortPriority = max(this.sortPriority, ::events.getEventUiSortPriority(event))
    }
  }

  function isEmpty()
  {
    return this.eventIds.len() == 0
  }

  function update()
  {
    this.eventIds = ::events.getEventsList(EVENT_TYPE.ANY, (@(name) function (event) {
      return ::events.getEventsChapter(event) == name
             && ::events.isEventVisibleInEventsWindow(event)
    })(this.name))
    this.sortValid = false
    this.sortPriority = -1
  }

  function sortChapterEvents(eventId1, eventId2) // warning disable: -return-different-types
  {
    let event1 = ::events.getEvent(eventId1)
    let event2 = ::events.getEvent(eventId2)
    if (event1 == null && event2 == null)
      return 0
    return (!!event1 <=> !!event2)
        || (::events.getEventUiSortPriority(event2) <=> ::events.getEventUiSortPriority(event1))
        || (::events.getEventDiffCode(event1) <=> ::events.getEventDiffCode(event2))
        || (::events.getEventNameText(event1) <=> ::events.getEventNameText(event2))
        || event1.name <=> event2.name
  }
}

::EventChaptersManager <- class
{
  chapters = []
  chapterIndexByName = {}

  constructor()
  {
    this.chapters = []
    this.chapterIndexByName = {}

    ::add_event_listener("GameLocalizationChanged", this.onEventGameLocalizationChanged, this)
  }

  /**
  * Method go through events list and gather chapters.
  * Then calls all chapters to update
  * And when some chapters are empty, removes them
  */
  function updateChapters()
  {
    let eventsList = ::events.getEventsList(EVENT_TYPE.ANY, ::events.isEventVisibleInEventsWindow)

    foreach (eventName in eventsList)
    {
      let event = ::events.getEvent(eventName)
      if (event == null)
        continue
      let chapterId = ::events.getEventsChapter(event)
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

  function getChapter(chapter_name)
  {
    let chapterIndex = this.chapterIndexByName?[chapter_name] ?? -1
    return chapterIndex < 0 ? null : this.chapters[chapterIndex]
  }

  function sortChapters()
  {
    this.chapters.sort(@(a, b) b.getSortPriority() <=> a.getSortPriority())
    this.reindexChapters()
  }

  function addChapter(chapter_name)
  {
    this.chapters.append(::EventChapter(chapter_name))
    this.sortChapters()
  }

  function deleteChapter(chapter_name)
  {
    this.chapters.remove(this.chapterIndexByName[chapter_name])
    this.sortChapters()
  }

  function reindexChapters()
  {
    this.chapterIndexByName.clear()
    foreach (idx, chapter in this.chapters)
      this.chapterIndexByName[chapter.name] <- idx
  }

  function getChapters()
  {
    return this.chapters
  }

  function onEventGameLocalizationChanged(_params)
  {
    foreach (chapter in this.chapters)
      chapter.sortValid = false
  }
}

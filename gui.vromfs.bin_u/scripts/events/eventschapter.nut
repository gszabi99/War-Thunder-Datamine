::EventChapter <- class
{
  name = ""
  eventIds = []
  sortValid = true
  sortPriority = -1

  constructor(chapter_id)
  {
    name = chapter_id
    eventIds = []
    update()
  }

  function getLocName()
  {
    return ::loc("events/chapter/" + name)
  }

  function getEvents()
  {
    if (!sortValid)
    {
      sortValid = true
      eventIds.sort(sortChapterEvents)
    }
    return eventIds
  }

  function getSortPriority()
  {
    if(sortPriority == -1)
      updateSortPriority()
    return sortPriority
  }

  function updateSortPriority()
  {
    sortPriority = 0
    foreach (eventName in getEvents())
    {
      let event = ::events.getEvent(eventName)
      if (event)
        sortPriority = max(sortPriority, ::events.getEventUiSortPriority(event))
    }
  }

  function isEmpty()
  {
    return eventIds.len() == 0
  }

  function update()
  {
    eventIds = ::events.getEventsList(EVENT_TYPE.ANY, (@(name) function (event) {
      return ::events.getEventsChapter(event) == name
             && ::events.isEventVisibleInEventsWindow(event)
    })(name))
    sortValid = false
    sortPriority = -1
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
        || (::g_string.utf8ToLower(::events.getEventNameText(event1))
          <=> ::g_string.utf8ToLower(::events.getEventNameText(event2)))
        || event1.name <=> event2.name
  }
}

::EventChaptersManager <- class
{
  chapters = []
  chapterIndexByName = {}

  constructor()
  {
    chapters = []
    chapterIndexByName = {}

    ::add_event_listener("GameLocalizationChanged", onEventGameLocalizationChanged, this)
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
      if (!getChapter(chapterId))
        addChapter(chapterId)
    }

    foreach (chapter in chapters)
      chapter.update()

    for (local i = chapters.len() - 1; i >= 0; i--)
      if (chapters[i].getEvents().len() == 0)
        deleteChapter(chapters[i].name)

    sortChapters()
  }

  function getChapter(chapter_name)
  {
    let chapterIndex = ::getTblValue(chapter_name, chapterIndexByName, -1)
    return chapterIndex < 0 ? null : chapters[chapterIndex]
  }

  function sortChapters()
  {
    chapters.sort(@(a, b) b.getSortPriority() <=> a.getSortPriority())
    reindexChapters()
  }

  function addChapter(chapter_name)
  {
    chapters.append(EventChapter(chapter_name))
    sortChapters()
  }

  function deleteChapter(chapter_name)
  {
    chapters.remove(chapterIndexByName[chapter_name])
    sortChapters()
  }

  function reindexChapters()
  {
    chapterIndexByName.clear()
    foreach (idx, chapter in chapters)
      chapterIndexByName[chapter.name] <- idx
  }

  function getChapters()
  {
    return chapters
  }

  function onEventGameLocalizationChanged(params)
  {
    foreach (chapter in chapters)
      chapter.sortValid = false
  }
}

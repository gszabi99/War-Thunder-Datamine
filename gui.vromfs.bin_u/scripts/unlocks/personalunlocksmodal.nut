from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { getBattleTaskUnlocks } = require("%scripts/unlocks/personalUnlocks.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isUnlockVisible } = require("%scripts/unlocks/unlocksModule.nut")
let { eachParam } = require("%sqstd/datablock.nut")
let { getSelectedChild } = require("%sqDagui/daguiUtil.nut")

const COLLAPSED_CHAPTERS_SAVE_ID = "personal_unlocks_collapsed_chapters"

local class personalUnlocksModal extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/unlocks/personalUnlocksModal.blk"
  unlocksItemTpl = "%gui/unlocks/battleTasksItem.tpl"

  unlocksArray = null
  unlocksConfigByChapter = null
  curChapterId = ""
  curUnlockId = ""
  showAllUnlocks = false
  isFillingUnlocksList = false

  chaptersObj = null
  unlocksObj = null
  collapsedChapters = null
  collapsibleChaptersIdx = null

  function initScreen() {
    this.showSceneBtn("show_all_unlocks", hasFeature("ShowAllBattleTasks"))
    this.chaptersObj = this.scene.findObject("chapters_list")
    this.unlocksObj = this.scene.findObject("unlocks_list")
    this.updateWindow()
    ::move_mouse_on_child_by_value(this.chaptersObj)
  }

  function updateWindow() {
    this.updatePersonalUnlocks()
    this.updateNoTasksText()
    this.fillChapterList()
    this.updateButtons()
  }

  function updatePersonalUnlocks() {
    this.unlocksArray = getBattleTaskUnlocks()
    this.unlocksConfigByChapter = {}
    foreach (unlock in this.unlocksArray) {
      let chapter = unlock?.chapter
      let group = unlock?.group
      if (chapter == null || group == null)
        continue

      this.unlocksConfigByChapter[chapter] <- this.unlocksConfigByChapter?[chapter] ?? []
      local groupIdx = this.unlocksConfigByChapter[chapter].findindex(@(g) g.id == group)
      if (groupIdx == null) {
        groupIdx = this.unlocksConfigByChapter[chapter].len()
        this.unlocksConfigByChapter[chapter].append({
          id = group
          name = $"#unlocks/group/{group}"
          image = unlock?.image ?? ""
          unlocks = []
        })
      }
      if (this.showAllUnlocks || isUnlockVisible(unlock))
        this.unlocksConfigByChapter[chapter][groupIdx].unlocks.append(
          ::g_battle_tasks.generateUnlockConfigByTask(unlock))
    }
  }

  function updateNoTasksText() {
    local text = ""
    if (this.unlocksArray.len() == 0)
      text = loc("mainmenu/battleTasks/noPersonalUnlocks")
    this.scene.findObject("no_unlocks_msg").setValue(text)
  }

  function fillChapterList() {
    let view = { items = [] }
    local curChapterIdx = -1
    this.collapsibleChaptersIdx = {}
    local idx = 0
    foreach (chapterName, chapters in this.unlocksConfigByChapter) {
      this.collapsibleChaptersIdx[chapterName] <- idx++
      curChapterIdx = this.curChapterId == chapterName ? view.items.len() : curChapterIdx
      view.items.append({
        itemTag = "campaign_item"
        id = chapterName
        itemText = $"#unlocks/chapter/{chapterName}"
        isCollapsable = true
      })

      foreach (group in chapters) {
        idx++
        let isUnlockedGroup = group.unlocks.len() > 0
        let groupId = group.id
        curChapterIdx = ((this.curChapterId == -1 && isUnlockedGroup) ||  this.curChapterId == groupId)
          ? view.items.len()
          : curChapterIdx
        view.items.append({
          itemTag = isUnlockedGroup ? "mission_item_unlocked" : "mission_item_locked"
          id = groupId
          itemText = group.name
          itemIcon = isUnlockedGroup ? "" : "#ui/gameuiskin#locked.svg"
        })
      }
    }
    let data = ::handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    this.guiScene.replaceContentFromText(this.chaptersObj, data, data.len(), this)

    eachParam(this.getCollapsedChapters(), @(_, chapterId) this.collapseChapter(chapterId), this)

    if (view.items.len() == 0) {
      this.fillUnlocksList()
      return
    }
    if (curChapterIdx == -1)
      curChapterIdx = view.items.len() > 1 ? 1 : 0
    this.chaptersObj.setValue(curChapterIdx)
  }

  function fillUnlocksList() {
    local currentChapterConfig = this.unlocksConfigByChapter?[this.curChapterId]
    if (currentChapterConfig == null) {
      let chapterId = this.curChapterId
      foreach (chapter in this.unlocksConfigByChapter) {
        currentChapterConfig = chapter.findvalue(@(g) g.id == chapterId)
        if (currentChapterConfig != null)
          break
      }
    }

    let unlocks = currentChapterConfig?.unlocks ?? []
    let needShowUnlocksList = unlocks.len() > 0
    let needShowChapterDescr = !needShowUnlocksList && currentChapterConfig?.name != null
    this.unlocksObj.show(needShowUnlocksList)
    let capterDescrObj = this.showSceneBtn("chapter_descr", needShowChapterDescr)
    if (needShowChapterDescr) {
      capterDescrObj.findObject("descr_name").setValue(currentChapterConfig?.name ?? "")
      capterDescrObj.findObject("descr_img")["background-image"] = currentChapterConfig?.image ?? ""
      return
    }

    let view = { items = unlocks.map(
      @(config) ::g_battle_tasks.generateItemView(config))
    }
    let data = ::handyman.renderCached(this.unlocksItemTpl, view)
    this.guiScene.replaceContentFromText(this.unlocksObj, data, data.len(), this)

    let unlockId = this.curUnlockId
    let curUnlockIdx = unlocks.findindex(@(unlock) unlock.id == unlockId) ?? 0
    this.isFillingUnlocksList = true
    this.unlocksObj.setValue(curUnlockIdx)
    this.isFillingUnlocksList = false
  }

  getSelectedChildId = @(obj) getSelectedChild(obj)?.id ?? ""

  function onChapterSelect(obj) {
    this.curChapterId = this.getSelectedChildId(obj)
    this.fillUnlocksList()
    this.updateButtons()
  }

  function onUnlockSelect(obj) {
    this.curUnlockId = this.getSelectedChildId(obj)
    if (::show_console_buttons && !this.isFillingUnlocksList) {
      this.guiScene.applyPendingChanges(false)
      ::move_mouse_on_child_by_value(obj)
    }
  }

  function onShowAllUnlocks(obj) {
    this.showAllUnlocks = obj.getValue()
    this.updateWindow()
  }

  function onEventUnlocksCacheInvalidate(_p) {
    this.updateWindow()
  }

  function updateButtons() {
    let canShow = !::show_console_buttons || this.chaptersObj.isHovered()
    let isHeader = canShow && this.unlocksConfigByChapter?[this.curChapterId] != null
    let collapsedButtonObj = this.showSceneBtn("btn_collapsed_chapter", canShow && isHeader)
    if (isHeader)
      collapsedButtonObj.setValue(
        loc(this.getCollapsedChapters()?[this.curChapterId] != null ? "mainmenu/btnExpand" : "mainmenu/btnCollapse"))
  }

  function onCollapse(obj) {
    if (obj?.id == null)
      return
    this.collapseChapter(::g_string.cutPrefix(obj.id, "btn_", obj.id))
    this.updateButtons()
  }

  function onCollapsedChapter() {
    this.collapseChapter(this.curChapterId)
    this.updateButtons()
  }

  function collapseChapter(chapterId) {
    let chapterObj = this.chaptersObj.findObject(chapterId)
    if (!chapterObj)
      return
    let isCollapsed = chapterObj.collapsed == "yes"
    let chapterGroups = this.unlocksConfigByChapter?[chapterId]
    if(chapterGroups == null)
      return

    local isHiddenGroupSelected = false
    foreach (group in chapterGroups)
    {
      let groupObj = this.chaptersObj.findObject(group.id)
      if(!checkObj(groupObj))
        continue

      isHiddenGroupSelected = isHiddenGroupSelected || this.curChapterId == group.id
      groupObj.show(isCollapsed)
      groupObj.enable(isCollapsed)
    }

    if (isHiddenGroupSelected) {
      this.chaptersObj.setValue(this.collapsibleChaptersIdx?[chapterId] ?? 0)
      ::move_mouse_on_child_by_value(this.chaptersObj)
    }

    chapterObj.collapsed = isCollapsed ? "no" : "yes"
    this.getCollapsedChapters()[chapterId] = isCollapsed ? null : true
    ::save_local_account_settings(COLLAPSED_CHAPTERS_SAVE_ID, this.getCollapsedChapters())
  }

  function getCollapsedChapters() {
    if(this.collapsedChapters == null)
      this.collapsedChapters = ::load_local_account_settings(COLLAPSED_CHAPTERS_SAVE_ID, ::DataBlock())
    return this.collapsedChapters
  }

  function onChaptersListHover(_obj) {
    if (::show_console_buttons)
      this.updateButtons()
  }
}

::gui_handlers.personalUnlocksModal <- personalUnlocksModal

return @(params = {}) ::handlersManager.loadHandler(personalUnlocksModal, params)

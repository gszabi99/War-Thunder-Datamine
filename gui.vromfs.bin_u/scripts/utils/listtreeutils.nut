from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let defaultListItemTpl = "%gui/customization/treeListItem.tpl"

function cutObjectPostfix(text) {
  let index = text.indexof(":")
  return index != null
    ? text.slice(0, index)
    : text
}

function getBranchDataByPath(branch, path) {
  let pathArr = path.split("/")
  for (local i = 0; i < pathArr.len(); i++)
    branch = branch?.branches[pathArr[i]]
  return branch
}

function generateListTree(parent, blkData, deep, params = null) {
  deep--
  foreach (id, data in blkData) {
    let branchName = cutObjectPostfix(id)
    let path = parent.path != "" ? $"{parent.path}/{branchName}" : branchName

    local branch = null
    let isMergingBranch = !!params?.mergeBranches.contains(branchName)
    if (!isMergingBranch) {
      let branchData = params?.getData(branchName, data, path, deep) ?? {}
      branch = { branches = {}, data = branchData, path, id = branchName }
      parent.branches[branchName] <- branch
    }
    else
      branch = parent

    if (deep > 0)
      generateListTree(branch, data, deep, params)
  }
}

function getTreeChaptersView(tree, params = null) {
  let view = []
  foreach (id, data in tree.branches) {
    let listItem = {}
    listItem.text <- params?.getText(id, data) ?? $"{id}"
    listItem.item_id <- $"{id}"
    listItem.paddingMult <- 0
    listItem.isChapter <- true
    view.append(listItem)
  }
  return view
}

function createBranchViewRecursively(parent, path, view, params) {
  params.paddingMult++
  let branches = params?.sortFn
    ? params.sortFn(parent.branches)
    : parent.branches

  foreach (data in branches) {
    let id = data.id
    let item_id = $"{path}/{id}"
    let text = params?.getBranchLabel(id, data) ?? id
    let viewItem = {
      item_id,
      text,
      paddingMult = params.paddingMult,
      isEnd = data.branches.len() == 0
    }
    if (params?.getCustomView)
      viewItem.__update(params.getCustomView(data))

    view.append(viewItem)
    if (data.branches.len() != 0)
      createBranchViewRecursively(data, item_id, view, params)
  }
  params.paddingMult--
}

function getBranchView(branchData, params = null) {
  let viewParams = {paddingMult = 0}
  if (params)
    viewParams.__update(params)
  let view = []
  createBranchViewRecursively(branchData, branchData.path, view, viewParams)
  return view
}

function getChapterBranchNest(chapter, listObj) {
  let chapterObj = listObj.findObject(chapter)
  return chapterObj.findObject("branch_list")
}

function closeTreeChapter(chapterId, listObj){
  let chapterObj = listObj.findObject(chapterId)
  let branchNest = chapterObj.findObject("branch_list")
  branchNest.show(false)
  branchNest.getParent().isCollapsed = "yes"
}

function openChapterImpl(chapterData, branchNest, guiScene, params = null) {
  branchNest.show(true)
  branchNest.getParent().isCollapsed = "no"
  if (branchNest.isInited == "yes")
    return
  let view = getBranchView(chapterData, params)
  let data = handyman.renderCached(params?.itemTpl ?? defaultListItemTpl, {items = view})
  guiScene.replaceContentFromText(branchNest, data, data.len(), this)
  branchNest.isInited = "yes"
}

function openTreeChapter(chapter, tree, listObj, guiScene, params = null) {
  let chapterData = getBranchDataByPath(tree, chapter)
  let branchNest = getChapterBranchNest(chapter, listObj)
  openChapterImpl(chapterData, branchNest, guiScene, params)
}

function isChapterOpened(chapter, listObj) {
  let branchNest = getChapterBranchNest(chapter, listObj)
  return branchNest.isVisible()
}

function collapseBranchRecursively(branchNest, collapseData) {
  let curPath = collapseData.branchPath
  let curBranchData = collapseData.branchData
  foreach (id, data in curBranchData.branches) {
    let path = $"{curPath}/{id}"

    let branchObj = branchNest.findObject(path)
    branchObj.show(!collapseData.needCollapse)
    if (collapseData.isCompletly)
      branchObj.isCollapsed = collapseData.needCollapse ? "yes" : "no"

    let canDoNextStep = !data?.isSkin && (collapseData.isCompletly
      || collapseData.needCollapse || branchObj.isCollapsed == "no")
    if (!canDoNextStep)
      continue
    collapseData.branchPath = path
    collapseData.branchData = data
    collapseBranchRecursively(branchNest, collapseData)
    collapseData.branchPath = curPath
    collapseData.branchData = curBranchData
  }
}

function collapseBranch(branchNest, treeData, branchPath, needCollapse, isCompletly = false) {
  let branchData = getBranchDataByPath(treeData, branchPath)
  if (branchData.branches.len() == 0)
    return
  let collapseData = {
    isCompletly
    branchData
    branchPath
    needCollapse
  }
  let branchObj = branchNest.findObject(branchPath)
  branchObj.isCollapsed = needCollapse ? "yes" : "no"
  collapseBranchRecursively(branchNest, collapseData)
}

return {
  getTreeChaptersView
  getBranchView
  generateListTree
  getBranchDataByPath
  closeTreeChapter
  openTreeChapter
  collapseBranch
  isChapterOpened
}
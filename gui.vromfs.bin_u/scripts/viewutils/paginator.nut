from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { format } = require("string")

function generatePaginator(nest_obj, handler, cur_page, last_page, my_page = null, show_last_page = false, hasSimpleNavButtons = false) {
  if (!checkObj(nest_obj))
    return

  let guiScene = nest_obj.getScene()
  let paginatorTpl = "%gui/paginator/paginator.tpl"
  local buttonsMid = ""
  let numButtonText = "button { to_page:t='%s'; text:t='%s'; %s on_click:t='goToPage'; underline{}}"
  let numPageText = "activeText{ text:t='%s'; %s}"
  local paginatorObj = nest_obj.findObject("paginator_container")

  if (!checkObj(paginatorObj)) {
    let paginatorMarkUpData = handyman.renderCached(paginatorTpl, { hasSimpleNavButtons = hasSimpleNavButtons })
    paginatorObj = guiScene.createElement(nest_obj, "paginator", handler)
    guiScene.replaceContentFromText(paginatorObj, paginatorMarkUpData, paginatorMarkUpData.len(), handler)
  }

  
  
  cur_page = cur_page.tointeger()
  
  local lastShowPage = show_last_page ? last_page : min(max(cur_page + 1, 2), last_page)

  let isSinglePage = last_page < 1
  paginatorObj.show(! isSinglePage)
  paginatorObj.enable(! isSinglePage)
  if (isSinglePage)
    return

  if (my_page != null && my_page > lastShowPage && my_page <= last_page)
    lastShowPage = my_page

  for (local i = 0; i <= lastShowPage; i++) {
    if (i == cur_page)
      buttonsMid = "".concat(buttonsMid, format(numPageText, (i + 1).tostring(), (i == my_page ? "mainPlayer:t='yes';" : "")))
    else if ((cur_page - 1 <= i && i <= cur_page + 1)       
             || (i == my_page)                              
             || (i < 3)                                     
             || (show_last_page && i == lastShowPage))      
      buttonsMid = "".concat(buttonsMid, format(numButtonText, i.tostring(), (i + 1).tostring(), (i == my_page ? "mainPlayer:t='yes';" : "")))
    else {
      buttonsMid = "".concat(buttonsMid, format(numPageText, "...", ""))
      if (my_page != null && i < my_page && (my_page < cur_page || i > cur_page))
        i = my_page - 1
      else if (i < cur_page)
        i = cur_page - 2
      else if (show_last_page)
        i = lastShowPage - 1
    }
  }

  guiScene.replaceContentFromText(paginatorObj.findObject("paginator_page_holder"), buttonsMid, buttonsMid.len(), handler)
  let nextObj = paginatorObj.findObject("pag_next_page")
  nextObj.show(last_page > cur_page)
  nextObj.to_page = min(last_page, cur_page + 1).tostring()
  let prevObj = paginatorObj.findObject("pag_prew_page")
  prevObj.show(cur_page > 0)
  prevObj.to_page = max(0, cur_page - 1).tostring()
}

function hidePaginator(nestObj) {
  let paginatorObj = nestObj.findObject("paginator_container")
  if (!paginatorObj)
    return
  paginatorObj.show(false)
  paginatorObj.enable(false)
}

function paginator_set_unseen(nestObj, prevUnseen, nextUnseen) {
  let paginatorObj = nestObj.findObject("paginator_container")
  if (!checkObj(paginatorObj))
    return

  let prevObj = paginatorObj.findObject("pag_prew_page_unseen")
  if (prevObj)
    prevObj.setValue(prevUnseen ?? "")
  let nextObj = paginatorObj.findObject("pag_next_page_unseen")
  if (nextObj)
    nextObj.setValue(nextUnseen ?? "")
}

return {
  generatePaginator
  hidePaginator
  paginator_set_unseen
}
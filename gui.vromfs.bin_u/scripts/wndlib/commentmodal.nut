::gui_modal_comment <- function gui_modal_comment(owner=null, titleText=null, buttonText=null, callbackFunc=null, isCommentRequired=false)
{
  ::gui_start_modal_wnd(::gui_handlers.commentModalHandler, {
    titleText = titleText
    buttonText = buttonText
    callbackFunc = callbackFunc
    owner = owner
    isCommentRequired = isCommentRequired
  })
}

class ::gui_handlers.commentModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    if (titleText && titleText.len())
      scene.findObject("comment_wnd_title").setValue(titleText)
    if (buttonText && buttonText.len())
      scene.findObject("ok_btn").setValue(buttonText)
    scene.findObject("comment_editbox").select()
    onChangeComment()
  }

  function onChangeComment()
  {
    comment = scene.findObject("comment_editbox").getValue() || ""
    scene.findObject("ok_btn").enable(!isCommentRequired || comment.len() > 0)
  }

  function onOk()
  {
    isConfirmed = true
    goBack()
  }

  function afterModalDestroy()
  {
    if (!isConfirmed || !callbackFunc || (isCommentRequired && comment.len() == 0))
      return

    if (owner)
      callbackFunc.call(owner, comment)
    else
      callbackFunc(comment)
  }

  comment = ""
  isCommentRequired = false
  isConfirmed = false

  titleText = null
  buttonText = null
  callbackFunc = null
  owner = null
  wndType = handlerType.MODAL
  sceneBlkName = "gui/commentModal.blk"
}

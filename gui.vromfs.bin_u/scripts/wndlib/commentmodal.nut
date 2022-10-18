from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { handlerType } = require("%sqDagui/framework/handlerType.nut")

::gui_modal_comment <- function gui_modal_comment(owner=null, titleText=null, buttonText=null, callbackFunc=null, isCommentRequired=false) {
  ::gui_start_modal_wnd(::gui_handlers.commentModalHandler, {
    titleText = titleText
    buttonText = buttonText
    callbackFunc = callbackFunc
    owner = owner
    isCommentRequired = isCommentRequired
  })
}

::gui_handlers.commentModalHandler <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  function initScreen()
  {
    if (titleText && titleText.len())
      this.scene.findObject("comment_wnd_title").setValue(titleText)
    if (buttonText && buttonText.len())
      this.scene.findObject("ok_btn").setValue(buttonText)
    onChangeComment()

    ::select_editbox(this.scene.findObject("comment_editbox"))
  }

  function onChangeComment()
  {
    comment = this.scene.findObject("comment_editbox").getValue() || ""
    this.scene.findObject("ok_btn").enable(!isCommentRequired || comment.len() > 0)
  }

  function onOk()
  {
    isConfirmed = true
    this.goBack()
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
  sceneBlkName = "%gui/commentModal.blk"
}

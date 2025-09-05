from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { select_editbox } = require("%sqDagui/daguiUtil.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")

gui_handlers.commentModalHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  function initScreen() {
    if (this.titleText && this.titleText.len())
      this.scene.findObject("comment_wnd_title").setValue(this.titleText)
    if (this.buttonText && this.buttonText.len())
      this.scene.findObject("ok_btn").setValue(this.buttonText)
    this.onChangeComment()

    select_editbox(this.scene.findObject("comment_editbox"))
  }

  function onChangeComment() {
    this.comment = this.scene.findObject("comment_editbox").getValue() ?? ""
    this.scene.findObject("ok_btn").enable(!this.isCommentRequired || this.comment.len() > 0)
  }

  function onOk() {
    this.isConfirmed = true
    this.goBack()
  }

  function afterModalDestroy() {
    if (!this.isConfirmed || !this.callbackFunc || (this.isCommentRequired && this.comment.len() == 0))
      return

    if (this.owner)
      this.callbackFunc.call(this.owner, this.comment)
    else
      this.callbackFunc(this.comment)
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

function openCommentModal(owner = null, titleText = null, buttonText = null, callbackFunc = null, isCommentRequired = false) {
  loadHandler(gui_handlers.commentModalHandler, {
    titleText = titleText
    buttonText = buttonText
    callbackFunc = callbackFunc
    owner = owner
    isCommentRequired = isCommentRequired
  })
}

return {
  openCommentModal
}

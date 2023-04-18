<<#categories>>
decorCategory {
  id:t='<<id>>'
  categoryId:t='<<categoryId>>'
  groupId:t='<<groupId>>'

  <<^hasGroups>>type:t='decoratorsList'<</hasGroups>>
  <<#hasGroups>>type:t='groupsList'<</hasGroups>>

  header {
    <<#isGroup>>margin-left:t='3@blockInterval'<</isGroup>>
    fullSizeCollapseBtn {
      id:t='btn_<<id>>'
      activeText {}
      text {
        id:t='txt_<<id>>'
        text:t='<<headerText>>'
      }
    }
  }

  content {
    id:t='content_<<id>>'
    total-input-transparent:t='yes'
    css-hier-invalidate:t='yes'

    <<#hasGroups>>
    width:t='pw'
    canSelectNone:t='yes'
    disableFocusParent:t='yes'
    on_select:t='onDecorCategorySelect'
    on_activate:t='onDecorCategoryActivate'
    <</hasGroups>>

    <<^hasGroups>>
    on_select:t='onDecorItemSelect'
    on_activate:t='onDecorItemActivate'
    on_hover:t='onDecorListHoverChange'
    on_unhover:t='onDecorListHoverChange'
    <</hasGroups>>

    on_wrap_up:t='onDecorItemHeader'
    on_wrap_down:t='onDecorItemNextHeader'
  }
}
<</categories>>

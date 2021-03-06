<<#collapsableBlocks>>
collapsableBlock {
  id:t='<<id>>'
  type:t='<<type>>'

  header {
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
    id:t='collapse_content_<<id>>'

    total-input-transparent:t='yes'
    css-hier-invalidate:t='yes'

    <<#onSelect>> on_select:t='<<onSelect>>' <</onSelect>>
    <<#onActivate>> on_activate:t='<<onActivate>>' <</onActivate>>
    <<#onHoverChange>>
    on_hover:t='<<onHoverChange>>'
    on_unhover:t='<<onHoverChange>>'
    <</onHoverChange>>
    <<@contentParams>>
  }
}
<</collapsableBlocks>>

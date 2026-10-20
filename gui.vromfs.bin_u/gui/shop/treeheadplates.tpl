<<#plates>>
  modBlockHeader {
    width:t='<<w>>'
    pos:t='<<x>>, 0'
    class:t='flat'
    text {
      text:t='<<title>>'
      width:t='pw'
      top:t='ph/2-h/2'
      text-align:t='center'
      position:t='absolute'
    }
    <<#hasExpandBtn>>
      shopCollapsedButton {
        id:t='title_expand_btn'
        position:t='absolute'
        pos:t='0.9@modArrowWidth - 8@sf/@pf, (ph-h)/2'
        padding-left:t='16@sf/@pf + 4@sf/@pf'
        isCollapsed:t='no'
        font:t='@fontSmall'
        text:t='#mainmenu/btnCollapseAll'
        on_click:t = 'onExpandAllBtn'

        shopCollapsedBtnIcon {
          img {}
        }
      }
    <</hasExpandBtn>>
  }
<</plates>>

<<#separators>>
  tdiv {
    size:t='1@dp, ph -6@dp'
    pos:t='<<x>>-w/2, ph/2-h/2'
    position:t='absolute'
    background-color:t='@tableHeaderSeparatorColor'
  }
<</separators>>


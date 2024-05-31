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
        width:t='16@sf/@pf'
        pos:t='0.9@modArrowWidth - w/2, (ph-h)/2'
        isCollapsed:t='no'
        isCollapseAllBtn:t='yes'
        text:t=''
        on_click:t = 'onExpandAllBtn'

        img {
          position:t='relative'
          size:t='16@sf/@pf, w'
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


<<#logEntries>>
expandable {
  id:t='<<id>>'

  selImg {
    tdiv {
      size:t='pw, 0.055@scrn_tgt'
      padding:t='0.01@scrn_tgt, 0'

      textareaNoTab {
        id:t='name'
        width:t='fw'
        max-height:t='ph'
        pare-text:t='yes'
        valign:t='center'
        overlayTextColor:t='active'
        overflow:t='hidden'
        padding-top:t='-0.005@scrn_tgt'
        text:t='<<header>>'
        on_link_rclick:t="onUserLinkRClick"
      }

      text {
        id:t='time'
        text:t='<<time>>'
        min-width:t='0.20@sf'
        valign:t='center'
        text-align:t='right'
        smallFont:t='yes'
      }

      text {
        id:t='middle'
        text:t=''
        top:t='ph/2 - h/2'
        position:t='absolute'
        width:t='pw'
        text-align:t='center'
      }

      <<#details>>
      expandImg {
        id:t='expandImg'
        height:t='0.01@scrn_tgt'
        width:t='2h'
        position:t='absolute'
        pos:t='pw/2 - w/2, ph - h'
        background-image:t='#ui/gameuiskin#expand_info'
        background-color:t='@premiumColor'
      }
      <</details>>
    }

    hiddenDiv {
      width:t='pw'
      padding:t='0.01@scrn_tgt, 0'
      flow:t='vertical'

      <<#details>>
      <<>details>>
      <</details>>
    }
  }
}
<</logEntries>>

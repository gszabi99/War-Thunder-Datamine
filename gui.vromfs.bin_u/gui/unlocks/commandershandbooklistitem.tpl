<<#items>>
expandable {
  id:t='<<id>>'
  unlockId:t='<<id>>'
  fullSize:t='yes'
  selImg {
    tdiv {
      width:t='pw'
      flow:t='horizontal'

      tdiv {
        size:t='1@cIco, 1@cIco'
        top:t='0.5ph-0.5h'
        position:t='relative'
        margin-right:t='1@blockInterval'
        <<#isDone>>
        img {
          size:t='pw, ph'
          background-image:t='#ui/gameuiskin#icon_primary_ok.svg'
          background-svg-size:t='pw, ph'
          background-color:t='@goodTextColor'
        }
        <</isDone>>
        <<#isLocked>>
        img {
          size:t='pw, ph'
          background-image:t='#ui/gameuiskin#locked.svg'
          background-svg-size:t='pw, ph'
          background-color:t='@fadedTextColor'
        }
        <</isLocked>>

        unseenIcon {
          value:t='<<unseenIcon>>'
          noMargin:t='yes'
          position:t='absolute'
          pos:t='0.5pw-0.5w, 0.5ph-0.5h'
        }
      }

      textareaNoTab {
        text:t='<<name>>'
        top:t='0.5ph-0.5h'
        position:t='relative'
        width:t='fw'
        overflow:t='hidden'
        <<#isActive>>overlayTextColor:t='active'<</isActive>>
        <<^isActive>>overlayTextColor:t='disabled'<</isActive>>
      }
    }
  }
}
<</items>>

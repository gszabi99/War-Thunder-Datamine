blur {}
blur_foreground {}

expandable {
  id:t='<<performActionId>>'
  fullSize:t='yes'
  on_click:t='<<action>>'
  headerBg {}
  selImg {
    header {
      width:t='pw'
      flow:t='horizontal'
      img {
        size:t='@cIco, @cIco'
        top:t='0.5ph-0.5h'
        position:t='relative'
        margin-right:t='1@blockInterval'
        background-image:t='!#ui/gameuiskin#btn_room_list.svg'
        background-svg-size:t='@cIco, @cIco'
      }

      tdiv {
        width:t='fw'
        top:t='0.5ph-0.5h'
        position:t='relative'
        css-hier-invalidate:t='yes'
        textareaNoTab {
          text:t='#unlocks/chapter/commanders_handbook'
        }
      }

      textareaNoTab {
        top:t='0.5ph-0.5h'
        position:t='relative'
        text:t='<<statusText>>'
        overlayTextColor:t='active'
      }
    }

    textareaNoTab {
      width:t='pw'
      text:t='<<unlockName>>'
      smallFont:t='yes'
    }

    textarea {
      width:t='pw'
      margin-top:t='1@blockInterval'
      smallFont:t='yes'
      removeParagraphIndent:t='yes'
      text:t='<<unlockDesc>>'
    }

    <<#needProgressBar>>
    battleTaskProgress {
      width:t='pw'
      margin-top:t='1@blockInterval'
      max:t='<<progressMaxValue>>'
      value:t='<<progressCurValue>>'
    }
    <</needProgressBar>>

    <<#hasUnclaimed>>
    tdiv {
      width:t='pw'
      flow:t='horizontal'
      margin-top:t='1@blockInterval'
      img {
        size:t='@cIco, @cIco'
        top:t='0.5ph-0.5h'
        position:t='relative'
        margin-right:t='1@blockInterval'
        background-image:t='#ui/gameuiskin#new_icon.svg'
        background-svg-size:t='@cIco, @cIco'
      }
      textareaNoTab {
        top:t='0.5ph-0.5h'
        position:t='relative'
        text:t='#mainmenu/rewardsNotCollected'
      }
    }
    <</hasUnclaimed>>
  }
}

collapsedContainer {
  on_click:t='<<action>>Collapsed'
  shortInfoBlock {
    tdiv {
      size:t='@cIco, @cIco'
      top:t='0.5ph-0.5h'
      position:t='relative'
      img {
        size:t='pw, ph'
        background-image:t='!#ui/gameuiskin#btn_room_list.svg'
        background-svg-size:t='@cIco, @cIco'
      }
      <<#hasUnclaimed>>
      img {
        size:t='0.6@cIco, 0.6@cIco'
        pos:t='pw-0.7w, -0.2h'
        position:t='absolute'
        background-image:t='#ui/gameuiskin#new_icon.svg'
        background-svg-size:t='0.6@cIco, 0.6@cIco'
      }
      <</hasUnclaimed>>
    }
  }
}

baseToggleButton {
  id:t='commanders_handbook_toggle'
  pos:t='pw-w-1@blockInterval'
  on_click:t='onToggleItem'
  type:t='right'
  directionImg {}
}

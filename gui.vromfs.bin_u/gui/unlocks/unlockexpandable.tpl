<<#items>>
expandable {
  selImg {
    tdiv {
      width:t='pw'

      cardImg {
        type:t='small'
        background-image:t='<<icon>>'
      }

      activeText {
        text:t='<<title>>'
        position:t='relative'
        pos:t='0, ph/2-h/2'
        max-width:t='pw'
        pare-text:t='yes'
        margin-left:t='2@blockInterval'
      }
    }

    hiddenDiv {
      width:t='pw'

      layeredIconContainer {
        position:t='relative'
        pos:t='0, ph/2-h/2'
        size:t='@profileUnlockIconSize, @profileUnlockIconSize'
        effectType:t='<<effectType>>'
        <<@image>>
      }

      tdiv {
        margin-left:t='0.015@sf'
        min-height:t='@profileUnlockIconSize'
        width:t='fw'
        flow:t='vertical'

        textareaNoTab {
          width:t='pw'
          overflow:t='hidden'
          smallFont:t='yes'
          margin-top:t='@blockInterval'
          text:t='<<description>>'
        }

        <<#hasProgressBar>>
        challengeDescriptionProgress {
          value:t='<<progress>>'
        }
        <</hasProgressBar>>

        textareaNoTab {
          width:t='pw'
          overflow:t='hidden'
          smallFont:t='yes'
          text:t='<<mainCondition>>'
          margin-top:t='@blockInterval'
        }

        textareaNoTab {
          width:t='pw'
          overflow:t='hidden'
          smallFont:t='yes'
          text:t='<<multDesc>>'
        }

        textareaNoTab {
          width:t='pw'
          overflow:t='hidden'
          smallFont:t='yes'
          text:t='<<conditions>>'
          margin-top:t='@blockInterval'
        }

        textareaNoTab {
          text:t='<<rewardText>>'
          smallFont:t='yes'
          margin-top:t='0.005@sf'
          title:t='$tooltipObj'
          max-width:t='pw'
          pare-text:t='yes'

          tooltipObj {
            tooltipId:t='<<rewardTooltipId>>'
            smallFont:t='yes'
            on_tooltip_open:t='onGenericTooltipOpen'
            on_tooltip_close:t='onTooltipObjClose'
            display:t='hide'
          }
        }

        tdiv {
          flow:t='h-flow'
          width:t='@sf'
          margin-top:t='@blockInterval'

          include "%gui/unlocks/subunlocks.tpl"
        }
      }

      unlockStages {
        position:t='relative'
        pos:t='0, 50%ph-50%h'
        margin-left:t='0.05@sf'
        flow:t='horizontal'
        behavior:t='PosNavigator'
        navigatorShortcuts:t='noSelect'

        <<#stages>>
        unlocked {
          class:t=<<#even>>'even'<</even>><<^even>>'odd'<</even>>
          substrateImg {}
          img { background-image:t='<<image>>' }
          <<@tooltip>>
        }
        <</stages>>
      }

      <<#hasLock>>
      img {
        position:t="absolute"
        pos:t="0, 10@sf/@pf"
        background-image:t="#ui/gameuiskin#locked.svg"
        size:t="@cIco, @cIco"
        background-svg-size:t="@cIco, @cIco"
        background-color:t="@white"
      }
      <</hasLock>>
    }

    expandImg {
      position:t='absolute'
      pos:t='50%pw-50%w, ph-h'
      size:t='2h, 0.01@scrn_tgt'
      background-image:t='#ui/gameuiskin#expand_info'
      background-color:t='@premiumColor'
    }
  }

  fgLine {}
}
<</items>>

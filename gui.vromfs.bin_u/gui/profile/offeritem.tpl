tdiv {
  flow:t='horizontal'
  height:t='357@sf/@pf'
  <<#offers>>
  <<#needSeparator>>
  separator {
    width:t='1@sf/@pf'
    height:t='330@sf/@pf'
    margin-top:t='27@sf/@pf'
    margin-left:t='-60@sf/@pf'
    background-color:t='#FFFFFF'
    color-factor:t='76'
  }
  <</needSeparator>>
  tdiv {
    flow:t='vertical'
    textareaNoTab {
      margin-top:t='10@sf/@pf'
      mediumFont:t="yes"
      overlayTextColor:t='userlog'
      text:t='<<title>>'
    }
    tdiv {
      flow:t='horizontal'
      margin-top:t='20@sf/@pf'
      <<#items>>
      tdiv {
        <<^firstInBlock>>
        margin-left:t='60@sf/@pf'
        <</firstInBlock>>
        margin-right:t='60@sf/@pf'
        tdiv {
          flow:t='vertical'
          tdiv {
            size:t='140@sf/@pf, 140@sf/@pf'
            background-color:t='#2D343C'
            imagePlace {
              pos:t='pw/2-w/2, ph/2-h/2'
              position:t='absolute'
              <<@image>>
            }
            textareaNoTab {
              pos:t='pw-w, ph-h'
              position:t='absolute'
              smallFont:t="yes"
              overlayTextColor:t='active'
              text:t='<<count>>'
            }
          }
          tdiv {
            margin-top:t='16@sf/@pf'
            position:t='relative'          
            max-width:t='242@sf/@pf'
            overflow:t='hidden'
            textareaNoTab {
              smallFont:t="yes"
              overlayTextColor:t='active'
              text:t='<<description>>'
              behaviour:t='OverflowScroller'
              move-pixel-per-sec:t='20*@scrn_tgt/100.0'
              move-sleep-time:t='1000'
              move-delay-time:t='1000'
            }
          }
          <<#cost>>
          tdiv {
            pos:t='0, 214@sf/@pf'
            position:t='absolute'
            flow:t='horizontal'
            textareaNoTab {
              smallFont:t="no"
              overlayTextColor:t='active'
              text:t='<<discountCost>>'
            }
            textareaNoTab {
              smallFont:t="no"
              margin-left:t='10@sf/@pf'
              overlayTextColor:t='active'
              text:t='<<cost>>'
              redLine {
                width:t='1.1pw'
                height:t='2@sf/@pf'
                pos:t='pw/2 - w/2, ph/2 - h/2'
                position:t='absolute'
                background-color:t='@red'
              }
            }
          }
          <</cost>>
          <<#canPreview>>
          Button_text {
            pos:t='0, 290@sf/@pf - h'
            position:t='absolute'
            text:t='#mainmenu/btnPreview'
            tooltip:t='<<btnTooltip>>'
            btnName:t='L3'
            on_click:t='<<funcName>>'
            showButtonImageOnConsole:t='no'
            class:t='image'
            img{ background-image:t='#ui/gameuiskin#btn_preview.svg' }
            <<@actionParamsMarkup>>
          }
          <</canPreview>>
        }
      }
      <</items>>
      <<#units>>
      tdiv {
        <<^firstInBlock>>
        margin-left:t='60@sf/@pf'
        <</firstInBlock>>
        margin-right:t='60@sf/@pf'
        tdiv {
          flow:t='vertical'
          tdiv {
            size:t='195@sf/@pf, 68@sf/@pf'
            tdiv {
              pos:t='pw/2-w/2, ph/2-h/2'
              position:t='absolute'
              <<@image>>
            }
          }
          tdiv {
            margin-top:t='16@sf/@pf'
            height:t='28@sf/@pf'
            flow:t='horizontal'
            position:t='relative'
            tdiv {
              size:t='40@sf/@pf, 40@sf/@pf'
              position:t='relative'
              pos:t='0, ph/2-h/2'
              background-color:t='@white'
              background-image:t='<<countryIco>>'
            }
            tdiv {
              margin-left:t='12@sf/@pf'
              height:t='ph'
              textareaNoTab {
                margin-top:t='ph-h'
                position:t='relative'
                normalBoldFont:t="yes"
                overlayTextColor:t='active'
                text:t='<<br>>'
                css-hier-invalidate:t='yes'
              }
              textareaNoTab {
                margin-left:t='4@sf/@pf'
                pos:t='0, ph-h+2@sf/@pf'
                position:t='relative'
                tinyFont:t="yes"
                overlayTextColor:t='active'
                text:t='#mainmenu/brText'
                css-hier-invalidate:t='yes'
              }
            }
          }
          tdiv {
            margin-top:t='14@sf/@pf'
            position:t='relative'          
            max-width:t='280@sf/@pf'
            overflow:t='hidden'
            textareaNoTab {
              overlayTextColor:t='active'
              text:t='<<unitFullName>>'
              behaviour:t='OverflowScroller'
              move-pixel-per-sec:t='20*@scrn_tgt/100.0'
              move-sleep-time:t='1000'
              move-delay-time:t='1000'
            }
          }
          textareaNoTab {
            tinyFont:t="yes"
            text:t='<<unitType>>'
          }
          textareaNoTab {
            margin-top:t='7@sf/@pf'
            smallFont:t="yes"
            overlayTextColor:t='active'
            text:t='<<unitRank>>'
          }
          <<#cost>>
          tdiv {
            pos:t='0, 214@sf/@pf'
            position:t='absolute'
            flow:t='horizontal'
            textareaNoTab {
              smallFont:t="no"
              overlayTextColor:t='active'
              text:t='<<discountCost>>'
            }
            textareaNoTab {
              smallFont:t="no"
              margin-left:t='10@sf/@pf'
              overlayTextColor:t='active'
              text:t='<<cost>>'
              redLine {
                width:t='1.1pw'
                height:t='2@sf/@pf'
                pos:t='pw/2 - w/2, ph/2 - h/2'
                position:t='absolute'
                background-color:t='@red'
              }
            }
          }
          <</cost>>
          Button_text {
            pos:t='0, 290@sf/@pf - h'
            position:t='absolute'
            text:t='#mainmenu/btnPreview'
            tooltip:t='<<btnTooltip>>'
            btnName:t='L3'
            on_click:t='<<funcName>>'
            showButtonImageOnConsole:t='no'
            class:t='image'
            img{ background-image:t='#ui/gameuiskin#btn_preview.svg' }
            <<@actionParamsMarkup>>
          }
        }
      }
      <</units>>
    }
  }
  <</offers>>
}
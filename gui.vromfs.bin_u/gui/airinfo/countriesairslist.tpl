tdiv {
  width:t='pw - 1@scrollBarSize'
  <<#countries>>
  tdiv {
    width:t='pw/<<total>>'
    frameBlock {
      width:t='pw'
      margin-right:t='1@blockInterval'
      margin-bottom:t='1@blockInterval'
      padding:t='0.01@scrn_tgt'
      flow:t='vertical'

      cardImg {
        pos:t='50%pw-50%w, 0'
        position:t='relative'
        background-image:t='<<countryIcon>>'
      }
    }
  }
  <</countries>>
}

tdiv {
  size:t='pw, fh'
  overflow-y:t="auto"
  scrollbarShortcuts:t='left'

  tdiv {
    width:t='fw - 1@scrollBarSize'
    min-height:t='ph'

    <<#countries>>
    tdiv {
      width:t='pw/<<total>>'
      min-height:t='ph'
      frameBlock {
        min-height:t='ph'
        width:t='pw'
        margin-right:t='1@blockInterval'
        padding:t='0.01@scrn_tgt'

        flow:t='vertical'

        <<#types>>
        tdiv {
          width:t='pw'
          flow:t='vertical'
          activeText {
            pos:t='0, 0.01@sf'
            position:t='relative'
            text:t='<<typeName>>'
          }

          <<#units>>
          tdiv {
            width:t='pw - 0.01@sf'
            margin-left:t='0.01@sf';
            smallFont:t='yes';
            img {
              id:t='air_icon';
              background-image:t='<<ico>>';
              shopItemType:t='<<type>>';
              size:t='@tableIcoSize, @tableIcoSize';
              background-svg-size:t='@tableIcoSize, @tableIcoSize';
              background-repeat:t='aspect-ratio';
            }
            textareaNoTab {
              id:t='air_name';
              width:t='fw'
              padding-left:t='4*@sf/@pf_outdated';
              padding-top:t='4*@sf/@pf_outdated';
              text:t='<<text>>';
            }
            tooltipObj {
              tooltipId:t='<<tooltipId>>';
              on_tooltip_open:t='onGenericTooltipOpen';
              on_tooltip_close:t='onTooltipObjClose';
              display:t='hide';
            }
            title:t='$tooltipObj';
          }
          <</units>>
        }
        <</types>>
      }
    }
    <</countries>>
  }
}

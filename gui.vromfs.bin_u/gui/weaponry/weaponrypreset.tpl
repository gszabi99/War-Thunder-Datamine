<<#presets>>
weaponryPreset {
  presetId:t='<<presetId>>'
  width:t='pw'
  padding:t='0, 1@blockInterval'
  <<#isCollapsable>>
  height:t='@buttonHeight'
  collapse_header:t='yes'
  collapsed:t='no'
  collapsing:t='no'
  on_click:t='onCollapse'
  bgcolor:t='@menuButtonColorHover'
  btnName:t='A'
  showOrNoneOn:t='selectedOnConsole'
  ButtonImg {}
  <</isCollapsable>>
  <<^isCollapsable>>
  height:t='@tierIconSize'
  on_click:t='onModItemClick'
  on_dbl_click:t='onModItemDblClick'
  <</isCollapsable>>

  tdiv {
    width:t='pw'
    overflow:t='hidden'
    position:t='absolute'
    <<#weaponryItem>>
    tdiv {
      flow:t='horizontal'
      <<#isSelected>>
      selected:t='yes'
      <</isSelected>>
      tdiv {
        size:t='<<presetTextWidth>>, @tierIconSize'
        <<^hideWarningIcon>>
        warning_icon{
          position:t='relative'
          size:t='@cIco, @cIco'
          background-image:t='#ui/gameuiskin#new_icon'
          bgcolor:t='#FFFFFF'
        }
        <</hideWarningIcon>>
        textareaNoTab {
          width:t='pw<<^hideWarningIcon>>-1@cIco<</hideWarningIcon>>'
          position:t='relative'
          pos:t='0, 30@sf/@pf-0.5h'
          text:t='<<nameText>>'
          text-align:t='left'
          style:t='color:@<<itemTextColor>>;'
          smallFont:t='yes'
          <<#hideWarningIcon>>
          padding:t='1@blockInterval, 0'
          <</hideWarningIcon>>
        }
        img{
          id:t='image'
          size:t='pw-2@weaponIconPadding, ph-2@weaponIconPadding'
          pos:t='50%pw-50%w, 50%ph-50%h'
          position:t='absolute'

          <<@modUpgradeIcon>>
          upgradeImg {
            id:t='upgrade_img'
            upgradeStatus:t=''
          }
        }
      }
      <<#tiers>>
      tdiv{
        size:t='@tierIconSize, @tierIconSize'
        border:t='yes'
        border-color:t='@separatorBlockColor'
        img {
          size:t='pw, ph'
          position:t='relative'
          background-image:t='<<#img>><<img>><</img>>'
          background-position:t='6'
          background-repeat:t='expand'
        }
      }
      <</tiers>>
    }
    <</weaponryItem>>
  }

  <<#isCollapsable>>
  fullSizeCollapseBtn {
    total-input-transparent:t='yes'
    css-hier-invalidate:t='yes'
    activeText{}
    ButtonImg {}
    text {
      position:t='relative'
      pos:t='0.5pw-0.5w, 0.5ph-0.5h'
      text:t='<<purposeTypeName>>'
    }
  }
  <</isCollapsable>>
  focus_border {}
}
<</presets>>
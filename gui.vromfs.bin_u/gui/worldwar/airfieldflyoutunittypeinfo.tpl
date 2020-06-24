tdiv {
  position:t='relative'
  pos:t='0.5pw-0.5w'

  <<#unitTypes>>
  wwUnitClassNest {
    id:t='unit_class_<<unitType>>'
    padding:t='4@blockInterval, 0'
    css-hier-invalidate:t='yes'
    isEnabled:t='no'

    wwUnitClass {
      padding:t='2@blockInterval, 1@blockInterval'

      <<#classIcons>>
        <<#hasSeparator>>
          textareaNoTab {
            top:t='0.5(ph-h)'
            position:t='relative'
            text:t='#weapons_types/short/separatorVertical'
          }
        <</hasSeparator>>
        classIcon{
          text:t='#worldWar/iconAir<<name>>'
          tooltip:t='#mainmenu/type_<<type>>'
          unitType:t='<<type>>'
          zeroPos:t='yes'
          css-hier-invalidate:t='yes'
        }
      <</classIcons>>
    }

    tdiv {
      top:t='0.5(ph-h)'
      position:t='relative'
      flow:t='vertical'
      css-hier-invalidate:t='yes'

      textareaNoTab {
        id:t='required_text'
        text:t=''
        smallFont:t='yes'
      }
      textareaNoTab {
        id:t='amount_text'
        text:t=''
        smallFont:t='yes'
      }
    }
  }
  <</unitTypes>>
}

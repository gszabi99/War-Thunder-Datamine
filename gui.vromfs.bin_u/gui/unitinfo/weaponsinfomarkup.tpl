<<#weapons>>
tr {
  keyHolder {
    key {
      fullScrolled:t='yes'
      tdiv {
        <<#count>>
        tdiv {
          width:t='@weaponsCountColWidth'
          textareaNoTab { text:t='<<count>>' }
          textareaNoTab { text:t='#measureUnits/pcs' }
          <<#hiddenCount>>display:t='hide'<</hiddenCount>>
        }
        <</count>>
        tooltipLink {
          <<#isNotLink>>isNotLink:t='yes'<</isNotLink>>
          textareaNoTab {
            text:t='<<weaponNameLoc>>'
            <<#isTooltipByHold>>
            tooltipId:t='<<tooltipId>>'
            <</isTooltipByHold>>
            <<^isTooltipByHold>>
            tooltip:t='$tooltipObj'
            tooltipObj {
              tooltipId:t='<<tooltipId>>'
              on_tooltip_open:t='onGenericTooltipOpen'
              on_tooltip_close:t='onTooltipObjClose'
              display:t='hide'
            }
            <</isTooltipByHold>>
          }
        }
      }
    }
    <<#ammo>>
    dashedLine {}
    <</ammo>>
  }
  <<#ammo>>
  value {
    textareaNoTab { text:t='<<ammo>>' }
  }
  <</ammo>>
}

<</weapons>>
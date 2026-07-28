<<#weapons>>
tr {
  keyHolder {
    key {
      fullScrolled:t='yes'
      tdiv {
        <<#count>>
        tdiv {
          width:t='@weaponsCountColWidth'
          textareaNoTab { text:t='<<count>>x' }
          <<#hiddenCount>>display:t='hide'<</hiddenCount>>
        }
        <</count>>
        tooltipLink {
          <<#isNotLink>>isNotLink:t='yes'<</isNotLink>>
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
          textareaNoTab {
            text:t='<<weaponNameLoc>>'
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
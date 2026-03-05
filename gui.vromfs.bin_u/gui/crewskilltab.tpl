<<#tabs>>
crewTab {
  <<#id>>id:t='<<id>>'<</id>>
  width:t='pw'
  height:t='1@crewSkillTabHeight'
  css-hier-invalidate:t='yes'
  tooltip:t=''

  tooltipObj {
    id:t='upgrade_tooltip'
    display:t='hide'
    noPadding:t='yes'

    tdiv {
      padding:t='@frameMediumPadding'
      bgcolor:t='@weaponCardBackgroundColor'
      flow:t='vertical'

      textareaNoTab {
        id:t='upgrade_tooltip_header'
        text:t=''
        smallFont:t='yes'
        overlayTextColor:t='active'
      }

      textareaNoTab {
        id:t='upgrade_tooltip_skills_list'
        padding-top:t='@blockInterval'
        text:t=''
        smallFont:t='yes'
      }
    }
  }

  <<#tabImage>>
  crewTabImage {
    size:t='1@crewSkillTabHeight, 1@crewSkillTabHeight'
    margin-left:t='13@sf/@pf'
    margin-right:t='3@sf/@pf'
    img {
      background-image:t='<<tabImage>>'
      size:t='pw,ph'
      background-svg-size:t='pw,ph'
    }
  }
  <</tabImage>>

  textareaNoTab {
    <<^tabImage>>
    margin-left:t='30@sf/@pf'
    <</tabImage>>
    <<#id>>id:t='<<id>>_text'<</id>>
    text:t='<<tabName>>'
    position:t='relative'
    top:t='ph/2-h/2'
  }

  <<#cornerImg>>
  cornerImg {
    id:t='<<cornerImgId>>'
    background-image:t='<<cornerImg>>'
  }
  <</cornerImg>>
}
<</tabs>>

<<#objectives>>
wwObjective {
  id:t='<<id>>'
  status:t='<<status>>'
  <<#hasObjectiveDesc>>
  width:t='pw'
  <</hasObjectiveDesc>>
  <<^hasObjectiveDesc>>
  size:t='pw, 1@objectiveHeight'
  <</hasObjectiveDesc>>

  tdiv {
    pos:t='0, 50%ph-50%h'
    position:t='relative'
    width:t='pw'
    flow:t='vertical'
    tdiv {
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      <<#hasObjectiveDesc>>
      margin-top:t='1@framePadding'
      <</hasObjectiveDesc>>
      taskIcon {
        id:t='statusImg'
        background-image:t='<<statusImg>>'
      }
      wwObjectiveName {
        id:t='<<getNameId>>'
        text:t='<<getName>>'
        max-width:t='p.p.w-1@cIco'
      }
    }
    <<#hasObjectiveDesc>>
    desc {
      left:t='50%pw-50%w'
      position:t='relative'
      margin:t='0, 1@framePadding'
      text-align:t='center'
      text:t='<<getDesc>>'
      hideEmptyText:t='yes'
      max-width:t='pw'
    }
    <</hasObjectiveDesc>>
    tdiv {
      pos:t='50%pw-50%w, 0'
      position:t='relative'
      <<#hasObjectiveDesc>>
      margin-bottom:t='1@framePadding'
      <</hasObjectiveDesc>>
      paramsBlock {
        flow:t='vertical';
        width:t='pw';
        <<#getParamsArray>>
          tdiv {
            id:t='<<id>>'
            pos:t='50%pw-50%w, 0'
            position:t='relative'
            smallFont:t='yes';

            textareaNoTab {
              id:t='pName'
              text:t='<<pName>>'
            }
            textareaNoTab { text:t='#ui/colon' }
            textareaNoTab {
              id:t='pValue'
              text:t='<<pValue>>'
              overlayTextColor:t='active'
            }
          }
        <</getParamsArray>>
      }
      paramsBlock {
        pos:t='50%pw-50%w, 0'
        position:t='relative'
        <<#hasObjectiveZones>>
        objectiveZones {
          css-hier-invalidate:t='yes'
          on_hover:t='onHoverName'
          on_unhover:t='onHoverLostName'

          <<#getUpdatableZonesData>>
          textareaNoTab {
            id:t='<<id>>'
            text:t='<<text>>'
            team:t='<<team>>'
            input-transparent:t='yes'
            smallFont:t='yes'
          }
          <</getUpdatableZonesData>>
        }
        <</hasObjectiveZones>>

        <<#getUpdatableData>>
          updatableParam {
            id:t='<<id>>'
            status:t='<<status>>'
            width:t='pw'
            margin:t='0.02@scrn_tgt, 0'
            team:t='<<team>>'
            css-hier-invalidate:t='yes'
            smallFont:t='yes'
              textareaNoTab {
                id:t='pName'
                text:t='<<pName>>'
                <<#addHoverCb>>
                  on_hover:t='onHoverName'
                  on_unhover:t='onHoverLostName'
                <</addHoverCb>>
                <<#colorize>>
                  overlayTextColor:t='<<colorize>>'
                <</colorize>>
              }
              <<#pValue>>
                textareaNoTab { text:t='#ui/colon' }
                textareaNoTab {
                  id:t='pValue'
                  text:t='<<pValue>>'
                  overlayTextColor:t='<<#colorize>><<colorize>><</colorize>><<^colorize>>active<</colorize>>'
                }
              <</pValue>>
          }
        <</getUpdatableData>>
        textareaNoTab {
          id:t='updatable_data_text'
          margin-left:t='1@blockInterval'
          text:t='<<getUpdatableDataDescriptionText>>'
          tooltip:t='<<getUpdatableDataDescriptionTooltip>>'
          hideEmptyText:t='yes'
          overlayTextColor:t='active'
          smallFont:t='yes'
        }
      }
    }
  }
  <<^isLastObjective>>
    <<#isPrimary>>
      objectiveTextSeparator {
        separatorLine {}
        textareaNoTab { text:t='#worldwar/airfield/conditions_separator' }
        separatorLine {}
      }
    <</isPrimary>>
    <<^isPrimary>>
      objectiveSeparator{ inactive:t='yes' }
    <</isPrimary>>
  <</isLastObjective>>
}

<</objectives>>

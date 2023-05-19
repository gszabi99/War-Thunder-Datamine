<<#rows>>
  modBlockHor {
    <<#id>>id:t='<<id>>'<</id>>
    width:t='<<width>>@modCellWidth'
    pos:t='<<offsetX>>@modCellWidth, (<<offsetY>> + <<top>>)*1@modCellHeight'
    type:t='<<rowtype>>'

    <<#tierText>>
    modBlockTierNum {
      pos:t='-w, 0.33@modCellHeight'
      text:t='<<tierText>>'

      <<#needTierArrow>>
      modArrow {
        height:t='1@modCellHeight - 1@modBlockTierNumHeight'
        pos:t='0.5pw-0.5w-1, -h'
        type:t='down'
        modArrowPlate{
          id:t='<<id>>_txt'
        }
      }
      <</needTierArrow>>
    }
    <</tierText>>
  }
<</rows>>

modBlockHeaderRow {
  pos:t='<<offsetX>>@modCellWidth, <<offsetY>>@modCellHeight-h'
  <<#headerClass>>class:t='<<headerClass>>'<</headerClass>>

  <<#columnsList>>
    <<#needDivLine>>
    tdiv {
      size:t='1@dp, <<height>>@modCellHeight-4@dp'
      pos:t='0, ph+2@dp'
      position:t='relative'
      background-color:t='@modSeparatorColor'
    }
    <</needDivLine>>
    <<#name>>
    modBlockHeader {
      id:t='header_<<id>>'
      width:t='<<width>>@modCellWidth'
      <<#needDivLine>>
      pos:t='-1@dp, 0'
      tdiv {
        size:t='1@dp, ph-1@dp'
        position:t='absolute'
        background-color:t='@modBgColor'
      }
      <</needDivLine>>
      tdiv {
        size:t='pw, ph'
        overflow:t='hidden'
        textareaNoTab {
          pos:t='0, 0.5ph-0.5h'
          position:t='relative'
          <<#isSmallFont>>
          smallFont:t='yes'
          auto-scroll:t='medium'
          <</isSmallFont>>
          text:t='<<name>>'
        }
      }
      <<#haveWarning>>
      warning_icon{
        id:t='<<warningId>>_warning'
        size:t='@cIco, @cIco'
        pos:t='1@modCellWidth-w, 0.5ph-0.5h'
        position:t='absolute'
        background-image:t='#ui/gameuiskin#new_icon.svg'
        background-svg-size:t='@cIco, @cIco'
        bgcolor:t='#FFFFFF'
      }
      <</haveWarning>>
    }
    <</name>>
  <</columnsList>>
}
table {
  id:t='country_stats';
  width:t='pw'
  overflow-w:t='auto';
  class:t='mpTable'

  tr {
    height:t='@leaderboardHeaderHeight'
    background-color:t='@separatorBlockColor'
    td {
      activeText {
        position:t='relative'
        pos:t='1@blockInterval, 0.5ph-0.5h'
        text:t='<<tableName>>'
      }
    }
    <<#columns>>
    td {
      img {
        size:t='@cIco, @cIco';
        left:t='0.5pw - 0.5w';
        top:t='0.5ph - 0.5h';
        position:t='relative';
        background-image:t='<<icon>>';
        background-svg-size:t='@cIco, @cIco';
      }
    }
    <</columns>>
  }

  tr {
    tooltip:t='#profile/units_own';
    td {
      img {
        size:t='@cIco, @cIco';
        position:t='relative';
        pos:t='0.5pw - 0.5w, 0';
        background-image:t='#ui/gameuiskin#unit_amount_icon';
        background-svg-size:t='@cIco, @cIco';
      }
    }
    <<#columns>>
    td {
      activeText {
        pos:t='0.5pw - 0.5w';
        position:t='relative';
        text:t='<<unitsCount>>';
        text-align:t='center';
      }
    }
    <</columns>>
  }

  tr {
    tooltip:t='#profile/elite_units_own';
    td {
      img {
        size:t='@cIco, @cIco';
        position:t='relative';
        pos:t='0.5pw - 0.5w, 0';
        background-image:t='#ui/gameuiskin#item_icon_elite';
        background-svg-size:t='@cIco, @cIco';
      }
    }
    <<#columns>>
    td {
      activeText {
        pos:t='0.5pw - 0.5w';
        position:t='relative';
        text:t='<<eliteUnitsCount>>';
        text-align:t='center';
      }
    }
    <</columns>>
  }
}

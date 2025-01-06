function collectPointsStep(argIndex, argsStr, data, tbl, content, unitSystemName)
{
  const format = data.format
  if (tbl == undefined)
    return
  else if (argIndex < format.args.length - 1)
  {
    var argData = format.args[argIndex]
    var newArgStr = argsStr + argData.name + ' = ' + convertToUnit(tbl[0], argData.unit, unitSystemName).toFixed(argData.precision) + ', '
    collectPointsStep(argIndex + 1, newArgStr, data, tbl[1], points, unitSystemName)
  }
  else
  {
    for (var curveIndex in format.curves)
    {
      var curveFormat = format.curves[curveIndex];
      var curveData = tbl[curveIndex]
      var allPoints = []
      for (var lineIndex in curveData)
      {
        var line = curveData[lineIndex]
        var argData = line[curveFormat.argIndex]
        if (argData != null)
        {
          var arg = convertToUnit(argData, curveFormat.invertAxes ? data.yAxes[curveFormat.argAxis].unit : data.xAxes[curveFormat.argAxis].unit, unitSystemName)
          var valuesData = line[curveFormat.valuesIndex]
          if (valuesData != null)
          {
            for (var valueSetIndex in curveFormat.values)
            {
              var valueSet = valuesData[valueSetIndex]
              if (valueSet != null)
              {
                while (allPoints.length <= valueSetIndex)
                  allPoints.push([])
                for (var valueIndex in curveFormat.values)
                {
                  var valueFormat = curveFormat.values[valueIndex]
                  if (valueFormat.enabled)
                  {
                    var valueData = valueSet[valueFormat.index]
                    if (valueData != null)
                    {
                      while (allPoints[valueSetIndex].length <= valueIndex)
                        allPoints[valueSetIndex].push([])
                      var value = convertToUnit(valueData, curveFormat.invertAxes ? data.xAxes[valueFormat.axis].unit : data.yAxes[valueFormat.axis].unit, unitSystemName)
                      allPoints[valueSetIndex][valueIndex].push(curveFormat.invertAxes ? [ value, arg ] : [ arg, value ])
                    }
                  }
                }
              }
            }
          }
        }
      }
      for (var valueSetIndex = 0; valueSetIndex < allPoints.length; ++valueSetIndex)
        for (var valueIndex = 0; valueIndex < allPoints[valueSetIndex].length; ++valueIndex)
        {
          var valueFormat = curveFormat.values[valueIndex]
          var points = allPoints[valueSetIndex][valueIndex]
          if (points.length > 0)
          {
            var name = valueFormat.name
            if (allPoints.length > 1)
              name = name + (valueSetIndex + 1).toString()
            content.push(
            {
              label: curveFormat.argName != undefined ? valueFormat.name + '(' + argsStr + curveFormat.argName + ')' : valueFormat.name,
              xaxis: curveFormat.invertAxes ? valueFormat.axis + 1 : undefined,
              yaxis: curveFormat.invertAxes ? undefined : valueFormat.axis + 1,
              color: valueFormat.color[valueSetIndex],
              //lines: { lineWidth: valueFormat.width - valueSetIndex * 0.5 },
              lines: { lineWidth: valueFormat.width - valueSetIndex },
              data: points
            })
          }
        }
    }
  }
}

function collectPoints(data, tables, unitSystemName)
{
  var content = []
  collectPointsStep(0, '', data, tables[data.tableName], content, unitSystemName)
  return content
}

function updateChartGroup(chartsData, group, charts, tables, unitSystemName)
{
  var chartGroupData = chartsData[group]
  if (chartGroupData != undefined &&
      chartGroupData.enabled)
  {
    var chartGroup = charts[group]  
    for(var i = 0; i < chartGroup.length; i++ )
    {
      var chartData = chartGroupData.charts[i]
      chartGroup[i].setData(chartData.func(chartData, tables, unitSystemName))
      chartGroup[i].draw();
    }
  }
}
  
function updateCharts(chartsData, charts, tables, unitSystemName)
{
  for (group in chartsData)
    updateChartGroup(chartsData, group, charts, tables, unitSystemName)
}

function buildTicks(axis)
{
  var dist = axis.max - axis.min
  var middle = (axis.max + axis.min) * 0.5
  var percent = dist / middle
  axis.min = Math.min(axis.min, middle * 0.9)
  axis.max = Math.max(axis.max, middle * 1.1)
  dist = axis.max - axis.min

  var step = dist / 10.0
  var power = Math.floor(Math.log(step) / Math.log(10.0))
  const stepVariants = [ 1, 2, 5 ]
  var stepMul = step / Math.pow(10.0, power)
  
  var finalStep = step
  if (stepMul > 7.5)
    finalStep = Math.pow(10.0, power + 1)
  else if (stepMul > 3.5)
    finalStep = 5.0 * Math.pow(10.0, power)
  else if (stepMul > 1.5)
    finalStep = 2.0 * Math.pow(10.0, power)
  else
    finalStep = 1.0 * Math.pow(10.0, power)
    
  var res = [], i = Math.floor(axis.min / finalStep);
  do {
    var v = i * finalStep
    res.push(v);
    ++i;
  } while (v < axis.max);
  return res
}

function buildAxes(axes, unitSystemName)
{
  var result = [] 
  result.length = axes.length
  for (var i = 0; i < axes.length; ++i)
  {
    var axis = axes[i]
    result[i] = {
      axisLabel: axis.unit != undefined ? axis.name + ', ' + getUnitName(axis.unit, unitSystemName) : axis.name,
      alignTicksWithAxis: axis.alignTicksWithAxis,
      position: axis.position,
      axisLabelUseCanvas: true,
      axisLabelFontSizePixels: 16,
      axisLabelFontFamily: 'Arial',
      min: axis.min && convertToUnit(axis.min, axis.unit, unitSystemName),
      max: axis.max && convertToUnit(axis.max, axis.unit, unitSystemName),
      ticks: buildTicks,
      reserveSpace: axis.reserveSpace,
      labelWidth: axis.labelWidth
    }
  }
  return result
}

function buildMarkings(markings, xAxes, yAxes, tables, unitSystemName)
{
  if (markings != undefined)
  {
    var result = []
    result.length = markings.length
    for (var i = 0; i < markings.length; ++i)
    {
      var marking = markings[i]
      if (marking.enabled)
      {      
        var xAxis = undefined
        if (marking.xAxis != undefined)
        {
          var value = convertToUnit(marking.value != undefined ? marking.value : tables[marking.tableName][marking.paramName],
            xAxes[marking.xAxis].unit, unitSystemName)
          xAxis = { from: value, to: value}
        }
        var yAxis = undefined
        if (marking.yAxis != undefined)
        {
          var value = convertToUnit(marking.value != undefined ? marking.value : tables[marking.tableName][marking.paramName],
            yAxes[marking.yAxis].unit, unitSystemName)
          yAxis = { from: value, to: value}
        }
        result[i] = {
          xaxis: xAxis,
          yaxis: yAxis,
          color: marking.color,
          lineWidth: marking.width
        }
      }
    }
    return result
  }
  else
    return undefined
}

function setupCharts(chartsData, charts, tables, unitSystemName)
{
  $(function() {
    for (group in chartsData)
    {
      var chartGroupData = chartsData[group]
      if (chartGroupData.enabled)
      {
        charts[group] = []
        var contents = []
        contents.length = chartGroupData.charts.length
        
        for (var i = 0; i < chartGroupData.charts.length; ++i)
        {
          var chartData = chartGroupData.charts[i]
          var content = chartData.func(chartData, tables, unitSystemName)
          contents[i] = content
          
          for (var seriesIndex in content)
          {
            var series = content[seriesIndex]
            if (series.data.length > 0)
            {
              if (series.xaxis)
              {
                var min = series.data[0][0]
                var max = series.data[0][0]
                for (var pointIndex = 1; pointIndex < series.data.length; ++pointIndex)
                {
                  min = Math.min(min, series.data[pointIndex][0])
                  max = Math.max(max, series.data[pointIndex][0])
                }
                var axis = chartData.xAxes[series.xaxis - 1]
                var minStd = convertFromUnit(min, axis.unit, unitSystemName)
                var maxStd = convertFromUnit(max, axis.unit, unitSystemName)
                axis.min = axis.min ? Math.min(axis.min, minStd) : minStd
                axis.max = axis.max ? Math.max(axis.max, maxStd) : maxStd
              }
              else if (series.yaxis)
              {
                var min = series.data[0][1]
                var max = series.data[0][1]
                for (var pointIndex = 1; pointIndex < series.data.length; ++pointIndex)
                {
                  min = Math.min(min, series.data[pointIndex][1])
                  max = Math.max(max, series.data[pointIndex][1])
                }
                var axis = chartData.yAxes[series.yaxis - 1]
                var minStd = convertFromUnit(min, axis.unit, unitSystemName)
                var maxStd = convertFromUnit(max, axis.unit, unitSystemName)
                axis.min = axis.min ? Math.min(axis.min, minStd) : minStd
                axis.max = axis.max ? Math.max(axis.max, maxStd) : maxStd
              }
            }
          }
        }
        
        if (chartGroupData.alignByArg)
        {
          var firstSeries = contents[0][0]
          var min = firstSeries.data[0][0]
          var max = firstSeries.data[0][0]
          for (var i = 0; i < chartGroupData.charts.length; ++i)
          {
            var content = contents[i]
            for (var seriesIndex in content)
            {
              var series = content[seriesIndex]
              for (var pointIndex = 1; pointIndex < series.data.length; ++pointIndex)
              {
                min = Math.min(min, series.data[pointIndex][0])
                max = Math.max(max, series.data[pointIndex][0])
              }
            }
          }
          for (var i = 0; i < chartGroupData.charts.length; ++i)
          {
            var axis = firstSeries.yaxis ? chartGroupData.charts[i].xAxes[0] : chartGroupData.charts[i].yAxes[0]
            var minStd = convertFromUnit(min, axis.unit, unitSystemName)
            var maxStd = convertFromUnit(max, axis.unit, unitSystemName)
            axis.min = axis.min ? Math.min(axis.min, minStd) : minStd
            axis.max = axis.max ? Math.max(axis.max, maxStd) : maxStd
          }
        }
          
        for (var i = 0; i < chartGroupData.charts.length; ++i)
        {
          var chartData = chartGroupData.charts[i]
          if (chartData.captionId != undefined)
            document.getElementById(chartData.captionId).innerHTML = chartData.name          
          
          var chartGroup = charts[group]
          var chartObj = $('#' + chartData.chart)
          
          var params = {
            series: {
              lines: {
                show: true
              },
              shadowSize: 0
            },
            grid: { markings: buildMarkings(chartData.markings, chartData.xAxes, chartData.yAxes, tables, unitSystemName) },
            xaxes: buildAxes(chartData.xAxes, unitSystemName),
            yaxes: buildAxes(chartData.yAxes, unitSystemName),
            zoom: {
              realTime: false
            },
            pan: {
              realTime: false
            },
            legend: {
              labelBoxBorderColor: "Black",
              position: chartData.legendPosition
            }
          }

          chartGroup[i] = $.plot(chartObj, contents[i], params);
        }
      }
    }
    updateCharts(chartsData, charts, tables, unitSystemName)
  });
}

  function resetPlotsRanges(chartsData)
  {
    for (group in chartsData)
    {
      var chartGroupData = chartsData[group]
      for (var i = 0; i < chartGroupData.charts.length; ++i)
      {
        var chartData = chartGroupData.charts[i]
        for (var xAxisIndex in chartData.xAxes)
          chartData.xAxes[xAxisIndex].min = chartData.xAxes[xAxisIndex].max = null
        for (var yAxisIndex in chartData.yAxes)
          chartData.yAxes[yAxisIndex].min = chartData.yAxes[yAxisIndex].max = null
      }
    }
  }
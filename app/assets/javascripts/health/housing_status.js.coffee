#= require ./namespace

class App.Health.HousingStatus
  constructor: (@chart_selector, @data) ->
    Chart.defaults.global.defaultFontSize = 10
    @color_map = {}
    @next_color = 0
    @_build_charts()


  _build_charts: () =>
    data = {
      x: 'x',
      columns: @data,
      type: 'bar',
      color: @_colors,
      labels: true,
    }
    bb.generate({
      data: data,
      bindto: @chart_selector,
      axis: {
        rotated: true,
        x: {
          type: 'category',
        }
      }
    })

  _colors: (c, d) =>
    key = d
    if key.id?
      key = key.id
    colors = [ '#51ACFF', '#45789C', ]
    if key in ['All']
      color = '#288BEE'
    else
      color = @color_map[key]
      if !color?
        color = colors[@next_color++]
        @color_map[key] = color
        @next_color = @next_color % colors.length
    return color


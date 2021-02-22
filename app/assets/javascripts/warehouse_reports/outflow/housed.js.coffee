#= require ./namespace

class App.WarehouseReports.Outflow.Housed
  constructor: (@chart_selector, @data, @support_url) ->
    Chart.defaults.global.defaultFontSize = 10
    @color_map = {}
    @next_color = 0
    @_build_chart()

  _build_chart: () =>
    @chart = bb.generate({
      data:
        x: 'x'
        columns: @data.data
        color: @_colors
        onclick: @_follow_link
      axis:
        x:
          type: 'category'
          tick:
            culling:
              max: 8
        y:
          tick:
            count: 7
            format: d3.format(",.0f")
          padding: 0
          min: 0
      grid:
        x:
          show: true
          ticks: 4
        y:
          show: true
          ticks: 4
      size:
        height: 200
      bindto: @chart_selector
    })


  _colors: (c, d) =>
    key = d
    if key.id?
      key = key.id
    colors = [ '#091f2f', '#fb4d42', '#288be4', '#d2d2d2' ]
    if key in ['All']
      color = '#288BEE'
    else
      color = @color_map[key]
      if !color?
        color = colors[@next_color++]
        @color_map[key] = color
        @next_color = @next_color % colors.length
    return color


  _follow_link: (d, e) =>
    # if d.name != 'All'
    month = @data.labels[d.index + 1]
    url = @support_url + encodeURI("&selected_project=#{d.name}&month=#{month}")
    # console.log(d, @data, url)

    $('.modal .modal-content').html('Loading...')
    $('.modal').modal('show')
    $('.modal .modal-content').load(url)

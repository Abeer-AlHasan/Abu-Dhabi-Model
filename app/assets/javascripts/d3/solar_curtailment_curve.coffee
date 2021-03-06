D3.solar_curtailment_curve =
  View: class extends D3.dynamic_demand_curve.View
    downsampleWith: 'max'

    draw: ->
      super

      @serieSelect = new D3ChartSerieSelect(@container_selector(),
                                            @serieSelectOptions())
      @serieSelect.draw(@refresh.bind(this))

    refresh: ->
      super()

      noData = _.all(
        @visibleData(),
        (s) => _.all(@model.series.with_gquery(s.key).future_value(), (v) -> v == 0)
      )

      if noData
        @svg.selectAll('g.no-data').style('display', 'inline')
      else
        @svg.selectAll('g.no-data').style('display', 'none')

      # Update each series tooltip and fill since the paths are re-used when a
      # new series is selected.
      @svg.selectAll('g.serie')
        .selectAll('path')
        .attr('class', (data) -> "area " + data.key)
        .attr('fill', (data) -> data.color )
        .attr('data-tooltip-text', (d) -> d.label)

    # When a slider is (re)set to zero while showing in the chart,
    # the zeroed series will remain in the chart data as there is
    # no new data to overwrite it. Because the series still appears in
    # the legend, its opcatiy is NOT set to 0. Therefore all g.series
    # are removed to ensure a full redraw.
    initialDraw: (xScale, yScale, area, line) ->
      @svg.selectAll('g.serie').remove()
      @svg.selectAll('g.no-data').remove()

      super(xScale, yScale, area, line)

      @svg.append('g')
        .attr('class', 'no-data')
        .append('foreignObject')
        .attr('width', @width + @margins.left + 2)
        .attr('height', 100)
        .attr('x', -@margins.left)
        .attr('y', (@height - @margins.bottom - 10) / 2)
        .append('xhtml:p')
        .attr('xmlns', 'http://www.w3.org/1999/xhtml')
        .text(
          I18n.t(
            'output_elements.empty.' + this.model.get('key'),
            { defaults: [{ scope: 'output_elements.common.empty' }] }
          )
        )

    visibleData: ->
      val = @serieSelect?.selectBox.val() || @serieSelectOptions()[0].match
      super().filter((serie) -> serie.key.includes(val))

    getLegendSeries: ->
      legendSeries = []
      val = @serieSelect.selectBox.val()
      @series.forEach (serie) ->
        if serie.attributes.gquery_key.includes(val) &&
            serie.future_value().find((v) => v != 0)
          legendSeries.push(serie)

      legendSeries

    serieSelectOptions: ->
      if (@model.get('config') && @model.get('config').serie_selections)
        @model.get('config').serie_selections.map((option) -> { match: option })
      else
        _(@series)
          .sortBy((serie) -> serie.get('label').toLowerCase())
          .map((serie) -> {
            match: serie.get('gquery_key'),
            name: serie.get('label'),
            group: serie.get('group')
          })

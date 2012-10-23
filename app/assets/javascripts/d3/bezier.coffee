D3.bezier =
  View: class extends D3ChartView
    el: 'body'
    initialize: ->
      @key = @model.get 'key'

      @start_year = App.settings.get('start_year')
      @end_year = App.settings.get('end_year')
      @initialize_defaults()

    can_be_shown_as_table: -> true

    outer_height: -> 400

    # This chart rendering is fairly complex. Here is the big picture:
    # this bezier chart is basically a stacked area chart. D3 provides some
    # utility methods that calculate the offset for stacked data. It expects
    # data to be given in a specific format and then it will add the
    # calculated attributes in place. Check the y0 attribute for instance.
    #
    # Once we have the stacked data, grouped by serie key, we can pass the array
    # of values to the SVG area method, that will create the SVG attributes
    # required to draw the paths (and add some nice interpolations)
    #
    draw: =>
      margins =
        top: 20
        bottom: 200
        left: 20
        right: 30

      @width = 494 - (margins.left + margins.right)
      @height = 360 - (margins.top + margins.bottom)
      # height of the series section
      @series_height = 190
      @svg = d3.select("#d3_container_#{@key}")
        .append("svg:svg")
        .attr("height", @height + margins.top + margins.bottom)
        .attr("width", @width + margins.left + margins.right)
        .append("svg:g")
        .attr("transform", "translate(#{margins.left}, #{margins.top})")

      legend_columns = if @model.series.length > 6 then 2 else 1
      @draw_legend
        svg: @svg
        series: @model.series.models
        width: @width
        vertical_offset: @series_height + 20
        columns: legend_columns

      # the stack method will filter the data and calculate the offset for every
      # item. The values function tells this method that the values it will
      # operate on are an array held inside the values member. This member will
      # be filled automatically by the nesting method
      @stack_method = d3.layout.stack().offset('zero').values((d) -> d.values)
      # This method groups the series by key, creating an array of objects
      @nest = d3.nest().key((d) -> d.id)
      # Run the stack method on the nested entries
      stacked_data = @stack_method(@nest.entries @prepare_data())

      @x = d3.scale.linear().range([0, @width - 15])
        .domain([@start_year, @end_year])

      # show years at the corners
      @svg.selectAll('text.year')
        .data([App.settings.get('start_year'), App.settings.get('end_year')])
        .enter().append('svg:text')
        .attr('class', 'year')
        .text((d) -> d)
        .attr('x', (d, i) => if i == 0 then -10 else 430)
        .attr('y', @series_height + 15)

      @y = d3.scale.linear().range([0, @series_height]).domain([0, 7])
      @inverted_y = d3.scale.linear().range([@series_height, 0]).domain([0, 7])

      # This method will return the SVG area attributes. The values it receives
      # should be already stacked
      @area = d3.svg.area()
        .interpolate('basis')
        .x((d) => @x d.x)
        .y0((d) => @inverted_y d.y0)
        .y1((d) => @inverted_y(d.y0 + d.y))

      # there we go
      series = @svg.selectAll('path.serie')
        .data(stacked_data, (s) -> s.key)
        .enter().append('svg:path')
        .attr('class', 'serie')
        .attr('d', (d) => @area d.values)
        .style('fill', (d) => d.values[0].color)
        .style('opacity', 0.8)
        .attr('data-title', (d) -> d.values[0].label)

      # draw a nice axis
      @y_axis = d3.svg.axis()
        .scale(@inverted_y)
        .ticks(4)
        .tickSize(-440, 10, 0)
        .orient("right")
        .tickFormat((x) => Metric.autoscale_value x, @model.get('unit'))
      @svg.append("svg:g")
        .attr("class", "y_axis inner_grid")
        .attr("transform", "translate(#{@width - 15}, 0)")
        .call(@y_axis)

      # series tooltips
      $('path.serie').qtip
        content:
          title: -> $(this).attr('data-title')
          text: -> $(this).attr('data-tooltip')
        position:
          target: 'mouse'
          my: 'bottom right'
          at: 'top center'

    refresh: =>
      # calculate tallest column
      tallest = Math.max(
        _.sum(@model.values_present()),
        _.sum(@model.values_future())
      )
      # update the scales as needed
      @y = @y.domain([0, tallest])
      @inverted_y = @inverted_y.domain([0, tallest])

      # animate the y-axis
      @svg.selectAll(".y_axis").transition().call(@y_axis.scale(@inverted_y))

      # and its grid
      @svg.selectAll('g.rule')
        .data(@y.ticks())
        .transition()
        .attr('transform', (d) => "translate(0, #{@inverted_y(d)})")

      # See above for explanation of this method chain
      stacked_data = @stack_method(@nest.entries @prepare_data())

      @svg.selectAll('path.serie')
        .data(stacked_data, (s) -> s.key)
        .transition()
        .attr('d', (d) => @area d.values)
        .attr('data-tooltip', (d) => "
          #{@start_year}: #{Metric.autoscale_value d.values[0].y, @model.get 'unit'}</br>
          #{@end_year}: #{Metric.autoscale_value d.values[2].y, @model.get 'unit'}
        ")

    # We need to pass the chart series through the stacking function and the SVG
    # area function. To do this let's format the data as an array. An
    # interpolated mid-point is added to generate a S-curve.
    prepare_data: =>
      left_stack  = 0
      mid_stack   = 0
      right_stack = 0
      # The mid point should be between the left and side value, which are
      # stacked
      series = @model.non_target_series().map (s) =>
        # let's calculate the mid point boundaries
        min_value = Math.min(left_stack + s.present_value(), right_stack + s.future_value())
        max_value = Math.max(left_stack + s.present_value(), right_stack + s.future_value())

        mid_point = if s.safe_future_value() > s.safe_present_value()
          s.safe_present_value()
        else
          s.safe_future_value()

        mid_point += mid_stack

        mid_point = if mid_point < min_value
          min_value
        else if mid_point > max_value
          max_value
        else
          mid_point
        # the stacking function wants the non-stacked values
        mid_point -= mid_stack

        mid_stack += mid_point
        left_stack += s.safe_present_value()
        right_stack += s.safe_future_value()

        gquery = s.get 'gquery_key'

        mid_year = (@start_year + @end_year) / 2

        out = [
          {
            x: @start_year
            y: s.safe_present_value()
            id: gquery
            color: s.get('color')
            label: s.get('label')
          },
          {
            x: mid_year
            y: mid_point
            id: gquery
            color: s.get('color')
          },
          {
            x: @end_year
            y: s.safe_future_value()
            id: gquery
            color: s.get('color')
          }
        ]
      _.flatten series

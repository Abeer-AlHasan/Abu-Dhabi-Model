class @MeritOrder
  constructor: (app) ->
    @app = app
    @gquery = gqueries.find_or_create_by_key 'dashboard_merit_order'

  dashboard_value: =>
    return null unless @app.settings.merit_order_enabled()
    q = @gquery.future_value()
    profitables = _.select(_.values(q), (v) -> v.profitable == 'profitable' ).length
    tot = _.keys(q).length
    profitables/tot

  format_table: =>
    tmpl = _.template $('#merit-order-table-template').html()
    items = []
    for key, values of @gquery.future_value()
      value = if @app.settings.merit_order_enabled()
        values.profitable
      else
        'N/A'
      items.push
        profitable: value
        key: key
        position: values.position
        capacity: values.capacity
        full_load_hours: values.full_load_hours
        profits: values.profits


    data = {series: items}

    $('#merit-order-table').html tmpl(data)
    true



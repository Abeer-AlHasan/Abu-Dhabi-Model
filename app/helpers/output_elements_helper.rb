module OutputElementsHelper
  def output_element_serie(serie)
    s = {      
      :id         => serie.id, # needed for block charts
      :gquery_key => serie.gquery_or_key_for_etengine,
      :color      => serie.converted_color,
      :label      => serie.title_translated,
      :group      => serie.group
    }

    "output_element.series.add(#{s.to_json});"
  end
  
  # Used in the constraint popups
  def js_for_output_element(id, dom_id)
    element = OutputElement.find(id) rescue nil
    return unless element
    
    chart_options = element.options_for_js.merge(:container => dom_id).to_json
    series_options = element.allowed_output_element_series.map{|s| output_element_serie(s)}.join
    
    out = <<EOJS
    
    var output_element = new Chart(#{chart_options});
    #{series_options}
    charts.add(output_element);
    
EOJS
    out.html_safe
  end
  
  # TODO: make a generic one
  def render_prediction_chart(c)
    out = <<EOJS
      InitializePolicyLine(
        'prediction_chart',
        [[1,2],[3,4]],
        '#{c.unit}',
        [0,4],
        ['#234876', '#826151'],
        ['foo', 'bar']
      )
EOJS
  end
end
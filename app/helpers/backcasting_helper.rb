module BackcastingHelper
  def describe_prediction(p)
    value = "%.1f" % p.corresponding_slider_value rescue nil
    slider = p.input_element
    if @end_year
      if ['growth_rate', 'efficiency_improvement'].include?(slider.command_type)
        "#{value}#{slider.unit} #{I18n.t('prediction.average_per_year')} #{@end_year}"
      else
        "#{value}#{slider.unit} in #{@end_year}"
      end
    else
      "#{value}#{slider.unit}"
    end
  end
end
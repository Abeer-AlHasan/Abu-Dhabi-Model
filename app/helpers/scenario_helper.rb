# frozen_string_literal: true

module ScenarioHelper
  # Determines if the user should be shown the tooltip highlighting the results
  # section.
  def show_results_tip?
    # Logged-in user who has the tip hidden?
    return false if current_user&.hide_results_tip

    setting = session[:hide_results_tip]

    return true unless setting
    return false if setting == :all

    setting != Current.setting.api_session_id
  end

  # Public: Parses a scenario or preset description with Markdown, removing any
  # unsafe links.
  #
  # Returns an HTML safe string.
  def formatted_scenario_description(description, allow_external_links: false)
    # First check if the description has a div matching the current locale,
    # indicating that a localized version is available.
    localized = Loofah.fragment(description).css(".#{I18n.locale}")

    rendered = RDiscount.new(
      localized.inner_html.presence || description || '',
      :no_image, :smart
    ).to_html

    sanitized = Rails::Html::SafeListSanitizer.new.sanitize(rendered)

    # rubocop:disable Rails/OutputSafety
    if allow_external_links
      add_rel_to_external_links(sanitized).html_safe
    else
      strip_external_links(sanitized).html_safe
    end
    # rubocop:enable Rails/OutputSafety
  end

  # Public: Parses the text as HTML, replacing any links to external sites with
  # only their inner text.
  #
  # Returns a string.
  def strip_external_links(text)
    link_stripper = Loofah.fragment(text)

    link_stripper.scrub!(Loofah::Scrubber.new do |node|
      next unless node.name == 'a'

      begin
        uri = URI(node['href'].to_s.strip)
      rescue URI::InvalidURIError
        node.replace(node.inner_text)
        next
      end

      next if uri.relative?

      domain = ActionDispatch::Http::URL.extract_domain(
        uri.host.to_s, ActionDispatch::Http::URL.tld_length
      )

      if !uri.scheme.start_with?('http') && domain != request.domain
        # Disallow any non-HTTP scheme.
        node.replace(node.inner_text)
        next
      end

      node.replace(node.inner_text) unless domain == request.domain
    end)

    link_stripper.inner_html
  end

  # Public: Adds a rel="noopener nofollow" attribute to any external links.
  #
  # Returns a string.
  def add_rel_to_external_links(text)
    link_stripper = Loofah.fragment(text)

    link_stripper.scrub!(Loofah::Scrubber.new do |node|
      next unless node.name == 'a'

      begin
        uri = URI(node['href'].to_s.strip)
        next if uri.relative?
      rescue URI::InvalidURIError
        # Remove the link with the text.
        node.replace(node.inner_text)
        next
      end

      domain = ActionDispatch::Http::URL.extract_domain(
        uri.host.to_s, ActionDispatch::Http::URL.tld_length
      )

      if !uri.scheme.start_with?('http') && domain != request.domain
        # Disallow any non-HTTP scheme.
        node.replace(node.inner_text)
        next
      end

      node[:rel] = 'noopener nofollow' unless domain == request.domain
    end)

    link_stripper.inner_html
  end

  # Public: Given a string, converts CO2 to have a subscript 2.
  #
  # Returns an HTML-safe string.
  def format_subscripts(string)
    # rubocop:disable Rails/OutputSafety
    h(string).gsub(/\bCO2\b/, 'CO<sub>2</sub>').html_safe if string.present?
    # rubocop:enable Rails/OutputSafety
  end

  # Public: Renders the HTML needed to show a price curve upload form.
  #
  # curve_name - The name/type of the curve.
  # input_name - An option input key which will be set to disabled if the
  #              scenario has a curve attached.
  def price_curve_upload(curve_name, input_key)
    render partial: 'scenarios/slides/price_curve_upload', locals: {
      associated_input: input_key,
      curve_name: curve_name,
      curve_type: :price
    }
  end

  # Public: Renders the HTML for an electricity interconnector price curve
  # upload form.
  #
  # num - The number of the interconnector (1-6).
  def interconnector_price_curve_upload(num)
    price_curve_upload(
      "interconnector_#{num}_price",
      "electricity_interconnector_#{num}_marginal_costs"
    )
  end

  # Public: Creates a link to view the source data behind the current area in the ETM Dataset
  # Manager.
  def link_to_datamanager_for_current_area
    "https://data.energytransitionmodel.com/datasets/#{Current.setting.area_code.split('_')[0]}"
  end

  # Public: Checks if the current area is a country. If so, a link to the Dataset Manager cannot
  # be generated. Pass on countries that are treated as regions in the Dataset Manager, like NI.
  def show_description_for_country?
    pass = %w[UKNI01_northern_ireland]
    Api::Area.find(Current.setting.area_code).country? and pass.exclude?(Current.setting.area_code)
  end

  # Public: Creates the warning message shown when the scenario was created with a previous version
  # of the model.
  def previous_version_scenario_warning(scenario, current_release_date)
    return if scenario.updated_at >= current_release_date

    t(
      'scenario.warning.message',
      last_updated: l(scenario.updated_at.to_date, format: :long),
      release_date: l(current_release_date.to_date, format: :long)
    )
  end
end

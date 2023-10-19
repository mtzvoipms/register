# frozen_string_literal: true

module ApplicationHelper
  def asset_present?(path)
    if Rails.configuration.assets.compile
      !Rails.application.assets.find_asset(path).nil?
    else
      Rails.application.assets_manifest.assets[path].present?
    end
  end

  def render_haml(haml)
    Haml::Engine.new(haml, escape_html: true).render(self)
  end

  def google_analytics
    return unless Rails.application.config.enable_analytics

    safe_join(
      [
        raw( # rubocop:disable Rails/OutputSafety
          <<-GA
          <script async src="https://www.googletagmanager.com/gtag/js?id=#{Rails.application.config.ga_tracking_id}"></script>
          <script>
            window.dataLayer = window.dataLayer || [];
            function gtag(){dataLayer.push(arguments);}
            gtag('js', new Date());

            gtag('config', '#{Rails.application.config.ga_tracking_id}', { anonymize_ip: true, client_storage: 'none' });
          </script>
          GA
        )
      ]
    )
  end

  def glossary_tooltip(label, glossary_key, position)
    tooltip(label, t("glossary.#{glossary_key}"), position)
  end

  def tooltip(label, title, position)
    content_tag(
      :span,
      label,
      data: { 'tippy-content' => title, 'tippy-placement' => position },
      class: 'tooltip-helper'
    )
  end

  def google_search_uri(params)
    uri = URI('https://www.google.com/search')
    uri.query = params.to_query
    uri.to_s
  end

  def opencorporates_officers_search_uri(params)
    uri = URI('https://opencorporates.com/officers')
    uri.query = params.to_query
    uri.to_s
  end

  PARTIAL_DATE_FORMATS = {
    1 => '%04d',
    2 => '%04d-%02d',
    3 => '%04d-%02d-%02d'
  }.freeze

  def partial_date_format(iso8601_date)
    return if iso8601_date.nil?

    PARTIAL_DATE_FORMATS[iso8601_date.atoms.size] % iso8601_date.atoms
  end

  REPORT_INCORRECT_DATA_URL = 'https://share.hsforms.com/1it46pw4MTL2L2jaUiepirA3upv4'

  def report_incorrect_data_url
    REPORT_INCORRECT_DATA_URL
  end

  FEEDBACK_FORM_URL = 'https://share.hsforms.com/1t-W-_8y1REuXNcXWxwTiaQ3upv4'

  def feedback_form_url
    FEEDBACK_FORM_URL
  end

  def transliteration_action(should_transliterate)
    link_to_if !should_transliterate, t('shared.transliteration.transliterate'), params_with_transliterated do
      link_to t('shared.transliteration.dont_transliterate'), params_without_transliterated
    end
  end

  def humanize_boolean(boolean)
    I18n.t(boolean.to_s)
  end

  private

  def params_with_transliterated
    request.params.dup.merge(transliterated: 'true')
  end

  def params_without_transliterated
    request.params.dup.merge(transliterated: nil)
  end
end

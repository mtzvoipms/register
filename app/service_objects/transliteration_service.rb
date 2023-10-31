# frozen_string_literal: true

class TransliterationService
  LANG_CODE_TO_RULE_SETS = {
    'uk' => 'Ukrainian-Latin/BGN'
  }.freeze

  def self.for(lang_code)
    @transliterators ||= {}
    @transliterators[lang_code] = new(lang_code) unless @transliterators.key?(lang_code)
    @transliterators[lang_code]
  end

  def initialize(lang_code)
    @lang_code = lang_code
  end

  def transliterate(value)
    # Return the original value if we have a blank value, blank lang code or the
    # lang code is not currently supported for transliteration
    return value if value.blank? || @lang_code.blank? || !LANG_CODE_TO_RULE_SETS.key?(@lang_code)

    rule_set.transform(value)
  rescue StandardError => e
    # We want to know about these errors, but we don't want them to crash a page
    # or an import.
    Rails.logger.error(e)
    value
  end

  private

  def rule_set
    rule_set_name = LANG_CODE_TO_RULE_SETS[@lang_code]
    @rule_set ||= TwitterCldr::Transforms::Transformer.get(rule_set_name)
  end
end

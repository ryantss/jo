module Jocale
  class << self

    def locales
      # Do not add :jo as a locale name
      @locales ||= [:en, :'zh-cn', :'zh-tw', :id, :ko]
    end

    def underscored_locales
      @underscored_locales ||= locales.collect{ |locale| underscore(locale) }
    end

    def aliases
      # locale => array of aliases
      @aliases ||= {
        :'zh-tw' => [:'zh-hk']
      }
    end

    def support?(locale)
      locales.include?(locale)
    end

    def localize(string, locale = nil)
      if locale
        "#{string}_#{underscore(locale)}".to_sym
      else
        underscored_locales.collect{ |locale| localize(string, locale) }
      end
    end

    # Convert a locale to underscored locale 
    def underscore(locale)
      "#{locale}".gsub(/-/, '_').to_sym
    end

  end
end
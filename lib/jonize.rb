module Jonize
  # Included in ActiveRecord::Base
  # You can turn a column into 2 types: Jo and i18n Jo
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    # Turn an AR column to a jo
    # Column name and the jo class to parse json for that column
    def jonize(name, clazz, options = {})
      name = name.to_sym
      options[:name] = name
      options[:class] = clazz
      meta = Metajo.new(options)

      get = name
      set = "#{name}=".to_sym
      check_changed = "#{name}_changed?".to_sym

      jo = "@#{name}"
      jo_changed = "@#{name}_changed"

      class_eval do
        define_method(get) do
          unless instance_variable_defined?(jo)
            if (json = read_attribute(name)).blank?
              # {} if meta.jo? || meta.hash?
              json = meta.array? ? '[]' : '{}'
            end
            if meta.array? || meta.hash?
              object = meta.class.new(meta.object_class, ::JSON.parse(json))
            else
              clazz.meta.merge!(options)
              object = clazz.new(::JSON.parse(json))
            end

            object = instance_variable_set(jo, object)
            object.root = name
            object.model = self
          end
          eval(jo)
        end

        # Write jo to column
        define_method(set) do |object|
          unless object.nil?
            object = meta.class.new(meta.object_class, object) if meta.hash? && object.is_a?(::Hash)
            object = meta.class.new(meta.object_class, object) if meta.array? && object.is_a?(::Array)
            object = meta.class.new(object) if meta.jo? && object.is_a?(::Hash)

            if meta.jo? || meta.array? || meta.hash?
              object.root = name
              object.model = self
            end
            raise TypeError, "Require an object of class #{clazz} for #{name}." unless object.is_a?(clazz)
          end

          # Mark changes when you assign a nil.
          if instance_eval(jo) != object || object.nil?
            instance_variable_set(jo_changed, true)
            instance_variable_set(jo, object)
          end
        end

        # Check if a jo_column is changed.
        define_method(check_changed) do
          eval(jo_changed) || instance_variable_set(jo_changed, false)
        end

        # Write the jo to column before save if there are changes.
        before_save :if => check_changed do |model|
          object = model.instance_variable_get(jo)
          object = object.to_hash if !object.nil? && (meta.jo? || meta.array? || meta.hash?)
          # Also write blank object.
          if object.blank?
            model.send(:write_attribute, name, nil)
          else
            model.send(:write_attribute, name, object.to_json)
          end
          true
        end

        after_save :if => check_changed do |model|
          model.instance_variable_set(jo_changed, false)
          true
        end
      end
    end

    def jonize_many(name, clazz, options = {})
      options[:object_class] ||= clazz
      options[:class] ||= Joray
      jonize(name, options[:class], options)
    end

    def jonize_i18n(name, clazz = String, options = {})
      options[:object_class] ||= clazz
      options[:class] ||= Joash
      jonize(name, options[:class], options)

      get_i18n = "#{name}_i18n".to_sym

      class_eval do
        define_method(get_i18n) do
          locale = defined?(I18n) ? I18n.locale.to_sym : :en
          locale = :en unless Jocale.support?(locale)

          object = send(name)[Jocale.underscore(locale)]
          object.blank? ? send(name)[:en] : object
        end

        # Accessors for each locale.
        Jocale.underscored_locales.each do |locale|
          name_locale = Jocale.localize(name, locale)

          define_method(name_locale) do
            send(name)[locale]
          end

          define_method("#{name_locale}=".to_sym) do |object|
            send(name)[locale] = object
          end
        end

        # Locale aliases.
        Jocale.aliases.each do |locale, aliases|
          locale = Jocale.localize(name, locale)

          aliases.each { |a| alias_method Jocale.localize(name, a), locale }
        end
      end
    end

    def jonize_many_i18n(name, options = {})
      options[:object_class] ||= String
      jonize_i18n(name, Joray, options)
    end

  end
end
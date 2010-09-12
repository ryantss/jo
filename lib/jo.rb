$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'blank'
require 'joray'
require 'joash'
require 'metajo'
require 'jocale'

class Jo
  # model is the object reflecting a row in MySQL.
  # Name of root object, which is the first jo object in the tree.
  attr_accessor :model, :root

  def initialize(hash = {})
    hash.each do |name, object|
      name = name.to_sym

      self.send("#{name}=", object) if self.class.meta.attributes[name]
    end
    self
  end

  def root=(root)
    self.class.meta.attributes.each do |name, attribute_meta|
      if (attribute_meta.jo? || attribute_meta.array? || attribute_meta.hash?) && !(attribute = eval("@#{name}")).nil?
        attribute.root = root
      end
    end
    @root = root
  end

  def model=(model)
    self.class.meta.attributes.each do |name, attribute_meta|
      if (attribute_meta.jo? || attribute_meta.array? || attribute_meta.hash?) && !(attribute = eval("@#{name}")).nil?
        attribute.model = model
      end
    end
    @model = model
  end

  # Notify the model so that it will update itself before save.
  def mark_changes
    !(@model.nil? || @root.nil?) && @model.instance_variable_set("@#{@root}_changed", true)
  end

  # It's better to use the hash to do hash#to_json and hash#blank?.
  # If you call object#to_json and object#blank? directly it might result in an wanted object.
  def to_hash
    hash = {}
    self.class.meta.attributes.each do |name, attribute_meta|
      object = eval("@#{name}")
      # Date and Time doesn't support json naturally, we have to convert it to String
      object = object.to_s if attribute_meta.date_time?
      object = object.to_hash if !object.nil? && (attribute_meta.jo? || attribute_meta.array? || attribute_meta.hash?)
      # False is blank by someone's definition but not ours. 
      hash[name] = object if object == false || !object.blank?
    end
    hash
  end

  class << self
    def meta
      # Clone from the superclass.attributes in case of inheritance.
      @meta ||= (self == Jo) ? Metajo.new : self.superclass.meta.clone
    end

    # Name of attribute
    # Class - enforce class for the attribute
    # Options - check Metajo
    def attribute(name, clazz = String, options = {})
      options[:name] = name
      options[:class] = clazz

      meta.attributes[name]
      # In case we override the attribute
      if (attribute_meta = meta.attributes[name]).nil?
        attribute_meta = meta.attributes[name] = Metajo.new(options)
      else
        attribute_meta.merge!(options)
        return
      end

      get = name
      set = "#{name}="
      attribute = "@#{name}"

      class_eval do
        define_method(get) do
          if !attribute_meta.available_if.nil? && !attribute_meta.available_if.call(model)
            raise ArgumentError, "Attribute #{name} is unavailable due to :available_if condition."
          end

          unless instance_variable_defined?(attribute)
            default = attribute_meta.cloned_default
            if !default.nil? && (attribute_meta.jo? || attribute_meta.array? || attribute_meta.hash?)
              default.root = self.root
              default.model = self.model
              instance_variable_set(attribute, default)
            end
          end
          eval(attribute)
        end

        define_method(set) do |object|
          if !attribute_meta.available_if.nil? && !attribute_meta.available_if.call(model)
            raise ArgumentError, "Attribute #{name} is unavailable due to :available_if condition."
          end

          unless object.nil?
            # If Joray but we have an ::Array.
            object = Joray.new(attribute_meta.object_class, object) if attribute_meta.array? && object.is_a?(::Array)

            # If Joash but we have an ::Hash
            object = Joash.new(attribute_meta.object_class, object) if attribute_meta.hash? && object.is_a?(::Hash)

            # If Jo but we have a ::Hash.
            object = attribute_meta.class.new(object) if attribute_meta.jo? && object.is_a?(::Hash)

            if attribute_meta.jo? || attribute_meta.array? || attribute_meta.hash?
              object.model = self.model unless self.model.nil?
              object.root = self.root unless self.model.nil?
            end

            # If Date Time but has a String.
            object = attribute_meta.class.parse(object) if attribute_meta.date_time? && object.is_a?(::String)
          end

          unless object.nil?
            unless object.is_a?(attribute_meta.class)
              raise ArgumentError, "Attribute #{name} expects class #{attribute_meta.class} for but get [#{object}] of class #{object.class}"
            end

            if !attribute_meta.validation.nil? && !attribute_meta.validation.call(object)
              raise ArgumentError, "Attribute #{name} cannot take [#{object}] due to :validation condition"
            end
          end

          if eval(attribute) != object
            mark_changes
            instance_variable_set(attribute, object)
          end
        end

      end
    end

    # Class must be String
    def attribute_i18n(name, clazz = String, options = {})
      options[:class] ||= Joash
      options[:object_class] ||= clazz
      options[:default] ||= Joash.new(clazz)

      # Check if the attribute is declared or not.
      if (attibute_meta = meta.attributes[name]).nil?
        attribute(name, options[:class], options)

        get_i18n = "#{name}_i18n".to_sym

        class_eval do
          Jocale.underscored_locales.each do |locale|
            name_locale = Jocale.localize(name, locale)

            define_method(name_locale) do
              send(name)[locale]
            end

            define_method("#{name_locale}=".to_sym) do |object|
              send(name)[locale] = object
            end
          end

          # Define alias reader methods for some locales
          Jocale.aliases.each do |locale, aliases|
            locale = Jocale.localize(name, locale)

            aliases.each { |a| alias_method Jocale.localize(name, a), locale }
          end

          # Define an accessor that can fallback to en
          define_method(get_i18n) do
            # If I18n is defined (e.g. in a Rails environment)
            locale = defined?(I18n) ? I18n.locale.to_sym : :en
            locale = :en unless Jocale.support?(locale)

            object = send(name)[Jocale.underscore(locale)]
            object.blank? ? send(name)[:en] : object
          end
        end
      else
        # Otherwise just merge the options to override old attribute.
        attibute_meta.merge!(options)
      end
    end

    def has_many(name, clazz = String, options = {})
      options[:class] ||= Joray
      options[:object_class] ||= clazz
      options[:default] ||= Joray.new(clazz)

      # Check if the attribute is declared or not.
      if (attibute_meta = meta.attributes[name]).nil?
        attribute(name, options[:class], options)
      else
        # Otherwise just merge the options to override old attribute.
        attibute_meta.merge!(options)
      end
    end

  end
end
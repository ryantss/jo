module Jovert
  # Included into a ActiveRecord::Base to help convert it Jo

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Set corresponding jo class, pass nil to get the current jo_class
    def jo_class(clazz = nil)
      clazz ? @jo_class = clazz : @jo_class
    end

  end

  # Convert current model to Jo
  def to_jo
    jo_class = self.class.jo_class
    jo = jo_class.new
    jo_class.meta.attributes.each do |name, meta_attribute|
      if self.respond_to?(name)
        jo.send("#{name}=", self.send(name))
      end
    end
    jo
  end
end
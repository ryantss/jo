class Metajo
  # :arrray class only used when :class is Joray
  attr_accessor :name, :class, :default, :attributes, :object_class
  attr_accessor :validation, :available_if

  def initialize(options = {})
    merge!(options)
    @attributes ||= {}
    self
  end

  def cloned_default
    # In case default cannot be cloned, e.g. NilClass, Fixnum or Symbol
    @default.clone rescue @default
  end

  def merge!(options = {})
    options.each do |name, value|
      send("#{name}=", value)
    end
    nil
  end

  def jo?
    @jo ||= @class <= Jo
  end

  def array?
    @array ||= @class <= Joray
  end

  def hash?
    @hash ||= @class <= Joash
  end

  def date_time?
    @date_time ||= @class <= Date || @class <= Time
  end

  def clone
    Metajo.new(:class => @class, :validation => @validation, :default => cloned_default, :attributes => @attributes.clone)
  end
end
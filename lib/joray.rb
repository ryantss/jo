class Joray < ::Array
  attr_accessor :root, :model, :object_class

  def initialize(clazz = nil, objects = [])
    # Only store class name.
    # If we store class itself we cannot dump this object because that class will be tained after we load it back.
    @object_class = clazz.name

    objects.each do |object|
      object = eval(@object_class).new(object) if jo? && object.is_a?(Hash)
      check_class(object)
      self << object
    end
  end

  def root=(root)
    self.each { |jo| jo.root = root } if jo?
    @root = root
  end

  def model=(model)
    self.each { |jo| jo.model = model } if jo?
    @model = model
  end

  # Notify the model so that it will update itself before save.
  def mark_changes
    !(@model.nil? || @root.nil?) && @model.instance_variable_set("@#{@root}_changed", true)
  end

  # It's better to use the hash to do hash#to_json and hash#blank?.
  # If you call object#to_json and object#blank? directly it might result in an wanted object.
  def to_hash
    jo = jo?
    self.collect do |object|
      object = object.to_hash if jo && !object.nil?
      (object == false || !object.blank?) ? object : nil
    end.compact
  end

  def ids
    self.collect(&:id)
  end

  def []=(index, object)
    check_class(object)
    mark_changes
    super(index, object)
  end

  def <<(object)
    check_class(object)
    mark_changes
    super(object)
  end

  def clear
    mark_changes
    super
  end

  def delete_at(index)
    mark_changes
    super(index)
  end

  def method_missing(method, *args, &block)
    # Support find_by, e.g. find_by_id, find_by_code, return the object(s) that satisfy the conditions
    # find_by_id(1, 2, 3, 4), find_all_by_code('abc', 'xyz')
    if match = /find_(all_by|by)_([_a-zA-Z]\w*)/.match(method.to_s)
      finder = match.captures.first == 'all_by' ? :all : :first

      attribute_name = match.captures.last

      case finder
      when :first
        return self.find { |object| args.include?(object.send(attribute_name)) }
      when :all
        return self.select { |object| args.include?(object.send(attribute_name)) }
      end
    end

    super(method, *args, &block)
  end

  private
    def check_class(object)
      if !eval("#{object.class} <= #{@object_class}")
        raise "Expected object of class #{@object_class} but get an object of class #{object.class}"
      end
    end

    def jo?
      @jo ||= eval("#{@object_class} <= Jo")
    end
end
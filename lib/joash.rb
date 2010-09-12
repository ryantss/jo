class Joash < Hash
  attr_accessor :root, :model, :object_class

  def initialize(clazz = nil, objects = {})
    # Only store class name.
    # If we store class itself we cannot dump this object because that class will be tained after we load it back.
    @object_class = clazz.name

    objects.each do |key, object|
      object = eval(@object_class).new(object) if jo? && object.is_a?(Hash)
      check_class(object)
      self[key] = object
    end
  end

  def root=(root)
    self.each { |key, jo| jo.root = root } if jo?
    @root = root
  end

  def model=(model)
    self.each { |key, jo| jo.model = model } if jo?
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
    self.inject({}) do |hash, object|
      object[1] = object[1].to_hash if jo && !object[1].nil?
      hash[object[0]] = object[1] if object[1] == false || !object[1].blank?
      hash
    end
  end

  def []=(key, object)
    check_class(object) unless object.nil?
    mark_changes
    super(key.to_sym, object)
  end

  def clear
    mark_changes
    super
  end

  def delete_if(&block)
    mark_changes
    super(index) { |key, object| block.call(key, object) }
  end

  private
    def check_class(object)
      if !eval("#{object.class} <= #{@object_class}")
        raise "Expected object of class #{@object_class} but get an [#{object}] of class #{object.class}"
      end
    end

    def jo?
      @jo ||= eval("#{@object_class} <= Jo")
    end
end
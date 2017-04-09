class InliningType
  attr_accessor :prototype_qualifiers
  attr_accessor :qualifiers

  def use_prototype?
    !prototype_qualifiers.nil?
  end

  def self.[](prototype_qualifiers, qualifiers = prototype_qualifiers)
    r = new
    r.prototype_qualifiers = prototype_qualifiers
    r.qualifiers = qualifiers
    r
  end

  def all_qualifiers
    q = qualifiers.split(' ')
    q.concat prototype_qualifiers.split(' ') if prototype_qualifiers
    q.uniq!
    q
  end

  def static_prototype?
    prototype_qualifiers.split(' ').include?('static')
  end

  def static_definition?
    qualifiers.split(' ').include?('static')
  end

  def static?
    static_prototype? || static_definition?
  end

  def extern_prototype?
    prototype_qualifiers.split(' ').include?('extern')
  end

  def extern_definition?
    qualifiers.split(' ').include?('extern')
  end

  def inline_keyword?
    all_qualifiers.include?('inline')
  end

  def inline_prototype?
    prototype_qualifiers.split(' ').include?('inline') ||
      prototype_qualifiers.split(' ').include?('__inline__')
  end

  def inline_definition?
    qualifiers.split(' ').include?('inline') ||
      qualifiers.split(' ').include?('__inline__')
  end

  def inline_specified?
    inline_prototype? || inline_definition?
  end

  def gnu_inline_prototype?
    prototype_qualifiers.split(' ').include?('__attribute__((gnu_inline))')
  end

  def gnu_inline_definition?
    qualifiers.split(' ').include?('__attribute__((gnu_inline))')
  end

  def gnu_inline?
    gnu_inline_prototype? || gnu_inline_definition?
  end

  def always_inline_prototype?
    prototype_qualifiers.split(' ').include?('__attribute__((always_inline))')
  end

  def always_inline_definition?
    qualifiers.split(' ').include?('__attribute__((always_inline))')
  end

  def always_inline?
    always_inline_prototype? || always_inline_definition?
  end

  def duplicate_inline?
    (prototype_qualifiers.split(' ').include?('inline') &&
     prototype_qualifiers.split(' ').include?('__inline__')) ||
      (qualifiers.split(' ').include?('inline') &&
       qualifiers.split(' ').include?('__inline__'))
  end

end

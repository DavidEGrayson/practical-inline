module InliningOracle
  class FuncAttrs
    attr_writer :inline, :always_inline, :gnu_inline, :static, :extern

    def initialize
      @inline = @always_inline = @gnu_inline = @static = @extern = false
    end

    def ==(other)
      other.class == FuncAttrs && to_a == other.to_a
    end

    def eql?(other)
      self == other
    end

    def hash
      to_a.hash
    end

    def inline?
      @inline
    end

    def always_inline?
      @always_inline
    end

    def gnu_inline?
      @gnu_inline
    end

    def static?
      @static
    end

    def extern?
      @extern
    end

    def to_a
      r = []
      r << :inline if inline?
      r << :always_inline if always_inline?
      r << :gnu_inline if gnu_inline?
      r << :static if static?
      r << :extern if extern?
      r
    end

    def to_s
      r = ''
      r << 'i' if inline?
      r << 'a' if always_inline?
      r << 'g' if gnu_inline?
      r << 's' if static?
      r << 'e' if extern?
      r
    end
  end

  def self.process_qualifiers(type, qualifiers, compiler, language, warnings, errors)
    cpp = language.to_s.include?('++')

    if qualifiers.include?('inline') && language == :c89
      errors[:inline_not_supported] = true
      parse_fail = true
    end

    attrs = FuncAttrs.new

    inline_qualifiers = ['__inline__']
    inline_qualifiers << 'inline' unless language == :c89

    inline_qualifiers_specified = (inline_qualifiers & qualifiers)
    if inline_qualifiers_specified.size > 1 && cpp
      errors[:duplicate_inline_error] = true
    end
    if inline_qualifiers_specified.size > 0
      attrs.inline = true
    end

    if qualifiers.include?('__attribute__((gnu_inline))')
      if attrs.inline?
        attrs.gnu_inline = true
      else
        warnings[:gnu_inline_ignored_warning] = true
      end
    end

    if qualifiers.include?('__attribute__((always_inline))')
      attrs.always_inline = true
    end

    if qualifiers.include?('static')
      attrs.static = true
    end

    if qualifiers.include?('extern')
      attrs.extern = true
    end

    if parse_fail
      return nil
    end

    attrs
  end

  def self.inline_behavior(inlining_type, compiler, language, optimization)
    cpp = language.to_s.include?('++')
    no_optimization = optimization == :'-O0'

    t = inlining_type
    #return {skip: true} unless !static_prototype && static_definition # tmphax

    warnings = {}
    errors = {}

    decl_attrs = process_qualifiers(
      :declaration, inlining_type.prototype_qualifiers.split(' '),
      compiler, language, warnings, errors)
    defn_attrs = process_qualifiers(
      :definition, inlining_type.qualifiers.split(' '),
      compiler, language, warnings, errors)

    # This behavior from GCC is really werid, somehow it dissociates the
    # declaration and definition, and claims it can't find the definition of the
    # inline function.
    if [:c99, :gnu99, :c11, :gnu11].include?(language)
      if decl_attrs && decl_attrs.inline? && !decl_attrs.gnu_inline? && !decl_attrs.static? &&
         defn_attrs && !decl_attrs.gnu_inline? && defn_attrs.static?
        warnings[:inline_never_defined_warning] = true
        defn_attrs = nil
      end
    end

    attrs_list = [decl_attrs, defn_attrs].compact

    # If you use __attribute__((gnu_inline)) for a function, make sure to use it
    # on every declaration that has "inline" or "__inline__".  Failure to do so
    # usually causes an error.
    if decl_attrs && defn_attrs && decl_attrs.inline? && defn_attrs.inline? &&
       decl_attrs.gnu_inline? != defn_attrs.gnu_inline? &&
       !(!t.static_prototype? && t.static_definition? && !cpp)
      if cpp
        if t.gnu_inline_prototype?
          style = :redeclared_without
        else
          style = :redeclared_with
        end
      else
        style = :present
      end
      errors[:gnu_inline_inconsistent_error] = style
      defn_attrs = nil
    end

    # It is an error to use static and extern together on the same definition or
    # declaration.
    if attrs_list.any? { |a| a.static? && a.extern? }
      if cpp
        errors[:conflicting_specifiers_error] = true
      else
        errors[:multiple_storage_classes_error] = true
      end
    elsif !(decl_attrs && decl_attrs.static?) && (defn_attrs && defn_attrs.static?)
      #if !static_mismatch_allowed?(inlining_type, compiler, language)
      style = cpp ? :extern : true
      errors[:static_inconsistent_error] = style

      #if (t.inline_prototype? || t.inline_definition?) &&
      #   [:c99, :gnu99, :c11, :gnu11].include?(language)
      #  warnings[:inline_never_defined_warning] = true
      #end
    end

    if attrs_list.any?(&:always_inline?) && attrs_list.none?(&:inline?)
      warnings[:always_inline_ignored_warning] = true
    end

    if errors.size > 0
      return errors.merge(warnings)
    end

    ############################# TODO: fix stuff below this line ################

    # If a declaration or definition has "__attribute__((gnu_inline))" or
    # without "inline" or "__inline__", the attribute will be ignored and there
    # will be a warning.
    if (!t.inline_prototype? && t.gnu_inline_prototype?) ||
       (!t.inline_definition? && t.gnu_inline_definition?)
      warnings[:gnu_inline_ignored_warning] = true
    end

    # The "inline" keyword is not supported in "-std=c89" mode, but "__inline__"
    # is.  Note that "-std=gnu89" does support "inline".
    if language == :c89 && t.inline_keyword?
      return { inline_not_supported: true }.merge(warnings)
    end

    if t.static_prototype? || t.static_definition?
      return { use_inline_def: true }.merge(warnings)
    end

    if [:c89, :gnu89].include?(language)
      extern_inline = (t.extern_prototype? || !t.inline_prototype?) && t.extern_definition? && t.inline_definition?
      if extern_inline
        if no_optimization && !t.always_inline?
          return { undefined_reference_error: true }.merge(warnings)
        else
          return { use_inline_def: true }.merge(warnings)
        end
      end
      return { multiple_definition_error: true }.merge(warnings)
    end

    if (language == :c99 || language == :gnu99 || \
        language == :c11 || language == :gnu11)
      if t.inline_prototype? && t.extern_prototype? && t.inline_definition? && !t.extern_definition?
        return { multiple_definition_error: true }.merge(warnings)
      end
      if t.inline_prototype? && t.gnu_inline_prototype? && !t.extern_prototype?
        return { multiple_definition_error: true }.merge(warnings)
      end
      if !t.inline_prototype? && t.gnu_inline_prototype? &&
         t.inline_definition? && t.extern_definition? && !t.gnu_inline_definition?
        return { multiple_definition_error: true }.merge(warnings)
      end
      if t.extern_definition? && t.inline_definition? && t.gnu_inline?
        if no_optimization && !t.always_inline?
          return { undefined_reference_error: true }.merge(warnings)
        else
          return { use_inline_def: true }.merge(warnings)
        end
      end
      if !t.inline_prototype? || !t.inline_definition?
        return { multiple_definition_error: true }.merge(warnings)
      end
      if t.extern_definition? && t.inline_definition?
        return { multiple_definition_error: true }.merge(warnings)
      end
      if t.gnu_inline?
        return { multiple_definition_error: true }.merge(warnings)
      end
      if t.prototype_qualifiers == 'extern'
        return { multiple_definition_error: true }.merge(warnings)
      end
      if no_optimization && !t.always_inline?
        return { undefined_reference_error: true }.merge(warnings)
      else
        return { use_inline_def: true }.merge(warnings)
      end
    end

    if cpp
      if !t.inline_specified?
        return { multiple_definition_error: true }.merge(warnings)
      end

      if no_optimization && !t.always_inline?
        if t.inline_definition? && t.gnu_inline_definition?
          return { undefined_reference_error: true }.merge(warnings)
        end
        return { link_once: true }.merge(warnings)
      end
    end

    return { use_inline_def: true }.merge(warnings)
  end

  def self.static_mismatch_allowed?(inlining_type, compiler, language)
    t = inlining_type

    if [:c99, :gnu99, :c11, :gnu11].include?(language)
      if t.inline_prototype? && !t.gnu_inline_prototype? && !t.extern_prototype?
        return true
      end

      if t.inline_prototype? && t.gnu_inline_prototype? && t.extern_prototype?
        if !t.extern_definition?
          return true
        end
      end
    end

    if [:c89, :gnu89].include?(language)
      if t.inline_prototype? && t.extern_prototype?
        return true
      end
    end

    false
  end
end

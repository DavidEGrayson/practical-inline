module InliningOracle
  def self.inline_behavior(inlining_type, compiler, language, optimization)
    no_optimization = optimization == :'-O0'
    cpp = language.to_s.include?('++')
    static_prototype = !(['static'] & inlining_type.prototype_qualifiers.split(' ')).empty?
    static_definition = !(['static'] & inlining_type.qualifiers.split(' ')).empty?
    static = static_prototype || static_definition
    extern_prototype = inlining_type.prototype_qualifiers.split(' ').include?('extern')
    extern_inline = inlining_type.qualifiers.include?('extern inline') ||
                    inlining_type.prototype_qualifiers.include?('extern inline')
    inline_keyword = inlining_type.all_qualifiers.include?('inline')
    inline_prototype = !(['inline', '__inline__'] & inlining_type.prototype_qualifiers.split(' ')).empty?
    inline_definition = !(['inline', '__inline__'] & inlining_type.qualifiers.split(' ')).empty?
    inline_specified = inline_prototype || inline_definition
    gnu_inline_prototype = inlining_type.prototype_qualifiers.split(' ').include?('__attribute__((gnu_inline))')
    gnu_inline_definition = inlining_type.qualifiers.split(' ').include?('__attribute__((gnu_inline))')
    gnu_inline = gnu_inline_prototype || gnu_inline_definition
    always_inline_prototype = inlining_type.prototype_qualifiers.split(' ').include?('__attribute__((always_inline))')
    always_inline_definition = inlining_type.qualifiers.split(' ').include?('__attribute__((always_inline))')
    always_inline = always_inline_prototype || always_inline_definition
    duplicate_inline =
      (inlining_type.prototype_qualifiers.split(' ').include?('inline') &&
       inlining_type.prototype_qualifiers.split(' ').include?('__inline__')) ||
      (inlining_type.qualifiers.split(' ').include?('inline') &&
       inlining_type.qualifiers.split(' ').include?('__inline__'))

    warnings = []

    if (!inline_prototype && gnu_inline_prototype) || (!inline_definition && gnu_inline_definition)
      warnings << :gnu_inline_ignored
    end

    if !inline_prototype && always_inline_prototype || (!inline_definition && always_inline_definition)
      warnings << :always_inline_ignored
    end

    if language == :c89 && inline_keyword
      # C89/C90 does not support the inline keyword.
      return { inline_not_supported: true, warnings: warnings }
    end

    if !static_prototype && static_definition
      style = true
      if cpp
        style = :extern
      elsif (inline_prototype && (inline_definition || [:c99, :gnu99, :c11, :gnu11].include?(language))) && ![:c89, :gnu89].include?(language)
        # TODO: handle this differently, it's just a warning, and this condition is messy
        style = :inline_never_defined
      end
      return { static_inconsistent_error: style, warnings: warnings }
    end

    if duplicate_inline && cpp
      return { duplicate_inline_error: true, warnings: warnings }
    end

    if inline_prototype && inline_definition && gnu_inline_prototype != gnu_inline_definition
      if cpp
        if gnu_inline_prototype
          style = :redeclared_without
        else
          style = :redeclared_with
        end
      else
        style = :present
      end
      return { gnu_inline_inconsistent_error: style, warnings: warnings }
    end

    if static
      return { use_inline_def: true, warnings: warnings }
    end

    if !inline_specified || (!cpp && (!inline_prototype || !inline_definition))
      return { multiple_definition_error: true, warnings: warnings }
    end

    if language == :c89 || language == :gnu89
      if extern_inline
        if no_optimization && !always_inline
          return { undefined_reference_error: true, warnings: warnings }
        else
          return { use_inline_def: true, warnings: warnings }
        end
      end
      return { multiple_definition_error: true, warnings: warnings }
    end

    if (language == :c99 || language == :gnu99 || \
        language == :c11 || language == :gnu11)
      if extern_inline && gnu_inline
        if no_optimization && !always_inline
          return { undefined_reference_error: true, warnings: warnings }
        else
          return { use_inline_def: true, warnings: warnings }
        end
      end
      if extern_inline
        return { multiple_definition_error: true, warnings: warnings }
      end
      if gnu_inline
        return { multiple_definition_error: true, warnings: warnings }
      end
      if inlining_type.prototype_qualifiers == 'extern'
        return { multiple_definition_error: true, warnings: warnings }
      end
      if no_optimization && !always_inline
        return { undefined_reference_error: true, warnings: warnings }
      else
        return { use_inline_def: true, warnings: warnings }
      end
    end

    if cpp && no_optimization && !always_inline
      if inline_definition && gnu_inline_definition
        return { undefined_reference_error: true, warnings: warnings }
      end
      return { link_once: true, warnings: warnings }
    end

    return { use_inline_def: true, warnings: warnings }
  end
end

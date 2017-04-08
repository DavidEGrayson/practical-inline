module InliningOracle
  def self.inline_behavior(inlining_type, compiler, language, optimization)
    no_optimization = optimization == :'-O0'
    cpp = language.to_s.include?('++')
    static = inlining_type.all_qualifiers.include?('static')
    extern_inline = inlining_type.qualifiers.include?('extern inline') ||
                    inlining_type.prototype_qualifiers.include?('extern inline')
    inline_keyword = inlining_type.all_qualifiers.include?('inline')
    inline_specified = !(['inline', '__inline__'] & inlining_type.all_qualifiers).empty?
    gnu_inline = inlining_type.all_qualifiers.include?('__attribute__((gnu_inline))')
    always_inline = inlining_type.all_qualifiers.include?('__attribute__((always_inline))')

    if language == :c89 && inline_keyword
      # C89/C90 does not support the inline keyword.
      return { inline_not_supported: true }
    end

    if static
      return { use_inline_def: true }
    end

    if !inline_specified
      return { multiple_definition_error: true }
    end

    if language == :c89 || language == :gnu89
      if extern_inline
        if no_optimization && !always_inline
          return { undefined_reference_error: true }
        else
          return { use_inline_def: true }
        end
      end
      return { multiple_definition_error: true }
    end

    if (language == :c99 || language == :gnu99 || \
        language == :c11 || language == :gnu11)
      if extern_inline && gnu_inline
        if no_optimization && !always_inline
          return { undefined_reference_error: true }
        else
          return { use_inline_def: true }
        end
      end
      if extern_inline
        return { multiple_definition_error: true }
      end
      if gnu_inline
        return { multiple_definition_error: true }
      end
      if inlining_type.prototype_qualifiers == 'extern'
        return { multiple_definition_error: true }
      end
      if no_optimization && !always_inline
        return { undefined_reference_error: true }
      else
        return { use_inline_def: true }
      end
    end

    if cpp && no_optimization && !always_inline
      if gnu_inline
        return { undefined_reference_error: true }
      end
      return { link_once: true }
    end

    return { use_inline_def: true }
  end
end

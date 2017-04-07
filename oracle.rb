module InliningOracle
  def self.inline_behavior(inlining_type, compiler, language, optimization)
    no_optimization = optimization == :'-O0'
    cpp = language.to_s.include?('++')
    extern_inline = inlining_type.qualifiers == 'extern inline' ||
                    inlining_type.prototype_qualifiers == 'extern inline'
    inline_keyword = inlining_type.all_qualifiers.include?('inline')

    if language == :c89 && inline_keyword
      # C89/C90 does not support inlining.
      return { inline_not_supported: true }
    end

    if language == :c89 || language == :gnu89
      if extern_inline
        if no_optimization
          return { undefined_reference_error: true }
        else
          return { use_inline_def: true }
        end
      end
      return { multiple_definition_error: true }
    end

    if (language == :c99 || language == :gnu99 || \
        language == :c11 || language == :gnu11)
      if extern_inline
        return { multiple_definition_error: true }
      end
      if inlining_type.prototype_qualifiers == 'extern'
        return { multiple_definition_error: true }
      end
      if no_optimization
        return { undefined_reference_error: true }
      else
        return { use_inline_def: true }
      end
    end

    if cpp && no_optimization
      return { link_once: true }
    end

    return { use_inline_def: true }
  end
end

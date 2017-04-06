module InliningOracle
  def self.inline_behavior(inlining_type, compiler, language, optimization)
    if language == :c89
      # C89/C90 does not support inlining.
      return { inline_not_supported: true }
    end

    if language == :gnu89
      return { multiple_definition_error: true }
    end

    if (language == :c99 || language == :gnu99 || language == :c11 || language == :gnu11) && optimization == :'-O0'
      return { undefined_reference_error: true }
    end

    return {}
  end
end

module InliningOracle
  def self.inline_behavior(inlining_type, compiler, language, optimization)
    if language == :c89
      # C89/C90 does not support inlining.
      return { inline_not_supported: true }
    end

    r = {}

    r
  end
end

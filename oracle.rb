module InliningOracle
  def self.inline_behavior(inlining_type, compiler, language, optimization)
    cpp = language.to_s.include?('++')
    no_optimization = optimization == :'-O0'

    t = inlining_type
    #return {skip: true} unless !static_prototype && static_definition # tmphax

    warnings = []

    # The "__attribute__((gnu_inline))" and "__attribute__((always_inline))"
    # qualifiers should only be used on a declaration or definition that also
    # has "inline" or "__inline__", otherwise they will be ignored and you will
    # get a warning.  Don't use those attributes on their own.
    if (!t.inline_prototype? && t.gnu_inline_prototype?) ||
       (!t.inline_definition? && t.gnu_inline_definition?)
      warnings << :gnu_inline_ignored
    end
    if (!t.inline_prototype? && t.always_inline_prototype?) ||
       (!t.inline_definition? && t.always_inline_definition?)
      warnings << :always_inline_ignored
    end

    # The "inline" keyword is not supported in "-std=c89" mode, but "__inline__"
    # is.  Note that "-std=gnu89" does support "inline".
    if language == :c89 && t.inline_keyword?
      return { inline_not_supported: true, warnings: warnings }
    end

    # It is an error to use static and extern together on the same definition or declaration.
    if (t.static_prototype? && t.extern_prototype?) ||
       (t.static_definition? && t.extern_definition?)
      if cpp
        return { conflicting_specifiers_error: true, warnings: warnings }
      else
        return { multiple_storage_classes_error: true, warnings: warnings }
      end
    end

    if t.duplicate_inline? && cpp
      return { duplicate_inline_error: true, warnings: warnings }
    end

    if t.inline_prototype? && t.inline_definition? &&
       t.gnu_inline_prototype? != t.gnu_inline_definition? &&
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
      return { gnu_inline_inconsistent_error: style, warnings: warnings }
    end

    if !t.static_prototype? && t.static_definition?
      if [:c99, :gnu99, :c11, :gnu11].include?(language)
        warnings << :inline_never_defined
      end

      if !static_mismatch_allowed?(inlining_type, compiler, language)
        style = cpp ? :extern : true
        return { static_inconsistent_error: style, warnings: warnings }
      end
    end

    if t.static?
      return { use_inline_def: true, warnings: warnings }
    end

    if language == :c89 || language == :gnu89
      extern_inline = (t.extern_prototype? || !t.inline_prototype?) && t.extern_definition? && t.inline_definition?
      if extern_inline
        if no_optimization && !t.always_inline?
          return { undefined_reference_error: true, warnings: warnings }
        else
          return { use_inline_def: true, warnings: warnings }
        end
      end
      return { multiple_definition_error: true, warnings: warnings }
    end

    if (language == :c99 || language == :gnu99 || \
        language == :c11 || language == :gnu11)
      if t.inline_prototype? && t.extern_prototype? && t.inline_definition? && !t.extern_definition?
        return { multiple_definition_error: true, warnings: warnings }
      end
      if t.inline_prototype? && t.gnu_inline_prototype? && !t.extern_prototype?
        return { multiple_definition_error: true, warnings: warnings }
      end
      if !t.inline_prototype? && t.gnu_inline_prototype? &&
         t.inline_definition? && t.extern_definition? && !t.gnu_inline_definition?
        return { multiple_definition_error: true, warnings: warnings }
      end
      if t.extern_definition? && t.inline_definition? && t.gnu_inline?
        if no_optimization && !t.always_inline?
          return { undefined_reference_error: true, warnings: warnings }
        else
          return { use_inline_def: true, warnings: warnings }
        end
      end
      if !t.inline_prototype? || !t.inline_definition?
        return { multiple_definition_error: true, warnings: warnings }
      end
      if t.extern_definition? && t.inline_definition?
        return { multiple_definition_error: true, warnings: warnings }
      end
      if t.gnu_inline?
        return { multiple_definition_error: true, warnings: warnings }
      end
      if t.prototype_qualifiers == 'extern'
        return { multiple_definition_error: true, warnings: warnings }
      end
      if no_optimization && !t.always_inline?
        return { undefined_reference_error: true, warnings: warnings }
      else
        return { use_inline_def: true, warnings: warnings }
      end
    end

    if cpp
      if !t.inline_specified?
        return { multiple_definition_error: true, warnings: warnings }
      end

      if no_optimization && !t.always_inline?
        if t.inline_definition? && t.gnu_inline_definition?
          return { undefined_reference_error: true, warnings: warnings }
        end
        return { link_once: true, warnings: warnings }
      end
    end

    return { use_inline_def: true, warnings: warnings }
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

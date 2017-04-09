module InliningOracle
  def self.inline_behavior(inlining_type, compiler, language, optimization)
    cpp = language.to_s.include?('++')
    no_optimization = optimization == :'-O0'

    t = inlining_type
    #return {skip: true} unless !static_prototype && static_definition # tmphax

    warnings = []

    if (!t.inline_prototype? && t.gnu_inline_prototype?) ||
       (!t.inline_definition? && t.gnu_inline_definition?)
      warnings << :gnu_inline_ignored
    end

    if (!t.inline_prototype? && t.always_inline_prototype?) ||
       (!t.inline_definition? && t.always_inline_definition?)
      warnings << :always_inline_ignored
    end

    if language == :c89 && t.inline_keyword?
      # C89/C90 does not support the inline keyword.
      return { inline_not_supported: true, warnings: warnings }
    end

    if (t.static_prototype? && t.extern_prototype?) ||
       (t.static_definition? && t.extern_definition?)
      if cpp
        return { conflicting_specifiers_error: true, warnings: warnings }
      else
        return { multiple_storage_classes_error: true, warnings: warnings }
      end
    end

    if !t.static_prototype? && t.static_definition? && \
       [:c99, :gnu99, :c11, :gnu11].include?(language)
      warnings << :inline_never_defined
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

    if !t.static_prototype? && t.static_definition? &&
       (!static_mismatch_allowed?(inlining_type, compiler, language)) && (
       # Weird exception 3
       !(t.inline_prototype? && !t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         !t.inline_definition? && !t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 4
       !(t.inline_prototype? && t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition? &&
         !cpp) &&
       # Weird exception 5
       !(t.inline_prototype? && !t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 6
       !(t.inline_prototype? && !t.gnu_inline_prototype? && t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && !t.gnu_inline_definition? && t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 7
       !(t.inline_prototype? && !t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && !t.gnu_inline_definition? && t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 8
       !(t.inline_prototype? && t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         !t.inline_definition? && t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition? &&
         !cpp) &&
       # Weird exception 9
       !(t.inline_prototype? && !t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         !t.inline_definition? && t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 9
       !(t.inline_prototype? && t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && !t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition? &&
         !cpp) &&
       # Weird exception 10
       !(t.inline_prototype? && !t.gnu_inline_prototype? && t.always_inline_prototype? && t.extern_prototype? &&
         !t.inline_definition? && !t.gnu_inline_definition? && t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 11
       !(t.inline_prototype? && t.gnu_inline_prototype? && t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && t.gnu_inline_definition? && t.always_inline_definition? && !t.extern_definition? &&
         !cpp) &&
       # Weird exception 12
       !(t.inline_prototype? && !t.gnu_inline_prototype? && t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && t.gnu_inline_definition? && t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 13
       !(t.inline_prototype? && !t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         !t.inline_definition? && !t.gnu_inline_definition? && t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 14
       !(t.inline_prototype? && t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 15
       !(t.inline_prototype? && t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && t.gnu_inline_definition? && t.always_inline_definition? && !t.extern_definition? &&
         !cpp) &&
       # Weird exception 16
       !(t.inline_prototype? && !t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && t.gnu_inline_definition? && t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language)) &&
       # Weird exception 17
       !(t.inline_prototype? && !t.gnu_inline_prototype? && t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && !t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition? &&
         [:c89, :gnu89].include?(language))
      ) then
      style = true
      if cpp
        style = :extern
      end
      return { static_inconsistent_error: style, warnings: warnings }
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
      if t.inline_prototype? && !t.extern_prototype? && !t.gnu_inline_prototype?
        return true
      end
    end

    if [:c89, :gnu89].include?(language)
      if t.inline_prototype? && !t.gnu_inline_prototype? && !t.always_inline_prototype? && t.extern_prototype? &&
         t.inline_definition? && !t.gnu_inline_definition? && !t.always_inline_definition? && !t.extern_definition?
        return true
      end
    end

    false
  end
end

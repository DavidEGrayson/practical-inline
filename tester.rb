# TODO: test -fgnu89-inline

require_relative 'oracle'
require_relative 'inlining_type'
require_relative 'test_domain'
require_relative 'run_script'
require_relative 'construct_script'
require_relative 'printing'

require 'pathname'
require 'fileutils'
require 'tmpdir'
require 'open3'
require 'digest'

def test_inlining(specs, case_number, behavior_hash, behavior)
  puts "test_inlining %6s, %s, %s" % [case_number, specs_summary(specs), behavior.inspect]

  script = construct_script(:call_in_two_files, *specs)
  result = run_script(script)
  case
  when behavior[:inline_not_supported]
    expect_compiler_error(result, 'file1')
    expect_compiler_error(result, 'file2')
    unspecified_warnings_possible = true
  when behavior[:static_inconsistent_error]
    case behavior[:static_inconsistent_error]
    when true
      expect_compiler_error(result, 'file1', /static declaration .* follows non-static declaration/)
      expect_compiler_error(result, 'file2', /static declaration .* follows non-static declaration/)
    when :extern
      expect_compiler_error(result, 'file1', /was declared .extern. and later .static./)
      expect_compiler_error(result, 'file2', /was declared .extern. and later .static./)
    else
      raise 'unknown style'
    end
    unspecified_warnings_possible = true
  when behavior[:duplicate_inline_error]
    expect_compiler_error(result, 'file1', /duplicate .inline/)
    expect_compiler_error(result, 'file2', /duplicate .inline/)
    unspecified_warnings_possible = true
  when behavior[:multiple_storage_classes_error]
    expect_compiler_error(result, 'file1', /multiple storage classes .* declaration/)
    expect_compiler_error(result, 'file2', /multiple storage classes .* declaration/)
    unspecified_warnings_possible = true
  when behavior[:conflicting_specifiers_error]
    expect_compiler_error(result, 'file1', /conflicting specifiers in declaration/)
    expect_compiler_error(result, 'file2', /conflicting specifiers in declaration/)
    unspecified_warnings_possible = true
  when behavior[:gnu_inline_inconsistent_error]
    expect_compiler_error(result, 'file1', /gnu_inline/)
    expect_compiler_error(result, 'file2', /gnu_inline/)
    unspecified_warnings_possible = true
    case behavior[:gnu_inline_inconsistent_error]
    when :present
      expect_compiler_error(result, 'file1', /.gnu_inline. attribute present/)
      expect_compiler_error(result, 'file1', /but not here/)
      expect_compiler_error(result, 'file2', /.gnu_inline. attribute present/)
      expect_compiler_error(result, 'file2', /but not here/)
    when :redeclared_with
      expect_compiler_error(result, 'file1', /.redeclared inline with .gnu_inline. attribute/)
      expect_compiler_error(result, 'file2', /.redeclared inline with .gnu_inline. attribute/)
    when :redeclared_without
      expect_compiler_error(result, 'file1', /.redeclared inline without .gnu_inline. attribute/)
      expect_compiler_error(result, 'file2', /.redeclared inline without .gnu_inline. attribute/)
    else
      raise
    end
  when behavior[:multiple_definition_error]
    expect_multiple_definition_error(result, 'foo')
  when behavior[:undefined_reference_error]
    expect_undefined_reference_error(result, 'foo')
  when behavior[:link_once]
    expect_success(result, "1\n1\n")
  when behavior[:use_inline_def]
    expect_success(result, "1\n2\n")
  else
    raise "unknown top-level behavior"
  end

  expected_warnings = behavior.fetch(:warnings, [])

  expected_warnings.each do |warning|
    case warning
    when :gnu_inline_ignored
      expect_warning(result, /.*gnu_inline.* attribute_ignored/)
    when :always_inline_ignored
      expect_warning(result, /always_inline function might not be inlinable/)
    when :inline_never_defined
      expect_warning(result, /inline function .* declared but never defined/)
    else
      raise "don't know how to look for warning #{warning}"
    end
  end

  if expected_warnings.empty? && !unspecified_warnings_possible
    expect_no_warnings(result)
  end

rescue
  $stderr.puts "Something went wrong."
  if specs
    $stderr.puts "  specs: #{specs.inspect}"
  end
  if script
    $stderr.puts "  script: "
    print_with_indent($stderr, script, '    ')
  end
  if result
    $stderr.puts "  result stdout:"
    print_with_indent($stderr, result[0], '    ')
    $stderr.puts "  result stderr:"
    print_with_indent($stderr, result[1], '    ')
    $stderr.puts "  result code: #{result[2]}"
    $stderr.puts "  skip command: SKIP=#{case_number}:#{behavior_hash.hexdigest[0..7]} ruby tester.rb"
  end
  raise
end

skip = 0
if ENV['SKIP']
  if md = ENV['SKIP'].match(/\A(\d+)(|:([0-9a-f]+))\Z/)
    skip = md[1].to_i
    expected_hash_of_skipped = md[3].to_s
  else
    raise 'SKIP argument has wrong format'
  end
end

behavior_hash = Digest::SHA256.new
minimal = ARGV.include?('--minimal')
inlining_types, compilers, languages, optimizations = generate_test_domain(minimal)
case_count = inlining_types.size * compilers.size * languages.size * optimizations.size
puts "Planning to test #{case_count} cases."
case_number = 0
optimizations.each do |optimization|
  inlining_types.each do |inlining_type|
    compilers.each do |compiler|
      languages.each do |language|
        specs = [inlining_type, compiler, language, optimization]
        behavior = InliningOracle.inline_behavior(*specs)
        if skip > 0
          skip -= 1
          behavior_hash.update(Marshal.dump(behavior))
          case_number += 1

          if skip == 0
            behavior_hash_hex = behavior_hash.dup.hexdigest
            puts "Hash of skipped behaviors: #{behavior_hash_hex}"
            if !behavior_hash_hex.start_with?(expected_hash_of_skipped)
              raise "does not match expected hash #{expected_hash_of_skipped.inspect} != #{behavior_hash_hex.inspect}"
            end
          end
        else
          test_inlining(specs, case_number, behavior_hash, behavior)
          behavior_hash.update(Marshal.dump(behavior))
          case_number += 1
        end
      end
    end
  end
end

# TODO: test -fgnu89-inline
# TODO: test -pedantic

require_relative 'oracle'
require_relative 'inlining_type'
require_relative 'test_domain'
require_relative 'run_script'
require_relative 'construct_script'
require_relative 'printing'
require_relative 'result_checking'

require 'pathname'
require 'fileutils'
require 'tmpdir'
require 'open3'
require 'digest'

def test_inlining(specs, case_number, behavior_hash, behavior)
  known_keys = %i(
    link_once
    use_inline_def

    inline_not_supported
    static_inconsistent_error
    duplicate_inline_error
    multiple_storage_classes_error
    multiple_definition_error
    undefined_reference_error
    conflicting_specifiers_error
    gnu_inline_inconsistent_error

    gnu_inline_ignored_warning
    always_inline_ignored_warning
    inline_never_defined_warning
  )
  unknown_keys = behavior.keys - known_keys
  if !unknown_keys.empty?
    raise "Unknown behavior keys: #{unknown_keys.inspect}"
  end

  puts "test_inlining %6s, %s, %s" % [case_number, specs_summary(specs), behavior.inspect]

  script = construct_script(:call_in_two_files, *specs)
  result = run_script(script)
  case
  when behavior[:inline_not_supported]
    expect_compiler_error(result, 'file1')
    expect_compiler_error(result, 'file2')
    error_expected = true
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
    error_expected = true
  when behavior[:duplicate_inline_error]
    expect_compiler_error(result, 'file1', /duplicate .inline/)
    expect_compiler_error(result, 'file2', /duplicate .inline/)
    error_expected = true
  when behavior[:multiple_storage_classes_error]
    expect_compiler_error(result, 'file1', /multiple storage classes .* declaration/)
    expect_compiler_error(result, 'file2', /multiple storage classes .* declaration/)
    error_expected = true
  when behavior[:conflicting_specifiers_error]
    expect_compiler_error(result, 'file1', /conflicting specifiers in declaration/)
    expect_compiler_error(result, 'file2', /conflicting specifiers in declaration/)
    error_expected = true
  when behavior[:gnu_inline_inconsistent_error]
    expect_compiler_error(result, 'file1', /gnu_inline/)
    expect_compiler_error(result, 'file2', /gnu_inline/)
    error_expected = true
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

  # For the warnings that the oracle knows about, make sure we are
  # correctly modelling them.  That means to make sure they appear if
  # an only if the oracle says the will, even if there are errors.
  # We want to know how the warnings really work.

  expect_warning(result, /.*gnu_inline.* attribute ignored/,
    behavior[:gnu_inline_ignored_warning])
  warning_expected = true if behavior[:gnu_inline_ignored_warning]

  expect_warning(result, /always_inline function might not be inlinable/,
    behavior[:always_inline_ignored_warning])
  warning_expected = true if behavior[:always_inline_ignored_warning]

  expect_warning(result, /inline function .* declared but never defined/,
                 behavior[:inline_never_defined_warning])
  warning_expected = true if behavior[:inline_never_defined_warning]

  # If there oracle says there are warnings or errors, we don't care
  # about detecting *all* the warnings and errors produced.  But if
  # the oracle doesn't report any errors or warnings, we want to say
  # this is a good scenario for programs to use.  So make sure there
  # are no warnings whatsoever.
  if !error_expected && !warning_expected
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
cases = generate_test_cases(minimal)
case_count = cases.count
puts "Planning to test #{case_count} cases."
case_number = 0
cases.each do |specs|
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

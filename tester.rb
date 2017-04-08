require_relative 'oracle'
require 'pathname'
require 'fileutils'
require 'tmpdir'
require 'open3'

class InliningType
  attr_accessor :prototype_qualifiers
  attr_accessor :qualifiers

  def use_prototype?
    !prototype_qualifiers.nil?
  end

  def self.[](prototype_qualifiers, qualifiers = prototype_qualifiers)
    r = new
    r.prototype_qualifiers = prototype_qualifiers
    r.qualifiers = qualifiers
    r
  end

  def all_qualifiers
    q = qualifiers.split(' ')
    q.concat prototype_qualifiers.split(' ') if prototype_qualifiers
    q.uniq!
    q
  end
end

def generate_test_domain(minimal)
  compilers = %i(gcc)

  if minimal
    # The minimal set of tests: don't test cases that we think are the
    # same as other cases.  (e.g. don't bother testing gnu99 if we
    # already test c99).

    inlining_types = [
      InliningType[''],
      InliningType['inline'],
      InliningType['__inline__'],
      InliningType['static'],
      InliningType['static inline'],
      InliningType['static __inline__'],
      InliningType['extern inline'],
      InliningType['extern', 'inline'],
      InliningType['__attribute__((gnu_inline))'],
      InliningType['inline __attribute__((gnu_inline))'],
      InliningType['extern __attribute__((gnu_inline))'],
      InliningType['extern inline __attribute__((gnu_inline))'],
      InliningType['__attribute__((always_inline))'],
      InliningType['inline __attribute__((always_inline))'],
      InliningType['extern __attribute__((always_inline))'],
      InliningType['extern inline __attribute__((always_inline))'],
    ]
    languages = %i(c89 gnu89 gnu99 gnu++11)
    optimizations = %i(-O0 -O1)
  else
    # Test a huge combinatorial explosion.

    qualifier_universe = %w(
      inline  __inline__
      __attribute__((gnu_inline)) __attribute__((always_inline))
      static extern
    )

    inlining_types = []
    bits = qualifier_universe.size * 2
    (0...(1 << bits)).each do |n|
      prototype_qualifiers = []
      qualifiers = []
      qualifier_universe.each do |qualifier|
        bit, n = [n & 1, n >> 1]
        prototype_qualifiers << qualifier if bit == 1

        bool, n = [n & 1, n >> 1]
        qualifiers << qualifier if bit == 1
      end
      inlining_types << InliningType[prototype_qualifiers.join(' '), qualifiers.join(' ')]
    end
    languages = %i(
      c89 gnu89 c99 gnu99 c11 gnu11
      c++98 gnu++98 c++11 gnu++11 c++14 gnu++14 c++1z gnu++1z
    )
    optimizations = %i(-O0 -O1 -O2 -O3 -Os)
  end

  [inlining_types, compilers, languages, optimizations]
end

def run_script(script)
  dir = Pathname(Dir.mktmpdir("inline_test"))
  script_file = dir + 'test.sh'
  File.open(script_file, 'w') do |f|
    f.write script
  end

  env = { }
  cmd = 'bash -e ' + script_file.basename.to_s
  opts = { chdir: dir.to_s }
  stdout, stderr, status = Open3.capture3(env, cmd, opts)

  FileUtils.rm_r(dir)
  dir = nil

  [stdout, stderr, status.exitstatus]
rescue
  if dir
    $stderr.puts "Keeping temporary directory: #{dir}"
  end
  raise
end

def construct_script(script_type, inlining_type, compiler, language, optimization)
  case script_type
  when :call_in_two_files
    file1 = ''
    if inlining_type.use_prototype?
      file1 << "#{inlining_type.prototype_qualifiers} int foo();\n"
    else
      file << "\n"
    end
    file1 << "#{inlining_type.qualifiers} int foo() { return 1; }\n"
    file1 << "void file2(void);\n"
    file1 << "#include <stdio.h>\n"
    file1 << "int main() {\n"
    file1 << '  printf("%d\n", foo());' + "\n"
    file1 << "  file2();\n"
    file1 << "  return 0;\n"
    file1 << "}\n"

    file2 = ''
    if inlining_type.use_prototype?
      file2 << "#{inlining_type.prototype_qualifiers} int foo();\n"
    end
    file2 << "#{inlining_type.qualifiers} int foo() { return 2; }\n"
    file2 << "#include <stdio.h>\n"
    file2 << "void file2() {\n"
    file2 << '  printf("%d\n", foo());' + "\n"
    file2 << "}\n"

  else raise "unknown script type #{script_type}"
  end

  cpp = language.to_s.include?('++')
  source_ext = cpp ? '.cpp' : '.c'

  script = ''
  script << "cat > file1#{source_ext} <<EOF\n"
  script << file1
  script << "EOF\n"
  script << "\n"

  script << "cat > file2#{source_ext} <<EOF\n"
  script << file2
  script << "EOF\n"
  script << "\n"

  case compiler
  when :gcc
    cflags = "-std=#{language} #{optimization} -Wall -Wextra"
    compiler_exe = cpp ? 'g++' : 'gcc'
  else
    raise 'unknown compiler'
  end

  script << "#{compiler_exe} #{cflags} " \
            "file1#{source_ext} file2#{source_ext} -o test\n"
  script << "./test\n"
  script
end

def result_has_compiler_error?(result, file, line_number = nil)
  stdout, stderr, code = result
  line_number ||= '\d+'
  stderr.each_line.any? do |line|
    regex = /\A#{file}(.c|.cpp|):#{line_number}(:\d+): error:/
    line.match?(regex)
  end
end

def expect_compiler_error(result, file, line_number = nil)
  if !result_has_compiler_error?(result, file, line_number)
    raise "Expected a compiler error in #{file} at line #{line_number}, " \
          "but did not find one."
  end
end

def result_has_multiple_definition_error?(result, symbol)
  stdout, stderr, code = result
  stderr.each_line.any? do |line|
    regex = /multiple definition .*#{symbol}/
    line.match?(regex)
  end
end

def expect_multiple_definition_error(result, symbol)
  if !result_has_multiple_definition_error?(result, symbol)
    raise "Expected a multiple definition error for #{symbol}."
  end
end

def result_has_undefined_reference_error?(result, symbol)
  stdout, stderr, code = result
  stderr.each_line.any? do |line|
    regex = /undefined reference .*#{symbol}/
    line.match?(regex)
  end
end

def expect_undefined_reference_error(result, symbol)
  if !result_has_undefined_reference_error?(result, symbol)
    raise "Expected a undefined reference error for #{symbol}."
  end
end

def expect_warning(result, regex)
  stdout, stderr, code = result
  stderr.each_line.any? do |line|
    line.match(/warning: (.*)/) && $1.match?(regex)
  end
end

def expect_no_warnings(result)
  stdout, stderr, code = result

  if stderr.include?('warning')
    raise "Expected no warnings, but stderr had a warning."
  end
end

def expect_success(result, expected_stdout)
  stdout, stderr, code = result

  if code != 0
    raise "Expected exit code 0, got #{code}"
  end

  if stdout != expected_stdout
    raise "Standard output is different from expected: " \
          "#{expected_stdout.inspect} #{stdout.inspect}"
  end
end

def print_with_indent(io, string, indent)
  string.each_line do |line|
    $stderr.puts "    #{line}"
  end
end

def test_inlining(specs, case_number)
  behavior = InliningOracle.inline_behavior(*specs)

  puts "test_inlining #{case_number}, #{behavior.inspect}"

  script = construct_script(:call_in_two_files, *specs)
  result = run_script(script)
  case
  when behavior[:inline_not_supported]
    expect_compiler_error(result, 'file1')
    expect_compiler_error(result, 'file2')
    unspecified_warnings_possible = true
  when behavior[:multiple_definition_error]
    expect_multiple_definition_error(result, 'foo')
  when behavior[:undefined_reference_error]
    expect_undefined_reference_error(result, 'foo')
  when behavior[:link_once]
    expect_success(result, "1\n1\n")
  when behavior[:use_inline_def]
    expect_success(result, "1\n2\n")
  end

  expected_warnings = behavior.fetch(:warnings, [])

  expected_warnings.each do |warning|
    case warning
    when :gnu_inline_ignored
      expect_warning(result, /.*gnu_inline.* attribute_ignored/)
    when :always_inline_ignored
      expect_warning(result, /always_inline function might not be inlinable/)
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
    $stderr.puts "  case number: #{case_number}"
  end
  raise
end

minimal = ARGV.include?('--minimal')
inlining_types, compilers, languages, optimizations = generate_test_domain(minimal)
case_count = inlining_types.size * compilers.size * languages.size * optimizations.size
puts "Planning to test #{case_count} cases."
case_number = 0
inlining_types.each do |inlining_type|
  compilers.each do |compiler|
    languages.each do |language|
      optimizations.each do |optimization|
        specs = [inlining_type, compiler, language, optimization]
        case_number += 1
        test_inlining(specs, case_number)
      end
    end
  end
end

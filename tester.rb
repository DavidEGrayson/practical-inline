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

inlining_types = [
  InliningType['inline'],
  InliningType['__inline__'],

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

compilers = %i(gcc)
languages = %i(
  c89 gnu89 c99 gnu99 c11 gnu11
  c++98 gnu++98 c++11 gnu++11 c++14 gnu++14 c++1z gnu++1z
)
optimizations = %i(-O0 -O1 -O2 -O3)

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

  expect_no_warnings(result)
end

def print_with_indent(io, string, indent)
  string.each_line do |line|
    $stderr.puts "    #{line}"
  end
end

def test_inlining(specs, case_count)
  behavior = InliningOracle.inline_behavior(*specs)

  puts "test_inlining #{case_count}, #{behavior.inspect}"

  script = construct_script(:call_in_two_files, *specs)
  result = run_script(script)
  case
  when behavior[:inline_not_supported]
    expect_compiler_error(result, 'file1')
    expect_compiler_error(result, 'file2')
  when behavior[:multiple_definition_error]
    expect_multiple_definition_error(result, 'foo')
  when behavior[:undefined_reference_error]
    expect_undefined_reference_error(result, 'foo')
    expect_no_warnings(result)
  when behavior[:link_once]
    expect_success(result, "1\n1\n")
  when behavior[:use_inline_def]
    expect_success(result, "1\n2\n")
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
  end
  raise
end

case_count = 0
inlining_types.each do |inlining_type|
  compilers.each do |compiler|
    languages.each do |language|
      optimizations.each do |optimization|
        specs = [inlining_type, compiler, language, optimization]
        case_count += 1
        test_inlining(specs, case_count)
      end
    end
  end
end

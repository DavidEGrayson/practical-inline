def result_has_compiler_error?(result, file, regex = nil)
  stdout, stderr, code = result

  return false if code == 0

  line_number = '\d+'
  regex ||= //
  stderr.each_line.any? do |line|
    error_regex = /\A#{file}(.c|.cpp|):#{line_number}(:\d+): error: (.*)/
    line.match(error_regex) && $3.match?(regex)
  end
end

def expect_compiler_error(result, file, regex = nil)
  if !result_has_compiler_error?(result, file, regex)
    raise "Expected a compiler error in #{file} (#{regex.inspect}), " \
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

def result_has_warning?(result, regex)
  stdout, stderr, code = result
  stderr.each_line.any? do |line|
    line.match(/warning: (.*)/) && $1.match?(regex)
  end
end

def expect_warning(result, regex, expect = true)
  if expect && !result_has_warning?(result, regex)
    raise "Expected a warning matching #{regex.inspect}, none found."
  end
  if !expect && result_has_warning?(result, regex)
    raise "Expected no warning matching #{regex.inspect}, but one was found."
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

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

def print_with_indent(io, string, indent)
  string.each_line do |line|
    $stderr.puts "    #{line}"
  end
end

def inlining_summary(inlining_type)
  map = {
    'inline' => 'i',
    '__inline__' => 'I',
    'extern' => 'e',
    'static' => 's',
    '__attribute__((gnu_inline))' => 'g',
    '__attribute__((always_inline))' => 'a'
  }

  pq_summary = ''
  inlining_type.prototype_qualifiers.split(' ').each do |q|
    pq_summary << map.fetch(q, q)
  end

  q_summary = ''
  inlining_type.qualifiers.split(' ').each do |q|
    q_summary << map.fetch(q, q)
  end

  "#{pq_summary};#{q_summary}{};"
end

def specs_summary(specs)
  inlining_type, compiler, language, optimization = specs

  "%s %-5s %-7s %-3s" %
    [inlining_summary(inlining_type),
     compiler, language, optimization]
end

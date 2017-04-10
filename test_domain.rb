require_relative 'inlining_type'

def generate_test_domain(minimal)
  compilers = %i(gcc)

  if minimal
    # The minimal set of tests: don't test cases that we think are the
    # same as other cases.  (e.g. don't bother testing gnu99 if we
    # already test c99).  TODO: get 100% code coverage of the oracle.

    inlining_types = [
      InliningType[''],
      InliningType['inline'],
      InliningType['', 'inline'],
      InliningType['inline', ''],
      InliningType['__inline__'],
      InliningType['inline __inline__'],
      InliningType['static'],
      InliningType['static inline'],
      InliningType['static', 'inline'],
      InliningType['static __inline__'],
      InliningType['extern inline'],
      InliningType['extern', 'inline'],
      InliningType['__attribute__((gnu_inline))'],
      InliningType['inline __attribute__((gnu_inline))'],
      InliningType['__attribute__((gnu_inline))', 'inline __attribute__((gnu_inline))'],
      InliningType['inline __attribute__((gnu_inline))', '__attribute__((gnu_inline))'],
      InliningType['inline', 'inline __attribute__((gnu_inline))'],
      InliningType['inline __attribute__((gnu_inline))', 'inline'],
      InliningType['extern __attribute__((gnu_inline))'],
      InliningType['extern inline __attribute__((gnu_inline))'],
      InliningType['static __attribute__((gnu_inline))'],
      InliningType['__attribute__((always_inline))'],
      InliningType['inline __attribute__((always_inline))'],
      InliningType['extern __attribute__((always_inline))'],
      InliningType['extern inline __attribute__((always_inline))'],
      InliningType['static __attribute__((always_inline))'],
      InliningType['inline', 'inline __attribute__((gnu_inline)) static'],
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
    indices = 0...(1 << bits)

    # Put the simpler combinations first (combinations with fewer
    # qualifiers).  We'll probably find bugs faster that way since
    # most bugs will be caused by the interaction of 1 or 2
    # qualifiers.
    indices = indices.sort_by do |n|
      popcount = n.to_s(2).count('1')
      [popcount, n]
    end

    indices.each do |n|
      prototype_qualifiers = []
      qualifiers = []
      qualifier_universe.each do |qualifier|
        bit0, n = [n & 1, n >> 1]
        bit1, n = [n & 1, n >> 1]

        if bit0 == 1
          prototype_qualifiers << qualifier
        end

        if (bit0 ^ bit1) == 1
          qualifiers << qualifier
        end
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

def generate_test_cases(minimal)
  inlining_types, compilers, languages, optimizations = generate_test_domain(minimal)

  Enumerator.new do |y|
    optimizations.each do |optimization|
      inlining_types.each do |inlining_type|
        compilers.each do |compiler|
          languages.each do |language|
            y << [inlining_type, compiler, language, optimization]
          end
        end
      end
    end
  end
end

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

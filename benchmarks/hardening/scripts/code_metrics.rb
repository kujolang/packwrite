#!/usr/bin/env ruby
require "json"

root = ARGV.fetch(0)
files = Dir.chdir(root) { Dir.glob("{src,tests}/**/*.{kujo,sh}").sort }
source = files.select { |path| path.start_with?("src/") }
tests = files.select { |path| path.start_with?("tests/") }

metrics = lambda do |paths|
  texts = paths.map { |path| File.read(File.join(root, path)) }
  {
    "files" => paths.length,
    "lines" => texts.sum { |text| text.lines.length },
    "nonblank_lines" => texts.sum { |text| text.lines.count { |line| !line.strip.empty? } },
    "functions" => texts.sum { |text| text.scan(/^\s*(?:export\s+)?func\s+/).length },
    "branches" => texts.sum { |text| text.scan(/\b(?:if|while|for|except)\b/).length },
    "todos" => texts.sum { |text| text.scan(/\b(?:TODO|FIXME)\b/).length },
    "bytes" => texts.sum(&:bytesize)
  }
end

all_files = Dir.chdir(root) { Dir.glob("**/*", File::FNM_DOTMATCH).select { |path| File.file?(path) && !path.start_with?(".git/") } }
puts JSON.pretty_generate({
  "source" => metrics.call(source),
  "tests" => metrics.call(tests),
  "tracked_like_files" => all_files.length,
  "repository_bytes" => all_files.sum { |path| File.size(File.join(root, path)) },
  "direct_dependencies" => 0
})

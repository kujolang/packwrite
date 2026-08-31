#!/usr/bin/env ruby
require "json"
require "time"

root = File.expand_path("..", __dir__)
results = File.join(root, "results")
config = JSON.parse(File.read(File.join(root, "benchmark-config.json")))

def percentile(values, fraction)
  sorted = values.sort
  sorted[[(fraction * (sorted.length - 1)).ceil, sorted.length - 1].min]
end

def stats(values)
  mean = values.sum / values.length.to_f
  variance = values.sum { |value| (value - mean) ** 2 } / values.length
  {
    "n" => values.length,
    "min" => values.min,
    "max" => values.max,
    "mean" => mean,
    "median" => percentile(values, 0.5),
    "p95" => percentile(values, 0.95),
    "p99" => percentile(values, 0.99),
    "stddev" => Math.sqrt(variance)
  }
end

timings = {}
Dir[File.join(results, "hyperfine", "*.json")].sort.each do |path|
  next if File.zero?(path)
  name = File.basename(path, ".json")
  parsed = JSON.parse(File.read(path))
  timings[name] = parsed.fetch("results").to_h do |entry|
    [entry.fetch("command"), stats(entry.fetch("times"))]
  end
  base = timings[name]["baseline"]["median"]
  curr = timings[name]["current"]["median"]
  timings[name]["change"] = {
    "absolute_seconds" => curr - base,
    "percent" => ((curr - base) / base) * 100.0,
    "speedup" => base / curr
  }
end

memory = {}
%w[baseline current].each do |variant|
  values = Dir[File.join(results, "memory", "#{variant}-*.txt")].sort.map do |path|
    File.read(path)[/^\s*(\d+)\s+maximum resident set size$/, 1].to_i
  end
  memory[variant] = stats(values)
end
memory["change"] = {
  "absolute_bytes" => memory["current"]["median"] - memory["baseline"]["median"],
  "percent" => ((memory["current"]["median"] - memory["baseline"]["median"]) / memory["baseline"]["median"].to_f) * 100.0
}

tests = {}
%w[baseline current].each do |variant|
  runs = (1..3).map do |index|
    output = File.read(File.join(results, "tests", "#{variant}-#{index}.out"))
    timing = File.read(File.join(results, "tests", "#{variant}-#{index}.time"))
    {
      "exit_code" => File.read(File.join(results, "tests", "#{variant}-#{index}.exit")).to_i,
      "seconds" => timing[/^real\s+([\d.]+)/, 1].to_f,
      "unit_passed" => output[/packwrite tests: (\d+) passed/, 1].to_i,
      "unit_failed" => output[/packwrite tests: \d+ passed, (\d+) failed/, 1].to_i,
      "cli_passed" => output[/cli integration: (\d+) passed/, 1].to_i,
      "cli_failed" => output[/cli integration: \d+ passed, (\d+) failed/, 1].to_i
    }
  end
  tests[variant] = {"runs" => runs, "timing" => stats(runs.map { |run| run["seconds"] }), "successful_runs" => runs.count { |run| run["exit_code"] == 0 }}
end

samples = {}
Dir[File.join(results, "samples", "*.json")].sort.each do |path|
  samples[File.basename(path, ".json")] = JSON.parse(File.read(path))
end

evaluation = {
  "schema_version" => "1.0.0",
  "generated_at" => Time.now.utc.iso8601,
  "boundary" => {
    "baseline" => JSON.parse(File.read(File.join(results, "git", "baseline.json"))),
    "current" => JSON.parse(File.read(File.join(results, "git", "current.json"))),
    "baseline_reason" => "Immediate parent of the first dedicated hardening commit 149a004; later than v1.0.0 and therefore avoids attributing two earlier maintenance commits to hardening.",
    "baseline_compatibility_patch" => "benchmarks/hardening/baseline-compat.patch"
  },
  "environment" => JSON.parse(File.read(File.join(results, "environment.json"))),
  "methodology" => {"warmups" => config["warmups"], "measured_runs" => config["measured_runs"], "latency_unit" => "seconds", "memory_unit" => "bytes"},
  "runtime" => timings,
  "memory_peak_rss" => memory,
  "output_and_prompt_samples" => samples,
  "reliability" => tests,
  "eval" => %w[baseline current].to_h { |variant| [variant, JSON.parse(File.read(File.join(results, "eval-#{variant}", "summary.json")))] },
  "code_metrics" => %w[baseline current].to_h { |variant| [variant, JSON.parse(File.read(File.join(results, "code-metrics-#{variant}.json")))] },
  "token_measurement" => {"status" => "not_demonstrated", "reason" => "Offline fake-response workloads make no model call and expose no tokenizer or provider usage counters."},
  "cost_model" => {"status" => "not_demonstrated", "reason" => "No measured token or provider-compute delta exists."},
  "regressions" => [
    "Successful-path latency increased in every measured common workload.",
    "Peak RSS increased for the 13-file dry-run workload.",
    "Rendered prompt and repository-context bytes increased.",
    "Source and test footprint increased."
  ],
  "limitations" => [
    "The shared host had unrelated build and benchmark jobs active; paired commands and variance are preserved, but absolute latency is load-sensitive.",
    "The unmodified baseline cannot start on standalone Kujo 1.1.0; a documented parser/module compatibility patch was applied only to the disposable performance checkout.",
    "The 64 KiB invalid-response baseline is right-censored at five seconds.",
    "No live model/provider was used, so tokens, cost, network behavior, and end-to-end agent completion quality were not measured.",
    "PackWrite is interpreted, so a PackWrite binary-size or compile-time comparison is not applicable."
  ]
}

File.write(File.join(results, "evaluation-results.json"), JSON.pretty_generate(evaluation) + "\n")

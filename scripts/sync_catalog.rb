#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "thread"
require "time"
require "uri"

INDEX_URL = "https://inductiveautomation.com/downloads/ignition"
SWITCH_BUILD_URL = "https://inductiveautomation.com/downloads/switch_build"
OUTPUT_PATH = File.expand_path("../data/stable-macos-artifacts.json", __dir__)
USER_AGENT = "Mozilla/5.0 (Macintosh; Apple Silicon Mac OS X 10_15_7) " \
             "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36"
WORKERS = 4

def perform(uri, request)
  request["Accept-Encoding"] = "identity"
  request["User-Agent"] = USER_AGENT
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 20, read_timeout: 45) do |http|
    response = http.request(request)
    raise "#{uri}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    response
  end
end

def macos_artifacts(html)
  html.split('<div class="flex-row data">').drop(1).map do |row|
    url = row[/<a\s+href="([^"]+)"/, 1]
    label = row[/<a\s+href="[^"]+"[^>]*>\s*<span>(.*?)<\/span>/m, 1]
    sha256 = row[/(?:installer|item)-sha'>([a-f0-9]{64})<\/span>/i, 1]
    next unless url && label && sha256

    label = label.gsub(/\s+/, " ").strip
    next unless label.match?(/mac\s*os|macos/i)

    { "label" => label, "url" => url, "sha256" => sha256 }
  end.compact
end

index_uri = URI(INDEX_URL)
index_response = perform(index_uri, Net::HTTP::Get.new(index_uri))
payload = index_response.body[/var\s+ignition_versions\s*=\s*JSON\.parse\('(.+?)'\);/m, 1]
abort "Could not find IA's embedded release catalogue" unless payload

cookies = index_response.get_fields("set-cookie") || []
csrf_token = cookies.map { |cookie| cookie[/\Acsrftoken=([^;]+)/, 1] }.compact.first
abort "Could not obtain IA CSRF token" unless csrf_token
cookie_header = cookies.map { |cookie| cookie.split(";", 2).first }.join("; ")

builds = JSON.parse(payload).flat_map do |entry|
  branch = entry.keys.first
  entry.fetch(branch).fetch("builds").map do |build|
    next unless build["state"] == "STABLE"

    build.merge("branch" => branch)
  end.compact
end

queue = Queue.new
builds.each { |build| queue << build }
artifacts = []
failures = []
mutex = Mutex.new

workers = WORKERS.times.map do
  Thread.new do
    loop do
      build = queue.pop(true)
      uri = URI(SWITCH_BUILD_URL)
      request = Net::HTTP::Post.new(uri)
      request["Cookie"] = cookie_header
      request["Referer"] = INDEX_URL
      request["X-Requested-With"] = "XMLHttpRequest"
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = URI.encode_www_form(
        build: build.fetch("buildid"),
        OSArch: 64,
        csrfmiddlewaretoken: csrf_token,
        page: "archive",
      )

      rows = nil
      3.times do |attempt|
        begin
          rows = macos_artifacts(perform(uri, request).body)
          break
        rescue StandardError
          raise if attempt == 2

          sleep(attempt + 1)
        end
      end
      mutex.synchronize do
        artifacts.concat(rows.map { |row| build.slice("branch", "buildid", "version", "released").merge(row) })
      end
      sleep 0.1
    rescue ThreadError
      break
    rescue StandardError => error
      mutex.synchronize { failures << build.merge("error" => "#{error.class}: #{error.message}") }
    end
  end
end
workers.each(&:join)

abort "Catalogue sync failed: #{failures.to_json}" unless failures.empty?

artifacts.sort_by! { |artifact| [Gem::Version.new(artifact.fetch("version")), artifact.fetch("label")] }
catalogue = {
  "source" => INDEX_URL,
  "scanned_at" => Time.now.utc.iso8601,
  "stable_build_count" => builds.length,
  "macos_artifact_count" => artifacts.length,
  "artifacts" => artifacts,
}
File.write(OUTPUT_PATH, JSON.pretty_generate(catalogue) + "\n")
puts "Wrote #{artifacts.length} macOS artifact records to #{OUTPUT_PATH}"

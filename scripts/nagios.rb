#!/usr/bin/env ruby

$working_path = File.expand_path(File.dirname(__FILE__))

require "#{$working_path}/lib/nagios_configuration.rb"
require "#{$working_path}/lib/overrides.rb"
require "fileutils"

if File.exists?("#{$working_path}/cache/discovered.yml")
  $discovered = NagiosConfiguration.new(YAML.load(open("#{$working_path}/cache/discovered.yml").read) || {})
else
  $discovered = NagiosConfiguration.new
end

def reload_nagios!(start: false)
  defaults = YAML.load(open("#{$working_path}/defaults.yml").read)

  config = if File.exists?("#{$working_path}/config/config.yml")
    YAML.load(open("#{$working_path}/config/config.yml").read)
  else
    {}
  end

  config = NagiosConfiguration.new(defaults.deep_merge($discovered.to_h).deep_merge(config))

  File.open("#{$working_path}/cache/discovered.yml", "w") do |f|
    f.puts("# Last update: #{Time.now}")
    f.puts($discovered.to_yaml)
  end if !start && !$discovered.empty?

  File.open("/etc/nagios4/conf.d/config.cfg", "w") do |f|
    f.puts(config.to_cfg)
  end

  File.open("/etc/nagios4/htpasswd.users", "w") do |f|
    f.puts(config.to_htpasswd)
  end

  output = `/etc/init.d/nagios4 #{start ? "start" : "reload"}`
  return_code = $?.to_i

  if return_code != 0
    puts output
    exit return_code
  else
    sleep 3
  end
end

reload_nagios!(start: true)

loop do
  check_results = Dir.glob("/nsca-checkresults/c*").reject do |filename|
    filename.end_with?(".ok")
  end.sort_by do |f|
    File.ctime(f)
  end

  reload_needed = false

  check_results.each do |check_result|
    lines = open(check_result).readlines

    host = nil
    service = nil

    lines.each do |line|
      k, v = line.split("=")

      if k == "host_name"
        host = v.strip
      elsif k == "service_description"
        service = v.strip
      end
    end

    if !host.nil? && !service.nil?
      if new_object = $discovered.add_passive_service(host, service)
        puts "Discovered new service: #{host} / #{service}"
      end
    elsif !host.nil? && service.nil?
      if new_object = $discovered.add_passive_host(host)
        puts "Discovered new host: #{host}"
      end
    end

    reload_needed = reload_needed || new_object
  end

  reload_nagios! if reload_needed

  check_results.each do |check_result|
    FileUtils.mv(check_result, "/var/lib/nagios4/spool/checkresults/#{File.basename(check_result)}")
    FileUtils.mv("#{check_result}.ok", "/var/lib/nagios4/spool/checkresults/#{File.basename(check_result)}.ok")
  end

  sleep 3
end

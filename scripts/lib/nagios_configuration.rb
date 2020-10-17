require "yaml"

class NagiosConfiguration
  def initialize(configuration = {})
    @configuration = configuration
  end

  def empty?
    @configuration.nil? || !@configuration || @configuration.empty?
  end

  def to_cfg
    nagios = []
    parsed_configuration = @configuration.deep_clone

    parsed_configuration["timeperiods"].each do |timeperiod, timeperiod_configuration|
      defaults = {
        "timeperiod_name" => timeperiod,
        "alias" => timeperiod,
        "name" => timeperiod
      }

      nagios << define_block("timeperiod", defaults.merge(timeperiod_configuration))
    end

    parsed_configuration["contacts"].each do |contact, contact_configuration|
      contact_configuration.delete("password")

      defaults = {
        "contact_name" => contact
      }

      if contact_configuration["register"] != false
        defaults["use"] = "generic-contact"
      else
        defaults["name"] = contact
      end

      nagios << define_block("contact", defaults.merge(contact_configuration))
    end

    parsed_configuration["contactgroups"].each do |contactgroup, contactgroup_configuration|
      contactgroup_configuration.delete("password")

      defaults = {
        "contactgroup_name" => contactgroup
      }

      nagios << define_block("contactgroup", defaults.merge(contactgroup_configuration))
    end

    parsed_configuration["hosts"].each do |host, host_configuration|
      host_services = host_configuration.delete("services")
      passive = host_configuration.delete("passive")
      passive = true if passive.nil?

      defaults = {
        "host_name" => host
      }

      if host_configuration["register"] != false
        defaults["use"] = if passive
          "generic-passive-host"
        else
          "generic-active-host"
        end
      else
        defaults["name"] = host
      end

      nagios << define_block("host", defaults.merge(host_configuration))

      host_services.map do |service|
        if service.is_a?(String)
          service_configuration = {"service_description" => service}
        else
          service = service.to_a.flatten
          service_configuration = {"service_description" => service[0]}.merge(service[1])
        end

        defaults = {
          "host_name" => host
        }

        if service_configuration["register"] != false
          defaults["use"] = if passive
            "generic-passive-service"
          else
            "generic-active-service"
          end
        else
          defaults["name"] = service_configuration["service_description"]
        end

        nagios << define_block("service", defaults.merge(service_configuration))
      end unless host_services.nil?

      host_configuration["hostgroups"].each do |hostgroup|
        parsed_configuration["hostgroups"] ||= []
        parsed_configuration["hostgroups"] << hostgroup
      end unless host_configuration["hostgroups"].nil?
    end

    parsed_configuration["hostgroups"].each do |hostgroup|
      nagios << define_block("hostgroup", {"hostgroup_name" => hostgroup})
    end if parsed_configuration.has_key?("hostgroups")

    parsed_configuration["commands"].each do |command, command_configuration|
      nagios << define_block("command", {"command_name" => command}.merge(command_configuration))
    end if parsed_configuration.has_key?("commands")

    nagios.join("\n")
  end

  def to_htpasswd
    @configuration["contacts"].map do |user, user_config|
      "#{user}:#{user_config["password"]}" unless user_config["password"].nil?
    end.compact.join("\n")
  end

  def define_block(object_type, object_keys)
    output = []

    output << "define #{object_type} {"
    object_keys.each do |k, v|
      if v === false
        v = 0
      elsif v === true
        v = 1
      end

      v = [v].flatten.map(&:to_s).join(", ")

      output << "  #{k} #{"%#{40 - k.size + v.size}s" % v}"
    end
    output << "}\n"
    output.join("\n")
  end

  def add_passive_host(host)
    @configuration["hosts"] ||= {}

    if @configuration["hosts"][host].nil?
      @configuration["hosts"][host] = {
        "services" => []
      }
      return true
    else
      return false
    end
  end

  def add_passive_service(host, service)
    add_passive_host(host)

    if @configuration["hosts"][host]["services"].include?(service)
      return false
    else
      @configuration["hosts"][host]["services"] << service
      return true
    end
  end

  def to_yaml
    to_h.to_yaml
  end

  def to_h
    @configuration.to_hash
  end
end

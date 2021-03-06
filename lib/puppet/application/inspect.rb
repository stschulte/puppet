require 'puppet/application'

class Puppet::Application::Inspect < Puppet::Application

  should_parse_config
  run_mode :agent

  option("--debug","-d")
  option("--verbose","-v")

  option("--logdest LOGDEST", "-l") do |arg|
    begin
      Puppet::Util::Log.newdestination(arg)
      options[:logset] = true
    rescue => detail
      $stderr.puts detail.to_s
    end
  end

  def setup
    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    raise "Inspect requires reporting to be enabled. Set report=true in puppet.conf to enable reporting." unless Puppet[:report]

    @report = Puppet::Transaction::Report.new("inspect")

    Puppet::Util::Log.newdestination(@report)
    Puppet::Util::Log.newdestination(:console) unless options[:logset]

    trap(:INT) do
      $stderr.puts "Exiting"
      exit(1)
    end

    if options[:debug]
      Puppet::Util::Log.level = :debug
    elsif options[:verbose]
      Puppet::Util::Log.level = :info
    end

    Puppet::Transaction::Report.indirection.terminus_class = :rest
    Puppet::Resource::Catalog.indirection.terminus_class = :yaml
  end

  def run_command
    retrieval_starttime = Time.now

    unless catalog = Puppet::Resource::Catalog.indirection.find(Puppet[:certname])
      raise "Could not find catalog for #{Puppet[:certname]}"
    end

    retrieval_time =  Time.now - retrieval_starttime
    @report.add_times("config_retrieval", retrieval_time)

    starttime = Time.now

    catalog.to_ral.resources.each do |ral_resource|
      audited_attributes = ral_resource[:audit]
      next unless audited_attributes

      audited_resource = ral_resource.to_resource

      status = Puppet::Resource::Status.new(ral_resource)
      audited_attributes.each do |name|
        event = ral_resource.event(:previous_value => audited_resource[name], :property => name, :status => "audit", :message => "inspected value is #{audited_resource[name].inspect}")
        status.add_event(event)
      end
      @report.add_resource_status(status)
    end

    @report.add_metric(:time, {"config_retrieval" => retrieval_time, "inspect" => Time.now - starttime})

    begin
      Puppet::Transaction::Report.indirection.save(@report)
    rescue => detail
      puts detail.backtrace if Puppet[:trace]
      Puppet.err "Could not send report: #{detail}"
    end
  end
end

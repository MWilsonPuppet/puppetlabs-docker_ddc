module Puppet::Parser::Functions
  newfunction(:ucp_install_flags, :type => :rvalue) do |args|
    opts = args[0] || {}
    flags = []
    flags << "--admin-username '#{opts['admin_username']}'" if opts['admin_username'].to_s != 'undef'
    flags << "--admin-password '#{opts['admin_password']}'" if opts['admin_password'].to_s != 'undef'
    flags << "--host-address '#{opts['host_address']}'" if opts['host_address'] && opts['host_address'].to_s != 'undef'
    flags << '--disable-tracking' unless opts['tracking']
    flags << '--disable-usage' unless opts['usage']
    flags << "--swarm-port '#{opts['swarm_port']}'" if opts['swarm_port'] && opts['swarm_port'].to_s != 'undef'
    flags << "--controller-port '#{opts['controller_port']}'" if opts['controller_port'] && opts['controller_port'].to_s != 'undef'
    flags << '--preserve-certs' if opts['preserve_certs']
    flags << '--external-ucp-ca' if opts['external_ca']

    if opts['swarm_scheduler']
      case opts['swarm_scheduler']
      when 'binpack'
        flags << '--binpack'
      when 'random'
        flags << '--random'
      end
    end

    multi_flags = lambda do |values, format|
      filtered = [values].flatten.compact
      filtered.map { |val| sprintf(format, val) }
    end

    [
      ["--dns '%s'",        'dns_servers'],
      ["--dns-search '%s'", 'dns_search_domains'],
      ["--dns-opt '%s'",    'dns_options'],
      ["--san '%s'",        'san'],
    ].each do |(format, key)|
      values    = opts[key]
      new_flags = multi_flags.call(values, format)
      flags.concat(new_flags)
    end

    opts['extra_parameters'].each do |param|
      flags << param
    end

    flags.flatten.join('')
  end
end

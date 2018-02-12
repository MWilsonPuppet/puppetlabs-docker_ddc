require 'spec_helper_acceptance'
require 'pry'

hosts.each do |host|
  vmhostname = on(host, 'hostname', acceptable_exit_codes: [0]).stdout.strip
  vmipaddr   = on(host, "ip route get 8.8.8.8 | awk '{print $NF; exit}'", acceptable_exit_codes: [0]).stdout.strip

describe 'the Puppet Docker module' do
  context 'clean up before each test' do
    before(:each) do
      # Stop all container using systemd
      shell('ls -D -1 /etc/systemd/system/docker-container* | sed \'s/\/etc\/systemd\/system\///g\' | sed \'s/\.service//g\' | while read container; do service $container stop; done')
      # Delete all running containers
      shell('docker rm -f $(docker ps -a -q) || true')
      # Delete all existing images
      shell('docker rmi $(docker images -q) || true')
      # Check to make sure no images are present
      shell('docker images | wc -l') do |r|
        expect(r.stdout).to match(/^0|1$/)
      end
      # Check to make sure no running containers are present
      shell('docker ps | wc -l') do |r|
        expect(r.stdout).to match(/^0|1$/)
      end
    end
  end
end

describe 'docker class' do
  context 'without docker_ee parameters' do
    docker_ee_source_location  = ENV['docker_ee_source_location']
    docker_ee_key_source  = ENV['docker_ee_key_source']
    docker_ee_key_id  = ENV['docker_ee_key_id']
    ucp_hostname = shell ('hostname')
    puts "#{ucp_hostname}"
    case fact('osfamily')
      when 'Debian'
        pp=<<-EOS
        class { 'docker':
          docker_ee => true,
          docker_ee_source_location => '#{docker_ee_source_location}',
          docker_ee_key_source => '#{docker_ee_key_source}',
          docker_ee_key_id => '#{docker_ee_key_id}',
        }
        EOS
        else
          pp=<<-EOS
          class { 'docker':
            docker_ee => true,
            docker_ee_source_location => '#{docker_ee_source_location}',
            docker_ee_key_source => '#{docker_ee_key_source}',
          }
          EOS
          end
    it 'should run successfully' do
      apply_manifest(pp, :catch_failures => true)
    end
    it 'should run idempotently' do
      apply_manifest(pp, :catch_changes => true) unless fact('selinux') == 'true'
    end
    it 'should be start a docker process' do
      shell('ps -aux | grep docker') do |r|
      expect(r.stdout).to match(/dockerd -H unix:\/\/\/var\/run\/docker.sock/)
      end
    end
    it 'should install a working docker client' do
      shell('docker ps', :acceptable_exit_codes => [0])
    end
    it 'should run hello-world' do
      shell('docker run hello-world', :acceptable_exit_codes => [0])
    end
  end
end

describe 'docker ucp version >= 2.0 install' do
  context 'with controller parameters' do
    it 'should install a UCP controller using Docker, with non default username and password' do
      pp=<<-EOS
      class { 'docker_ddc':
         controller => true,
         username   => 'tester',
         password   => 'tester1234',
         version    => '2.2.3'
      }
      EOS
      binding.pry
        on (master, 'apply_manifest(pp, :catch_failures => true)
#        on (master, "echo #{pp} > mark.pp")
#        on(master, 'puppet apply mark.pp', :catch_failures => true)

    it 'The UCP login page should be reachable' do
      shell("curl -k https://#{vmipaddr}/login/") do |r|
      expect(r.stdout).to match(/Universal Control Plane/)
      end
    end 
  end
end
#    it 'The non default user created at install time should be able to login' do
#      shell(curl -sk -d '{"username":"tester","password":"tester1234"}' https://#{vmpaddr/auth/login | jq -r .auth_token", :acceptable_exit_codes => [0])
#    end
#  end
#end

# describe 'Joining node to swarm with UCP version >=2.0' do
#  it 'should obtain token successfully' do
#    join_token = on(default, "docker swarm join-token worker | grep docker |awk '{$1=$1};1'",:acceptable_exit_codes=> [0]).stdout
#    pp=<<-EOS
#    class { 'docker_ddc':
#      version => '2.2.3',
#      token => '#{join_token}',
#      listen_address => '{vmipaddr}',
#      advertise_address => '#{vmipaddr}',
#      ucp_manager => '#{vmipaddr}',
#    }
#    on(default, echo "#{pp} >> join_node.pp":acceptable_exit_codes=> [0])
#    on(default, 'puppet apply join_node.pp':acceptable_exit_codes => [0,2])
#  end
# end

# Include uninstall tests here to remove node from swarm and uninstall ucp

#  describe 'docker ucp version <= 1.0 install' do
#    context 'with controller parameters' do
#      it 'should install a UCP controller with non default username and password' do
#        pp=<<-EOS
#        class { 'docker_ddc':
#          controller => true,
#          username   => 'tester',
#          password   => 'tester1234',
#          version    => '1.0.0'
#        }
#        EOS
#        on(master, "echo #{pp} > mark.pp", :catch_failures => true)
#      end
#    end
#  end

#describe 'Joining node to swarm with UCP version <= 1.0' do
#  it 'should obtain fingerprint successfully' do
#    fingerprint = on(master, "docker run --rm --name ucp -v /var/run/docker.sock:/var/run/docker.sock docker/ucp fingerprint",:acceptable_exit_codes=> [0]).stdout
#    pp=<<-EOS
#    class { 'docker_ddc':
#      ucp_url                   => 'https://',
#      fingerprint               => '#{fingerprint#}',
#      username                  => 'tester',
#      password                  => 'tester1234',
#      host_address              => ::ipaddress_eth1,
#      subject_alternative_names => ::ipaddress_eth1,
#      replica                   => true,
#      version                   => '0.8.0',
#      usage                     => false,
#      tracking                  => false,
#    }       

end

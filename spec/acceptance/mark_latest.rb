require 'spec_helper_acceptance'
require 'net/ssh'
require 'pry'
hosts.each do |host|
  vmhostname = on(host, 'hostname', acceptable_exit_codes: [0]).stdout.strip
  vmipaddr = on(host, "ip route get 8.8.8.8 | awk '{print $NF; exit}'", acceptable_exit_codes: [0]).stdout.strip
  ubuntu_1604 = hosts[0]
  ubuntu_1604_host_name = on(ubuntu_1604, 'hostname', acceptable_exit_codes: [0]).stdout.strip
  ubuntu_1604_ip = on(ubuntu_1604, "ip route get 8.8.8.8 | awk '{print $NF; exit}'", acceptable_exit_codes: [0]).stdout.strip
  rhel7 = hosts[1]
  rhel7_hostname = on(rhel7, 'hostname', acceptable_exit_codes: [0]).stdout.strip


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
      context 'with Docker EE params set' do
        docker_ee_source_location_ubuntu  = ENV['docker_ee_source_location_ubuntu']
        docker_ee_source_location_rhel = ENV['docker_ee_source_location_rhel']
        docker_ee_key_source_ubuntu  = ENV['docker_ee_key_source_ubuntu']
        docker_ee_key_source_rhel  = ENV['docker_ee_key_source_rhel']
        docker_ee_key_id  = ENV['docker_ee_key_id']
        ucp_hostname = shell ('hostname')
        puts "#{ucp_hostname}"
          pp=<<-EOS
            if \\\$facts['os']['family'] == 'Debian'{
              class { 'docker':
              docker_ee => true,
              docker_ee_source_location => '#{docker_ee_source_location_ubuntu}',
              docker_ee_key_source => '#{docker_ee_key_source_ubuntu}',
              docker_ee_key_id => '#{docker_ee_key_id}',
              }
            }
           else {
             class { 'docker':
               docker_ee => true,
               docker_ee_source_location => '#{docker_ee_source_location_rhel}',
               docker_ee_key_source => '#{docker_ee_key_source_rhel}',
               docker_ee_key_id => '#{docker_ee_key_id}',
              }
           }
           EOS


        it 'should be installed successfully on Ubuntu_1604' do
          on "#{ubuntu_1604}", "echo \"#{pp}\" > docker_install.pp", :acceptable_exit_codes => [0]
          on "#{ubuntu_1604}", 'puppet apply docker_install.pp', :acceptable_exit_codes => [0,2]
        end

        it 'should start a docker process on ubuntu_1604' do
          on("#{ubuntu_1604}", 'ps -aux | grep docker', :acceptable_exit_codes => [0]) do |result|
            expect(result.stdout).to match(/dockerd -H unix:\/\/\/var\/run\/docker.sock/)
          end
        end

        it 'should install a working docker client on ubuntu_1604' do
          on "#{ubuntu_1604}", 'docker ps', :acceptable_exit_codes => [0]
        end

        it 'should run hello-world on Ubuntu_1604' do
          on "#{ubuntu_1604}", 'docker run hello-world', :acceptable_exit_codes => [0]
        end

        it 'should be installed successfully on RHEL7' do
          on "#{rhel7}", "echo \"#{pp}\" > docker_install.pp", :acceptable_exit_codes => [0]
          on "#{rhel7}", 'puppet apply docker_install.pp', :acceptable_exit_codes => [0,2]
        end

        it 'should start a docker process on rhel 7' do
          on("#{rhel7}", 'ps -aux | grep docker') do |result|
            expect(result.stdout).to match(/dockerd -H unix:\/\/\/var\/run\/docker.sock/)
          end
        end

        it 'should install a working docker client on rhel7' do
          on("#{rhel7}", 'docker ps', :acceptable_exit_codes => [0])
        end

          it 'should run hello-world on rhel7' do
            on("#{rhel7}", 'docker run hello-world', :acceptable_exit_codes => [0])
          end
      end
    end


    describe 'docker_ddc class controller parameters' do
     context 'with controller parameters' do
       it 'should install a UCP controller using Docker' do
             pp=<<-EOS
               if \\\$facts['os']['family'] == 'Debian'{
                 class { 'docker_ddc':
                 controller => true,
                 username => 'tester',
                 password => 'test1234',
                 }
               }
               EOS

          on "#{ubuntu_1604}", "echo \"#{pp}\" > ddc_install.pp", :acceptable_exit_codes => [0]
          on "#{ubuntu_1604}", 'puppet apply ddc_install.pp', :acceptable_exit_codes => [0,2]
        end

       it 'should be able to access UCP Control Plane' do
          on("#{ubuntu_1604}", "curl -k https://#{ubuntu_1604_ip}/login/") do |result|
            expect(result.stdout).to match(/Universal Control Plane/)
          end
        end

       # we are testing that the user and password were created successfully by requesting an auth token.
       # If the token is returned successfully rather than unauthorized we know the creds are valid.
       it 'Should be able to get an auth token using non default creds' do
         on("#{ubuntu_1604}", "curl -sk -d '{\"username\":\"tester\",\"password\":\"test1234\"}' https://#{ubuntu_1604_host_name}.delivery.puppetlabs.net/auth/login") do |result|
         expect(result.stdout).to match(/auth_token/)
       end
     end
     end
    end

   describe 'join worker node to swarm cluster' do
      it 'the token should be obtained successfully' do
        get_token=on("#{ubuntu_1604}", "curl -sk -d '{\"username\":\"tester\",\"password\":\"test1234\"}' https://#{ubuntu_1604_host_name}.delivery.puppetlabs.net/auth/login")
        token_parse=JSON.parse(get_token)
        auth_token=token_parse["auth_token"]
        pp=<<-EOS
          if \\\$facts['os']['family'] == 'RedHat'
            class { 'docker_ddc':
            version => '2.2.3',
            token => "#{auth_token}",
            listen_address => '0.0.0.0:2377',
            advertise_address => '0.0.0.0:2377'
            ucp_manager => "https://#{ubuntu_1604_host_name}.delivery.puppetlabs.net"
            }
          }
          EOS

        on "#{rhel7}", "echo \"#{pp}\" > node_join.pp", :acceptable_exit_codes => [0]
        on "#{rhel7}", 'puppet apply node_join.pp', :acceptable_exit_codes => [0,2]

        it 'should show the newly added node in the cluster' do
          on("#{ubuntu_1604}", 'docker node ls', :acceptable_exit_codes => [0]) do |result|
            expect(result.stdout).to match(/#{ubuntu_1604_host_name}/)
          end
        end
      end
   end

  # include test for removing node from the cluster
  # include test for uninstalling ucp

#  describe ' install DTR' do
#    context ' with DTR class params set' do
#      it 'should install DTR successfully' do
#        pp=<<-EOS
#        if \\\$facts['os']['family'] == 'RedHat'{
#          class { 'docker_ddc::dtr':
#            install => true,
#            dtr_version => 'latest',
#            dtr_external_url => '#{rhel7_hostname}.delivery.puppetlabs.net',
#            ucp_node => '#{rhel7_hostname}',
#            ucp_username => 'tester',
#            ucp_password => 'test1234',
#            ucp_insecure_tls => true,
#            dtr_ucp_url => "https://#{rhel7_hostname}.delivery.puppetlabs.net",
#            require => Class['docker_ucp']
#            }
#        }
#        EOS

#        on "#{rhel7}", "echo \"#{pp}\" > install_dtr.pp", :acceptable_exit_codes => [0]
#        on "#{rhel7}", 'puppet apply install_dtr.pp', :acceptable_exit_codes => [0,2]
       # include DTR tests here that check running as expected.
#      end
#    end
#  end

#  describe ' Uninstall DTR' do
#    context ' with DTR class params set' do
#      it 'should uninstall DTR successfully' do
#        pp=<<-EOS
#        if \\\$facts['os']['family'] == 'RedHat'{
#          class { 'docker_ddc::dtr':
#            ensure => absent,
#            dtr_version => 'latest',
#           dtr_external_url => '#{rhel7_hostname}.delivery.puppetlabs.net',
#            ucp_node => '#{rhel7_hostname}',
#            ucp_username => 'tester',
#            ucp_password => 'test1234',
#            ucp_insecure_tls => true,
#            dtr_ucp_url => "https://#{rhel7_hostname}.delivery.puppetlabs.net",
#            require => Class['docker_ucp']
#            }
#        }
#        EOS

#        on "#{rhel7}", "echo \"#{pp}\" > install_dtr.pp", :acceptable_exit_codes => [0]
#        on "#{rhel7}", 'puppet apply install_dtr.pp', :acceptable_exit_codes => [0,2]
        # include DTR tests here that check running as expected.
#      end
#    end
#  end
end

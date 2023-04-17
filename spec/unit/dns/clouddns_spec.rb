require 'spec_helper'
require 'mock_redis'
require 'vmpooler/dns/gcp'

describe 'Vmpooler::PoolManager::Dns::Gcp' do
  let(:logger) { MockLogger.new }
  let(:metrics) { Vmpooler::Metrics::DummyStatsd.new }
  let(:poolname) { 'debian-9' }
  let(:options) { { 'param' => 'value' } }
  let(:name) { 'gcp' }
  let(:zone_name) { 'vmpooler-example-com' }
  let(:config) { YAML.load(<<~EOT
  ---
  :config:
    max_tries: 3
    retry_factor: 10
  :dns_configs:
    :#{name}:
      dns_class: gcp
      project: vmpooler-example
      domain: vmpooler.example.com
      zone_name: vmpooler-example-com
      dns_zone_resource_name: vmpooler-example-com
  :providers:
    :dummy:
      filename: '/tmp/dummy-backing.yaml'
  :pools:
    - name: '#{poolname}'
      alias: [ 'mockpool' ]
      template: 'Templates/debian-9-x86_64'
      size: 5
      timeout: 10
      ready_ttl: 1440
      provider: 'dummy'
      dns_config: '#{name}'
EOT
    )
  }

  let(:vmname) { 'spicy-proton' }
  let(:connection_options) {{}}
  let(:connection) { mock_Google_Cloud_Dns_Project_Connection(connection_options) }
  let(:redis_connection_pool) do
    Vmpooler::PoolManager::GenericConnectionPool.new(
      metrics: metrics,
      connpool_type: 'redis_connection_pool',
      connpool_provider: 'testprovider',
      size: 1,
      timeout: 5
    ) { MockRedis.new }
  end

  subject { Vmpooler::PoolManager::Dns::Gcp.new(config, logger, metrics, redis_connection_pool, name, options) }

  describe '#name' do
    it 'should be gcp' do
      expect(subject.name).to eq('gcp')
    end
  end

  describe '#project' do
    it 'should be the project specified in the dns config' do
      expect(subject.project).to eq('vmpooler-example')
    end
  end

  describe '#zone_name' do
    it 'should be the zone_name specified in the dns config' do
      expect(subject.zone_name).to eq('vmpooler-example-com')
    end
  end

  describe '#create_or_replace_record' do
    let(:hostname) { 'spicy-proton' }
    let(:zone) { MockDnsZone.new }
    let(:ip) { '169.254.255.255' }

    context 'when adding a record' do
      before(:each) do
        allow(Google::Cloud::Dns).to receive(:configure)
        allow(Google::Cloud::Dns).to receive(:new).and_return(connection)
        allow(connection).to receive(:zone).and_return(zone)
        allow(subject).to receive(:get_ip).and_return(ip)
      end

      it 'should attempt to add a record' do
        expect(zone).to receive(:add).with(hostname, 'A', 60, ip)
        result = subject.create_or_replace_record(hostname)
      end
    end

    context 'when record already exists' do
      before(:each) do
        allow(Google::Cloud::Dns).to receive(:configure)
        allow(Google::Cloud::Dns).to receive(:new).and_return(connection)
        allow(connection).to receive(:zone).and_return(zone)
        allow(subject).to receive(:get_ip).and_return(ip)
      end

      it 'should attempt to replace a record' do
        allow(zone).to receive(:add).with(:hostname, 'A', 60, ip).and_raise(Google::Cloud::AlreadyExistsError,'MockError')
        expect(zone).to receive(:replace).with(:hostname, 'A', 60, ip)
        allow(subject).to receive(:get_ip).and_return(ip)
        result = subject.create_or_replace_record(:hostname)
      end
    end

    context 'when add record fails' do
      before(:each) do
        allow(Google::Cloud::Dns).to receive(:configure)
        allow(Google::Cloud::Dns).to receive(:new).and_return(connection)
        allow(connection).to receive(:zone).and_return(zone)
        allow(subject).to receive(:get_ip).and_return(ip)
      end

      it 'should retry' do
        allow(zone).to receive(:add).with(:hostname, 'A', 60, ip).and_raise(Google::Cloud::FailedPreconditionError,'MockError')
        expect(zone).to receive(:add).with(:hostname, 'A', 60, ip).exactly(30).times
        allow(subject).to receive(:sleep)
        result = subject.create_or_replace_record(:hostname)
      end
    end

    context 'when IP does not exist' do
      let(:ip) { nil }

      before(:each) do
        allow(Google::Cloud::Dns).to receive(:configure)
        allow(Google::Cloud::Dns).to receive(:new).and_return(connection)
        allow(connection).to receive(:zone).and_return(zone)
        allow(subject).to receive(:get_ip).and_return(ip)
      end

      it 'should not attempt to add a record' do
        allow(zone).to receive(:add).with(:hostname, 'A', 60, ip).and_raise(Google::Cloud::AlreadyExistsError,'MockError')
        expect(zone).to_not have_received(:add)
        allow(subject).to receive(:get_ip).and_return(ip)
        result = subject.create_or_replace_record(:hostname)
      end
    end
  end

  describe "#delete_record" do
    let(:hostname) { 'spicy-proton' }
    let(:zone) { MockDnsZone.new }

    context 'when removing a record' do
      before(:each) do
        allow(Google::Cloud::Dns).to receive(:configure)
        allow(Google::Cloud::Dns).to receive(:new).and_return(connection)
        allow(connection).to receive(:zone).and_return(zone)
      end

      it 'should attempt to remove a record' do
        expect(zone).to receive(:remove).with(:hostname, 'A')
        result = subject.delete_record(:hostname)
      end
    end

    context 'when removing a record fails' do
      before(:each) do
        allow(Google::Cloud::Dns).to receive(:configure)
        allow(Google::Cloud::Dns).to receive(:new).and_return(connection)
        allow(connection).to receive(:zone).and_return(zone)
      end

      it 'should retry' do
        allow(zone).to receive(:remove).with(:hostname, 'A').and_raise(Google::Cloud::FailedPreconditionError,'MockError')
        expect(zone).to receive(:remove).with(:hostname, 'A').exactly(30).times
        allow(subject).to receive(:sleep)
        result = subject.delete_record(:hostname)
      end
    end
  end

  describe '#ensured_gcp_connection' do
    let(:connection1) { mock_Google_Cloud_Dns_Project_Connection(connection_options) }
    let(:connection2) { mock_Google_Cloud_Dns_Project_Connection(connection_options) }

    before(:each) do
      allow(subject).to receive(:connect_to_gcp).and_return(connection1)
    end

    it 'should return the same connection object when calling the pool multiple times' do
      subject.connection_pool.with_metrics do |pool_object|
        expect(pool_object[:connection]).to be(connection1)
      end
      subject.connection_pool.with_metrics do |pool_object|
        expect(pool_object[:connection]).to be(connection1)
      end
      subject.connection_pool.with_metrics do |pool_object|
        expect(pool_object[:connection]).to be(connection1)
      end
    end

    context 'when the connection breaks' do
      before(:each) do
        # Emulate the connection state being good, then bad, then good again
        expect(subject).to receive(:gcp_connection_ok?).and_return(true, false, true)
        expect(subject).to receive(:connect_to_gcp).and_return(connection1, connection2)
      end

      it 'should restore the connection' do
        subject.connection_pool.with_metrics do |pool_object|
          # This line needs to be added to all instances of the connection_pool allocation
          connection = subject.ensured_gcp_connection(pool_object)

          expect(connection).to be(connection1)
        end

        subject.connection_pool.with_metrics do |pool_object|
          connection = subject.ensured_gcp_connection(pool_object)
          # The second connection would have failed.  This test ensures that a
          # new connection object was created.
          expect(connection).to be(connection2)
        end

        subject.connection_pool.with_metrics do |pool_object|
          connection = subject.ensured_gcp_connection(pool_object)
          expect(connection).to be(connection2)
        end
      end
    end
  end

  describe '#connect_to_gcp' do
    before(:each) do
      allow(Google::Cloud::Dns).to receive(:configure)
      allow(Google::Cloud::Dns).to receive(:new).and_return(connection)
    end

    context 'successful connection' do
      it 'should return the connection object' do
        result = subject.connect_to_gcp

        expect(result).to be(connection)
      end

      it 'should increment the connect.open counter' do
        expect(metrics).to receive(:increment).with('connect.open')
        subject.connect_to_gcp
      end
    end

    context 'connection is initially unsuccessful' do
      before(:each) do
        # Simulate a failure and then success
        allow(Google::Cloud::Dns).to receive(:configure)
        expect(Google::Cloud::Dns).to receive(:new).and_raise(RuntimeError,'MockError')
        allow(subject).to receive(:sleep)
      end

      it 'should return the connection object' do
        result = subject.connect_to_gcp

        expect(result).to be(connection)
      end

      it 'should increment the connect.fail and then connect.open counter' do
        expect(metrics).to receive(:increment).with('connect.fail').exactly(1).times
        expect(metrics).to receive(:increment).with('connect.open').exactly(1).times
        subject.connect_to_gcp
      end
    end

    context 'connection is always unsuccessful' do
      before(:each) do
        allow(Google::Cloud::Dns).to receive(:configure)
        allow(Google::Cloud::Dns).to receive(:new).exactly(3).times.and_raise(RuntimeError,'MockError')
        allow(subject).to receive(:sleep)
      end

      it 'should retry the connection attempt config.max_tries times' do
        expect(Google::Cloud::Dns).to receive(:new).exactly(config[:config]['max_tries']).times

        begin
          # Swallow any errors
          subject.connect_to_gcp
        rescue
        end
      end

      it 'should increment the connect.fail counter config.max_tries times' do
        expect(metrics).to receive(:increment).with('connect.fail').exactly(config[:config]['max_tries']).times

        begin
          # Swallow any errors
          subject.connect_to_gcp
        rescue
        end
      end
    end
  end
end
require 'spec_helper.rb'

RSpec.describe RSolr::Cloud::Connection do
  before do
    @zk_in_solr = ZK.new
    delete_with_children(@zk_in_solr, '/live_nodes')
    delete_with_children(@zk_in_solr, '/collections')
    wait_until(10) do
      !@zk_in_solr.exists?('/live_nodes')
    end
    wait_until(10) do
      !@zk_in_solr.exists?('/collections')
    end
    @zk_in_solr.create('/live_nodes')
    @zk_in_solr.create('/collections')

    ['192.168.1.21:8983_solr',
     '192.168.1.22:8983_solr',
     '192.168.1.23:8983_solr',
     '192.168.1.24:8983_solr'
    ].each do |node|
      @zk_in_solr.create("/live_nodes/#{node}", '', mode: :ephemeral)
    end
    %w(collection1 collection2).each do |collection|
      @zk_in_solr.create("/collections/#{collection}")
      json = File.read("spec/files/#{collection}_all_nodes_alive.json")
      @zk_in_solr.create("/collections/#{collection}/state.json",
                         json,
                         mode: :ephemeral)
    end
    @zk = ZK.new
    @subject = RSolr::Cloud::Connection.new @zk
  end

  let(:client) { double.as_null_object }

  let(:http) { double(Net::HTTP).as_null_object }

  it 'should configure Net::HTTP with one of active node in select request.' do
    expect(@subject.instance_variable_get(:@leader_urls)['collection1'].sort).to eq(
      ['http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect(@subject.instance_variable_get(:@all_urls)['collection1'].sort).to eq(
      ['http://192.168.1.21:8983/solr/collection1',
       'http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect(Net::HTTP).to receive(:new) do |host, port|
      expect(host).to be_one_of(['192.168.1.21', '192.168.1.22', '192.168.1.23', '192.168.1.24'])
      expect(port).to eq(8983)
      http
    end
    expect(http).to receive(:request) do |request|
      expect(request.path).to eq('/solr/collection1/select?q=*:*')
      double.as_null_object
    end
    @subject.execute client, collection: 'collection1', method: :get, path: 'select', query: 'q=*:*'
  end

  it 'should configure Net::HTTP with one of leader node in update request' do
    expect(@subject.instance_variable_get(:@leader_urls)['collection1'].sort).to eq(
      ['http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect(@subject.instance_variable_get(:@all_urls)['collection1'].sort).to eq(
      ['http://192.168.1.21:8983/solr/collection1',
       'http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect(Net::HTTP).to receive(:new) do |host, port|
      expect(host).to be_one_of(['192.168.1.22', '192.168.1.24'])
      expect(port).to eq(8983)
      http
    end
    expect(http).to receive(:request) do |request|
      expect(request.path).to eq('/solr/collection1/update')
      expect(request.body).to eq('the data')
      double.as_null_object
    end
    @subject.execute client, collection: 'collection1',
                             method: :post,
                             path: 'update',
                             data: 'the data'
  end

  it 'should remove downed replica node and add recovered node' do
    @zk_in_solr.delete('/live_nodes/192.168.1.21:8983_solr')
    @zk_in_solr.set('/collections/collection1/state.json',
                    File.read('spec/files/collection1_replica_down.json'))
    expect { @subject.instance_variable_get(:@leader_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect { @subject.instance_variable_get(:@all_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    @zk_in_solr.create('/live_nodes/192.168.1.21:8983_solr', mode: :ephemeral)
    @zk_in_solr.set('/collections/collection1/state.json',
                    File.read('spec/files/collection1_all_nodes_alive.json'))
    expect { @subject.instance_variable_get(:@leader_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect { @subject.instance_variable_get(:@all_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.21:8983/solr/collection1',
       'http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
  end

  it 'should remove downed leader node and add recovered node' do
    @zk_in_solr.delete('/live_nodes/192.168.1.22:8983_solr')
    @zk_in_solr.set('/collections/collection1/state.json',
                    File.read('spec/files/collection1_leader_down.json'))
    expect { @subject.instance_variable_get(:@leader_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect { @subject.instance_variable_get(:@all_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.21:8983/solr/collection1',
       'http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    @zk_in_solr.create('/live_nodes/192.168.1.22:8983_solr', mode: :ephemeral)
    @zk_in_solr.set('/collections/collection1/state.json',
                    File.read('spec/files/collection1_all_nodes_alive.json'))
    expect { @subject.instance_variable_get(:@leader_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect { @subject.instance_variable_get(:@all_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.21:8983/solr/collection1',
       'http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
  end

  it 'should remove recovering leader node and add recovered node' do
    @zk_in_solr.set('/collections/collection1/state.json',
                    File.read('spec/files/collection1_leader_recovering.json'))
    expect { @subject.instance_variable_get(:@leader_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect { @subject.instance_variable_get(:@all_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.21:8983/solr/collection1',
       'http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    @zk_in_solr.set('/collections/collection1/state.json',
                    File.read('spec/files/collection1_all_nodes_alive.json'))
    expect { @subject.instance_variable_get(:@leader_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
    expect { @subject.instance_variable_get(:@all_urls)['collection1'].sort }.to become_soon(
      ['http://192.168.1.21:8983/solr/collection1',
       'http://192.168.1.22:8983/solr/collection1',
       'http://192.168.1.23:8983/solr/collection1',
       'http://192.168.1.24:8983/solr/collection1'].sort)
  end

  it 'should add new created collection.' do
    @zk_in_solr.create('/collections/collection3')
    @zk_in_solr.create('/collections/collection3/state.json',
                       File.read('spec/files/collection3_all_nodes_alive.json'))
    expect { @subject.instance_variable_get(:@leader_urls)['collection3'].to_a.sort }
      .to become_soon(['http://192.168.1.24:8983/solr/collection3'])
    expect { @subject.instance_variable_get(:@all_urls)['collection3'].to_a.sort }
      .to become_soon(['http://192.168.1.21:8983/solr/collection3',
                       'http://192.168.1.24:8983/solr/collection3'].sort)
  end

  it 'should remove deleted collection.' do
    delete_with_children(@zk_in_solr, '/collections/collection2')
    expect { @subject.instance_variable_get(:@leader_urls).keys }.to become_soon(['collection1'])
    expect { @subject.instance_variable_get(:@all_urls).keys }.to become_soon(['collection1'])
  end

  after do
    @zk_in_solr.close if @zk_in_solr
    @zk.close         if @zk
  end
end

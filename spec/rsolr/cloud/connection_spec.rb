require 'spec_helper.rb'

RSpec.describe RSolr::Cloud::Connection do

  before do
    @zk_in_solr = ZK.new

    @zk_in_solr.create('/live_nodes', ignore: :node_exists)
    @zk_in_solr.create('/collections', ignore: :node_exists)

    ['192.168.1.21:8983_solr',
      '192.168.1.22:8983_solr',
      '192.168.1.23:8983_solr',
      '192.168.1.24:8983_solr'
    ].each do |node|
      @zk_in_solr.create("/live_nodes/#{node}", '', mode: :ephemeral)
    end
    ['collection1', 'collection2'].each do |collection|
      @zk_in_solr.create("/collections/#{collection}", ignore: :node_exists)
      json = File.read("spec/files/#{collection}_all_nodes_alive.json")
      @zk_in_solr.create("/collections/#{collection}/state.json",json, mode: :ephemeral)
    end
    @zk = ZK.new
    @subject = RSolr::Cloud::Connection.new @zk
  end

  let(:client) { double.as_null_object }

  let(:http) { double(Net::HTTP).as_null_object }

  it "should configure Net::HTTP with one of solr host." do
    @subject.synchronize do 
      expect(@subject.instance_variable_get(:@leader_urls)['collection1'].sort).to eq(
        ["http://192.168.1.22:8983/solr/collection1","http://192.168.1.24:8983/solr/collection1"].sort)
      expect(@subject.instance_variable_get(:@all_urls)['collection1'].sort).to eq(
        ["http://192.168.1.21:8983/solr/collection1",
         "http://192.168.1.22:8983/solr/collection1",
         "http://192.168.1.23:8983/solr/collection1",
         "http://192.168.1.24:8983/solr/collection1"].sort)
    end
    expect(Net::HTTP).to receive(:new) do |host, port|
      expect(host).to be_one_of(['192.168.1.21', '192.168.1.22', '192.168.1.23', '192.168.1.24'])
      expect(port).to eq(8983)
      http
    end
    @subject.execute client, {collection: 'collection1', method: :get}
  end

  context 'replica node is down' do 

    it 'should remove down node' do 
      @zk_in_solr.delete('/live_nodes/192.168.1.21:8983_solr')
      @zk_in_solr.set('/collections/collection1/state.json', File.read('spec/files/collection1_replica_down.json'))
      expect{@subject.instance_variable_get(:@leader_urls)['collection1'].sort}.to become_soon(
          ["http://192.168.1.22:8983/solr/collection1","http://192.168.1.24:8983/solr/collection1"].sort)
      expect{@subject.instance_variable_get(:@all_urls)['collection1'].sort}.to become_soon(
        ["http://192.168.1.22:8983/solr/collection1",
         "http://192.168.1.23:8983/solr/collection1",
         "http://192.168.1.24:8983/solr/collection1"].sort)
    end
    
  end

  context 'leader node is down' do 

    it 'should remove down node' do
      @zk_in_solr.delete('/live_nodes/192.168.1.22:8983_solr')
      @zk_in_solr.set('/collections/collection1/state.json', File.read('spec/files/collection1_leader_down.json'))
      expect{@subject.instance_variable_get(:@leader_urls)['collection1'].sort}.to become_soon(
          ["http://192.168.1.23:8983/solr/collection1","http://192.168.1.24:8983/solr/collection1"].sort)
      expect{@subject.instance_variable_get(:@all_urls)['collection1'].sort}.to become_soon(
        ["http://192.168.1.21:8983/solr/collection1",
         "http://192.168.1.23:8983/solr/collection1",
         "http://192.168.1.24:8983/solr/collection1"].sort)
    end
    
  end

  after do
    @zk_in_solr.close
    @zk.close
  end

end

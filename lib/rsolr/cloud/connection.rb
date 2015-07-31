class RSolr::Cloud::Connection < RSolr::Connection

  include MonitorMixin

  ZNODE_LIVE_NODES  = '/live_nodes'
  ZNODE_COLLECTIONS = '/collections'

  def initialize(zk)
    super()
    @zk = zk
    initialize_live_node_watcher
    initialize_collections_watcher
    update_urls
  end

  def execute client, request_context
    collection_name = request_context[:collection]
    unless collection_name
      raise "The :collection option must be specified."
    end
    path = request_context[:path]
    query = request_context[:query]
    url = get_url(collection_name, leader_only: path == 'update')
    unless url
      raise RSolr::Cloud::Error::NotEnoughNodes.new
    end
    request_context[:uri] = RSolr::Uri.create(url).merge(path.to_s + (query ? "?#{query}" : ""))
    super(client, request_context)
  end

  private

  def get_url(collection, leader_only: false)
    if leader_only
      synchronize { @leader_urls[collection].to_a.sample }
    else
      synchronize { @all_urls[collection].to_a.sample }
    end
  end

  def initialize_live_node_watcher
    @zk.register(ZNODE_LIVE_NODES) do
      update_live_nodes
      update_urls
    end
    update_live_nodes
  end

  def initialize_collections_watcher
    @zk.register(ZNODE_COLLECTIONS) do
      update_collections
      update_urls
    end
    update_collections
  end

  def initialize_collection_state_watcher(collection)
    @zk.register("/collections/#{collection}/state.json") do
      update_collection_state(collection)
      update_urls
    end
    update_collection_state(collection)
  end


  def update_urls
    synchronize do
      @all_urls = {}
      @leader_urls = {}
      @collections.each do |name, state|
        leader_urls = []
        all_urls = []
        available_nodes(state).each do |node|
          url = "#{node['base_url']}/#{name}"
          leader_urls << url if leader_node?(node)
          all_urls << url
        end
        @all_urls[name] = all_urls
        @leader_urls[name] = leader_urls
      end
    end
  end

  def update_live_nodes
    synchronize do
      @live_nodes = {}
      @zk.children(ZNODE_LIVE_NODES, watch: true).each do |node|
        @live_nodes[node] = true
      end
    end
  end

  def update_collections
    collections = @zk.children(ZNODE_COLLECTIONS, watch: true)
    created_collections = []
    synchronize do 
      @collections ||={}
      deleted_collections = @collections.keys - collections
      created_collections = collections - @collections.keys
      deleted_collections.each do |collection|
        @collections.delete(collection)
      end
    end
    created_collections.each do |collection|
      initialize_collection_state_watcher(collection)
    end
  end

  def update_collection_state(collection)
    synchronize do
      collection_state_json, _ = @zk.get("/collections/#{collection}/state.json", watch: true)
      @collections.merge!(JSON.parse(collection_state_json))
    end
  end

  def available_nodes(collection_state)
    shards = collection_state['shards'].values
    nodes = shards.map { |shard| shard['replicas'].values }.flatten
    nodes.select do |node|
      @live_nodes[node['node_name']] && node['state'] == 'active'
    end
  end

  def leader_node?(node)
    node['leader'] == 'true'
  end

end
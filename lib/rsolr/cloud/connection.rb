module RSolr
  module Cloud
    # RSolr connection adapter for SolrCloud
    class Connection < RSolr::Connection
      include MonitorMixin

      ZNODE_LIVE_NODES  = '/live_nodes'
      ZNODE_COLLECTIONS = '/collections'

      def initialize(zk)
        super()
        @zk = zk
        init_live_node_watcher
        init_collections_watcher
        update_urls
      end

      def execute(client, request_context)
        collection_name = request_context[:collection]
        fail 'The :collection option must be specified.' unless collection_name
        path  = request_context[:path].to_s
        query = request_context[:query]
        query = query ? "?#{query}" : ''
        url   = select_node(collection_name, leader_only: path == 'update')
        fail RSolr::Cloud::Error::NotEnoughNodes unless url
        request_context[:uri] = RSolr::Uri.create(url).merge(path + query)
        super(client, request_context)
      end

      private

      def select_node(collection, leader_only: false)
        if leader_only
          synchronize { @leader_urls[collection].to_a.sample }
        else
          synchronize { @all_urls[collection].to_a.sample }
        end
      end

      def init_live_node_watcher
        @zk.register(ZNODE_LIVE_NODES) do
          update_live_nodes
          update_urls
        end
        update_live_nodes
      end

      def init_collections_watcher
        @zk.register(ZNODE_COLLECTIONS) do
          update_collections
          update_urls
        end
        update_collections
      end

      def init_collection_state_watcher(collection)
        @zk.register(collection_state_znode_path(collection)) do
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
            @all_urls[name], @leader_urls[name] = available_urls(name, state)
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
        created = []
        synchronize do
          @collections ||= {}
          deleted = @collections.keys - collections
          created = collections - @collections.keys
          deleted.each { |collection| @collections.delete(collection) }
        end
        created.each { |collection| init_collection_state_watcher(collection) }
      end

      def update_collection_state(collection)
        synchronize do
          collection_state_json, _stat =
            @zk.get(collection_state_znode_path(collection), watch: true)
          @collections.merge!(JSON.parse(collection_state_json))
        end
      end

      def available_urls(collection_name, collection_state)
        leader_urls = []
        all_urls = []
        all_nodes(collection_state).each do |node|
          next unless active_node?(node)
          url = "#{node['base_url']}/#{collection_name}"
          leader_urls << url if leader_node?(node)
          all_urls << url
        end
        [all_urls, leader_urls]
      end

      def all_nodes(collection_state)
        nodes = collection_state['shards'].values.map do |shard|
          shard['replicas'].values
        end
        nodes.flatten
      end

      def collection_state_znode_path(collection_name)
        "/collections/#{collection_name}/state.json"
      end

      def active_node?(node)
        @live_nodes[node['node_name']] && node['state'] == 'active'
      end

      def leader_node?(node)
        node['leader'] == 'true'
      end
    end
  end
end

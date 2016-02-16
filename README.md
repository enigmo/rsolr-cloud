# RSolr::Cloud

A RSolr's connection adopter supporting SolrCloud.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rsolr-cloud'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rsolr-cloud

## Example

```ruby
require 'zk'
require 'rsolr/cloud'

# Create Zookeeper client for the Zookeeper ensemble in SolrCloud.
zk = ZK.new('localhost:2181,localhost:2182,localhost:2183')

# Connecting the SolrCloud through the Zookeeper.
cloud_connection = RSolr::Cloud::Connection.new(zk)

# Get rsolr client for solr_cloud.
solr_client  = RSolr::Client.new(cloud_connection,
                                 read_timeout: 60,
                                 open_timeout: 60)

# You can use rsolr as usual but :collection option must be specified with the name of the collection.
response = solr.get('select', collection: 'collection1', params: {q: '*:*'})

```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/rsolr-cloud/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Development

To install gems which are necessary for development and testing:

```
$ bundle install
```

To run the test suite:

```
$ rake
```

The default rake task contains RuboCop and RSpec. Each task can be run separately:

```
$ rake rubocop
```
```
$ rake spec
```

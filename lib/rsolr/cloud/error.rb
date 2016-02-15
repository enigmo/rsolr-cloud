module RSolr
  module Cloud
    module Error
      # This error cause when all solr nodes aren't active.
      class NotEnoughNodes < RuntimeError
        def to_s
          'Not enough nodes to handle the request.'
        end
      end
    end
  end
end

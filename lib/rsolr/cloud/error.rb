module RSolr
  module Cloud
    module Error

      class NotEnoughNodes < RuntimeError
        def to_s
          'Not enough nodes to handle the request.'
        end
      end

    end
  end
end
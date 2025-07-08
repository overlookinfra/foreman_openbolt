require 'json'

module ProxyAPI
  class Bolt < Resource
    def initialize(args)
      @url = args[:url]
      super args
    end

    def task_names
      JSON.parse(get('/bolt/tasks').body).keys
    end
  end
end

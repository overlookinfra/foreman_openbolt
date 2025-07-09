require 'json'

module ProxyAPI
  class Bolt < Resource
    def initialize(args)
      @url = args[:url]
      super args
    end

    def fetch_tasks
      @tasks = JSON.parse(get('/bolt/tasks').body)
    end

    def tasks
      @tasks ||= fetch_tasks
    end

    def reload_tasks
      @tasks = JSON.parse(get('/bolt/tasks/reload').body)
    end

    def task_names
      tasks.keys
    end
  end
end

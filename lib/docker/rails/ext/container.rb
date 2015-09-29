class Docker::Container

  def compose
    return nil unless Compose.is_compose_container?(self)
    @_compose ||= Compose.new(self)
  end

  class Compose
    attr_reader :number, :oneoff, :project, :service, :version

    def initialize(container)
      labels = container.info['Labels']
      @service = labels['com.docker.compose.service']
      @project = labels['com.docker.compose.project']
      @oneoff = !!labels['com.docker.compose.oneoff']
      @number = labels['com.docker.compose.container-number'].to_i
      @version = labels['com.docker.compose.version']
    end

    def to_s
      s = "#{@project}_#{@service}_"
      # s += 'oneoff_' if @oneoff
      s += "#{@number}"
      s
    end

    class << self
      def is_compose_container?(container)
        labels = container.info['Labels']
        (!labels.nil? && !labels['com.docker.compose.version'].nil?)
      end
    end
  end
end


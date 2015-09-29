class Docker::Container

  def name
    info['Names'][0].gsub(/^\//, '')
  end

  def status
    info['Status']
  end

  def up?
    status =~ /^(up|Up)/
  end

  def down?
    !up?
  end

  def exit_code
    return nil if up?
    return nil unless (status =~ /xited/)

    #  Up 10 seconds
    #  Exited (0) 2 seconds ago
    status =~ /^.* \((\w+)\)/
    $1.to_i
  end

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

    class << self
      def is_compose_container?(container)
        labels = container.info['Labels']
        (!labels.nil? && !labels['com.docker.compose.version'].nil?)
      end
    end
  end
end


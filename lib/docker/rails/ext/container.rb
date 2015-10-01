class Docker::Container

  #FIXME: remove this method when pull #321 is accepted
  # Update the @info hash, which is the only mutable state in this object.
  def refresh!
     other = Docker::Container.all({all: true}, connection).find { |c|
      c.id.start_with?(self.id) || self.id.start_with?(c.id)
    }

    info.merge!(self.json)
    other && info.merge!(other.info)
    self
  end

  def status
    # info is cached, return the first one otherwise retrieve a new container and get the status from it
    refresh!

    info['Status']
  end

  def name
    info['Names'][0].gsub(/^\//, '')
  end

  def up?
    #  Up 10 seconds
    #  Exited (0) 2 seconds ago
    return true if status =~ /^(up|Up)/
    false
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


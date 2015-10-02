module Docker
  module Rails
    module CLI
      class SshAgent < Thor
        desc 'forward', 'Run SSH Agent Forwarding'
        def forward(target = nil)
          App.configured(target, options).run_ssh_agent
        end

        desc 'rm', 'Stop and remove SSH Agent Forwarding'
        def rm(target = nil)
          App.configured(target, options).rm_ssh_agent
        end
      end
    end
  end
end

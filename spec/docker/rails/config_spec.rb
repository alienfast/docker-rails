require 'spec_helper'

describe Docker::Rails::Config do

  subject(:options) { {} }
  let(:target) { :foo }
  let(:build) { 111 }
  let(:dir_name) { 'rails' }
  let(:project_name) { "#{dir_name}#{target}#{build}" }
  subject(:config) { Docker::Rails::Config.new(build: build, target: target) }

  it 'should not raise error when key is not found' do
    config.clear
    expect(config.foo).to be_nil
  end

  it 'should provide seed configuration' do
    config.clear
    assert_common_seed_settings

    # ensure no unnecessary environments make it into the resolved configuration
    expect(config.development).to be_nil
    expect(config.production).to be_nil
  end

  it 'should fail if the target environment does not exist' do
    expect {
      Dir.chdir(File.dirname(__FILE__)) do
        config.clear
        config.load!(:foobar)
      end
    }.to raise_error /Unknown target environment/
  end

  it 'should fail if the target environment is nil' do
    expect {
      Dir.chdir(File.dirname(__FILE__)) do
        config.clear
        config.load!(nil)
      end
    }.to raise_error /Target environment unspecified/
  end


  context ':development' do
    let(:target) { :development }
    before(:each) {
      Dir.chdir(File.dirname(__FILE__)) do
        config.clear
        config.load!(target)
      end
    }

    it 'should read default file' do
      assert_common_top_level_settings

      web = config[:'compose'][:web]
      expect(web[:links]).to match_array %w(elasticsearch db)
      expect(web[:ports]).to match_array ['3000']

      elasticsearch = config[:'compose'][:elasticsearch]
      expect(elasticsearch[:ports]).to match_array ['9200']

      # ensure no unnecessary environments make it into the resolved configuration
      expect(config.development).to be_nil
      expect(config.production).to be_nil
    end

    it 'should manipulate command to yaml single line' do
      yaml = config.to_yaml
      expect(yaml).to include 'command: >'
      expect(yaml).not_to include 'command: |'
    end

    context 'compose' do
      let(:compose_config) {
        file = tmp_file('compose')
        config.write_docker_compose_file(file)
        compose_config =Docker::Rails::ComposeConfig.new
        compose_config.load!(nil, file)
        compose_config
      }

      it 'web should have ssh-agent' do
        expect(compose_config[:web][:environment]).to include('SSH_AUTH_SOCK=/root/.ssh/socket')
        expect(compose_config[:web][:volumes_from]).to include("#{project_name}_ssh_agent")
      end
      it 'web should have gemset' do
        expect(compose_config[:web][:environment]).to include('GEM_HOME=/gemset/2.2.2')
        expect(compose_config[:web][:volumes_from]).to include('gemset-2.2.2')
      end
    end
  end

  # it 'should read specific file' do
  #   config.clear
  #   config.load!(nil, config_file_path)
  # end

  private

  def assert_common_seed_settings
    expect(config[:verbose]).to eql false
  end

  def assert_common_top_level_settings
    expect(config[:verbose]).to eql true
  end

  def tmp_file(name = 'foo')
    file = File.expand_path("../../../../tmp/#{name}-docker-rails-config_spec.yml", __FILE__)
    FileUtils.mkdir_p File.dirname file
    file
  end

  def config_file_path
    File.expand_path('../sample-docker-rails.yml', __FILE__)
  end
end
require 'spec_helper'

describe Docker::Rails::Config do

  subject(:options) { {} }
  subject(:config) { Docker::Rails::Config.new }

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

  context 'when loading a single configuration file' do

    it 'should read default env and file' do
      Dir.chdir(File.dirname(__FILE__)) do
        config.clear
        config.load!(nil)
      end

      assert_common_top_level_settings

      # ensure no unnecessary environments make it into the resolved configuration
      expect(config.development).to be_nil
      expect(config.production).to be_nil
    end

    it 'should read :development and default file' do
      Dir.chdir(File.dirname(__FILE__)) do
        config.clear
        config.load!(:development)
      end

      assert_common_top_level_settings

      web = config[:'docker-compose'][:web]
      expect(web[:links]).to match_array %w(elasticsearch db)
      expect(web[:ports]).to match_array ['3000:3000']

      elasticsearch = config[:'docker-compose'][:elasticsearch]
      expect(elasticsearch[:ports]).to match_array ['9200:9200']

      # ensure no unnecessary environments make it into the resolved configuration
      expect(config.development).to be_nil
      expect(config.production).to be_nil
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

  def config_file_path
    File.expand_path('../sample-docker-rails.yml', __FILE__)
  end
end
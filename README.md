# docker-rails
[![Gem Version](https://badge.fury.io/rb/docker-rails.svg)](https://rubygems.org/gems/docker-rails)
[![Build Status](https://travis-ci.org/alienfast/docker-rails.svg)](https://travis-ci.org/alienfast/docker-rails)
[![Code Climate](https://codeclimate.com/github/alienfast/docker-rails/badges/gpa.svg)](https://codeclimate.com/github/alienfast/docker-rails)

A simplified pattern to execute rails applications within Docker (with a CI build emphasis).

## Features
- DRY declarative `docker-rails.yml` allowing multiple environments to be defined with an inherited docker `compose` configuration
- Provides individual convenience functions `up | bash | stop | cleanup` to easily work with target environment (even in a concurrent situation)
- Full workflow for CI usage with automated container, volume, and image cleanup.
- Automated cached global gems data volume based on ruby version
- Interpolates variables `docker-compose.yml` making CI builds much easier
- DB check CLI function provided for docker-compose `command` to check if db is ready

## Usage

```bash
Commands:
  docker-rails bash <target> <service_name>  # Open a bash shell to a running container e.g. bundle exec docker-rails bash --build=222 development db
  docker-rails ci <target>                   # Execute the works, everything with cleanup included e.g. bundle exec docker-rails ci --build=222 test
  docker-rails cleanup <target>              # Runs container cleanup functions stop, rm_volumes, rm_compose, rm_dangling, ps_all e.g. bundle exec docker-rails cleanup --build=222 development
  docker-rails compose <target>              # Writes a resolved docker-compose.yml file e.g. bundle exec docker-rails compose --build=222 test
  docker-rails db_check <db>                 # Runs db_check e.g. bundle exec docker-rails db_check mysql
  docker-rails gems_volume <command>         # Gems volume management e.g. bundle exec docker-rails gems_volume create
  docker-rails help [COMMAND]                # Describe available commands or one specific command
  docker-rails ps <target>                   # List containers for the target compose configuration e.g. bundle exec docker-rails ps --build=222 development
  docker-rails ps_all                        # List all remaining containers regardless of state e.g. bundle exec docker-rails ps_all
  docker-rails rm_dangling                   # Remove danging images e.g. bundle exec docker-rails rm_dangling
  docker-rails rm_volumes <target>           # Stop all running containers and remove corresponding volumes for the given build/target e.g. bundle exec docker-rails rm_volumes --build=222 development
  docker-rails stop <target>                 # Stop all running containers for the given build/target e.g. bundle exec docker-rails stop --build=222 development
  docker-rails up <target>                   # Up the docker-compose configuration for the given build/target. Use -d for detached mode. e.g. bundle exec docker-rails up -d --build=222 test

Options:
  -b, [--build=BUILD]  # Build name e.g. 123
                       # Default: 1
```

## Work in progress - contributions welcome
Open to pull requests. Open to refactoring. It can be expanded to suit many different configurations.

TODO:
- **Permissions** - [Shared volume for project has files written as root](https://github.com/alienfast/docker-rails/issues/5)
- **DB versatility** - expand to different db status detection as-needed e.g. postgres. CLI is now modularized to allow for this.


## Installation

Add this line to your application's Gemfile:

    gem 'docker-rails'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install docker-rails

## Usage

### 1. Add a Dockerfile

```bash
FROM atlashealth/ruby:2.2.2

ENV DEBIAN_FRONTEND noninteractive

# For building, nokogiri support, capybara-webkit, mysql client
# Clean up APT when done.
RUN apt-get update -qq && \
    apt-get install -qy build-essential libxml2-dev libxslt1-dev g++ qt5-default libqt5webkit5-dev xvfb libmysqlclient-dev && \

    # cleanup
    apt-get clean && \
    cd /var/lib/apt/lists && rm -fr *Release* *Sources* *Packages* && \
    truncate -s 0 /var/log/*log

# https://github.com/docker/docker/issues/4032
ENV DEBIAN_FRONTEND newt
```

### 2. Add a docker-rails.yml

Environment variables will be interpolated, so feel free to use them. 
Below shows an example with all of the environments `development | test | parallel_tests | staging` to show reuse of the primary `compose` configuration. 

```yaml
verbose: true

# local environments need elasticsearch, staging/production connects to existing running instance.
elasticsearch: &elasticsearch
  elasticsearch:
    image: library/elasticsearch:1.7
    ports:
      - "9200"

development:
  compose:
    <<: *elasticsearch
    web:
      links:
        - elasticsearch # standard yaml doesn't merge arrays so we have to add this explicitly
      environment:
        - RAILS_ENV=development
      command: >
        bash -c "

        echo 'Bundling gems'
        && bundle install --jobs 4 --retry 3

        && echo 'Generating Spring binstubs'
        && bundle exec spring binstub --all

        && echo 'Clearing logs and tmp dirs'
        && bundle exec rake log:clear tmp:clear

        && echo 'Check and wait for database connection'
        && bundle exec docker-rails db_check mysql

        && echo 'Setting up new db if one doesn't exist'
        && bundle exec rake db:version || { bundle exec rake db:setup; }

        && echo "Starting app server"
        && bundle exec rails s -p 3000

        && echo 'Setup and start foreman'
        && gem install foreman
        && foreman start
        "

test:
  before_command: rm -Rf target
  compose:
    <<: *elasticsearch
    web:
      links:
        - elasticsearch # standard yaml doesn't merge arrays so we have to add this explicitly
      environment:
        - RAILS_ENV=test
      command: >
        bash -c "
        echo 'Bundling gems'
        && bundle install --jobs 4 --retry 3

        && echo 'Clearing logs and tmp dirs'
        && bundle exec rake log:clear tmp:clear

        && echo 'Check and wait for database connection'
        && bundle exec docker-rails db_check mysql

        && echo 'Setting up new db if one doesn't exist'
        && bundle exec rake db:version || { bundle exec rake db:setup; }

        && echo 'Tests'
        && cd ../..
        && xvfb-run -a bundle exec rake spec cucumber
        "

parallel_tests:
  before_command: rm -Rf target
  compose:
    <<: *elasticsearch
    web:
      links:
        - elasticsearch # standard yaml doesn't merge arrays so we have to add this explicitly
      environment:
        - RAILS_ENV=test
      command: >
        bash -c "

        echo 'Bundling gems'
        && bundle install --jobs 4 --retry 3

        && echo 'Clearing logs and tmp dirs'
        && bundle exec rake log:clear tmp:clear

        && echo 'Check and wait for database connection'
        && bundle exec docker-rails db_check mysql

        && echo 'Setting up new db if one doesn't exist'
        && bundle exec rake parallel:drop parallel:create parallel:migrate parallel:seed

        && echo 'Tests'
        && cd ../..
        && xvfb-run -a bundle exec rake parallel:spec parallel:features
        "

staging:
  compose:
    web:
      environment:
        - RAILS_ENV=staging
      command: >
        bash -c "

        echo 'Bundling gems'
        && bundle install --jobs 4 --retry 3

        && echo 'Clearing logs and tmp dirs'
        && bundle exec rake log:clear tmp:clear

        && echo 'Check and wait for database connection'
        && bundle exec docker-rails db_check mysql

        && echo 'Setting up new db if one doesn't exist'
        && bundle exec rake db:migrate

        && echo "Starting app server"
        && bundle exec rails s -p 3000

        && echo 'Setup and start foreman'
        && gem install foreman
        && foreman start
        "

# base docker-compose configuration for all environments
compose:
  web:
    build: .
    working_dir: /project/spec/dummy
    ports:
      - "3000"

    links:
      - db

    volumes:
      - .:/project

    volumes_from:
      # Mount the gems data volume container for cached bundler gem files
      - #{DOCKER_RAILS_GEMS_VOLUME_NAME}

    # https://docs.docker.com/v1.6/docker-compose/cli/#environment-variables
    environment:
      # Tell bundler where to get the files
      - GEM_HOME=#{DOCKER_RAILS_GEMS_VOLUME_PATH}

  db:
    # https://github.com/docker-library/docs/tree/master/mysql
    image: library/mysql:5.7.6
    ports:
      - "3306"

    # https://github.com/docker-library/docs/tree/master/mysql#environment-variables
    environment:
      - MYSQL_ALLOW_EMPTY_PASSWORD=true
```

### 3. Run it

`bundle exec docker-rails ci 111 test`

### 4. Submit pull requests!

The intent for this is to make rails with docker a snap.  The code should be modular enough that adding a check for a different database etc should be quite simple.
We are open to expanding functionality beyond what is already provided.


## Contributing

1. Fork it ( https://github.com/[my-github-username]/docker-rails/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License and Attributions
MIT license, inspired by many but certainly a [useful blog post by AtlasHealth](http://www.atlashealth.com/blog/2014/09/persistent-ruby-gems-docker-container). 

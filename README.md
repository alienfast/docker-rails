# docker-rails
[![Gem Version](https://badge.fury.io/rb/docker-rails.svg)](https://rubygems.org/gems/docker-rails)
[![Build Status](https://travis-ci.org/alienfast/docker-rails.svg)](https://travis-ci.org/alienfast/docker-rails)
[![Code Climate](https://codeclimate.com/github/alienfast/docker-rails/badges/gpa.svg)](https://codeclimate.com/github/alienfast/docker-rails)

A simplified pattern to execute rails applications within Docker (with a CI build emphasis).

## Features
- DRY declarative `docker-rails.yml` allowing multiple environments to be defined with an inherited docker `compose` configuration
- Provides individual convenience functions `up | bash | stop | extract | cleanup` to easily work with target environment (even in a concurrent situation)
- Full workflow for CI usage with automated container, volume, and image cleanup.
- Automated cached global gems data volume based on ruby version
- Interpolates variables `docker-compose.yml` making CI builds much easier
- DB check CLI function provided for docker-compose `command` to check if db is ready
- Configurable exit_code for `ci` - determine which container's exit code will be the result of the process (useful for CI tests)

## Usage

### CI

CI, the reason this is built. Do it all, do it consistently, do it concurrently, do it easily, and always cleanup after yourself.

`docker-rails ci test`

#### CI workflow

`ci` executes: 

1. `before_command` - run anything on the host prior to building the docker image e.g. `rm -Rf target`
2. `compose` - create the resolved `docker-compose.yml`
3. `gems_volume` - find or create the shared global gems volume for this ruby version
4. `build` - `docker-compose build` the configuration
5. `up` - `docker-compose up` the configuration
6. `cleanup`
    1. `stop` - stop all containers for this configuration (including one-off sessions)
    2. `extract` - extract any defined files from any container
    3. `rm_volumes` - `docker-compose rm -v --force` to cleanup any container volumes (excluding the gems volume)
    4. `rm_compose` - cleanup the generated compose.yml file for the `build`
    5. `rm_dangling` - cleanup any dangling images

#### CI execution options
  
**NOTE:** If using `bundle exec`, you'll need to do a `bundle` on both the host and container.  These examples avoid `bundle exec` on the host to avoid the time taken to bundle (it should happen inside your container). 
  
In your environment, ensure that `docker-rails` is present:

```bash
gem install --no-ri --no-rdoc docker-rails
```

Then run it:
  
```bash
docker-rails ci --build=222 test
```
  
or with the environment variable option

```bash
DOCKER_RAILS_BUILD=222 docker-rails ci test
```

or for local testing (uses `1` for build)
 
```bash
 docker-rails ci test
```

### General CLI

Almost all of the commands below are in support of the `ci` command, so why not give access directly to them? Helpful additions include `bash_connect` to connect to a running container and `exec` the equivalent of `docker-compose run` (but thor complained and we can't use reserverd word `run`)

```bash
Commands:
  docker-rails bash_connect <target> <service_name>    # Open a bash shell to a running container (with automatic cleanup) e.g. bundle exec docker-rails bash --build=222 development db
  docker-rails build <target>                          # Build for the given build/target e.g. bundle exec docker-rails build --build=222 development
  docker-rails ci <target>                             # Execute the works, everything with cleanup included e.g. bundle exec docker-rails ci --build=222 test
  docker-rails cleanup <target>                        # Runs container cleanup functions stop, rm_volumes, rm_compose, rm_dangling, ps_all e.g. bundle exec docker-rails cleanup --build=222 development
  docker-rails compose <target>                        # Writes a resolved docker-compose.yml file e.g. bundle exec docker-rails compose --build=222 test
  docker-rails db_check <db>                           # Runs db_check e.g. bundle exec docker-rails db_check mysql
  docker-rails exec <target> <service_name> <command>  # Run an arbitrary command on a given service container e.g. bundle exec docker-rails exec --build=222 development db bash
  docker-rails gems_volume <command>                   # Gems volume management e.g. bundle exec docker-rails gems_volume create
  docker-rails help [COMMAND]                          # Describe available commands or one specific command
  docker-rails ps <target>                             # List containers for the target compose configuration e.g. bundle exec docker-rails ps --build=222 development
  docker-rails ps_all                                  # List all remaining containers regardless of state e.g. bundle exec docker-rails ps_all
  docker-rails rm_dangling                             # Remove danging images e.g. bundle exec docker-rails rm_dangling
  docker-rails rm_volumes <target>                     # Stop all running containers and remove corresponding volumes for the given build/target e.g. bundle exec docker-rails rm_volumes --build=222 development
  docker-rails stop <target>                           # Stop all running containers for the given build/target e.g. bundle exec docker-rails stop --build=222 development
  docker-rails up <target>                             # Up the docker-compose configuration for the given build/target. Use -d for detached mode. e.g. bundle exec docker-rails up -d --build=222 test

Options:
  -b, [--build=BUILD]  # Build name e.g. 123.  Can also be specified as environment variable DOCKER_RAILS_BUILD
                       # Default: 1
```

## Installation

Add this line to your application's Gemfile:

    gem 'docker-rails'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install docker-rails

## Setup and Configuration

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

    COPY . /project # figure out/automate this as a volume instead https://github.com/alienfast/docker-rails/issues/14
    
# https://github.com/docker/docker/issues/4032
ENV DEBIAN_FRONTEND newt

# Bypass the union file system for better performance https://docs.docker.com/userguide/dockervolumes/
VOLUME /project

# Copy the project files into the container (again, better performance).  Use `extract` in the docker-rails.yml to obtain files such as test results.
COPY . /project
```

### 2. Add a docker-rails.yml

Environment variables will be interpolated, so feel free to use them. 
The _rails engine_ example below shows an example with all of the environments `development | test | parallel_tests | staging` to show reuse of the primary `compose` configuration. 

```yaml
verbose: true
exit_code: web
before_command: bash -c "rm -Rf target && rm -Rf spec/dummy/log"

extractions: &extractions
  web:
    extract:
      - '/project/target'
      - '/project/vcr'
      - '/project/spec/dummy/log:spec/dummy'
      - '/project/tmp/parallel_runtime_cucumber.log:./tmp'
      - '/project/tmp/parallel_runtime_rspec.log:./tmp'

      
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
  <<: *extractions
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
  <<: *extractions
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

## CI setup

### Bamboo

The following shows execution within Atlassian Bamboo using an script task and RVM on the host.

#### 1. Add an inline script task

This will run everything, including cleanup.

```bash
#!/bin/bash
 
# force bash, not bin/sh
if [ "$(ps -p "$$" -o comm=)" != "bash" ]; then
    # Taken from http://unix-linux.questionfor.info/q_unix-linux-programming_85038.html
    bash "$0" "$@"
    exit "$?"
fi

source ~/.bash_profile
rvm gemset list
echo "Build: $bamboo_buildNumber"
gem install --no-ri --no-rdoc docker-rails

docker-rails ci --build=$bamboo_buildNumber parallel_tests
```

#### 2. Add an inline script final task 

In the _Final tasks_ section, add another inline script task just to ensure cleanup.  If all is well, this is duplicate work (that takes very little time), but we have seen cases where executing `stop` in Bamboo will kill off the process without a chance to cleanup.  This will take care of that scenario.

```bash
#!/bin/bash
 
# force bash, not bin/sh
if [ "$(ps -p "$$" -o comm=)" != "bash" ]; then
    # Taken from http://unix-linux.questionfor.info/q_unix-linux-programming_85038.html
    bash "$0" "$@"
    exit "$?"
fi

source ~/.bash_profile
docker-rails cleanup --build=$bamboo_buildNumber parallel_tests
```

## Work in progress - contributions welcome
Open to pull requests. Open to refactoring. It can be expanded to suit many different configurations.

TODO:
- **DB versatility** - expand to different db status detection as-needed e.g. postgres. CLI is now modularized to allow for this.

## Contributing

1. Fork it ( https://github.com/[my-github-username]/docker-rails/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License and Attributions
MIT license, inspired by many but certainly a [useful blog post by AtlasHealth](http://www.atlashealth.com/blog/2014/09/persistent-ruby-gems-docker-container). 

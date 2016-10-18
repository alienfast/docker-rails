# docker-rails
[![Gem Version](https://badge.fury.io/rb/docker-rails.svg)](https://rubygems.org/gems/docker-rails)
[![Build Status](https://travis-ci.org/alienfast/docker-rails.svg)](https://travis-ci.org/alienfast/docker-rails)
[![Code Climate](https://codeclimate.com/github/alienfast/docker-rails/badges/gpa.svg)](https://codeclimate.com/github/alienfast/docker-rails)

A simplified pattern to execute rails applications within Docker (with a CI build emphasis).  

Note: The only item that is rails-specific is the `db_check`, otherwise this can be useful for other CI situations as well.  Perhaps we should have chosen a different name?

## Features
- DRY declarative `docker-rails.yml` allowing multiple environments to be defined with an inherited docker `compose` configuration
- Provides individual convenience functions `up | bash | stop | extract | cleanup` to easily work with target environment (even in a concurrent situation)
- Full workflow for CI usage with automated container, volume, and image cleanup.
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
1. `compose` - create the resolved `docker-compose.yml`
1. `build` - `docker-compose build` the configuration
1. `up` - `docker-compose up` the configuration
1. `cleanup`
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
  docker-rails bash_connect <target> <service_name>    # Open a bash shell to a running container (with automatic cleanup) e.g. docker-rails bash --build=222 development db
  docker-rails build <target>                          # Build for the given build/target e.g. docker-rails build --build=222 development
  docker-rails ci <target>                             # Execute the works, everything with cleanup included e.g. docker-rails ci --build=222 test
  docker-rails cleanup <target>                        # Runs container cleanup functions stop, rm_volumes, rm_compose, rm_dangling, ps_all e.g. docker-rails cleanup --build=222 development
  docker-rails compose <target>                        # Writes a resolved docker-compose.yml file e.g. docker-rails compose --build=222 test
  docker-rails db_check <db>                           # Runs db_check e.g. bundle exec docker-rails db_check mysql
  docker-rails exec <target> <service_name> <command>  # Run an arbitrary command on a given service container e.g. docker-rails exec --build=222 development db bash
  docker-rails help [COMMAND]                          # Describe available commands or one specific command
  docker-rails ps <target>                             # List containers for the target compose configuration e.g. docker-rails ps --build=222 development
  docker-rails ps_all                                  # List all remaining containers regardless of state e.g. docker-rails ps_all
  docker-rails rm_dangling                             # Remove danging images e.g. docker-rails rm_dangling
  docker-rails rm_exited                               # Remove exited containers e.g. docker-rails rm_exited
  docker-rails rm_volumes <target>                     # Stop all running containers and remove corresponding volumes for the given build/target e.g. docker-rails rm_volumes --build=222 development
  docker-rails stop <target>                           # Stop all running containers for the given build/target e.g. docker-rails stop --build=222 development
  docker-rails up <target>                             # Up the docker-compose configuration for the given build/target. Use -d for detached mode. e.g. docker-rails up -d --build=222 test

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

This is a _real world example_ (**not a minimal example**) of a rails engine called `acme` with a `dummy` application used for testing.  Other notable items:
 - installs node
 - uses [`dockito/vault`](https://github.com/dockito/vault) via `ONVAULT` to execute `npm` with private key access without exposing the npm key to the layer
 - runs `npm build` to transpile the `dummy` application UI  

```bash
FROM convox/ruby

# mysql client, nodejs, clean up APT when done.
# - libelf1 for flow-bin
# - libfontconfig for phantomjs
RUN apt-get update -qq && apt-get install -qy \
  vim \
  wget \
  libelf1 \
  libfontconfig \
  libmysqlclient-dev \
  mysql-client \
  git \
  curl \
  && curl -L https://raw.githubusercontent.com/dockito/vault/master/ONVAULT > /usr/local/bin/ONVAULT \
  && chmod +x /usr/local/bin/ONVAULT \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get -y autoclean

# Install nodejs - see dockerfile - https://github.com/nodejs/docker-node/blob/master/6.2/Dockerfile
# gpg keys listed at https://github.com/nodejs/node
RUN set -ex \
  && for key in \
    9554F04D7259F04124DE6B476D5A82AC7E37093B \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    0034A06D9D9B0064CE8ADF6BF1747F4AD2306D93 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
  ; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done

ENV NPM_CONFIG_LOGLEVEL error
ENV NODE_VERSION 6.8.1

RUN curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -SLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt

# Set an environment variable to store where the app is installed to inside of the Docker image.
ENV INSTALL_PATH /app
RUN mkdir -p $INSTALL_PATH
WORKDIR $INSTALL_PATH

# Ensure gems are cached they are less likely to change than node modules
COPY acme.gemspec               acme.gemspec
COPY Gemfile                  Gemfile
COPY Gemfile_shared.rb        Gemfile_shared.rb
COPY spec/dummy/Gemfile       spec/dummy/Gemfile

# bundle acme
RUN bundle install --jobs 12 --retry 3 --without development

# Ensure node_modules are cached next, they are less likely to change than source code
WORKDIR $INSTALL_PATH
COPY package.json             package.json
COPY spec/dummy/package.json  spec/dummy/package.json

# npm install with:
#   - private keys accessible
#   - skip optional dependencies like fsevents
#   - production (**turned off because we need eslint etc devDependencies)
#   - link dummy's node_modules to acme for a faster install
#   - add the authorized host key for github (avoids "Host key verification failed")
RUN ONVAULT npm install --no-optional \
  && cd spec/dummy \
  && ln -s $INSTALL_PATH/node_modules node_modules \
  && npm install --no-optional

# add all the test hosts to localhost to skip xip.io
RUN echo "127.0.0.1	localhost dummy.com.127.0.0.1.xip.io" >> /etc/hosts

#--------------
# NOTE: we evidently must include the VOLUME command **after** the npm install so that we can read the installed modules
#--------------
# Bypass the union file system for better performance (this is important for read/write of spec/test files)
# https://docs.docker.com/engine/reference/builder/#volume
# https://docs.docker.com/userguide/dockervolumes/
VOLUME $INSTALL_PATH

# Copy the project files into the container (again, better performance).  Use `extract` in the docker-rails.yml to obtain files such as test results.
COPY . .

RUN cd spec/dummy && npm run build
```

### 2. Add a docker-rails.yml

Environment variables will be interpolated, so feel free to use them. 
The _rails engine_ example below shows an example with all of the environments `ssh_test | development | test | parallel_tests | staging` to show reuse of the primary `compose` configuration. 

```yaml
verbose: true
exit_code: web
before_command: bash -c "rm -Rf target && rm -Rf spec/dummy/log"

# ---
# Run a dockito vault container during the build to allow it to access secrets (e.g. github clone)
dockito:
  vault:
    enabled: true

# ---
# Declare a reusable extract set
extractions: &extractions
  web:
    extract:
      - '/app/target'
      - '/app/vcr'
      - '/app/spec/dummy/log:spec/dummy'
      - '/app/tmp/parallel_runtime_cucumber.log:./tmp'
      - '/app/tmp/parallel_runtime_rspec.log:./tmp'

      
# ---
# Declare a reusable elasticsearch container, staging/production connects to existing running instance.
elasticsearch: &elasticsearch
  elasticsearch:
    image: library/elasticsearch:1.7
    ports:
      - "9200"
      
# ---
# Base docker-compose configuration for all environments.  Anything under the `compose` element must be standard docker-compose syntax.
compose:
  web:
    build: .
    working_dir: /app/spec/dummy
    ports:
      - "3000"
    links:
      - db
    volumes:
      # make keys and known_hosts available
      - ~/.ssh:/root/.ssh      

  db:
    # https://github.com/docker-library/docs/tree/master/mysql
    image: library/mysql:5.7.6
    ports:
      - "3306"

    # https://github.com/docker-library/docs/tree/master/mysql#environment-variables
    environment:
      - MYSQL_ALLOW_EMPTY_PASSWORD=true      

# ---
# Overrides based on the named targets ssh_test | development | test | parallel_tests | staging       
ssh_test:
  compose:
    web:
      command: bash -c "ssh -T git@bitbucket.org"      

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

## Contributing

Yes please.

1. Fork it ( https://github.com/[my-github-username]/docker-rails/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License and Attributions
MIT license 

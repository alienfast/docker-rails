# Docker::Rails

A simplified pattern to execute rails applications within Docker.

Features:
- cached global bundler data volume (automatic) based on ruby version
- interpolates `docker-compose.yml` making CI builds much easier
- starts `db` container first, and continues with `web` once `db` is ready
- cleans up `db` and `web` containers once completed


**Very much a work in progress - contributions welcome**
Open to pull requests, while this starts off as one-person's environment, it can be expanded to suit many different configurations.

Needs:
- remove hardcoded ip for db ip resolution
- remove or default hardcoded BUILD_NAME
- expand to different db status detection as needed

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
    apt-get install -qy build-essential libxml2-dev libxslt1-dev \
            g++ qt5-default libqt5webkit5-dev xvfb libmysqlclient-dev && \

    # cleanup
    apt-get clean && \
    cd /var/lib/apt/lists && rm -fr *Release* *Sources* *Packages* && \
    truncate -s 0 /var/log/*log

# https://github.com/docker/docker/issues/4032
ENV DEBIAN_FRONTEND newt

ADD . /project
WORKDIR /project
RUN ["chmod", "+x", "/project/scripts/*"]
```

### 2. Add a docker-compose.yml

Environment variables will be interpolated, so feel free to use them.

```yaml
web:
  build: .
  working_dir: /project/spec/dummy
  command: /project/script/start
  ports:
    - "3000:3000"
  links:
    - db
  volumes:
    - .:/project
  links:
    - db
  volumes_from:
    # Mount the gems data volume container for cached bundler gem files
    - #{GEMS_VOLUME_NAME}
  environment:
    # Tell bundler where to get the files
    - GEM_HOME=#{GEMS_VOLUME_PATH}

db:
  image: library/mysql:5.7.6
  ports:
    - "3306:3306"
  environment:
    - MYSQL_ALLOW_EMPTY_PASSWORD=true
```

### 3. Add a startup script

TODO: verify a good sample

```bash
#!/usr/bin/env bash

echo "Bundling gems"
bundle install --jobs 4 --retry 3

echo "Generating Spring binstubs"
bundle exec spring binstub --all

echo "Clearing logs"
bin/rake log:clear

echo "Setting up new db if one doesn't exist"
bin/rake db:version || { bundle exec rake db:setup; }

echo "Removing contents of tmp dirs"
bin/rake tmp:clear

echo "Starting app server"
bundle exec rails s -p 3000

# or use foreman
# gem install foreman
# foreman start
```

### 4. Run it

`bundle exec docker-rails`

### 5. Submit pull requests!

This is starting off simple, but again, we welcome pulls to make this and the process of using docker for rails much easier.


## Contributing

1. Fork it ( https://github.com/[my-github-username]/docker-rails/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License and Attributions
MIT license, inspired by many but certainly a [useful blog post by AtlasHealth](http://www.atlashealth.com/blog/2014/09/persistent-ruby-gems-docker-container). 

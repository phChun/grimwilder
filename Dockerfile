# syntax=docker/dockerfile:1
# check=error=true

# The production image, on Docker Hardened Images (https://dhi.io): built in the
# -dev image (root, a shell, apt), run in the runtime image, which has no shell
# and no package manager. Log in first: docker login dhi.io
#
# Use with Kamal or build'n'run by hand:
# docker build -t grimwilder .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name grimwilder grimwilder
#
# There's no shell in the running container, so commands go through Ruby
# (`ruby bin/rails console`), and debugging is `docker debug <container>`.

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=4.0.9

# Throw-away build stage: gems, bootsnap and assets
FROM dhi.io/ruby:$RUBY_VERSION-debian13-dev AS build

# Rails app lives here
WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Packages to build gems, plus what the runtime can't install itself: jemalloc,
# and time zone data for TZInfo
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libyaml-dev pkg-config libjemalloc2 tzdata && \
    mkdir -p /opt/jemalloc && cp /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /opt/jemalloc/ && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY vendor/* ./vendor/
COPY Gemfile Gemfile.lock ./

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    # -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
    bundle exec bootsnap precompile -j 1 --gemfile

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times.
# -j 1 disable parallel compilation to avoid a QEMU bug: https://github.com/rails/bootsnap/issues/495
RUN bundle exec bootsnap precompile -j 1 app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Final stage for app image: the hardened runtime
FROM dhi.io/ruby:$RUBY_VERSION-debian13

# Production environment, and jemalloc for reduced memory usage and latency.
# HOME is the app, as uid 1000 has no home of its own here. BUNDLE_VERSION:
# use the image's Bundler rather than switching to the lockfile's, which
# re-runs bin/rails through #!/usr/bin/env, and this image has no env.
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    BUNDLE_VERSION="system" \
    LD_PRELOAD="/opt/jemalloc/libjemalloc.so.2" \
    HOME="/rails"

# Copy built artifacts: jemalloc, time zones, gems, application. The gems and
# app belong to uid 1000, which owns the storage volume, as in the image this
# one replaced. Copying creates /rails, so it's theirs too (WORKDIR first
# would make it root's).
COPY --from=build /opt/jemalloc /opt/jemalloc
COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo
COPY --chown=1000:1000 --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --chown=1000:1000 --from=build /rails /rails
WORKDIR /rails

# Which release this is (config/deploy.yml passes them; shown in /admin). Last,
# so a new version doesn't bust the cached layers above.
ARG APP_VERSION APP_REVISION
ENV APP_VERSION=$APP_VERSION \
    APP_REVISION=$APP_REVISION

# Run as a non-root user
USER 1000:1000

# Entrypoint prepares the database. It's Ruby: there's no shell to run a script.
ENTRYPOINT ["ruby", "/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["ruby", "bin/thrust", "ruby", "bin/rails", "server"]

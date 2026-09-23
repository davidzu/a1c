#!/usr/bin/env bash
# Migrate + seed, then serve. Runs at boot so DATABASE_URL is available.
set -o errexit
bundle exec rails db:prepare
# db:prepare seeds only on first create. Seed is idempotent — always run.
bundle exec rails db:seed
exec bundle exec puma -C config/puma.rb

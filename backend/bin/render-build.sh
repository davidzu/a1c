#!/usr/bin/env bash
# Install gems only. Do not migrate here: db:prepare needs DATABASE_URL and
# often fails in the build environment (exit 1, never starts Puma).
set -o errexit
bundle install

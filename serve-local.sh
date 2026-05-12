#!/usr/bin/env bash
# Local preview for Academic Pages (Jekyll). Run from the repo root:
#   ./serve-local.sh
# Open the URL printed on the last line (usually http://127.0.0.1:4000/).
#
# If port 4000 is already taken (e.g. another Jekyll still running), the script
# picks the next free port in 4000–4010 and prints it.
#
# We do not pass -l (LiveReload) by default: it binds an extra port (35729) and
# fails if that port is in use. Jekyll still rebuilds when you save files.
# For browser auto-refresh when ports are free:
#   ./serve-local.sh -l
# If 35729 is busy:
#   ./serve-local.sh -l --livereload-port 35229
#
# macOS ships Ruby 2.6, which is too old for current github-pages gems.
# If Bundler fails, this script prepends Homebrew's embedded Ruby (3.1+).

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

use_homebrew_portable_ruby() {
  local dir
  for dir in \
    "/opt/homebrew/Library/Homebrew/vendor/portable-ruby/current/bin" \
    "/usr/local/Homebrew/Library/Homebrew/vendor/portable-ruby/current/bin"; do
    if [[ -x "${dir}/ruby" ]]; then
      export PATH="${dir}:${PATH}"
      return 0
    fi
  done
  return 1
}

if ! ruby -e 'abort unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.0")' 2>/dev/null; then
  if use_homebrew_portable_ruby; then
    :
  else
    echo "This project needs Ruby >= 3.0. Your default ruby is $(ruby -e 'print RUBY_VERSION' 2>/dev/null || echo unknown)." >&2
    echo "Install a newer Ruby, for example: brew install ruby" >&2
    echo "Then open a new terminal and run ./serve-local.sh again." >&2
    exit 1
  fi
fi

user_specified_port() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -P|--port)
        return 0
        ;;
      --port=*)
        return 0
        ;;
    esac
    shift
  done
  return 1
}

# First localhost port in [4000, 4010] we can bind to (same machine as Jekyll will use).
pick_port() {
  ruby -e '
    require "socket"
    4000.upto(4010) do |p|
      begin
        s = TCPServer.new("127.0.0.1", p)
        s.close
        puts p
        exit 0
      rescue Errno::EADDRINUSE
        next
      end
    end
    warn "No free TCP port between 4000 and 4010 on 127.0.0.1."
    exit 1
  '
}

bundle config set --local path 'vendor/bundle'
bundle install --quiet

if user_specified_port "$@"; then
  exec bundle exec jekyll serve -H localhost "$@"
fi

PORT="$(pick_port)"
echo "" >&2
echo "  Preview: http://127.0.0.1:${PORT}/" >&2
echo "  (Stop with Ctrl+C. If 4000 was busy, another port was chosen automatically.)" >&2
echo "" >&2
exec bundle exec jekyll serve -H localhost -P "$PORT" "$@"

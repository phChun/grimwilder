# Run using bin/ci

CI.run do
  step "Setup", "bin/setup --skip-server"

  group "Checks", parallel: 2 do
    step "Style: Ruby", "bin/rubocop"
    step "Security: Gem audit", "bin/bundler-audit"
    step "Security: Importmap vulnerability audit", "bin/importmap audit"
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

    group "Tests" do
      step "Tests: Rails", "bin/rails test"
      step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"
      # Optional: Run system tests
      # step "Tests: System", "bin/rails test:system"
    end
  end

  # Set a green "signoff" commit status on GitHub, which a pull request into
  # main needs before it can merge; publishing a release deploys (.github/workflows/deploy.yml).
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`; push
  # the branch first.
  if success?
    step "Signoff: All systems go. Ready to merge.", "gh signoff"
  else
    failure "Signoff: CI failed. Do not merge.", "Fix the issues and try again."
  end
end

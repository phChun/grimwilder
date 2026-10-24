# Contributing

Thanks for helping. Grimwilder is a play toolkit for *Grimwild*, not a rules reference, so changes should help people at the table and quote only as much of the book as a tool needs.

## Before you start

- Read [`AGENTS.md`](AGENTS.md): the conventions, the domain glossary and the gotchas (ReActionView and Herb especially).
- For anything bigger than a fix, open an issue first so we can agree on the shape.

## Making a change

```sh
bin/setup                                 # gems, database, then the app
bin/rails test                            # Ruby tests
node --test test/javascript/dice.test.mjs # dice rules (Node 22+)
bin/rubocop                               # Ruby style
npx @herb-tools/linter@0.11.0 app/views   # templates, after any template change
```

A rule change goes in both `app/javascript/grimwild/dice.js` and `app/models/grimwild/dice.rb`, with a case in `test/dice_examples.json`.

## Pull requests

`main` only changes through pull requests. CI runs locally: `bin/ci` runs the checks and tests, then sets a `signoff` status with `gh signoff`, which only maintainers can do. Run the checks above and say in the PR that they pass; a maintainer runs `bin/ci` before merging.

## License

By contributing, you agree that your contribution is licensed under the same [O'Saasy License](LICENSE.md) as the rest of the code.

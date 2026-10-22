# Grimwilder

A play toolkit for the tabletop RPG **Grimwild: Community Edition** (CE Preview 5.2). It's meant for use at the table, not as a rules reference: each tool quotes only as much of the book as a player needs in the moment.

## What it does

Open to everyone, no account needed:

- **Roll**: action and defense rolls with thorns, cuts and criticals, rolled in the browser.
- **Crucibles**: the book's 6×6 tables, rolled with 2d6, with a place to keep the combinations you like.
- **Talents**: the full talent catalog, searchable and filtered by path.

With an account (passwordless: an emailed code or a passkey):

- **Campaigns** with a reusable invite link, a GM and players.
- **Character sheets**: stats, marks and harm, conditions, spark and thread, XP and levels, talents with their uses and pools, bonds, and characters who fall or retire.
- **The GM table**: sessions and scenes, suspense, diminishing pools (task, pressure, timer, resource, power, campaign, and linked phases), rest and downtime.
- **A shared table log and chat**: the server rolls every character roll, so everyone can trust the log. Story rolls, montages and quarrels wait for each player to roll their own dice. Messages can be narration, NPC lines, in character, table talk or whispers to the GM, and everything updates live.
- **Session history**, with recaps and every roll by scene.

## Stack

Ruby 4.0.7 and Rails 8.2 (main), with views compiled by [Herb](https://herb-tools.dev) through [ReActionView](https://reactionview.dev). It uses Turbo, Stimulus and importmaps, plain CSS, SQLite with Solid Cache, Queue and Cable, and deploys with Kamal. The image is built on Docker Hardened Images.

## Running it

```sh
bin/setup   # install gems, prepare the database, start the app
bin/dev     # run the app (also starts the Herb dev server)
```

In development, sign-in codes appear on the page, so you don't need to set up email.

## Tests and checks

```sh
bin/rails test                            # Ruby tests
node --test test/javascript/dice.test.mjs # dice rules (Node 22+)
bin/rubocop                               # Ruby style
npx @herb-tools/linter@0.11.0 app/views   # templates
bin/ci                                    # setup, style, security audits and the Ruby tests
```

## Configuration

| Variable | Purpose |
|---|---|
| `APP_ORIGIN` | The site's origin (`https://example.com`). In production, passkeys need it to match the origin exactly. |
| `ALLOW_SIGNUPS` | Set to `false` to close sign-ups. Existing accounts and people with an invite link can still sign in. |

## Contributing

[`AGENTS.md`](AGENTS.md) holds the project's conventions, the domain glossary and how each part is built. Read it before you change anything. It's written for coding agents and humans alike.

## License

The code is under the [O'Saasy License](LICENSE.md): use, change and share it freely, but don't offer it to others as a competing hosted service.

The license covers the code only. *Grimwild* is by J. D. Maxwell (Oddity Press) and is used under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); the Community Edition text is CC0. The rules text quoted in the app (the talent catalog, crucibles and reference lists in `config/`) stays under those licenses. Grimwilder is unofficial and isn't endorsed by Oddity Press. It doesn't use the book's graphic assets or illustrations.

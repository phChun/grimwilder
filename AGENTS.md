# AGENTS.md — Grimwilder

Guidance for AI coding agents (and humans) working in this repo. Read this before changing anything. It covers conventions, gotchas and the non-obvious rules; the code and `CHANGELOG.md` cover the rest.

## What this is

**Grimwilder** is a *play toolkit* for the tabletop RPG **Grimwild: Community Edition** (`Grimwild::EDITION`, shown in the footer). It is **not** a rules reference/SRD: quote only as much rule text as a player needs at the table.

Built: the public tools (action roller `/roll`, crucibles, talent catalog), passwordless accounts with plans, campaigns (join links, archiving, on hold, schedules), character sheets, the GM table and campaign page, table chat, sessions and scenes, pools, the table log, optional rules, journals, polls and handouts. Nothing is scheduled next; see *Roadmap*.

Page numbers are Preview 6's: the CE text has no page breaks, and its three cross-references (pg. 25, 52, 175) match P6. Re-check them once there's a CE PDF. Crucibles and talent text now come from the CE text.

## Stack

| Piece | Choice |
|---|---|
| Ruby / Rails | Ruby **4.0.9**, Rails **8.2.0.alpha** (`main` from GitHub) |
| Views | `.html.erb` compiled by **Herb**, routed through **ReActionView 0.6** (reactionview.dev) |
| JS | importmap-rails, Turbo, Stimulus, the `reactionview` client (pinned by the gem) |
| CSS | Plain CSS via Propshaft. No Tailwind, no Sass |
| DB / infra | SQLite, Solid Cache/Queue/Cable, Kamal to a droplet behind Cloudflare, images on ghcr.io (`ghcr.io/phchun/grimwilder`) |
| Image | Docker Hardened Images (`dhi.io/ruby:4.0.9-debian13[-dev]`; `docker login dhi.io` first). See *Production* |
| Tests | Minitest (`bin/rails test`) plus Node's built-in test runner for pure JS |
| Auth | Passwordless: emailed codes + passkeys (`webauthn`); no `has_secure_password` / bcrypt |

## Commands

```sh
bin/dev                                   # run the app (also starts the Herb dev server)
bin/rails test                            # Ruby tests
node --test test/javascript/*.test.mjs    # pure JS: dice, backgrounds, selects (Node 22+, no npm install)
bin/rubocop                               # Ruby style
npx @herb-tools/linter@0.11.0 app/views   # template lint, including reactive-state validation
bin/ci                                    # everything, then `gh signoff`
```

Run the Herb linter after every template change. Its `herb-state-valid-reads` rule catches state expressions the browser can't evaluate; those still render on the server but silently stop updating in the browser.

## Workflow

- `main` changes only through squash-merged PRs, which need the `signoff` status from `bin/ci` on the branch's latest commit (pushing again needs `bin/ci` again), signed commits and linear history.
- Every PR adds `CHANGELOG.md` entries: one bolded, user-facing line per change under the UTC merge day, ending with the PR link.
- Merging doesn't deploy; publishing a GitHub release (`gh release create v1.4.0 --target main --generate-notes`) does, via `.github/workflows/deploy.yml`, after the `production` environment's required reviewer approves. Only admins can create `v*` tags. Keep workflow actions pinned to commit SHAs.
- Don't commit or push unless asked.

## File map (the core)

```
app/assets/stylesheets/application.css   # @font-face, design tokens (dark only), base, shell, layout
app/assets/stylesheets/components.css    # buttons, cards, dice, pools, pips, steppers, each screen
app/helpers/application_helper.rb        # TOOLKIT_NAV (ready: false shows "soon"), title_case, toasts
app/javascript/grimwild/dice.js          # PURE dice rules (no DOM), pinned as "grimwild/dice"
app/models/grimwild/dice.rb              # the same rules for server rolls
app/views/shared/                        # the partials every screen is built from (see *Design system*)
config/grimwild.yml                      # book lists: paths, backgrounds, traits, schools…
config/talents.yml                       # the talent catalog and its mechanics
config/crucibles.yml                     # every crucible table
config/plans.yml                         # account plans
config/initializers/reactionview.rb      # intercept_erb + slots on, debug_mode in development
test/dice_examples.json                  # shared cases for both dice implementations
.herb.yml                                # framework: actionview, template_engine: herb
```

## ReActionView conventions (important)

Reactive templates are **experimental (^0.6.0)**; markup, payload and JS API may change. Check https://reactionview.dev and https://herb-tools.dev/language/state when upgrading.

**Directives** go at the top of the template, one per line, no trim markers:
```erb
<%# herb:slots client %>
<%# herb:state (stat: 2, thorns: 0, mode: "action", outcome: "", critical: false) %>
```
- State defaults can be Boolean, Integer, String, Symbol or nil. **Float, Array and Hash are rejected.**
- `herb:slots client`: the browser evaluates everything. Use `server` only when a read needs Ruby or the DB; the controller then reads `herb_state(name, default)`.

**Actions**: `data-herb-set="name=value"` (or `"change->name=value"`; `$value` is the element's value), `data-herb-toggle`, `data-herb-increment`/`-decrement` (step `data-herb-by`), `data-herb-reset`, `data-herb-action="$refresh"`; timing with `data-herb-debounce`/`-throttle="ms"`.

**Browser-evaluable expressions**: a bare state; `!`/`not`; `==`/`!=` against a literal; `< > <= >=` on Integers; `||`; `case/when` with literal arms; `nil? positive? zero? one? empty? blank? present?`; `to_s`; `length`/`size` on Strings. **Not**: `count`, computed Ruby (`(!x).to_s`, `titleize`), ternaries; templates can't assign state. Need a computed value? Add a state and set it from an action or Stimulus.
- Boolean attributes (`disabled`, `checked`, `selected`) follow the expression: `disabled="<%= stat <= 1 %>"`. Non-boolean ones like `aria-pressed` can't be computed: use radios bound with `checked=` (`shared/_segmented`).
- Inside a keyed loop the loop variable counts as row state, so `pool.size != pool.starting_size` fails the linter; move it into a model method (`Pool#resettable?`).
- A hash key with a state's name (`@preset[:thorns]`) counts as reading that state; rename the key.

**Stimulus ↔ state**: `import { useState } from "reactionview"`; `connect() { useState(this) }`; `this.state.get("stat")`, `this.state.set({ outcome: "messy" })`; optional `<name>Changed(value)` and `this.state.on("name", fn)`. Pattern: **the template owns inputs and result text; Stimulus owns randomness and any DOM the template doesn't render.**

**Herb gotchas**
- **Don't use `stylesheet_link_tag :app` or `:all`**: Herb compiles it statically and looks for `app.css`. List each stylesheet by name; a new CSS file needs a new line in the layout. Other tag helpers may compile statically too: check the compiled output on the error page.
- **`link_to` with an interpolated attribute containing a space breaks** (`"aria-label": "Account: #{name}"` → `aria-label="Account:" gwen=""`). Write the `<a>` by hand (see `layouts/_app_header`); ignore the linter's "prefer link_to". `button_to` is fine.
- **Keep `locals:` defaults `nil`**: Herb prints non-nil defaults into the output. Default to `nil`, then `<% size ||= 44 %>` (`test/helpers/shared_components_test.rb` checks).
- **`tag.details`/`tag.section` drop a `**splat` inside `data:`**: spell the hash out or write the tag by hand.
- **`turbo_frame_tag` with a record breaks** (no prefix, empty `src`): use a literal string id or a hand-written `<turbo-frame>`.
- **`<%==` escapes like `<%=`** and the linter refuses `raw()`: gem-built HTML strings go through a helper that marks them `html_safe` (`AdminHelper`). Avoid `<%#=`.

## Grimwild glossary

**Core roll**
- **Stats** (1–3 to start, each starts at 1 plus 4 points): **Brawn**, **Agility** (physical), **Wits**, **Presence** (mental). (pg. 23)
- **Action roll**: d6s equal to the stat, plus dice from spark, assists and talents; **highest d6 is the result**: **Perfect** (6), **Messy** (4–5, success with an impact move), **Grim** (1–3, failure with an impact move), **Disaster** (a grim that gets cut; worse impact, and the player takes spark). (pg. 11, 18)
- **Defense roll**: avoiding danger the PC didn't cause. Perfect avoids, messy reduces, grim takes it, disaster takes worse, plus spark. (pg. 16)
- **Thorns (t)**: d8s for difficulty; each 7 or 8 is a **cut**, lowering the result one step. Usually 0–2, no cap. (pg. 12)
- **Critical**: a perfect with more than one 6; thorns can't cut it. Pick **Greater effect** (drop 1d from the task pool first), **Secondary effect**, or **Setup** (a riskless assist); if none fits, take spark. (pg. 11)
- **Story roll** (luck or truth, usually 2d), **Montage roll** (a stretch of activity), **Quarrel** (PC vs PC, 2d each, higher die wins). (pg. 17, 24)
- **Vantage**: what's plausible now: Certain (no roll), Reasonable (+0–1t), Doubtful (+2t+), Impossible. (pg. 13–14)
- **Impact move**: a GM move bringing trouble, usually after messy, grim or disaster. (pg. 101)

**Currencies**: **Spark** (+1d each before a roll, max 2, carries over; from tangles, disasters, arcs, quarrels, bond changes; pg. 13). **Thread** (2 per session, adds story details; pg. 26). **Tangle** (a player's own complication, for spark). **Suspense** (the GM's: extra moves, dropping 1d from a pool; gained by skipping impact moves, suspense moves, and each session after the first; spending it prompts an impact move; pg. 97).

**Play structure**: **Session** (before each after the first: players take spark, reset thread and per-session talents; GM takes suspense and recaps; after: 1 XP, 2 for a standout; pg. 32). **Scene** (opens mid-action, closes with a montage; some talents and conditions last a scene; pg. 30). **Rest** (clears marks and harm). **Downtime** (full heal, per-session talents reset, GM rolls campaign pools and depletes one; pg. 31).

**Damage** (pg. 28–31): **Mark** (+1t on the stat's next roll, then clears; a second mark becomes harm). **Harm**: Bloodied (+1t Brawn/Agility), Rattled (+1t Wits/Presence), Desperate (+1t all; from a second bloodied or rattled); harm while desperate is **dropped**. **Vex**: fight, flight, freeze, freakout. **Conditions**: short to permanent, often a timer pool (`4d poisoned`), +1t when relevant.

**Pools** (pg. 19–20): d6s tracking progress; roll and **drop every 1–3**; at **0d** it happens. Written *4d* Barroom Brawl; 2d/4d/8d clear in about 2.7/3.5/4.4 rolls. Kinds: task, pressure, timer, resource (must be rollable to use), power (rolled *as* an action roll, then 1–3s drop; spark dice separate), linked (phases: 4d+4d), campaign (rolled in downtime). A task roll that drops nothing can **push** (take a mark, drop 1d) or **pivot**. *Tick pools* (optional, pg. 178) drop exactly 1d and are never rolled.

**Other**: **Crucible** (a 6×6 table, roll 2d6, "roll 2 and smash them together"), **Bonds** (intensity + nature toward each other PC, pg. 23), **Traits/Desires** (2 that fit, 1 that doesn't), **Wises** (expertise widening vantage), **Story arcs** (group + character; resolving gives spark), **Paths** (classes, each with a core talent), **Enemy tiers** (mook, tough, elite, boss; pg. 110).

## Dice

Two pure implementations (no DOM, no DB, randomness injected): `app/javascript/grimwild/dice.js` for the anonymous `/roll` page, `app/models/grimwild/dice.rb` for server rolls (all character rolls are server-rolled so the shared log can be trusted). Both run against `test/dice_examples.json`. **Change a rule in both files and add the case to the JSON.** Use the book's worked examples as cases (pg. 123: `[2,6]` vs a 7 thorn is messy; `[3,4,2]` vs `7,8` is disaster).

- `interpretRoll(dice, thorns, { boosts })` / `interpret(dice, thorns, boosts:)` → `{ result, critical, highest, cuts, appliedCuts, appliedBoosts, base }`. Extra cuts past disaster do nothing; a critical ignores every cut. Boosts are Panache's d8s, raising a step on 7–8.
- `countAs(dice, rule)`: `"reckless"` (5s as 6s, 4s as 1s) or `"teamwork"` (an assist's 5s as 6s). `isTwist(dice, thorns)`: two or more 1s, a magical twist when casting.
- `talentRoll(…)` mirrors the server's talent rules for `/roll`'s Talents fold; `rollPool(size)` mirrors `Pool#roll!`.

## Table rolls & the log

- **`Roll`** is one log entry: `action`/`defense` (from a sheet), `story`, `quarrel`, `montage`, `pool` (drop-first or push), plus `marker` (session/scene boundaries, campaign events) and `note` (`Roll.note!`, one line, no dice; skipped quietly in archived campaigns). Names are copied in, so the log survives renames and deletes. Rolls are stamped with the open `play_session`/`scene`.
- **`Character#roll!`** (`Character::Rolling`) does it all in one transaction: spends spark (`settle_spark`, the one place spark is spent and taken, capped at 2, doesn't save), rolls 1d per assisting character (`assists`, counted by `Roll#all_dice`), adds damage thorns, clears the stat's mark, gives spark on a disaster, applies talent bonuses and Panache, records the Roll. Unseated characters' rolls have no campaign and aren't logged.
- **Rolling on the sheet**: each stat card's Roll opens `characters/_roll_form` in a `<dialog class="roll-dialog">` (`roll_dialog_controller.js` closes it on submit, since a morph would leave the page inert). It posts to `characters/:id/rolls#create`, which redirects back; the result shows as the **roll toast**. The steppers post totals; the controller derives `help` and situational `thorns` only after checking the stat name (`Character#stat` is a `public_send`). "Only the GM sees it" makes it `gm_only`: `Roll.visible_to` shows it to GMs and the roller; it streams on `[campaign, :gm_rolls]` and the roller's `[membership, :rolls]`.
- **Power pools**: `Pool#roll!(as_action: true, …)` uses the highest die as the outcome, then drops 1–3s; spark dice are stored last in `dice` and never drop. Rolls on hidden pools are `gm_only`.
- **Story rolls, montages, quarrels** (`Roll::Story`, `Roll::Montage`, `Roll::Quarrel`): only the GM calls them (`require_gm`), from the GM table's Rolls fold. A story roll for no one in particular rolls at once (optionally GM-only); one for a character, a montage or a quarrel is a **roll call**. Montages have no thorns; each side's result goes in `sides`. Quarrels: everyone involved takes spark; a tie has no `winner`.
- **Roll calls** (`RollCall`): wait for each seated player to roll their own dice (`#roll!` spends their spark then). The GM can roll for anyone (`#roll_everyone!`) but never spends their spark; cancelling gives it back. One open call per campaign (partial unique index). It's a modal on every campaign page, live via a **`data-turbo-permanent` slot** (`Campaign#roll_call_slot_id`): each change broadcasts an *update* of the slot with an empty, non-permanent frame carrying a versioned `src` over `[campaign, :live]`, so each viewer fetches their own copy (replacing a permanent frame directly does nothing). Polls use the same pattern.
- **Follow-ups** (`follow_ups:` in talents.yml, `Talent::FollowUp`, `Roll::FollowUps`): talents that change a roll after it's made (`bonus`, `reroll`, `raise`, `assist`, `critical_effect`), only on a character's latest action/defense/story roll within 15 minutes at a table in play. `follow_up!` changes the roll in place; `was_outcome` keeps the first result (spark from a disaster stays). Page: `campaigns/:id/rolls/:roll_id/follow_up/new`.
- A critical where nothing fits: `Character#take_spark_for_critical!` from the toast, once, owner only.
- **Roll toast** (`rolls/_toast`, `RollsHelper#toast_roll`): your own rolls, on whatever page you land on, for 10 seconds (the server passes seconds left, so client clocks don't matter); dismissal is remembered per tab.
- **Live**: `rolls/_feed_item` is appended to `#table_feed` over `[campaign, :rolls]` and replaced on update. It renders in a job, so **no `Current`**. Load a member's log with `campaign.rolls.table_log(membership)`.
- Tests: `assert_no_turbo_stream_broadcasts` counts every broadcast so far in the test, not just its block. `FixedDice` stands in for `Random`.

## Table chat

- **`TableFeed`** merges `Message`s (chat) and `Roll`s (log) a member may see into one stream, `PAGE` (50) at a time; `feed_controller.js` loads older pages on scroll, keeps your place, shows a "3 new" pill and puts your own lines on the right. The rail is `campaigns/_table_rail` (GM table, seated sheets, the players' campaign page).
- **Kinds** (`messages.kind`): `narration`, `npc` and `handout` (GM), `in_character` (needs a seated active character), `table_talk`, `whisper`. The model enforces who may speak how; the composer sends only a context (the Show select), mapped by `Campaigns::MessagesController#speaking`.
- **Whispers are only ever seen by their two sides** (the GM side is every GM; GMs don't see player-to-player whispers). Never broadcast on `[campaign, :chat]`/`:table`; `Message.visible_to` filters them; `Message.streams_for` gives each member their streams.
- `messages/_message` renders once for everyone (no `Current`); per-viewer bits (mine vs theirs, delete buttons, thread filtering, unread counts in localStorage) are done client-side via `data-from`/`data-to`/`data-identity`.
- **Presence**: `PresenceChannel` + `presence_controller.js`, check-ins every 30s (`Membership::PRESENCE_BEAT`), dropped after 75s silence.
- Times are `<time datetime>` localized by `local_time_controller.js`; the server fallback is UTC.

## Polls and handouts

- **Polls** (`TableQuestion`, `TableAnswer`): GM asks chosen players (choices up to 6, or words); only GMs see answers; closable. Shown to players as a modal through the permanent-slot pattern (`Campaign#question_slot_id`, `Campaigns::AskedQuestionsController`).
- **Handouts**: a `handout` `Message` with `has_one_attached :image` (PNG/JPEG/WebP/GIF by content sniffing, **never SVG**, ≤5 MB, no resizing). Served only through `Campaigns::Messages::ImagesController` (via `Message.visible_to`, `nosniff`, private cache), never Active Storage's signed URLs. Not built: moderation; add reporting if sign-ups open.

## Campaign screens

- **GM table** (`/campaigns/:id/table`, `Campaigns::TablesController`, `require_gm`, data from `CampaignTable#load_table`): scene bar (clocks, suspense, scene and session controls, Respite), party cards, pool cards, the Rolls fold, crucibles (lazy `turbo_frame_tag "crucible"`, `data-turbo-permanent`), Share with the table, and the rail. "Copy for an AI" (`Campaign::Brief`) exports the campaign and party as Markdown, with nothing GM-only and no stats.
- **Campaign page** (`campaigns#show`): read-only overview for everyone: hero (pitch, party facts, rules in play, Coming up), party, what looms, Previously on…, kept crucibles. Nobody rolls here.
- **Settings** (`campaigns#edit`, GM only): pitch, characters (`Campaign::CharacterSettings`), optional rules, schedule, invite link, members and blocks, reset, archive, delete. Each section saves alone.
- **Redirects**: `back_to_table` sends the GM to the GM table, a player to the campaign page or their sheet (by referer). `campaign_play_path` sends a player to their seated sheet. Turbo drops a redirect's `#fragment` after a form post.
- **Live banner** uses its own `[campaign, :live]` stream, not `:table`: `:table` carries refreshes, which would wipe half-typed forms on pages that don't morph. `Campaign#broadcast_table_refresh` sends both.
- `details_memory_controller.js` remembers each `<details>`'s open state per campaign in localStorage and restores it after a morph. Floating menus use `menu_controller.js` (positions on screen; closes after a successful save).

## Sessions & scenes

- **`PlaySession`** (`Session` is sign-in): at most one open per campaign. `start!` resets present characters (thread, spark, talent uses and pools; not before session 1) and gives the GM 1 suspense; `end!` gives XP (twice if standout) and ends any open scene. Attendance is `play_session_characters`.
- **`Scene`**: one open per session; `start!` takes story-roll args for an opening roll; `end!` clears the ticked scene conditions and per-scene uses. **Scene prep**: `ScenePlan`s grouped into `SceneBlock`s; a session may name its block.
- **Rest and downtime** (`Campaign::Breaks`) apply to `Campaign#resting_characters`. Downtime rolls campaign pools and depletes the one picked. **Expanded downtime** (`Campaign::DowntimeActions`, `Character::Goals`) gives each character an action and replaces carousing.
- **Talent uses** (`uses:` in talents.yml, `Talent::Use`, `Character::TalentUses`): counts, talent pools, extra thread; `per` `session`/`scene`/`rest`/`never`; `growth` by level; named, tally and track variants. Talent pools are `Pool`s with `character_id`. `test/models/talent_use_test.rb` checks every entry.
- **History** (`campaigns/:id/play_sessions`): sessions, with "Between sessions" stretches for rolls made outside any. **Journals** (`Journal` over `JournalEntry`): per player per campaign, keyed by session *number* so a reset keeps them; GM can read while shared.
- **Reset** (`Campaign::Reset`) deletes sessions, the log and roll calls (refunding spark); chat, pools and characters stay.
- **Suspense** is `campaigns.suspense`, GM-only to change, visible to all, never logged.
- Best moments were removed (2026-10-22): sharing them happens at the table, not in the app.

## Schedules

`Campaign::Schedule` holds a rule (weekly every N weeks or monthly by weekday, a time and IANA zone); dates are computed (`rule_dates`, `upcoming`, `next_game`), never stored. `GameDate` stores only exceptions (`skipped`, `moved`) and `extra` dates. Times are built in the schedule's zone so DST keeps 7pm at 7pm; `game_time_tag` renders them and `local_time_controller.js` rewrites them for other zones. Changing the rule drops exceptions no longer on it. Hidden when archived or on hold.

## Accounts, campaigns and tenancy

- **Passwordless**, modelled on Fizzy: `Identity` (by email), `Session` (signed http-only cookie, 6-hour `LIFETIME`), `MagicLink` (6-char code, 15 minutes, single use, keyed by email so asking never creates an account, redeemable only in the browser with the `pending_authentication` cookie; shown on the page in development), `Passkey` (discoverable WebAuthn; challenges in the Rails session; `APP_ORIGIN` must match production's origin).
- **Tenancy = shared database + `campaign_id`** (not activerecord-tenanted). Campaign controllers `include CampaignScoped`, which loads the campaign *through* `Current.identity.memberships` (non-members get 404); `require_gm` for GM actions. New campaign-owned models `belongs_to :campaign` and are always queried through `Current.campaign`. `Membership` is `gm`/`player`; a campaign always keeps a GM.
- Join via `/join/:code` (12 random base58 chars), which the GM can reset or turn off. GMs can remove or block players (`Campaign::Blocking`).
- **Plans** (`config/plans.yml`, `Plan`, `Identity::Plans`): limits on campaigns run and played. **`Identity#apply_plan!` is the only way a plan changes**; it holds GM seats past the limit (**on hold**, `Campaign::Hold`): readable, chat works, but no play (`Campaign#playable?`, `refuse_new_play`, `refuse_play!`, `refuse_when_on_hold`). Tester accounts must never be downgraded by a future Stripe webhook.
- **Archived** campaigns (`Campaign::Archive`) are read-only: `refuse_when_archived` on non-GETs, models refuse new rolls/messages/roll calls, `Character#in_play?` gates sheet actions (character controllers use `refuse_when_campaign_archived`). Not while a session is open.
- **Sign-ups** follow `ALLOW_SIGNUPS` (`config.x.signups_open`). Closed, only existing accounts or holders of a working invite link get a code; others can leave their email on `/interest`. Tests flip `Rails.configuration.x.signups_open` and restore it in teardown.
- **Rate limits** (`rate_limit`, Solid Cache, real IP via `cloudflare-rails`) on codes, sign-ins, passkey challenges and the interest form. Tests use a null cache.
- Controllers opt in with `require_authentication`; sign-in pages use `require_unauthenticated_access`. The public tools stay public.
- The home page is marketing (`pages/home`); `pages/_cta` adapts to signed-in and sign-up state. Keep its claims true when features or plans change.
- Tests: `sign_in_as(identity)` goes through the real code flow; passkey tests use `WebAuthn::FakeClient.new("http://www.example.com")`.

## Admin

`identities.admin` is set only from the console (`bin/kamal console`). `/admin` (`Admin::BaseController`; 404 for non-admins) has Stats, Interested, Accounts (plans via `apply_plan!`, Feedback access) and Campaigns (read-only), searchable (`AdminSearch`) and paged with pagy. Admins get no way into campaigns they aren't in. Last sign-in is `identities.last_signed_in_at` (not `sessions`, which sign-out deletes). **Feedback** (`Feedback`) is per-account opt-in and exports to Markdown without emails.

## Pools

`Pool` belongs to a campaign: `kind`, `starting_size` 1–20, `size`, `hidden`, the last roll, linked `phases`, `tick`. Rolled **on the server** (`Pool#roll!`, mirroring `rollPool`). Members roll and push what they can see; the GM adds, resets, hides and deletes; players get 404 for hidden pools. Dropping 1d first: `Pool#drops_first_for?(gm:)`. Live via `broadcasts_refreshes_to [campaign, :pools]` and morph refreshes, so each viewer refetches with their own permissions and hidden pools never leak.

## Crucibles

Data in `config/crucibles.yml` (97 crucibles, 152 tables), read by a plain `Crucible` class (`Crucible::Table` Data objects; reloaded each request outside production). Tables may be 6×6, narrower (`Crucible::WIDTHS`) or d8 (`Table#d8?`). Rolling is client-side and public (`crucible_controller.js`). When adding tables, check cell boundaries against the source; `test/models/crucible_test.rb` enforces shape and spot-checks hand-transcribed tables. The CE text is the source from now on; heritage, eldritch mutations and monster crucibles still come from Preview 6.

## Characters

- Owned by an identity, optionally seated in one of the owner's campaigns (`Character::Seating`). Owners edit; members of that campaign read; others get 404 (`Character.visible_to`). **`tended_by?`** (owner or the campaign's GM) may change harm, marks, conditions, talent uses, choices and re-skins; GM changes are logged and refresh the owner's sheet.
- Book lists live in `config/grimwild.yml`, read through `Grimwild`. JSON detail columns are cleaned and capped by model setters, which accept Rails' `{"0"=>…}` hashes. Stats total 8 on create (3 at level 0).
- **Status** (`active`/`fallen`/`retired`, `Character::Farewell`) and **archived** (`Character::Archive`, housekeeping) take characters out of play. **Up for grabs** (`Character::Claiming`): GM-made characters any player can claim (`with_lock`). Query the party as `campaign.characters.played.active`.
- `Character::Damage` (marks, harm, conditions as `{ "name", "lasts" }`, vex, `damage_thorns`, `take_mark`), `Character::Advancement` (XP, max level 7). `changed_by` records who changed harm.
- The sheet (`characters#show`) is a size container; quick changes are `button_to` PATCHes with `quick: 1` and morph refreshes.
- Arcana (`Arcanum`, irregular inflection; `Character::Arcana`) get power pools sized by tier, refreshed by `refresh_arcana_pools!`.

## Talents

- Catalog in `config/talents.yml` (`Talent`, `Talent::Group`, Data classes): 18 paths, background/heritage and legacy talents. Keys are slugged names unless the YAML sets `key:` (Hex keeps `pact`). `retired: true` talents stay on existing sheets but can't be picked. Prohibitions and "[X Only]" go through `Talent#prohibited_for?`, checked only for new picks.
- `talent_keys` are capped by level (`talents_fit_level`, validated only when talents or level change, so old over-cap sheets still save). Eldritch talents (Pact) are a separate list. Optional rules: Level 0, stat progression, legacy cores.
- Every talent has our own `summary:` (≤100 chars, not book text). Mechanics are declared in YAML and each has a test checking every entry: `uses:`, `rolls:` (`Talent::Roll`), `bonuses:` (`Talent::Bonus`; use `only:`, not `on:`, which YAML reads as `true`), `follow_ups:`, `choices:` (`Talent::Choice`, `Character::TalentChoices`; options must appear in the talent text), `arcana:`, `makes:`, `state:`.
- Re-skins (`Character::TalentSkins`, `SkinnedTalent`) change name, summary and text only; mechanics stay.
- The PDF extraction left U+0002 hyphenation characters once; a test guards against them.

## Design system (night-table)

- **Dark only.** Every color, font and radius is a custom property in `:root` in `application.css`; components use only the variables. Fonts are self-hosted (Spectral, IBM Plex Sans, IBM Plex Mono); no Google Fonts.
- Body 15px/1.5. Every button and input is at least `--tap` (44px). Icons are inline SVGs from `icon(:name)`, never emoji or glyphs; icon-only buttons need an `aria-label`.
- Result colors `--perfect`, `--messy`, `--grim`, `--disaster`: **always show the word next to the color.** Spark amber circles, thread blue diamonds, suspense purple diamonds.
- One `.button--primary` (ember) per area; `.button` outline, `.button--ghost` text. BEM-style class names. Layout `.fluid` > `.fluid__main` + `.fluid__rail`; 16px gutter, no horizontal scroll at 390px.
- **Shared partials** (`app/views/shared`): `_die`, `_roll_result`, `_pool_track`, `_pips`, `_segmented` (radios, not `aria-pressed`), `_tally`, `_stepper`, `_card`, `_close_button`, `_popover_head`, `_confirm`, `_toasts`, `_frame_modal`. Broadcast-rendered partials must not use `Current`.
- **Selects** are redrawn by `selects_controller.js`; the native select stays the truth, so write selects as usual (`data-native` to opt out).
- **Confirmations**: write `form: { data: { turbo_confirm: "…" } }`; `shared/_confirm` handles it.
- **Modals**: link with `data: { turbo_frame: "modal" }` to a page wrapping its content in `turbo_frame_tag "modal"`; its forms target `_top`.
- **Toasts**, no flash banners: `notice:` is a neutral toast; `alert:`, 422 re-renders and unrescued `RecordInvalid` are grim-red failure toasts (`ApplicationController#not_saved`).
- Every popover and modal has a title and a ✕. Lists that grow end with a dashed "Create new …" card (`.add-card`), no + glyph.
- Text boxes with the book's words use `type_or_select` placeholders. Show list words with `title_case` (never Rails' `titleize`, which turns hyphens into spaces); stored values stay lowercase.
- Accessibility: skip link, `:focus-visible` outlines, `aria-live` on changing results, `prefers-reduced-motion`.

## Roadmap

**Set aside**: RSVPs and game-day reminder emails (`docs/design/holds-and-schedules/BRIEF.md` part 4); payments (Stripe prices in `plans.yml`, Checkout, Customer Portal, a webhook that moves accounts only between Free and paid, never touching Tester).

**Not modelled** (the book gives no rules): Wild Shape's and the Vassal's per-form details, the vassal's thematic path aspect; Augury's omens on others' open roll calls; using talent picks in the roll setup; the hex flowers and the lich's spell list.

**Decided**: no sharing a roll without an account; Sorcery's twist is one open pick; the quarry die is an after-roll follow-up on action rolls only.

The repo is open source under O'Saasy (`LICENSE.md`).

## Production

- **Image**: Docker Hardened Images with **no shell, no package manager and no `/usr/bin/env`**. `bin/docker-entrypoint` is Ruby and runs `db:prepare`; run commands as `ruby bin/rails …` inside a container (`docker run image bin/rails …` goes through the entrypoint and is fine). `BUNDLE_VERSION=system`. jemalloc and zoneinfo are copied from the build stage; there's no libvips, so images are never transformed (`variant_processor = :disabled`). Runs as uid 1000. Keep `.ruby-version` and the `RUBY_VERSION` build arg together.
- **Live** at https://grimwilder.com (`www.` redirects). `bin/kamal deploy|console|logs` from the Mac need secrets from 1Password; the server address and secrets never go in the repo. `APP_VERSION`/`APP_REVISION` are baked into the image and shown in /admin.
- SQLite lives in the `grimwilder_storage` volume, with nightly `DatabaseSnapshot`s. Mail goes through an SMTP provider (name it only that way in docs). `ErrorNotifier` emails server errors and failed jobs when `ERROR_EMAIL_TO` is set.
- Server setup and operations notes are kept locally, outside the repo, in `docs/ops/production-server.md`.

## Search engines and link previews

`layouts/_meta` writes description, canonical, Open Graph and Twitter tags; pages set `content_for :description`/`:title`. The preview image (`app/assets/images/og-image.png`) is our own, **never the book's art**. Invite-link previews show only the campaign name and GM. `public/robots.txt` disallows signed-in areas and `/join/`; `/sitemap.xml` lists the public tools and crucibles.

## Licensing (must keep)

- The footer must credit *Grimwild* by J. D. Maxwell (Oddity Press) under **CC BY 4.0**, say the site is unofficial and not endorsed, and note the CE text is CC0.
- **Do not** reuse the book's Canva graphic assets or Per Janke's illustrations.
- Quote the book's text only as much as a tool needs.

## Agent working notes

- The user develops on macOS and runs the app there.
- Sandboxes may not be able to `bundle install` (rubygems.org blocked, old Ruby). If Rails won't boot, still run the Herb linter and the Node tests, and say plainly that the Rails tests weren't run.
- Useful npm packages: `@herb-tools/linter@0.11.0`, and `reactionview@0.6.0` (its source shows the client API).

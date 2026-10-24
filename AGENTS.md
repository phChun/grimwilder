# AGENTS.md — Grimwilder

Guidance for AI coding agents (and humans) working in this repo. Read this before changing anything.

## What this is

**Grimwilder** is a *play toolkit* for the tabletop RPG **Grimwild: Community Edition** (CE Preview 5.2).
It is **not** a rules reference/SRD. Each tool should quote only as much rule text as a player needs at the table.

Current state:
- Done: site layout (header nav, footer), home page (`/`), action roller (`/roll`), passwordless accounts (email code + passkeys), campaigns with join links, campaign pools, crucibles, character sheets and the talent catalog, and the table log (server-rolled character rolls that spend and award spark, plus pool rolls, live on the campaign page).
- Next: see *Roadmap*.

Source rulebook: `GWCE P5.2 Pages.pdf` (in the Claude project "Grimwilder", not in the repo). Page numbers below refer to it.

## Stack

| Piece | Choice |
|---|---|
| Ruby / Rails | Ruby **4.0.7**, Rails **8.2.0.alpha** (`main` branch from GitHub) |
| Views | `.html.erb` compiled by **Herb** and routed through **ReActionView 0.6** (reactionview.dev) |
| JS | importmap-rails, Turbo, Stimulus, the `reactionview` client (pinned automatically by the gem) |
| CSS | Plain CSS served by Propshaft. No Tailwind, no Sass |
| DB / infra | SQLite, Solid Cache/Queue/Cable, Kamal to a DigitalOcean droplet, images on ghcr.io (droplet `129.212.197.211`, image `ghcr.io/phchun/grimwilder`; Cloudflare proxies the domain and kamal-proxy serves a Cloudflare Origin CA cert from `CERTIFICATE_PEM`/`PRIVATE_KEY_PEM`). CI runs locally: `bin/ci` ends with `gh signoff`. `main` only changes through pull requests (squash merge), which need that signoff; every push to `main` deploys via `.github/workflows/deploy.yml` |
| Image | Docker Hardened Images: built in `dhi.io/ruby:4.0.7-debian13-dev`, run in `dhi.io/ruby:4.0.7-debian13` (`docker login dhi.io` first). See *Production image* |
| Tests | Minitest (`bin/rails test`) plus Node's built-in test runner for pure JS |
| Auth | Passwordless: emailed codes + passkeys (`webauthn` gem); no `has_secure_password` / bcrypt |

## Commands

```sh
bin/dev                                   # run the app (ReActionView also starts the Herb dev server)
bin/rails test                            # Ruby tests
node --test test/javascript/dice.test.mjs # dice-rule tests (Node 22+, no npm install needed)
bin/rubocop                               # Ruby style
npx @herb-tools/linter@0.11.0 app/views   # template lint, including reactive-state validation
```

Run the Herb linter after every template change. Its `herb-state-valid-reads` rule catches state expressions the browser can't evaluate. Those still render on the server but quietly stop updating in the browser.

## File map

```
app/
  assets/fonts/             # self-hosted Spectral + IBM Plex woff2 (OFL, licenses alongside)
  assets/stylesheets/
    application.css        # @font-face, design tokens (dark only), base, the shell (header, live banner), layout
    components.css         # buttons, cards, dice, roll results, pool tracks, pips, steppers, and each screen
  controllers/
    pages_controller.rb    # home
    rolls_controller.rb    # /roll (no server logic; all client-side)
    admin/                 # /admin: admins only (see *Admin*)
  helpers/application_helper.rb   # TOOLKIT_NAV: the nav items; ready: false shows "soon"
  javascript/
    grimwild/dice.js       # PURE rules module: no DOM. Pinned as "grimwild/dice"
    controllers/roller_controller.js  # Stimulus: rolls, draws the dice tray, writes state back
  views/
    layouts/application.html.erb
    pages/home.html.erb
    rolls/show.html.erb    # the anonymous /roll page: reactive template (herb:state)
config/initializers/reactionview.rb  # intercept_erb + slots on
test/javascript/dice.test.mjs
.herb.yml                  # framework: actionview, template_engine: herb
```

## ReActionView conventions (important)

ReActionView's reactive templates are **experimental (^0.6.0)**. The markup, payload and JS API may change between releases. Check https://reactionview.dev and https://herb-tools.dev/language/state when upgrading.

**Config** (`config/initializers/reactionview.rb`): `intercept_erb = true`, `slots = true`, `debug_mode` in development.

**Template directives**: put them at the top of the template, each on one line, with no trim markers:
```erb
<%# herb:slots client %>
<%# herb:state (stat: 2, thorns: 0, mode: "action", outcome: "", critical: false) %>
```
- State defaults can be Boolean, Integer, String, Symbol or nil. **Float, Array and Hash are rejected.**
- `herb:slots client` means the browser evaluates everything and never asks the server. Use `server` only when a read needs Ruby or the DB. The controller then reads values with `herb_state(name, default)`.

**Actions** (HTML attributes):
- `data-herb-set="name=value"` (or `"change->name=value"`; `$value` is the element's value)
- `data-herb-toggle` (Boolean), `data-herb-increment` / `data-herb-decrement` (Integer, step set by `data-herb-by`)
- `data-herb-reset`, and `data-herb-action="$refresh"` (re-render the server-computed parts)
- Timing: `data-herb-debounce="ms"`, `data-herb-throttle="ms"`

**Expressions the browser can evaluate**: a bare state; `!`/`not`; `==`/`!=` against a literal; `< > <= >=` on Integers; `||`; `case/when` with literal arms; `nil? positive? zero? one? empty? blank? present?`; `to_s`; `length`/`size` on Strings.
- **Not supported**: `count`, computed Ruby like `(!x).to_s` or `titleize`, and ternaries. Templates can't assign state.
- If you need a computed value, add another state and set it from an action or from Stimulus.
- Boolean attributes (`disabled`, `checked`, `selected`) are added or removed based on the expression: `disabled="<%= stat <= 1 %>"`.
- `aria-pressed` and other non-boolean attributes can't be computed. Use radio inputs bound with `checked=` instead (see the Action/Defense switch on the roll page).

**Stimulus ↔ state**:
```js
import { useState } from "reactionview"
connect() { useState(this) }          // attach to the states around this element
this.state.get("stat")                 // read
this.state.set({ outcome: "messy" })   // write (updates every template part that reads it)
// optional: <name>Changed(value) callbacks, this.state.on("name", fn)
```
Pattern used here: **the template owns the inputs and the result text; Stimulus owns randomness and any DOM the template doesn't render** (the dice tray).

**Known gotchas**
- **Don't use `stylesheet_link_tag :app` or `:all`.** Herb compiles `stylesheet_link_tag` into a static `<link>` built with `stylesheet_path`, so the shorthand becomes a lookup for `app.css` and fails. List each stylesheet by name in the layout. **Adding a new CSS file means adding a new `stylesheet_link_tag` line.**
- Other tag helpers may get the same static compilation. If a helper does something unusual with its arguments, check the compiled output (the error page shows it).
- **`link_to` with an interpolated attribute value that contains a space comes out broken**: `"aria-label": "Account: #{name}"` (or `aria: { label: … }`) renders as `aria-label="Account:" gwen=""`. Write that `<a>` by hand (see `layouts/_app_header`); the linter's "prefer link_to" info is wrong there. `button_to` isn't affected.
- **Keep `locals:` defaults `nil`.** Herb prints non-nil defaults from a `<%# locals: (…) %>` line into the output (`size: 44, kind: "d6"` puts "d644" before the markup). Default to `nil` and fill in below (`<% size ||= 44 %>`); `test/helpers/shared_components_test.rb` checks the shared partials print nothing extra.
- Avoid `<%#=` commented-out output tags; the linter flags them.
- **`tag.details`/`tag.section` drop a `**splat` inside `data:`** (Herb compiles them statically): `data: { section: "kept", **more }` loses everything in `more`. Spell the hash out, or write the tag by hand (see `campaigns/_kept_crucibles`).
- **`turbo_frame_tag` with a record breaks**: `turbo_frame_tag campaign, :roll_call, src: nil` comes out as `id="campaign_1" src=""` (no prefix, and an empty `src` that makes Turbo load the page itself). A literal string id is fine; otherwise write `<turbo-frame>` by hand (see `roll_calls/_frame`).

## Grimwild glossary (domain definitions)

**Core roll**
- **Stats**: four, each 1–3 to start (every stat starts at 1, plus 4 more points to assign). **Brawn** (power, menace, toughness), **Agility** (precision, athleticism, reflexes), **Wits** (smarts, trickery, reading situations), **Presence** (influence, willpower, reading people). Brawn and Agility are physical; Wits and Presence are mental. (pg. 22)
- **Action roll**: roll d6s equal to the stat, plus extra dice from spark, assists and talents. **The highest d6 is the result.** (pg. 10, 17)
  - **Perfect** (6): success, and you avoid trouble.
  - **Messy** (4–5): success, with an impact move.
  - **Grim** (1–3): failure, with an impact move.
  - **Disaster** (a grim that gets cut): failure, with a worse impact move. The player takes spark.
- **Defense roll**: made to avoid danger that *didn't* come from the PC's own action. Perfect = avoid the impact move, messy = reduce it, grim = take it in full, disaster = take a worse one, then take spark. (pg. 15)
- **Thorns (t)**: d8s added for difficulty factors. A 7 or 8 is a **cut**, which lowers the result one step (perfect → messy → grim → disaster). Each cut counts separately. Typical play uses 0–2 thorns; there's no cap. (pg. 11)
- **Critical**: a perfect with **more than one 6**. Thorns can't cut it. Pick one: **Greater effect** (drop 1d from the task pool before rolling it), **Secondary effect** (also gain the effects of another related perfect), **Setup** (a riskless assist on a follow-up roll). If nothing fits, take spark. (pg. 10)
- **Story roll**: tests luck or how true a detail is, from good to bad. Usually 2d. (pg. 16)
- **Montage roll**: summarizes a stretch of activity. (pg. 16)
- **Quarrel**: PC against PC. Each player rolls 2d and the higher die wins. (pg. 23)
- **Vantage**: what's plausible for this character right now, based on their sheet, reasonable inferences and the scene. The vantage scale: **Certain** (no roll needed), **Reasonable** (+0–1t), **Doubtful** (+2t or more), **Impossible** (no roll allowed). (pg. 12–13, 17)
- **Impact move**: a GM action that brings trouble; usually triggered by messy, grim or disaster results. (pg. 100)

**Meta-currencies**
- **Spark**: spend it before any roll for +1d per spark. A character holds at most 2, and it carries over between sessions. Gained from tangles, rolling a disaster, resolving a story arc, quarrels, or an ally changing their bond with you. (pg. 12)
- **Thread**: 2 per session. Spend it to add story details that go beyond set dressing. (pg. 25)
- **Tangle**: a complication the player introduces from their own vantage; they take spark for it. (pg. 25)
- **Suspense**: the GM's currency, used for things like making extra moves or dropping 1d from a pool. The GM gains it by skipping a prompted impact move or making suspense moves, and at the start of each session after the first; spending it prompts an impact move. Some talents give it away (Challenge, Provoke, Wordplay). (pg. 96)

**Play structure**
- **Session**: one sitting. Before every session after the first, each player takes spark, resets thread and per-session talents, and shares their PC's best moment from last time; the GM takes suspense and recaps ("Previously on…"). After each session, everyone takes 1 XP, or 2 for a standout session (about 1 in 4). (pg. 31)
- **Scene**: one stretch of action. It opens in the middle of things (with a story roll if the setup is unclear) and closes with a montage once it has served its purpose. Short-term conditions can wear off after a scene, and some talents work "for a scene" or reset each scene. (pg. 29, 95)
- **Rest**: a significant stretch of time; clears all marks and harm. (pg. 30)
- **Downtime**: PCs fully heal, including relevant conditions, and reset per-session talents; the GM rolls faction (campaign) pools. (pg. 30)

**Damage** (pg. 27–30)
- **Mark**: a light hit to one stat. +1t on the next roll with that stat, then the mark clears. A second mark on an already-marked stat becomes harm instead.
- **Harm**: **Bloodied** (physical; +1t to Brawn and Agility), **Rattled** (mental; +1t to Wits and Presence), **Desperate** (+1t to everything; comes from a second bloodied or rattled). Harm while desperate leaves you **dropped**: out of the scene, and you make a story roll to see how bad it is.
- **Vex**: a fear response: fight, flight, freeze or freakout.
- **Conditions**: urgent, short-term, long-term or permanent. Often a timer pool, e.g. `4d poisoned`. +1t when relevant.
- A significant rest clears all marks and harm.

**Diminishing pools** (pg. 18–19)
- A pool is a set of d6s that tracks progress. Roll it when triggered and **drop every die that shows 1–3**. When it reaches **0d**, the event happens.
- Notation: size first, in italics, e.g. *4d* Barroom Brawl. Usual sizes are 2d (short), 4d (medium), 8d (long). On average, 2d clears in about 2.7 rolls, 4d in about 3.5 and 8d in about 4.4. Pools bigger than 8d barely change that.
- Types:
  - **Task**: effort toward a goal, or defeating an enemy.
  - **Pressure**: an approaching threat.
  - **Timer**: background events.
  - **Resource**: a supply; you must be able to roll it to use it.
  - **Power**: rolled *as* an action roll. Its highest die is the result, then 1–3s drop as usual. Spark dice are tracked separately.
  - **Linked**: phases; e.g. 4d+4d works like a 51d pool, about 7 rolls.
  - **Campaign**: long-term, rolled during downtime.
- If a task pool drops nothing, you can **push** (take a mark and drop 1d anyway) or **pivot** (take a secondary effect instead).
- *Tick pools* (optional rule): drop exactly 1d each time and are never rolled. (pg. 177)

**Other terms**
- **Crucible**: a 6×6 random table. Roll 2d6 for the row and column; many tools say "roll 2 on each table and smash them together." Examples: character, NPC, heritage, arcana, GM, wild surge, building (pg. 135), exploration, settlement and site (pg. 138).
- **Bonds**: an intensity plus a nature describing how one PC sees another, e.g. "tense rivalry." (pg. 22)
- **Traits / Desires**: pick 2 that fit the character and 1 that doesn't. (pg. 20)
- **Wises**: areas of knowledge or expertise that expand vantage. (pg. 20)
- **Story arcs**: a group arc plus a character arc. Resolving one gives spark. (pg. 26)
- **Paths**: the character classes, e.g. Fighter, Rogue, Wizard, Druid. Each has a core talent and path talents.
- **Enemy tiers**: tough (standard) → elite → boss; mooks are minor foes. Higher tiers get larger task pools to defeat. (pg. 109)

## Dice implementation

The rules live in two places, and both are kept **pure** (no DOM, no database) with the randomness passed in so tests are deterministic:
- `app/javascript/grimwild/dice.js` for the anonymous `/roll` page, which never touches the server.
- `app/models/grimwild/dice.rb` (`Grimwild::Dice.roll` / `.interpret`) for rolls the server makes. Character rolls are server-rolled so the shared log can be trusted; `Pool#roll!` rolls its own d6s.
- Both are tested against the same cases in `test/dice_examples.json`. **Change a rule in both files and add the case to the JSON.**

In JavaScript:
- `interpretRoll(dice, thorns)` returns `{ result, critical, highest, cuts, appliedCuts, base }`.
- Extra cuts past disaster have no effect (`appliedCuts` ≤ `cuts`). A critical ignores every cut.
- `rollPool(size)` returns `{ dice, dropped, remaining }`.
- Where you can, use the worked examples in the book as test cases (e.g. pg. 122: `[2,6]` vs a 7 thorn gives messy; `[3,4,2]` vs thorns `7,8` gives disaster).

## Table rolls & the log

- **Roll** is one entry in a campaign's log: an `action` or `defense` roll from a character sheet, a `story` roll, a `quarrel`, a `montage`, or a `pool` roll, drop-first or push.
- **Power pools** (pg. 19): `Pool#roll!(as_action: true, thorns:, character:, spend_spark:)` rolls the pool as an action roll in place of a stat. The highest die is the `outcome`, then 1–3s drop. Spark dice count toward the result but never drop or join the pool, and they're stored after the pool's own dice in the Roll's `dice` (the last `spark_spent` of them). A disaster gives the character spark. A plain roll is the use that isn't risky: it works, and dice still drop. Names are copied in when the roll is made, so the log survives renames and deletes. Rolls on hidden pools are `gm_only`.
- `Character#roll!(stat, by:, mode:, spend_spark:, help:, assists:, thorns:)` (in `Character::Rolling`) does everything in one transaction: it spends spark (+1d each), rolls 1d for each assisting character (pg. 13; stored in `assists` and counted via `Roll#all_dice`, so an assist can set the result or make a critical), adds damage thorns, clears the stat's mark, gives spark on a disaster (capped at `Grimwild::MAX_SPARK`), and records the Roll. Unseated characters' rolls are kept but have no campaign, so they aren't logged.
- Rolls happen on the sheet. Each stat card's Roll button is a `<details class="stat-roll" name="stat-roll">` (one open at a time; the open card spans the stat grid's row) holding the setup form (`characters/_roll_form`). It posts to `characters/:id/rolls#create`, which redirects back to the sheet; the morph refresh closes the setup and shows the result as the roll toast (see *Roll toast* under Characters). There are no separate setup or result pages any more.
- A critical where no effect fits gives spark (`Character#take_spark_for_critical!`, from a button on the sheet's roll toast): owner only, once, on the character's latest roll, below 2 spark. It sets `spark_gained` on the Roll, which then reads "Critical: nothing fit…" instead of "Disaster…".
- Updating a Roll replaces its log entry live, the same way new rolls are prepended.
- **Story rolls** (`Roll.story!`, in `Roll::Story`; pg. 16) come from the Rolls fold: 1d/2d/3d for bad/even/good odds, rare thorns, and a `question`. For a character it's a roll call (below): a player can call one for their own characters, the GM for anyone's; spark can go in, and a disaster gives spark. For no one in particular it's rolled straight away. A scene's opening story roll is still rolled straight away. `stat_dice` holds the odds.
- **Quarrels** (`Roll.quarrel!`, in `Roll::Quarrel`; pg. 23) are called from the Rolls fold or their own page. Each side rolls 2d plus any spark, and each assist rolls its own 1d (pg. 13). The highest die wins, and a tie has no `winner`. Everyone involved takes spark. Sides go in the `sides` JSON and the stakes in `question`. Any member can call a quarrel.
- **Montages** (`Roll.montage!`, in `Roll::Montage`; pg. 16) are called from the Rolls fold or their own page. Each seated character taking part rolls 2d plus any spark, with no thorns, since the book gives montages none. The best single result is the scene's `outcome`, and each character's own result goes in `sides`, so the table can see what to zoom in on. The scene goes in `question`.
- **Roll calls** (`RollCall`, table `roll_calls`): a story roll for a character, a montage or a quarrel waits for its players to roll their own dice. Whoever calls it picks who's in it (`RollCall.story!/montage!/quarrel!`); each `seats` entry (character, player, `lead_id` for a quarrel assist, `dice`, `thorns`, `spark`, `rolled_by`) fills in as that player rolls (`#roll!`, which spends their spark then and there). The GM can roll for anyone waiting, one at a time or `#roll_everyone!`, but never spends a player's spark; the caller or the GM can call it off (`#cancel!`, which gives spent spark back). When the last seat rolls, the call builds the usual Roll from those dice (`Roll.story!(rolled:)`, and `dice:`/`helper_dice:` on montage participants and quarrel sides) and is `done`; the log credits the caller. One open call per campaign (a check plus a partial unique index).
  - It shows as a modal (`roll_calls/_call`, `roll_call_controller.js`, a `<dialog>`) on every campaign page, to everyone in it, the GM and the caller (`RollCall.showing_for`), and the result stays up for `RESULT_SHOWS_FOR` (2 minutes) until closed. Hiding a waiting call leaves a pill in the bottom-left; hidden keys are remembered per tab (sessionStorage). Results from a call don't also show the roll toast.
  - Live: the layout renders `roll_calls/_frame` (`<turbo-frame id="roll_call_campaign_N">`) inside a `data-turbo-permanent` slot (`Campaign#roll_call_slot_id`), so morphs leave the modal alone. Each change broadcasts an **update** of the slot with an empty, non-permanent frame carrying a versioned `src` over `[campaign, :live]` (Turbo swaps any permanent element inside a stream back for the one on the page, so replacing a permanent frame does nothing), so every viewer loads their own copy from `campaign_roll_call_path` (each person's buttons differ, and broadcasts can't use `Current`). Rolling and cancelling are forms inside the frame that redirect back to it; errors render in it with 422. A finished call also refreshes `[campaign, :roll_calls]`, which the end-scene form follows so it can offer the montage.
- `Character#settle_spark(spent:, take:)` is the one place spark is spent before a roll and taken after it, capped at 2. It doesn't save.
- Live updates: `Roll` appends `rolls/_feed_item` to `#table_feed` (the table rail, see *Table chat*) over `[campaign, :rolls]`, or over `[campaign, :gm_rolls]` for GM-only rolls; an update replaces it. Load a member's log with `campaign.rolls.table_log(membership)`. `rolls/_feed_item` renders in a job, so it must not use `Current`. The session pages still list rolls with the fuller `rolls/_roll`.
- In tests, `assert_no_turbo_stream_broadcasts` counts every broadcast so far in the test, not just the ones inside its block. `FixedDice` (test/test_helpers) stands in for `Random`.

## Table chat (night-table phase 5)

- **One stream in the rail.** `Message` (chat) and `Roll` (the log) stay separate models; `TableFeed` merges what a member may see (messages and rolls through their `visible_to`) into one stream, a page of `TableFeed::PAGE` (50) lines at a time, newest first, shown oldest first, and lists the streams to follow. **Scrolling back**: `feed_controller.js` watches the `.feed__older` marker at the top; when it comes into view it loads the page before the oldest line (`GET campaigns/:id/feed?before=…`, `Campaigns::FeedsController`, `campaigns/_feed_page`) and puts it above, marking those lines seen so they don't count as new, until there's nothing earlier ("That's the start of the table."). A morph refresh renders the first page again. The chat area is at most 80% of the window (and so is the pinned rail on wide screens). `campaigns/_table_rail` (locals `campaign:, membership:, feed:, speakers:, speaker:, suspense:, quick_roll:, classes:`) is the rail on the GM table, a seated character's sheet (with read-only suspense) and, for players, the campaign page. Its list is `#table_feed`; a `column-reverse` scroller keeps the newest at the bottom. `feed_controller.js` keeps your place: near the newest line (48px), new lines scroll into view; scrolled up, it holds what you're reading and shows a "3 new" pill (`.feed__new`) that jumps back down, counting only lines the filter shows and not replaced ones (an updated roll); your own lines and rolls (`data-identity`, on chat lines and roll lines) always bring you to the latest.
- **Kinds** (`messages.kind`): `narration` and `npc` (with `speaker_name`) are the GM's; `in_character` needs `character`, the sender's active character seated here (the GM may use any); `table_talk` is anyone, with no character; `whisper` is a player to the GM. The model enforces all of it (`sender_may_speak_this_way`), and the composer sends `speak_as` (`narration`, `npc`, `table_talk`, `whisper`, `character:<id>`). Old rows were backfilled as `in_character` where they had a character, `table_talk` otherwise.
- **Whispers: only the sender and the GM, ever.** They're never broadcast on `[campaign, :chat]` or `:table`: they go to `[campaign, :gm]` and to the sender's `[membership, :chat]`, and `Message.visible_to(membership)` filters them out of every player-facing query (as hidden pools are). `Message.streams_for` gives each member their streams.
- **Look**, in `messages/_message` (rendered once, in broadcasts, so viewer-agnostic: no `Current`): scene divider (a scene-start marker), narration ("GM · Cut to", Spectral italic), NPC (purple name, "voiced by GM"), in character, table talk, whisper (dashed purple, lock, "only you and the GM"); `rolls/_feed_item`: character rolls as small `shared/_roll_result` cards, pool rolls as one line ("5d → 3d"), markers and notes as centered game events. `feed_controller.js` does the per-viewer part: your own lines on the right (`chat-line--mine`).
- **Deleting a line**: the GM only (`Campaigns::MessagesController#destroy`). Every `messages/_message` carries a delete button (it renders once, for everyone), shown only inside `.table-rail--gm` (not once the campaign is done); removal is broadcast to the same streams the line went to.
- **Filters** (Everything / Story / Dice) are `shared/_segmented` radios and CSS `:has()`: Story keeps messages, Dice keeps rolls and pool changes. It's browser state with no reload, and it applies to lines that arrive live, which herb:state couldn't (broadcast lines aren't template-rendered).
- **Composer**: speak-as (players: As <character> for each active character, Table talk, To GM; the GM: Narrate, As NPC with a name field, Table talk) in a grid (`composer__voices--N`: one row of up to three, two by two for four, three across for more; long names are cut with an ellipsis), a quick-roll link (`quick_roll:`), the text box (Spectral italic in character and when narrating) and Send. Enter sends, Shift+Enter is a new line (`chat_form_controller.js`); a Turbo submit gets `204` and the line arrives over the stream. "Log a game event" folds the old note box (`Roll.note!`) under it.
- **Presence halos**: the faces atop the rail (`.avatars`, each `data-presence-identity`) are haloed green while they have a campaign page open and in use, yellow while it's open but idle (no input for 2 minutes, or a hidden tab), and none when no page is open. `presence_controller.js` (on the rail) subscribes to `PresenceChannel` and checks in every `Membership::PRESENCE_BEAT` (30s), and right away when an idle page is used again; the channel stores `memberships.seen_at`/`active_at` (`Membership#check_in!`, `#presence`), sends a snapshot on subscribe and broadcasts each check-in to the campaign. Pages drop a halo after `PRESENCE_WINDOW` (75s) without word, so a closed tab needs no announcement and a second tab still counts. `ApplicationCable::Connection` knows the identity from the session cookie; anyone may still connect, since Turbo Streams guard themselves with signed names.
- Times are `<time datetime>` shown in the viewer's zone by `local_time_controller.js` (re-run after a morph); the server fallback is UTC.

## The GM table (campaigns/tables#show)

Night-table phase 3. **`/campaigns/:id/table`** (`Campaigns::TablesController`, `require_gm`) is the GM table, built from `CampaignTable#load_table` like the old page: a scene bar ("Session 8 · live 1h 12m · Scene 2 of 2", the scene title, then its actions in order: suspense (`campaigns/tables/_suspense_panel`: a purple `shared/_tally`, "− 4 suspense left +", no track; − spends, which prompts an impact move), Start scene/Cut to new scene, Start/End session, and a "Respite" fold-out, spaced evenly across the bar, titled "How long a break?", with Rest and Downtime); the party: party cards (`harm_line`, spark and thread, talent uses and talent pools; a member without a character gets a dashed card); pools as cards (`campaigns/pools/_card`); the Rolls fold (`campaigns/_rolls`: a `shared/_segmented` picks Story / Montage / Quarrel and CSS `:has()` shows that form; Montage and Quarrel are greyed out, saying why, until the party has one or two characters; the montage and quarrel forms are `campaigns/montages/_form` and `campaigns/quarrels/_form`, shared with their own pages, which still take error re-renders and the scene-end montage); the crucible fold;  and the table rail (see *Table chat*) with the Kept crucibles card under it (`campaigns/_kept_crucibles`, as on the campaign page), in `.gm-view__side`: the chat at a set height, the card at full length below it, and the page scrolls (that column doesn't stick).
- Floating menus here (a pool card's ⋯, "+ New pool") use `menu_controller.js`: opening places the panel on screen (upward when there's no room below, nudged in from the sides, scrolling if it fits neither way), and a form in it that saves closes it, so details-memory doesn't reopen it after the refresh; one that fails stays open.
- Pool cards: the dice count, a track (`shared/_pool_track`) or the last roll's dice when rolled this scene (`pool_card_shows_last_roll?`, "6d → 4d · 2 minutes ago"), a ⋯ menu (drop-first, push, reset, hide, delete, the power-pool action roll) and "Roll Nd". Hidden pools are dashed purple with an eye-off icon, a purple Roll and **Reveal** (PATCH `hidden: false`). An empty resource pool dims, says "All gone." and offers **Restock to Nd** (the reset).
- "Cut to new scene" opens the end-scene form with `then=new_scene`; ending it then redirects to the new-scene form.
- Redirects: campaign controllers send people back with `back_to_table` (`CampaignScoped#table_path_for_viewer`): the GM to the GM table, a player to `campaign_path`. `/pools` and `campaign_play_path` follow the same rule. A pool that fails to save renders `campaigns/tables/show`.
- Shared with the campaign page: `details_memory_controller.js` remembers each `<details>` section's open/closed state per browser in localStorage (keyed by campaign and section), and restores it after a Turbo morph, because a pool refresh re-renders the page with the server's defaults. The new-pool form (`campaigns/pools/_form`) keeps its own herb:state. **Crucibles** are a fold like Rolls (`details#crucibles`, its open state kept by details-memory as `crucible`). They load in a lazy `turbo_frame_tag "crucible"` from `crucible_path(key, embed: 1)` (`crucibles/_roller`, `crucible_controller.js`), so a closed fold fetches nothing; `crucible_picker_controller.js` swaps the frame's `src` and keeps three "Recent" chips; the fold is `data-turbo-permanent`, so morphs don't wipe a roll.
- Turbo drops a redirect's `#fragment` after a form post, so pool actions land at the top of the page rather than on the card.

## The campaign page (campaigns#show)

Night-table phase 4. The series overview, for the GM and players alike (`CampaignsController#show`: `load_table` plus `load_overview`):
- **Hero**: "Campaign · You're the GM" / "Playing Tibbs", the name, the one-line `pitch` in Spectral italic, and four facts: `party_is` (two concepts, JSON), `party_never`, `group_arc`, `setting` (columns on `campaigns`, set by the GM in settings; a GM with none gets a prompt). Above the party, a row of actions spread across (`.campaign-actions__row`), ending with a "Campaign settings" button for everyone: the GM's "Open the GM table", "Copy invite link" (`campaigns/_copy_join_button`) and "Reset link"; a player's "Open my character" (`Membership#seated_character`; with more than one active character seated there, a `details.go-menu` button listing each, and the eyebrow says "Playing Tibbs and Moss") or "Make your character".
- **The party**: a card per active character (monogram, short name, path and level, player, spark pips, four stat tiles with a marked stat red and ✕, the harm line); a member with no active character gets a dashed "joined · still making a character" card. Characters have a **`status`** (`active`, `fallen`, `retired`; the owner sets it on the edit form), and fallen and retired ones are one line under the grid. `seated_character` only counts active ones.
- **Previously on…**: the last ended session (date, scenes and roll counts, recap, each scene with `scene_outcome`: how it closed, a quarrel, a pool running out, or its opening story roll) Then the two before it and "All N sessions". Sessions have no names, so they're headed "Session N".
- **Side column**: "What looms": the GM sees visible shared pools as tracks plus "N hidden pools, only you see it"; players get the pool rows (`campaigns/pools/_pool`, with drop-first, push and the power-pool action roll) and the Rolls fold. Then "At the table" (members with their character, "GM" or "making one"), "Kept crucibles" (`campaigns/_kept_crucibles`, also on the GM table; `kept_crucibles_controller.js` reads the per-crucible lists `crucible_controller.js` keeps in this browser's localStorage and shows them under each crucible's name in the crucibles' grouped order; it refreshes on `crucible:kept`, is permanent so morphs don't hide it, hides when there are none, and Clear empties them all after the confirm dialog). The compact roller (`crucibles/_roller`) has no kept list of its own; the full crucible page still does, and for players the table rail (see *Table chat*).
- **Settings** are `campaigns#edit` (`edit_campaign_path`): the GM's pitch form (name, pitch, the party is/never, group arc with the book's arcs as suggestions, setting), the invite link, members (remove, or leave for a player) and delete. Removing someone returns there.

## Sessions & scenes

Built in steps from a design brief: (1) sessions, (2) scenes, (3) talent uses, (4) history, (5) rest and downtime.

- **`PlaySession`** (table `play_sessions`; `Session` is sign-in). `number` per campaign, `started_at`/`ended_at`, `recap` ("Previously on…", not on session 1), `notes` (from the end form), `standout`. A campaign has at most one open session (validation plus a partial unique index); `Campaign#current_session`.
- **Attendance** is the `play_session_characters` join table (`PlaySession#characters`, `Character#play_sessions`). Only characters marked present get a session's resets and XP.
- **`PlaySession.start!(campaign, characters:, recap:, by:)`** runs `Character#start_session!` for each present character: thread resets to `Character#session_thread` and they take spark, but not before session 1. The campaign takes 1 suspense (also not before session 1). **`PlaySession#end!(by:, standout:, notes:)`** gives each present character `gain_xp!`, twice if standout, and returns those who levelled up.
- **Markers**: boundaries post a `marker` kind of `Roll` ("Session 4 begins", recap in `question`, level-ups in `sides` with links to choose a talent). They broadcast like rolls, and `Campaign#broadcast_table_refresh` refreshes every table over `[campaign, :table]`.
- **Stamping**: every Roll gets `play_session` (and `scene`, while one is open) from the campaign when created. Rolls made outside a session have neither, and show between sessions in the history.
- **`Scene`**: `number` per session, `title`, `notes`, optional `opening_roll` (a story roll) and `closing_roll` (a montage from the scene). One open scene per session; `Campaign#current_scene`, `PlaySession#current_scene`. **`Scene.start!(session, title:, by:, opening:)`** takes `Roll.story!` arguments for the opening (the `StoryRollParams` controller concern builds them from the story form). **`Scene#end!(by:, clear:, notes:, closing_roll:)`** clears the picked "clears after scene" conditions (`clear` is `"character_id:index"` strings; the end form ticks them all by default). `PlaySession#end!` ends an open scene first, with the same `clear:`.
- **Conditions** are `{ "name", "lasts" }`, where `lasts` is `"scene"` or nil (`Character::Damage::CONDITION_LASTS`); `conditions=` accepts plain strings too. `Character#scene_conditions` gives `[index, condition]` pairs.
- **Notes**: a `note` kind of Roll (`Roll.note!(campaign:, by:, text:, character:)`) is one short line in the log, with no dice. Anyone at the table can add one from under the log.
- Calling a montage with `then=end_scene` returns to the end-scene form, which offers it as the closing roll once everyone has rolled (the page refreshes when the call finishes).
- **Talent uses**: talents in `config/talents.yml` can list `uses:`. Each is a `Talent::Use` (`Talent#uses`) of one of three kinds: a count (`count`, shown as tick boxes), a talent pool (`pool`, `pool_kind`), or extra thread per session (`thread`). Each has a `per` of `session` or `scene`, and `growth` (`{ level => more }`; `count_at(level)`, `pool_at(level)`). `Talent::Use#id` is `"talent-key/use-key"`. `test/models/talent_use_test.rb` checks every entry is well formed.
- `Character::TalentUses`: `talent_uses` (JSON, spent counts by use id), `spend_use!`, `talent_thread` (raises `session_thread`, and so thread's cap), and talent pools. A talent pool is a `Pool` with `character_id`, `refresh` and `use_key`, in the character's campaign, named "Ash: Bulwark". `PlaySession.start!` resets every use and refills (or creates and resizes) every talent pool for each present character. `Scene#end!` does the same for the per-scene ones.
- On the sheet, each talent's row (`characters/_talent`) shows its tick boxes (PATCH `characters/:id/talent_uses`, for the owner and the campaign's GM). Ticking can post a note to the log ("Fen spends inspiration"); that choice is remembered per browser. Talent pools show as pool rows under their talent on the sheet (rolling them there returns to the sheet via `return_to=character`, anchored at `#talent-<key>`); before the first session the row shows a chip instead ("Luck · 1d resource pool, resets each session") and under the character on the table, where the GM gets Reset once one is at 0d, in case it was spent by accident. The table's main pool list is `Pool.shared` only.
- **Best moments were removed** (2026-10-22, at Shawn's request): the moments, the start-of-session prompt, the chat's star and the Previously on… pull quote, with their tables (`DropBestMoments`). The book's sharing of a best moment before each session (pg. 31) happens at the table, not in the app.
- **History**: `campaigns/:id/play_sessions` lists sessions (date, recap snippet, scenes, attendance, XP and level-ups from the end marker via `PlaySession#level_ups`) with a **Between sessions** card in each gap: the log made outside any session (rests, downtime, rolls, notes; rolls with no `play_session`), grouped by the session that came after it (headed "Between Sessions 3 and 4", "Before Session 1", and "Since Session 4" at the top, with the entry count beside), oldest first. Every session and every between-sessions stretch is a fold (`<details>` via `tag.details`, since ERB can't sit in a tag's attributes) holding its rolls: the session's grouped by scene, then "Outside scenes". They stack in one column (`.fluid__main`), newest first. Beside them (`.fluid__rail`, below on a phone) is **Recaps**: a fold per session with its recap, notes, scenes/attendance/XP line and a link to its page. The newest of each starts open, and details-memory (on the `.session-history` wrapper) remembers the rest per campaign. `campaigns/:id/play_sessions/:id` shows each scene (opening and closing results, notes, its rolls oldest first), then anything outside scenes, then the recap and notes, then attendance. GM-only rolls stay GM-only. The GM can edit a session's recap and notes and a scene's title and notes there. The session bar links to the history.
- **Rest and downtime** (`Campaign::Breaks`; pg. 30), from the GM's "Between scenes" fold-out in the session bar. Both apply to `Campaign#resting_characters`: those at the current session, or everyone seated between sessions. `Campaign#rest!` clears marks and harm (`Character#rest`). `Campaign#downtime!(clear:)` also clears the conditions the GM leaves ticked on its form (all are ticked, so untick permanent ones), resets per-session talent uses and refills talent pools, and rolls every shared `campaign` pool (`Campaign#downtime_pools`). Each posts one marker. Campaign-level markers come from `Campaign#post_marker!`; `PlaySession#post_marker!` passes itself along.
- Talent effects deliberately not modelled: Mischief Maker's rising story-roll thorns, Augury's omens, Magnum Opus's touchstones, Herbalism's herb names and one-time major potion, Oathsworn's Affirmation, Awakened Mind's instability thorns, Vassal refilling at 0d, and the pools Echo, Soothsayer and Awaken create when used (only the use is counted). Quarry tracks one Quarry pool per session even though two quarries can be designated. Flesh Wounds and similar are just conditions marked "clears after scene".
- **Suspense** is `campaigns.suspense`: the GM's counter first in the scene bar's actions (`require_gm` on changes). Everyone at the table sees it (night-table brief): `campaigns/_suspense_meter` shows it read-only in the sheet's rail, and a change replaces it live over `[campaign, :live]`. It's never logged.
- **Session bar**: under the campaign name in the GM table's header. It shows "Session 4 · started 20 min ago" or "Between sessions"; the GM's actions sit beside it, folded away on phones.
- **Reset** (`Campaign::Reset`, POST `campaigns/:id/reset`, from settings; GM only, not once done): deletes every session (scenes and attendance cascade), the whole roll log and any roll call, so play starts again at Session 1. Open roll calls are called off first, so spark spent into them goes back. Chat, pools, suspense and characters (XP, levels) stay.
- All boundary actions are GM-only (`require_gm`), and their reset logic lives in the models.

## Accounts & campaigns (passwordless)

Modelled on Fizzy (github.com/basecamp/fizzy): no passwords, ever.

- **Identity**: a person, keyed by email (`name` = display name). **Session**: one row per sign-in, found via the signed, http-only `session_token` cookie. `Current.session/identity/campaign/membership` hold request state.
- **MagicLink**: a 6-character base32 code emailed by `MagicLinkMailer` that expires in 15 minutes and is single-use. It is keyed by *email address*, not Identity, so asking for a code never creates an account (with sign-ups closed, an unknown email is told so: see *Sign-ups*); the Identity is found or created when the code is redeemed. The code only works in the browser holding the signed `pending_authentication` cookie. In development the code is also shown on the page. `MagicLink.cleanup` runs hourly (config/recurring.yml).
- **Passkey**: a WebAuthn credential (gem `webauthn` ~> 3.4). Discoverable credentials (`resident_key: required`, `user_verification: required`) allow usernameless sign-in. Challenges are kept in the Rails session between the `.../challenge` POST and the verify POST. `passkey_controller.js` does the base64url conversion by hand and needs no browser JSON helpers. `APP_ORIGIN` must equal the site's origin in production.
- **Campaign** is the tenant. **Membership** (role `gm` | `player`) joins an Identity to a Campaign. Anyone signed in can start a campaign and becomes its GM. Players join via `/join/:code`, a reusable link the GM can reset. A campaign always keeps at least one GM.
- **Tenancy = shared database + `campaign_id`** (decided 2026-10-15; we do *not* use activerecord-tenanted). People belong to many campaigns, and "my campaigns/characters" needs queries across all of them. Campaign-owned controllers `include CampaignScoped`, which loads the campaign *through* `Current.identity.memberships` (non-members get a 404). Use `require_gm` for GM-only actions. New campaign-owned models get `belongs_to :campaign` and are always queried through `Current.campaign`.
- **One active campaign per account** (for now; see *Roadmap* for the plan): `Membership` validates on create that the identity isn't at another active campaign, GM or player (`#other_active_membership`), and that the campaign isn't done. `Membership.one_campaign_limit(membership)` is the one wording, used by that error, the campaigns page (which swaps the start form for it) and the join page.
- **Done campaigns** (`Campaign::Done`, `campaigns.done_at`; scopes `active`/`done`): the GM marks a campaign done or reopens it from settings (`#done`; POST/DELETE `campaigns/:id/done`, `Campaigns::DonesController`). Not while a session is open; open roll calls are cancelled; each posts a marker. Done is a read-only archive: `CampaignScoped#refuse_when_done` turns away every non-GET (controllers that may still act skip it: settings update and delete, memberships, dones), `Roll`, `Message` and `RollCall` refuse to be created there (`Campaign#refuse_new_play`), `Roll.note!` quietly skips it (so a sheet can still change, e.g. moving the character elsewhere, without touching the old log), `Pool#rollable?` is false, and `Character#in_play?` (active, in no done campaign) gates the sheet's rolls, pushes and talent rolls. Character controllers aren't CampaignScoped, so the ones that play (damage, conditions and their rolls, talent uses, pushes, talent rolls) add `ApplicationController#refuse_when_campaign_done`; `push!` refuses in the model too, and claiming or giving a character back is closed (`claimable_by?`/`releasable_by?`). The GM table redirects to the campaign page and drops from the tabs; the rail shows no composer; nobody can join or be seated there. Reopening is refused while anyone there is at another active campaign.
- The play tools stay public. Controllers opt in with `require_authentication`; `require_unauthenticated_access` is for sign-in pages.
- **Sign-ups** (`ALLOW_SIGNUPS`, read into `config.x.signups_open` in `config/application.rb`; on unless set to false; `Identity.signups_open?`). Closed, `Identity.may_sign_in?` lets an email in only if it already has an account or the browser opened a campaign's invite link (`JoinsController#show` sets `session[:invite_code]`; `PendingAuthentication#invited?` checks the link still works, so resetting it takes that back). An unknown email gets no code and goes back to sign-in with "We're not taking new sign-ups right now…" (this does reveal which emails have accounts; for an invite-only beta, being clear won), and a code sent before sign-ups closed won't make an account after. Tests flip `Rails.configuration.x.signups_open` and restore it in teardown.
- **The public nav** (`TOOLKIT_NAV`: header tabs outside a campaign, and the footer) is Roll, Crucibles and Talents. Characters and pools need an account (`require_authentication`), so the home page offers them as cards only when signed in; signed out, its "Start a campaign and build characters" button leads to sign-in. Signed in, the header's tabs (toolkit or campaign) end with **Characters** (`characters_tab`), your own characters list; the footer doesn't list it.
- Tests: `sign_in_as(identity)` in integration tests goes through the real code flow. Passkey tests use `WebAuthn::FakeClient.new("http://www.example.com")`.

## Admin (built 2026-10-24)

- `identities.admin` (boolean, default false) marks an admin. It's never set from a form: use the console, `Identity.find_by!(email_address: "…").update!(admin: true)` (`bin/kamal console` in production).
- `/admin` (`Admin::BaseController`: `require_authentication`, then a 404 for anyone not an admin, as at a campaign you aren't in): **Stats** (counts, this week's rolls and messages, who signed in this week and last), **Accounts** (every identity with last sign-in, passkeys and campaigns; "Create new account" makes one by email, which then signs in with a code even with sign-ups closed) and **Campaigns** (read-only: GMs, players, characters, sessions, last roll, done). Admins get no way into campaigns they aren't in.
- Last sign-in is `identities.last_signed_in_at`, stamped by `start_new_session_for` (code or passkey). Don't read it from `sessions`: signing out deletes the row.
- The header ends with an Admin tab for admins (`admin_tab`), in both navs.

## Pools (built 2026-10-15)

- `Pool` belongs to a campaign: `kind` (task/pressure/timer/resource/power/campaign), `starting_size` 1–20, `size` (0 = it happens), `hidden` (GM only), and the last roll (`last_dice` json, `last_dropped`, `last_action` rolled | rolled_after_drop | pushed, `last_rolled_by`).
- Rolls happen **on the server** (`Pool#roll!`), so the table shares one truth. `Pool#roll!` mirrors `rollPool` in dice.js; tests pass a fake `random:`.
- Routes: `/campaigns/:id/pools` plus nested `roll`, `push` and `reset` resources. `/pools` redirects to the latest campaign's pools.
- Permissions: members roll and push the pools they can see; the GM adds, resets, hides and deletes (`require_gm`). Players get a 404 for hidden pools.
- **Dropping 1d before rolling** (`Pool#drops_first_for?(gm:)`, checked in the views and `Pools::RollsController`): anyone on a task pool (a critical's Greater effect, pg. 10), the GM on any shared pool (suspense), and a talent pool only when its use has `drop_first: true` in `config/talents.yml` (rites' potent spells, Wild Shape's wild talents, Alchemist's minor potions). On a power pool that allows it, the action-roll form has a "drop 1d first" box. A power talent pool marked `bonus_dice: true` (Luck, Quarry, Competence: extra dice for another roll) never rolls as an action (`Pool#rolls_as_action?`), and a pool row only gets its ⋯ when something in it applies, so most talent pools show just Roll.
- Live updates: `broadcasts_refreshes_to [campaign, :pools]` + `turbo_stream_from` + morph refreshes. Each viewer refetches with their own permissions, so hidden pools never leak.
- ReActionView: per-row `herb:state (drop_first: false)` under `herb:key pool.id`, and `new_size` bound to the size presets and the number input.
- Linter gotcha: inside a keyed loop, Herb treats the loop variable as row state, so `pool.size != pool.starting_size` fails `herb-state-valid-reads`. Move comparisons like that into model methods (`Pool#resettable?`).
- Not yet: linked pools (phases), tick pools, power-pool action results.

## Crucibles (built 2026-10-15)

- Data lives in `config/crucibles.yml`, not the DB. `Crucible` is a plain Ruby class (YAML is reloaded every request outside production), and each table is a `Crucible::Table` Data object.
- There are 13 crucibles and 32 tables: GM, settlements, sites, dangers, curiosities, barriers, factions, buildings, heritage, expanded wises (column headers), distinctive features, arcana (5 themes), and wild surge.
- The YAML was extracted from the PDF's text layer. Multi-word cells ("fortune teller", "over the hill", "laws of the land") were split by hand. When adding tables, check the cell boundaries against the PDF; `test/models/crucible_test.rb` enforces 6x6 tables with no blank cells.
- Rolling is client-side and public (`crucible_controller.js`, using `rollDie` from dice.js). Each 2d6 roll highlights both readings, row/column and switched (pg. 6). Tapping a chip chooses a word, "Keep" saves the combination to localStorage per crucible, and `herb:state show_tables` toggles the grids.
- Not yet: the path-specific crucibles (spell, patron, vassal, swashbuckler names, herbalism, eldritch mutations) and the seasons/months tables (their columns came out garbled in the text layer).

## Characters (built 2026-10-15)

- `Character` belongs to an identity (its owner) and can optionally be seated in one of that owner's campaigns. Owners edit; members of the seated campaign can read the sheet; everyone else gets a 404 (`Character.visible_to`).
- Book reference lists (paths with core talents, the 18 backgrounds with their wises, traits, desires, weapon styles, bond words, arcs) live in `config/grimwild.yml` and are read through the `Grimwild` module.
- Stats are 1–3 each and must total 8 on create. Detail lists (backgrounds, traits, features, bonds…) are json columns; the model setters clean and cap them, and accept Rails' `{"0"=>…}` nested form hashes.
- **Bonds** (pg. 22, 46): one toward each other PC. A seated character's form has a row for each other active character at the table (`Character#bond_party`: anyone's, even the same player's), labelled "played by …". Under it, "NPCs and others": name-and-bond rows (`characters/_bond_row`) for NPCs and anyone not at the table, one blank to start and "Add an NPC" for more (`bonds_controller.js` copies a `<template>` row, numbered past the others); an unseated character has only these. Bonds to party members store `character_id` (a blank one is dropped), and `bonds=` keeps one per character or name. `bond_for` also matches bonds written by name before ids; the sheet lists the whole party by current name, "not set yet" where there's none. Not modelled: the other PC taking spark when a bond changes.
- `Character::Damage`: marks per stat, bloodied/rattled/desperate, conditions, and `damage_thorns(stat)`. `roll!(stat)` clears that stat's mark. `Character::Advancement`: XP fills level+1 boxes, then levels up (max 7).
- **Seating** (`Character::Seating`): the owner seats a character in one of their campaigns, moves it, or takes it away (`seat!(campaign, by:)`, PATCH `characters/:id/seat` with `campaign_id`, blank for none) from the Characters list or the edit page's "At the table" (`characters/_seat_form`, plus a "Take … out of …" button). Each table it leaves or joins gets a note and a refresh. Talent pools follow it to the new campaign, or are deleted when it leaves every table (an `after_update`, so any update that changes `campaign_id` does the same (only a new character's form has a Campaign select now)). Up-for-grabs characters can't be moved this way.
- **Fallen and retired** (`Character::Farewell`): the owner ends a character's story from the edit page (`#story-ends`, "Their story ends…"; a desperate character's Harm card links there for the owner, quietly: desperate isn't death: Mark fallen or Retire, with an optional `farewell` line, max 200; POST `characters/:id/story_end`), or brings them back from the sheet's banner (DELETE). `status_changed_at` is stamped on any status change, and the farewell clears on return. Each posts a note ("Tibbs has fallen. “…”") and refreshes the table. Not while up for grabs. A gone character is out of the party: query it with `campaign.characters.played.active` (group rolls, assists, attendance, rests and downtime, the GM table). They can't roll, push, roll a condition or their talent pools (`Pool#held_by_gone_character?`), and the sheet hides those buttons. Every status change, a `character[status]` PATCH included, is refused while up for grabs and logs its note in the same save (an `after_update`); a gone character can't be put up for grabs. They're remembered as `characters/_farewell_card`s: under the party on the campaign page (`#fallen-and-retired`, newest first) and in their own section on the Characters page; the edit form keeps the farewell field for changing their words, and the edit page offers Return to play.
- **Up for grabs** (`Character::Claiming`, `characters.up_for_grabs`): the GM makes a character for the table (the form's "Up for grabs" box, or the "Create new character" card at the end of the campaign page's party) or puts any character in the campaign up for grabs (party card, the sheet's strip for someone else's, or the edit page's "At the table" for their own; DELETE `characters/:id/claim`). A GM holds it as owner until anyone at the table picks it (POST `characters/:id/claim`, `with_lock` so only one wins) and becomes its owner; a player can give theirs back from the sheet's Adjust menu, to the campaign's first GM. Each change posts a note and refreshes the table. Up-for-grabs characters aren't in the party: query the party with `campaign.characters.played` (attendance, rests and downtime, story rolls, montages, quarrels, assists, speak-as, `seated_character`). A GM leaving passes theirs to another GM; deleting the campaign leaves them with their GM, no longer offered.
- **Roll from the sheet:** see *Table rolls & the log*. The setup folds open on the stat card and the result shows in a toast.
- **The character view** (`characters#show`, `.fluid.play-view`; night-table phase 2): an identity band (monogram from `Character#short_name`, spark/thread pips and XP; the owner instead gets a row of `shared/_tally`s spread across the band, "− 1 of 2 spark +", thread and XP (+ goes through `gain_xp!`), and an Edit sheet button), the four stat cards and Harm (`.sheet__top`), then Talents (the owner's "Edit talents" top right; `.talent-list`: each talent a box with its own uses and pools, wrapping, all the same height when there are columns; one with its full text open spans the row), then "Who … is" (backgrounds, wises, traits, desires, carrying, bonds and arcs; each a `.facts__list`, title-cased, with "But not …" last for traits and desires), then notes. `.sheet` is a size container: at 40rem and up the stats go two by two with Harm beside them, as tall as the stats until a roll setup opens, and the facts spread into columns; narrower, everything stacks. A seated character gets the table rail (`campaigns/_table_rail`, with read-only suspense; see *Table chat*), which drops below the sheet on a phone. An unseated character gets `.play-view--solo` and no rail. Other viewers see the same page with every control hidden.
- **Stat cards**: the owner's Roll button is a `<details class="stat-roll">` (`characters/_roll_form`); the open card spans two columns with an ember ring, the Roll button hides, and the setup's ✕ in the card's top right corner closes it. Its steppers show totals: `dice` (the stat's own plus extras, min = the stat) and `total_thorns` (damage thorns plus situational, min = damage). `Characters::RollsController` takes the difference as `help` and situational `thorns`, only after checking the stat name, because `Character#stat` is a `public_send`. `help`/`thorns` still work as before. Roll and Defense are two submit buttons (`name="mode"`); `stat_roll_controller.js` keeps the "Roll 3d + 1t" label current with spark and assists.
- **Marks** are on the stat cards: the name on top, then a Mark / Marked toggle on the left and the dice on the right (dashed and dim until it's on, then red) for the owner and the GM (PATCH `characters/:id/damage`), a red Marked tag for everyone else.
- **Harm card**: Bloodied, Rattled and Desperate toggles (Desperate isn't in the mockup but is a rule), conditions, and adding one (`[4]d [poisoned] [ ] Clears after scene`: the dice count is optional, and `add_condition!(dice:)` prefixes it unless the name is already a pool). A condition written as a pool (`"4d poisoned"`, `Character::Damage::CONDITION_POOL`) shows its size and a Roll button: `Character#roll_condition!` (POST `characters/:id/conditions/:index/roll`) rolls it like a pool, drops 1–3s, renames it (`"2d poisoned"`), and logs a `pool` kind of Roll with no `pool_id`. At 0d it stays until cleared.
- **Who changed harm**: callers set `Character#changed_by` (the sheet, rolls, condition changes, rest, downtime, scene end), and a `before_save` records `harm_change` ("cleared Bloodied and the Agility mark"), `harm_changed_by` and `harm_changed_at`. The Harm card shows "GM marked Bloodied · 3 minutes ago" when that wasn't the owner (`harm_changed_by_someone_else?`).
- **The GM tends harm too.** `Character#tended_by?` (the owner, or the seated campaign's GM) may change harm, marks and conditions, and tick talent uses; everything else on the sheet stays the owner's. The Harm card's toggles PATCH `characters/:id/damage` (`Characters::DamagesController`, harm and mark attributes only), and conditions and condition rolls use the same `CharacterDamage` concern. When the GM changes something it's logged as a note ("Gwen marked Bloodied on Tibbs"; a condition roll logs itself instead), the owner's open sheet refreshes (`turbo_stream_from @character`, `broadcast_refresh_later`), and so does the table.
- **Roll toast** (`rolls/_toast`, rendered by the layout from `RollsHelper#toast_roll`; `toast_controller.js`): every roll you make (action, defense, story, montage, quarrel, pool, condition) shows as the same toast on whatever page you land on, and only to you; others' rolls are in the log. It sits at the top of the toast stack, top center (`shared/_toasts`), for `RollsHelper::ROLL_TOAST_SECONDS` (10) after the roll was made or changed, then gone; the server only renders it while it's that fresh, and passes the seconds left, so client clocks don't matter. Hovering or focusing holds it; closing it is remembered for the tab (sessionStorage, by `roll_toast_key`), so a morph doesn't bring it back. A critical still offering "Nothing fits: take spark" stays (sticky) until closed or taken. Grim-red for grim and disaster; action, defense, story and power-pool rolls use `shared/_roll_result` (with the result text as `detail:`), montages and quarrels list their sides, and plain pool rolls show the dice and "3d → 2d". Its only follow-up is "Nothing fits: take spark" on a critical: spark and assists go in before a roll (pg. 12–13), so there's no reroll or "ask for help".
- Quick changes on the sheet (marks, harm, spark, thread) are `button_to` PATCHes with `quick: 1`, with morph refreshes on the page.
- Herb linter false positive: a hash key with a state's name (`@preset[:thorns]` on the roll page) counts as reading the state. Rename the key (`:damage_thorns`).
- Not yet: a talent catalog (talents are free text plus the path's core talent), path-specific sheet parts, spending spark straight into a roll, and auto-taking spark on a disaster.

## Talents (built 2026-10-15)

- The catalog is `config/talents.yml`: 17 paths, each with its core talent plus 7 path talents, and 11 background/heritage talents (pg. 89), for 147 in all. `Talent` and `Talent::Group` are Data classes loaded from the YAML; keys are slugged names (`according-to-plan`).
- It was extracted from the PDF's text layer by a script: talents start at `NAME:` lines, and the book's sidebar tips go in `note`. Several core talents were cleaned up by hand (Artificer, Berserker, Druid, Monk, Psion, Swashbuckler, Warlock, Witch). The PDF's hyphenation leaves U+0002 control characters, which a test now guards against.
- "[Prohibited: Path]" in a talent's text blocks that path (`Talent#prohibited_for?`, validated on `Character`).
- Characters store chosen talents in `talent_keys` (json). The core talent always comes from the path. Chosen talents are capped at the level (one at creation, plus one per level, from any path; pg. 31, 46, 52): `talents_fit_level` validates it only when talents or level change, so an old sheet that's over still saves other changes. `talents_to_choose` drives the reminder, `talents_full?` swaps the picker's Take buttons for "No room at level N", and `extra_talents` puts a warning on the sheet. Swapping means removing one first. Not modelled: the optional stat progression rule (pg. 175: forgo a talent once for +1 stat), and the summoner vassal's thematic path talent aspect. See `docs/design/talent-limits/BRIEF.md`.
- **Eldritch Talents** (`Character::EldritchTalents`; Pact, pg. 82): a character whose core is Pact (the Warlock) has its own list, `eldritch_talent_keys` (json), with `eldritch_talent_slots` = 1, +1 at levels 3 and 6 (`GROWTH_LEVELS`). They don't count against `talent_keys`. Only non-core path talents (no background ones), not prohibited and not already chosen; a talent can't be in both lists. Same "only when they or the level change" validation. The picker takes them at `new_character_talent_path(c, eldritch: 1)` (404 for other paths), and create/destroy take `eldritch: 1` too. The sheet lists them under Talents ("Eldritch Talents 1 of 2", `characters/_talent` with `eldritch: true`), and flags a talent's "One time only" feature (`Talent#one_time_only?`), which thematic path talents can't use (pg. 53). Their uses and pools count like any talent's, and re-skins work on them. The Patience pool isn't modelled: changing one just says to roll it.
- Every talent has a `summary:` in the YAML: our own one-line gist (not book text, under 100 characters; `TalentTest` checks). The catalog (and the picker) shows it under the name, with the book's text and tip folded under "Full text"; the search still matches the folded text.
- **On the sheet** (Talents), each talent is a card (`characters/_talent`), the core talent on its own above a grid of the rest: name, a ⋯ menu (re-skin form, Remove; `menu_controller.js`), source, **kind badges** (`talents/_kinds`, `Talent#kinds`: Spell, Roll, Pool, Uses, Push, else Always; the catalog shows them too), the summary, a core talent's "Grows" line (`Talent#growth`, cut from its paragraphs), what it gives (tick boxes with "N left", talent pools (the shared pool row, rearranged on the card by `.pool-rows--sheet`: dice, Roll and ⋯ on top, the name, kind and last roll under them), a pool preview before the first session, "+1 thread each session"), its **actions**, then "From the book". With room for columns (the sheet's 40rem container query), the non-core cards are all as tall as the tallest (`grid-auto-rows: 1fr`), with "From the book" at the foot; one with its book text open spans the row and the rows go back to their own heights. On a phone they keep their own. The "Post to the table log" tick sits under the talents.
- **Talent rolls** (`rolls:` in the YAML, `Talent::Roll`): a story roll at set odds or a montage (`bonus:` extra dice, `RollCall.montage!(bonus:)`), which may spend `thread:` or tick a `use:` first. The owner's button on a seated character's card (POST `characters/:id/talents/:talent_id/roll`, `index`) calls `Character#call_talent_roll!`: it spends, then makes the roll call the player rolls in the dialog, and a call that can't be made gives the spending back. `test/models/talent_roll_test.rb` checks every entry.
- **Push yourself** (pg. 21) on any talent whose text says so (`Talent#pushes?`): a menu of the four stats (POST `characters/:id/talents/:talent_id/push`, `stat`) runs `Character#push!`, which takes a mark with `Character#take_mark` (pg. 27: a marked stat takes its harm instead, that harm again makes you desperate, and harm while desperate is "dropped", which isn't tracked; `mark_would_be` labels each button) and logs "Tibbs pushes for Lurker and marks Agility." What's still missing (bonus dice after a roll, talent ticks in the roll setup, dice rules, trackers, casting) is listed in `docs/design/talent-ui/BRIEF.md`.
- **Re-skins** (pg. 52, "Re-Skin Talents"): `Character::TalentSkins` stores `talent_skins` (json, by talent key) with an optional own `name`, `summary` and `text`; blank falls back to the book's, and all blank removes the skin. `Character#talent_entries` returns `Character::SkinnedTalent`s (a `SimpleDelegator` over `Talent`; `#book` is the original). The book's text and the mechanics always stay. The owner and the campaign's GM can re-skin (`tended_by?`), via PATCH/DELETE `characters/:id/talents/:talent_id/skin`. Removing a talent drops its skin.
- `/talents` is the public catalog (`talents/_catalog`). Each group lists its core talent first, then the rest A to Z (`Talent::Group#talents`). A dropdown shows one path's talents, Background and heritage, or All talents; only that group shows, and the search narrows it, all client-side (`talent_filter_controller.js`). The choice is kept in the URL as `?path=` (`selected:`; the server hides the other groups too, so there's no flash). `/characters/:id/talents/new` is the same catalog with Take buttons, opening on the character's own path.
- The free-text `talents` column is now "Talent notes", for choices talents ask for (skills, spells, tricks) or homebrew.
- Not yet: the Monk martial arts style, Rogue thieves' guild, and other optional path builders; legacy talents (pg. 190–191).

## Design system (the night-table direction)

The UI rethink (brief "Grimwilder: night-table UI", 2026-10-20; mockups in the local, git-ignored `docs/design/ui-rethink/`) is being built in five phases: (1) tokens and shell, (2) character view, (3) GM table, (4) campaign page, (5) chat. All five phases are done (2026-10-20): 1 shell, 2 character view, 3 GM table, 4 campaign page, 5 chat; screens not yet rebuilt still use their older class names in the new palette.

- **Dark only.** Every color, font and radius is a custom property in `:root` in `application.css`; templates and components use only the variables. The older names (`--paper`, `--ink`, `--moss`, `--font-body`…) are aliases kept until each screen is rebuilt. Don't use them in new work.
- Fonts are self-hosted through Propshaft (`app/assets/fonts`, `@font-face` in `application.css`): **Spectral** (500, 700, italic 500) for names, headings and in-character speech (`--font-display`); **IBM Plex Sans** (400, 500, 600) for UI (`--font-ui`); **IBM Plex Mono** (500, 600) for dice and counts (`--font-dice`). No Google Fonts.
- Body text is 15px, line-height 1.5. Every button and input is at least `--tap` (44px) tall; icon-only buttons have an `aria-label`. Icons are inline stroke SVGs from `icon(:name)` (`IconsHelper`), never emoji or glyphs.
- Results: `--perfect`, `--messy`, `--grim` (plus `--grim-ring`/`--grim-bg`/`--grim-line` for cards), and `--disaster`, which is ours: the palette has no disaster color. Always show the word (Perfect, Messy, Grim, Disaster, Critical) next to the color. Meta-currencies: `--spark` amber circles, `--thread` blue diamonds, `--suspense` purple diamonds.
- Primary actions are `--ember`. One `.button--primary` per area; `.button` is the outline secondary, `.button--ghost` text only. Buttons and cards are CSS classes (`.button…`, `.card`/`.card--dashed`) because `button_to`, `link_to` and submits all need them; `shared/_card` wraps a block when that's tidier.
- Page layout: `.fluid` > `.fluid__main` (flex 999 1 640px) + `.fluid__rail` (flex 1 1 340px, max 420px), so the rail drops under the content on a phone. Keep a 16px gutter and no horizontal scrolling at 390px.
- **Type-or-pick boxes**: every text box with a datalist of the book's words has the placeholder from `type_or_select` ("Type one in or select from our list"; `type_or_select("But not…")` for the one you aren't).
- **Title case for list words.** The book's lists in `config/grimwild.yml` are lowercase. Show them, and what players typed from them, through `title_case` (`ApplicationHelper`: "Uncover the Truth", "Quick-Witted"; short words stay lowercase, existing capitals stay) in datalists, hints and the sheet. Stored values aren't changed. Don't use Rails' `titleize`: it turns hyphens into spaces.
- **"Create new …" cards**: a list that can grow ends with a dashed card that makes one (`.add-card`, `.add-card--link`): Create new campaign (holding the form, or the one-campaign message), Create new character on the Characters page, and in the campaign page's and GM table's party grids. No + glyph.
- BEM-style class names. Accessibility: a skip link, `:focus-visible` outlines (`--focus`), `aria-live` on changing results, `prefers-reduced-motion` respected.

**Shared partials** (`app/views/shared`), which every rebuilt screen is assembled from:
- `_die` (`value:, kind:, state: nil|:highest|:dropped, size: 28|32|44`): a d6 gets its own tier class (`die--perfect/messy/grim`), so the highest die fills with *its* result's color (a 5 cut to grim is still messy-ochre); a d8 is a diamond (a turned square behind the upright number), red and filled when it cuts. Classes `die--top`/`die--dropped`/`die--cut` are shared with `roller_controller.js`. `RollsHelper#roll_dice_tags` renders every roll's dice through it.
- `_roll_result` (`roll:, size:, heading:`): dice, the word (`roll_result_word`) and the reason line (`roll_reason`: "Messy, cut to grim by a thorn"). No `Current`, so it renders in broadcasts.
- `_pool_track` (segments = the current phase's `starting_size`; purple when hidden), `_pips` (`kind:, value:, max:, cap:`, always with an `aria-label` like "1 of 2 spark"; `cap:` shows at most that many, then "+N". Suspense shows just its number, on the GM table and in the rail), `_segmented` and `_stepper`.
- `_segmented` uses radio inputs rather than `aria-pressed` buttons: herb:state can't compute `aria-pressed`, and a checked radio tells the browser and screen readers the same thing. Pass `input_data:` for a `data-herb-set` binding, and a third value in an option (`[value, text, why]`) to grey it out with `why` as its title.
- `_tally` (`kind:, noun:, value:, down:, up:, of:, left:, group_label:`): a tinted `[ − | 1 of 2 spark | + ]` card of two `button_to`s (`down:`/`up:` hashes of `url:, label:, method:, params:, disabled:`); `tally--suspense/spark/thread/xp`. Suspense on the GM table (`left: true`: "4 suspense left"), spark, thread and XP on the owner's sheet.
- `_stepper` is a real number input with − and + (`stepper_controller.js` steps it and fires `input`/`change`, so herb bindings still see it).

**The shell** (`layouts/_app_header`): wordmark, tabs and an account button. Signed in, a `.reset-notice` ("While in beta, data may be reset any time") sits before the account button, on its own row on a phone. Signed in, the tabs start with All campaigns (`all_campaigns_tab`); no campaign menu, since it's one active campaign at a time. Inside a campaign (`context_membership`: `Current.membership`, or `@membership` on a seated character's sheet) the tabs are the campaign's (`campaign_tabs`): GM All campaigns · <the campaign's name> · Table · Log; player All campaigns · <name> · My character · Log (`Membership#seated_character`). A player with more than one active character seated there gets "My characters" instead, a `<details class="tab-menu">` listing each sheet (`Membership#seated_characters`); the live banner still leads to the first by name. Log goes to the session history. Outside a campaign the tabs are the toolkit's, which the footer always lists too. Signed in, both end with Characters.

**Toasts** (`shared/_toasts`, `shared/_toast`, `toasts_controller.js`) stack at the top center: the roll toast first, then news (every `notice:` flash, a neutral `toast--notice`: "Everyone rests.", "Barroom brawl removed."), then failures. There are no flash banners. Anything that fails to save says so in a grim-red toast, for `ApplicationHelper::FAILURE_TOAST_SECONDS` (10; hovering holds it). That covers every `alert:` flash (pages show no flash banners at all), a form re-rendered with 422 and no alert ("That didn't save. Check the form for what to fix."), any `RecordInvalid`/`RecordNotSaved` a controller didn't rescue, or a `params.expect` that found a field missing or blank, on a non-GET (`ApplicationController#not_saved` redirects back, 303, with the record's errors or "Fill in … and try again."), a Turbo form that couldn't reach the server (`turbo:fetch-request-error` on a non-GET), and a `toasts:show` event (`{ detail: { message } }`) from JS whose own `fetch` failed (the feed loading earlier lines). Each toast is `data-turbo-permanent` with its own id, so a morph neither wipes it nor blocks a newer one; `toast_controller.js` removes it once gone (`remove` value).

**Pages in a modal** (`shared/_frame_modal`, in the layout; `frame_modal_controller.js`): a link with `data: { turbo_frame: "modal" }` loads its page's `turbo_frame_tag "modal"` into a dialog, which opens once it's loaded (named after the page's heading). The page still works on its own. Its forms target `_top` (`data: { turbo_frame: "_top" }`), so saving refreshes the page behind, and the dialog closes when they succeed; closing empties it, so it's fresh next time. Inside it the page header loses its campaign link and the form its panel. Downtime ("Downtime" in the GM table's Respite fold-out) is one.

**Close buttons and titles**: every popover and modal has a title and a ✕ in its top right (`shared/_close_button`, `.close-button`). A floating `<details>` panel starts with `shared/_popover_head` (`title:`, and `list: true` inside a `<ul>` menu, which makes it a `<li>`): the title, then the ✕, which closes the `<details>` it's in and puts focus back on the summary (`dismiss_controller.js`). A dialog renders the ✕ with its own controller's action (`action: "confirm#cancel"`).

**Confirmations** (`shared/_confirm`, in the layout; `confirm_controller.js`): every `data-turbo-confirm` (on `button_to`'s form or a form) opens this dialog instead of the browser's `confirm()`; the controller is `Turbo.config.forms.confirm`. It shows the message, Cancel (focused, so Enter doesn't delete by accident) and a confirm button labelled with what was clicked, red when it deletes or removes (`button--danger`/`button--danger-text`, or the label starts with Delete/Remove). Escape or a click outside cancels. Keep writing confirmations as `form: { data: { turbo_confirm: "…" } }`; nothing else is needed.

**Live banner** (`campaigns/_live_banner`): "Live now · Session 8 · Scene 2, The mill fire · 3 at the table" while a session is open, linking to `campaign_play_path`, which sends the GM to the table and a player to their sheet. It shows on campaign pages except the one it links to (`live_banner?`). It updates over its own **`[campaign, :live]`** stream, not `:table`: `:table` carries refresh actions, which would reload pages that don't morph (and wipe a half-typed form). `Campaign#broadcast_table_refresh` sends both, so every boundary updates the banner.

## Roadmap

1. **Pools**: built, with linked phases (`Pool::Phases`: `phases` JSON plus a current `phase` index, entered as the book writes them, e.g. `4d Claws + 4d Tail`; only the current phase rolls, and a 0d phase unlocks the next one; log entries record `phase` and `next_phase`).
2. **Crucibles**: built (see above). Next: path-specific crucibles.
3. **Characters**: built, with the talent catalog and spark spent into rolls (see above).
4. **Campaign play**: the table log is built, and so are sessions and scenes (see "Sessions & scenes"). Action, defense, story, montage and quarrel rolls are built, with spark and assists. Power pools roll as action rolls too. Next ideas: assists on story rolls, and outside help as its own named die.

5. **Plans**: today every account is at one active campaign, GM or player (`Membership#one_active_campaign`). Planned: playing in any number of campaigns is free; running (GM-ing) more than one active campaign is the paid plan. That means counting only GM memberships toward the free limit, plus billing.

Open question: whether rolls can be shared without an account.

## Production image

The `Dockerfile` builds on Docker Hardened Images (Debian 13). The runtime image has **no shell, no package manager and no `/usr/bin/env`**, and only the libraries Ruby needs, so:
- `bin/docker-entrypoint` is Ruby (`ENTRYPOINT ["ruby", …]`): it runs `db:prepare` before the server, and runs `bin/…` scripts through `ruby`, since their `#!/usr/bin/env ruby` line can't work. The default command is `ruby bin/thrust ruby bin/rails server`.
- Run commands as `ruby bin/rails …` when you `docker exec` (Kamal's `--reuse` aliases); `docker run image bin/rails …` goes through the entrypoint and is fine. There's no `kamal shell` or `dbc` (no bash, no sqlite3); use `docker debug` on the server for a shell.
- `BUNDLE_VERSION=system`: otherwise Bundler re-runs `bin/rails` to switch to the lockfile's version, which needs `env`.
- What the runtime lacks is installed in the build stage and copied in: jemalloc (`/opt/jemalloc`, `LD_PRELOAD`) and time zone data (`/usr/share/zoneinfo`, which TZInfo needs). Anything else with a system library has to be copied the same way, so there's no libvips: images aren't transformed (`variant_processor = :disabled`, no image_processing).
- It runs as uid 1000 (not the image's 65532), which owns the existing `grimwilder_storage` volume. `/rails` is created by copying, so it's that user's too.
- Ruby versions follow what DHI publishes (4.0.7 now): keep `.ruby-version` and the `RUBY_VERSION` build arg together.

## Production server

Live at **https://grimwilder.com** since 2026-10-24 (`www.` redirects to it, `config/routes.rb`).

- **Deploying**: work on a branch, push it, run `bin/ci` there (it ends with `gh signoff`, a green `signoff` status on the branch's latest commit), open a PR and squash-merge it. The "Main" ruleset requires a PR, the `signoff` check, signed commits (a squash merge in GitHub's UI is signed by GitHub) and linear history. Every push to `main` runs `.github/workflows/deploy.yml`, which runs `bin/kamal deploy`; it logs in to ghcr.io with the job's own `GITHUB_TOKEN`. Its other secrets live in the repo's `production` environment and are listed at the top of that file. Pushing to a branch again after a signoff needs `bin/ci` again.
- **From the Mac**: `bin/kamal deploy`, `bin/kamal console`, `bin/kamal logs`. They need `KAMAL_REGISTRY_PASSWORD` (a classic token with `write:packages`, kept in 1Password), plus `CERTIFICATE_PEM`/`PRIVATE_KEY_PEM` for anything that boots the proxy.
- **Cloudflare** proxies both names (SSL "Full (strict)"; kamal-proxy serves a Cloudflare Origin CA certificate, so there's no Let's Encrypt). Public DNS shows Cloudflare's addresses, never the droplet's, so check records in the dashboard or with `dig @adi.ns.cloudflare.com`.
- **Droplet**: Ubuntu 24.04 at the Reserved IP `129.212.197.211`, with DigitalOcean backups on. It was set up by hand; to rebuild one:
  - Docker from `get.docker.com` (`kamal deploy` doesn't install it; `kamal setup` would).
  - The DigitalOcean Cloud Firewall from `script/digitalocean_firewall.rb`: 80/443 from Cloudflare's ranges only, 22 from anywhere (GitHub's runners have no fixed IPs). Re-run it when Cloudflare's ranges change. Don't use `ufw`: Docker's published ports bypass it.
  - SSH: keys only (`/etc/ssh/sshd_config.d/00-hardening.conf`: `PermitRootLogin prohibit-password`, no passwords, no X11). `root`'s `authorized_keys` holds Shawn's key and the deploy key (`SSH_PRIVATE_KEY`, no passphrase, since the workflow's ssh-agent can't take one). Leave `MaxAuthTries` at its default: at 3, clients offering several keys get "Too many authentication failures".
  - A 2 GB `/swapfile` (in fstab, `vm.swappiness=10`): the old and new containers overlap during a deploy on 2 GB of RAM.
  - unattended-upgrades reboots when an update needs it, at 09:00 UTC (`/etc/apt/apt.conf.d/52unattended-upgrades-reboot`); the containers restart themselves.
- **Data**: the SQLite files live in the `grimwilder_storage` volume. `DatabaseSnapshot` copies the primary database to `storage/backups` nightly at 04:00 and keeps 7; DigitalOcean's backups carry them off the droplet. `config/master.key` is in 1Password: without it the credentials can't be read.
- **Email**: Resend over SMTP from `no-reply@mail.grimwilder.com` (`MAILER_FROM`; `mail.grimwilder.com` is the domain in Resend, with its DKIM, SPF and return-path records under `mail.` and DMARC at the root). **Port 2587, not 587**: DigitalOcean blocks outgoing 25, 465 and 587, and a blocked port shows up as `Net::OpenTimeout` in the mail job. The key is in the credentials' `smtp:` section (`config/environments/production.rb`).
- **Errors**: `ErrorNotifier` (a `Rails.error` subscriber, on when `ERROR_EMAIL_TO` is set) emails a server error or a failed job, at most once an hour for the same error, and skips 4xx errors such as not found. It sends through the same SMTP, so it can't report email itself being down; `bin/kamal logs` has everything.
- **Sign-ups are closed** (`ALLOW_SIGNUPS: false`). An admin makes accounts at `/admin/accounts` (see *Admin*).

## Licensing (must keep)

- The footer must credit *Grimwild* by J. D. Maxwell (Oddity Press) under **CC BY 4.0**, say the site is unofficial and not endorsed, and note that the CE text is CC0.
- **Do not** reuse the book's Canva graphic assets or Per Janke's illustrations.
- The book's text may be quoted, but keep it to what a tool needs.

## Agent working notes

- The user develops on macOS (folder `~/Desktop/projects.nosync/grimwilder`) and runs the app there.
- Sandboxed agent environments may be unable to `bundle install` (rubygems.org may be blocked, and the Linux VM ships Ruby 3.0). If you can't boot Rails, still run the Herb linter and the Node tests, and say plainly that the Rails tests weren't run.
- npm packages useful for checks: `@herb-tools/linter@0.11.0`, and `reactionview@0.6.0` (its source shows the client API).
- Don't commit or push unless asked.
- Before a significant decision, check the project plan doc (`claude/toolkit-plan.md` in the Claude project).

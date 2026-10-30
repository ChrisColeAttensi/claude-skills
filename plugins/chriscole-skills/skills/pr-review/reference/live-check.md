# Live check

Read this when the review profile names a pass that stands the app up and uses it, and its
trigger fires. It covers both halves: the premise check in step 0, and trying the findings in
step 6b.

## Step 0: check the premise

**A pass that stands the app up and uses it runs in an agent, not here.** Some PRs cannot be
reviewed from the diff: the code is right line by line and the feature still does not work,
because the premise was wrong — the flow has a dead end, the state never reaches the component,
the thing the user is supposed to see never appears. A profile that wants this names it as a
pass, and names the **medium** the app is driven through.

Driving an app is the bulkiest tool output in the whole review — screens, trees, logs — and
almost none of it is evidence. Spawn `pr-review-live-checker` with the claim and the medium's
playbook, and let the bulk die with the agent. What comes back is a short verdict, which is all
step 7 needed. Running it in this session instead puts every observation in context and re-reads
it on every turn that follows.

Three rules travel with it, whatever the medium:

- **Write the claim as one falsifiable sentence before touching the app, and stop when it is
  answered.** The premise is the target; the rest of the app is not.
- **Prefer the cheapest observation that settles the claim.** Text over pictures, one assertion
  over a dump.
- **Expensive captures are closing evidence, not a way of looking around.** One at the end, for
  a claim you genuinely cannot settle any other way.

Medium playbooks say what those cash out to. Web: [live-check-web.md](./live-check-web.md).
No playbook for the medium the profile names — say so, apply the three rules directly, and keep
the agent.

**A web check has two drivers; use the one this session has.** The built-in browser
(`mcp__Claude_Browser__*`) exists only inside Claude Desktop. Claude in Chrome
(`mcp__claude-in-chrome__*`) exists when the CLI runs with `--chrome`, or after `/chrome`.
Prefer the built-in browser when both are there, and name the driver in the agent's brief so it
knows which tools to reach for.

**The preview tool comes with the built-in browser, and goes with it.** `preview_start`,
`preview_logs` and `.claude/launch.json`'s `autoPort` exist only in Claude Desktop. When the
profile says to start the app through the preview tool and this session drives Claude in Chrome
instead, run the command that `launch.json` entry names, as a background shell command — the
profile's "never a raw command" rule is about the preview tool being there, not a ban on starting
the app. Then:

- **Take the URL from the server's startup output**, not from the config's port. Nothing
  rewrites it for you.
- **Logs are that command's output.** Hand its path to the live checker in place of `preview_logs`.
- **Never click through a certificate warning** in the user's Chrome. It is their browser and
  their trust decision; stop, and point them at the profile's setup for a trusted cert.
- **Stop the server when the review is done with it** — after step 6b, not after the premise
  check. The preview tool cleans up after itself; a background command does not.

The profile owns the specifics — which script, which port to prefer, how its cert gets trusted.

**A login is the user's, and often already done.** Before asking for one, open the app and let it
settle: still on the app, rendered → a session is cached, say so and carry on; redirected to the
login host the profile names → only now ask. Sessions are per origin, so a server that landed on
a different port has none, and a prompt there is expected — say which port when you ask. The user
logs in; never enter credentials and never ask for them. One login then serves the premise check
and step 6b.

**Neither driver is a gap to offer a fix for, not a reason to skip quietly.** With a user in the
loop, say what the check would settle and offer Claude in Chrome: "`/chrome` connects your
Chrome, then I can run it." With nobody to ask (`-p`), the pass is unreachable: say so in the
report's facts row, and name the fix — rerun with `--chrome`, or from Claude Desktop — so the
reader knows the premise went unexercised and how to exercise it.

Its result behaves like any other pass: findings join the candidate pool and go through a skeptic
in step 6, with the observation as evidence, which is the strongest kind. A clean run is a fact —
say so in the report's second line, naming the medium and the backend, so the reader knows the
feature was exercised and against what.

**A live check has two jobs, and one yes covers both.** The premise is checked here, before the
finders run. The code findings are tried in step 6b, after the skeptics, against the same
running app. Ask once, and name both in the ask: "I'd use the app to check that <the premise>,
then try the repro for each defect the review turns up." Leave the app running between the
two — stopping it costs the user a second login for nothing.

## Step 6b: try the findings in the app

Only when the user said yes to a live check. A skeptic proves a fault from the code; the app shows whether it happens. Do this before anything is reported, so the report carries what was seen rather than what was argued.

**Pick the findings the app can show.** Every confirmed and unsettled finding whose effect lands on a screen — something a user does, then sees, including a record that comes back wrong after a reload. Skip the ones no screen shows: a misleading API, a type that lies, a deploy-time fault, a race no driver can time. Skip any the profile says the running mode cannot reach, and any whose repro would destroy data the review did not create. A live check's own failing point was already watched — do not send it round again.

**Spawn one `pr-review-live-checker` with the whole list**, not one per finding — there is one app and one login, and parallel drivers fight over both. Same driver, URL, mode and playbook as the premise check. Each entry carries its number, the effect in plain words, and the skeptic's `REPRO` copied, so the agent follows the skeptic's steps rather than inventing its own. Above six, send the highest-consequence six and say in the report which went untried.

Apply what comes back:

- **reproduced** → keep it; the Repro bullet ends "— seen in the app (<mode>)". An unsettled finding that reproduces is confirmed: move it to Change before merge.
- **not reproduced** — the steps ran as written and the app behaved → drop it into the discarded file with what the app showed. The exception is a mode that differs from production on exactly that path (seeded data, a missing backend, a locked feature): then it goes to step 6c, naming the difference.
- **unreachable** → unchanged. The skeptic's verdict stands, and the Repro bullet does not claim the app.

No finding the app can show, or no live check approved: skip this step and say nothing about it.

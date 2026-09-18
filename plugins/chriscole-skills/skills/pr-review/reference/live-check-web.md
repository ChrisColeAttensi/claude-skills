# Live check — web

The medium playbook for a browser-driven live check. The profile says how to stand *this* app
up; this says how to drive any app cheaply once it is up. Paste it into the
`pr-review-live-checker` prompt.

Measured on one wizard flow, against the same claim with no budget: **34 screenshots to 1**,
73 tool calls to 49, 7.9 minutes to 4.1. Both runs reached the same verdict on all three points.
The screenshots were the spend; the wandering was the latency.

## Read with text, not pictures

A screenshot costs roughly a thousand tokens and answers less than a page read.

| Question | Use | Not |
| --- | --- | --- |
| Is this label / heading / copy present? | `get_page_text`, `find` | a screenshot |
| Where is the button, is it enabled? | `read_page` with `filter: "interactive"` | `read_page` full tree |
| Did it error? | `read_console_messages` with `onlyErrors: true` and a small `limit` | the default 50-row dump |
| Did the request fire? | `read_network_requests` with a `urlPattern` | the default listing |
| A computed colour, a token, a class | `javascript_tool` reading the one value | a screenshot to eyeball it |

`find` before `read_page`: if you know roughly what you are looking for, it returns the handful
of refs instead of the tree.

## Screenshots

**At most one, at the end, as evidence.** Pass `scale: 0.5` — quarter the tokens, and enough for
any claim a reviewer will read.

Take it only for a claim that is genuinely visual: layout, spacing, colour, ordering you cannot
establish from the accessibility tree, or a theme change whose whole assertion is appearance. If
you are about to screenshot to find out where you are, you wanted `get_page_text`.

## Batch

`browser_batch` runs a sequence in one round trip. Whenever a step does not need the previous
step's output — navigate, click, type, press, read — batch it. Coordinates inside a batch refer
to the screenshot taken *before* the call, so prefer `ref`s from `find` or `read_page` over
pixels; they survive batching and re-renders.

## Stop conditions

- The claim is answered — every numbered point has a verdict. Stop.
- A point is unreachable in this mode (seed data missing, a backend the mode does not have, a
  native file dialog the browser cannot drive). Say so and move on. Do not go looking for a way
  round; unreachable is a legitimate result and the reader needs to know which parts were not
  exercised.
- You have found the defect the claim was about. Stop — the skeptic in step 6 does the rest.

Incidental discoveries away from the claim are not your job. A render quirk two screens away is
a fact about the app, not a finding about this PR, and chasing it is where the budget goes.

## Tabs

Open your own with `tabs_create` and drive that. The session's other tabs belong to whoever
opened them. Close yours when you are done.

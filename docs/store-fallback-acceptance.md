# App Store fallback policy (#19)

Checked on 2026-10-24 at base `50900b6` plus the accompanying focused patch:
macOS 27.0.1 (26A434), Xcode 27, Swift 6.4, arm64. This is headless correctness
evidence, not native Store installation or interactive UI acceptance.

The production provider previously propagated local `mas list` errors after
successfully reading Store metadata. The live runtime then discarded the offer
and displayed an unknown status. The new provider regression fails on the
previous source with `Could not start missing-mas: 2.` and passes after the fix.

Routing now belongs to `LatestCore.BrokerPolicy`. Direct installation requires
fresh metadata, a receipt-bearing unwrapped instance immediately under
`/Applications`, exactly that instance in the inventory and a matching valid
local claim. The platform adapter supplies metadata and ownership. Missing or
failed ownership preserves the external Store URL; cancellation still propagates.
Installation-time client/server validation remains independently mandatory.

| Criterion | Status | Evidence / next step |
|---|---|---|
| Exact supported ownership is required for direct routing | fulfilled | `storeRoutingRequiresExactSupportedOwnership`: positive direct action plus mismatched ID/bundle/path, missing claim and out-of-range broker ID |
| Duplicate, nonstandard, wrapped, receiptless and stale inputs cannot authorize direct routing | fulfilled | Same production policy test covers duplicate paths/bundle IDs, a different sole instance, empty inventory, nested/external paths, wrapped/receiptless snapshots and stale metadata |
| Ownership failures retain the external update path | fulfilled | `unavailableStoreOwnershipKeepsExternalUpdate`: production provider + bounded HTTP client, controlled URLProtocol lookup, actual missing executable, failing process and malformed process output; exact Store URL, external status and bulk exclusion |
| Native duplicate/volume/wrapped-app inventory and visible external action | open | Requires isolated native fixtures and actual macOS UI observation; handcrafted snapshots do not establish this |
| Native App Store target launch | open | Observe the actual external destination on macOS; the headless action/URL checks do not establish a GUI launch |
| README matches current behavior | fulfilled | App Store boundaries describe shared policy, ownership fallback and these evidence limits |

Current checks: full Swift Testing suite (49 functions discovered, nine native
opt-ins skipped), 84 compiled invariants, 18 Python release contracts, 85 EN/DE
keys/source boundaries, warnings-as-errors Release and Xcode MCP GUI build pass.
No GUI automation, Store-account access, broker registration, installation,
certificate/trust change, release publication or Git remote operation was used.

Issue #19 remains open until its native criteria are observed. The absent private
fixture directory and expired historical localhost certificate prevent reusing
the old native results as current evidence. Rebuilding generic dependencies
does not recreate or rotate the approved certificate.

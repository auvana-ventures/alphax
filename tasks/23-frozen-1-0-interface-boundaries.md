# Frozen 1.0 Interface Boundaries

Status: [x] Completed

## Goal

Expand the frozen AlphaX 1.0 interface requirements so the core contract,
transport responsibilities, protocol guarantees, omitted policy layers, and
performance-claim boundaries are explicit and consistent across release
documents.

## Scope and Non-goals

Scope:

- document that `alphax` is transport-independent and does not include a native
  transport implementation by itself;
- document that Web is unsupported in AlphaX 1.0;
- document opportunistic H3 negotiation and the provider/server/proxy/network
  conditions that determine the actual protocol;
- document that retries, authentication orchestration, cookies, caching, and
  vendor-specific resilience policy are not included in the frozen 1.0
  contract;
- document that AlphaX makes no universal speed, zero-copy, or “fastest
  client” claim;
- synchronize the public API inventory, scope, requirements audit, release
  gate, and RC review language.

Non-goals:

- no source, public API, constructor, transport, package, or dependency change;
- no new retry, auth, cookie, cache, resilience, Web, or H3 behavior;
- no benchmark rerun, historical-report rewrite, publication, tag, commit, or
  push.

## Owner

Codex coordinator; maintainer review remains required.

## Dependencies

- `docs/phase1a-public-api-inventory.md`;
- `docs/ALPHAX_1_0_SCOPE.md`;
- `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`;
- `docs/ALPHAX_1_0_RELEASE_GATE.md`;
- `docs/ALPHAX_1_0_RC_REVIEW.md`;
- accepted ADRs 0003–0008.

## Assumptions

- the existing frozen public symbols and implementation evidence remain
  unchanged;
- the requested statements are release-contract boundaries, not new required
  implementations;
- package READMEs already contain user-facing versions of these limitations and
  should remain consistent with the authoritative release documents.

## Work Items

- [x] Inspect the current frozen inventory, scope, audit, release gate, RC
  review, ADRs, and package README wording.
- [x] Add the explicit five-point frozen interface contract to the 1.0 scope.
- [x] Mirror the contract in the API inventory, requirements audit, release
  gate, and RC review.
- [x] Review for contradictions, unsupported claims, and accidental API or
  implementation expansion.
- [x] Run focused Markdown, link, whitespace, and diff validation.

## Validation

Completed on 2026-08-17:

- `markdownlint --disable MD013 MD060 -- ...` passed for the changed README,
  release, inventory, scope, and task Markdown. `MD013` and `MD060` remain
  explicit exceptions because the existing release documents use long prose
  and compact table formatting.
- The local relative-link target check passed for all reviewed Markdown files.
- `git diff --check` passed; the added-line trailing-whitespace scan found no
  matches.
- The targeted claim scan confirmed explicit coverage for the native-transport,
  Web, H3, retry/auth/cookie/cache/resilience, zero-copy, and fastest-client
  boundaries.
- No source, package, transport, benchmark, or historical report files were
  changed by this task.

## Next Action

Maintainer review the synchronized frozen-interface wording. No source or
release implementation changes are required.

## Blockers

None.

## Outcome

Completed. The frozen 1.0 scope now explicitly states the transport injection
seam and all five requested non-guarantees. The API inventory, requirements
audit, release gate, and RC review use matching language without expanding the
public API or implementation scope.

## References

- `docs/phase1a-public-api-inventory.md`
- `docs/ALPHAX_1_0_SCOPE.md`
- `docs/ALPHAX_1_0_REQUIREMENTS_AUDIT.md`
- `docs/ALPHAX_1_0_RELEASE_GATE.md`
- `docs/ALPHAX_1_0_RC_REVIEW.md`
- `docs/decisions/0003-public-api-transport-independence.md`
- `docs/decisions/0004-platform-native-mobile-transports.md`
- `docs/decisions/0005-completion-time-protocol-metadata.md`
- `docs/decisions/0006-protocol-preference-vs-requirement.md`
- `docs/decisions/0007-transport-neutral-tls-policy-and-pinning.md`
- `docs/decisions/0008-proxy-policy-semantics.md`

## History

- 2026-08-17: Reserved task 23 for the frozen 1.0 interface-boundary
  documentation update.
- 2026-08-17: Completed the synchronized documentation update and focused
  validation.
- 2026-08-17: Post-completion correction: task 24 supersedes the documentation-
  only exclusions for Web, retries, authentication, cookies, caching, and
  generic resilience with explicit opt-in implementations. The pure-core
  native-transport boundary, opportunistic H3 semantics, and no-universal-
  performance-claim boundary remain unchanged.

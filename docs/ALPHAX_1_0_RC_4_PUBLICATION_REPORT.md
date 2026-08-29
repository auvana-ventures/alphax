<!-- markdownlint-disable MD013 -->

# AlphaX 1.0.0-rc.4 publication report

Status: completed. The coordinated six-package RC4 publication gate passed and
all six packages were accepted by pub.dev.

## 1. Publication date and source

The packages were published on 2026-08-29 UTC (2026-08-30 in the repository's
IST timezone). Pub.dev's version API reports these publication timestamps:

| Order | Package | Version | Pub.dev timestamp (UTC) | Version page |
| ---: | --- | --- | --- | --- |
| 1 | `alphax` | `1.0.0-rc.4` | 2026-08-29T18:56:35.277601Z | [version](https://pub.dev/packages/alphax/versions/1.0.0-rc.4) |
| 2 | `alphax_test` | `1.0.0-rc.4` | 2026-08-29T18:58:35.868437Z | [version](https://pub.dev/packages/alphax_test/versions/1.0.0-rc.4) |
| 3 | `alphax_native` | `1.0.0-rc.4` | 2026-08-29T18:59:26.349338Z | [version](https://pub.dev/packages/alphax_native/versions/1.0.0-rc.4) |
| 4 | `alphax_web` | `1.0.0-rc.4` | 2026-08-29T19:00:17.515741Z | [version](https://pub.dev/packages/alphax_web/versions/1.0.0-rc.4) |
| 5 | `alphax_dio` | `1.0.0-rc.4` | 2026-08-29T19:01:10.115895Z | [version](https://pub.dev/packages/alphax_dio/versions/1.0.0-rc.4) |
| 6 | `alphax_transform` | `1.0.0-rc.4` | 2026-08-29T19:02:02.834991Z | [version](https://pub.dev/packages/alphax_transform/versions/1.0.0-rc.4) |

The package archives were produced from source commit
`adea44a69fb2c1c59ac1449805c6de70df225175`. That commit includes the accepted
RC4 package manifests, changelogs, implementation, and release task record.
Task 45 documentation was pushed first in `5bf676e7175acb9ee17698cb97018ab04102796f`.

## 2. Package versions and dependency order

All six packages were published as `1.0.0-rc.4` in the manifest dependency
order:

1. `alphax`
2. `alphax_test`
3. `alphax_native`
4. `alphax_web`
5. `alphax_dio`
6. `alphax_transform`

Internal AlphaX constraints in the publication source were:

| Package | Internal runtime dependency | Internal development dependency |
| --- | --- | --- |
| `alphax` | none | none |
| `alphax_test` | `alphax: ^1.0.0-rc.4` | none |
| `alphax_native` | `alphax: ^1.0.0-rc.4` | `alphax_test: ^1.0.0-rc.4` |
| `alphax_web` | `alphax: ^1.0.0-rc.4` | none |
| `alphax_dio` | `alphax: ^1.0.0-rc.4` | `alphax_test: ^1.0.0-rc.4` |
| `alphax_transform` | `alphax: ^1.0.0-rc.4` | none |

The external dependencies remained package-specific: Flutter for
`alphax_native`, `http` for `alphax_web`, Dio for `alphax_dio`, and Dart test
tooling as development dependencies. No Retrofit, generator, Freezed, or
serialization dependency was added to an AlphaX package.

## 3. Archive sizes and contents

The final dry-runs reported zero warnings. Downloaded pub.dev archives were
inspected after publication:

| Package | Dry-run size | Downloaded archive size |
| --- | ---: | ---: |
| `alphax` | 54 KB | 55,598 bytes |
| `alphax_test` | 12 KB | 12,857 bytes |
| `alphax_native` | 94 KB | 96,282 bytes |
| `alphax_web` | 11 KB | 12,144 bytes |
| `alphax_dio` | 15 KB | 16,215 bytes |
| `alphax_transform` | 14 KB | 14,526 bytes |

Archive inspection found only expected source, tests, examples, documentation,
assets, and plugin files. No raw benchmark results, logs, local paths,
signing configuration, private certificates/keys, device fixtures, or native
build output was present.

## 4. Final validation

Passed before publication:

- Dart formatting and analysis for all six packages.
- Flutter analysis and package tests, including native tests.
- All six package test suites, conformance/policy tests, and transform tests.
- Generated Retrofit/Dio/Freezed compatibility fixture.
- Dartdoc dry-runs with zero warnings and errors.
- Web package tests, Flutter Web JavaScript build, and Chrome test.
- Local RC4 consumer Android profile and release builds.
- Local RC4 consumer macOS build.
- Local RC4 consumer iOS device no-code-sign and simulator builds.
- Workspace dependency resolution and package dry-runs with zero warnings.
- Relative Markdown link validation and release-archive inspection.
- Security, secret, signing, and machine-path audits.
- `git diff --check`.

No Phase 0 or integration-cost benchmark was rerun.

The repository's full Markdownlint baseline still reports existing HTML and
80-column line-length violations in branded READMEs and historical tables. A
structural Markdownlint run with those two established rules disabled passed;
new Task 45/46 documents were clean under the default rules. This did not
affect package validation or archive contents.

## 5. Hosted clean-consumer validation

After all six versions became visible, hosted-only disposable consumers passed
without path overrides:

| Consumer | Result |
| --- | --- |
| `alphax` + `alphax_native` quick start | Hosted resolution, analysis, and Android profile build passed. |
| `alphax` + `alphax_web` | Hosted resolution, analysis, Web build, and Chrome test passed. |
| `alphax` + `alphax_native` + `alphax_dio` + Dio | Hosted resolution, Flutter analysis, and adapter test passed. |
| `alphax` + `alphax_transform` | Hosted resolution, analysis, and one-shot transform execution passed. |
| `alphax_test` dev dependency | Hosted resolution, analysis, and fake-transport test passed. |
| Hosted Retrofit fixture | Hosted AlphaX packages, Retrofit generation, Freezed/json_serializable generation, analysis, 9 compatibility tests, and documented example passed. |

The hosted Retrofit path remains:

```text
Retrofit generated client
  -> Dio
  -> AlphaXDioAdapter
  -> AlphaXClient
  -> AlphaX transport
```

The generated-client caveat remains unchanged: the maintained generator's
temporary `Future<Map<String, dynamic>>` shape can emit invalid
`dynamic.fromJson` code before adapter execution; typed DTOs are the validated
surface. AlphaX does not replace Retrofit or its generator.

## 6. Post-publication examples and documentation

The two standalone examples were moved from hosted RC3 to hosted RC4 in
`ce1fbef0fd875a9b06633f84d3027b5d09a4d6bc`:

- `examples/basic`: `alphax` and `alphax_native` `^1.0.0-rc.4`.
- `examples/waypoint`: `alphax`, `alphax_dio`, `alphax_native`, and
  `alphax_test` `^1.0.0-rc.4`.

Both examples passed dependency resolution, analysis, and tests. Current
repository package/root READMEs were updated to state that RC4 is published in
`ed50a657264a16211a5d51cd24eb418ff9515e5a`.

The immutable RC4 package archives necessarily contain the README snapshots
used at publication time, whose status paragraphs said the candidate was
prepared. The repository's current-facing READMEs now state the published
status; no RC4 package can be republished at the same version.

## 7. Remaining limitations

- Dart IO remains the truthful H1-only fallback on Linux and Windows.
- Browser protocol, TLS, proxy, cookie, CORS, and file authority remains
  browser/provider-owned where Web APIs do not expose it.
- Android H3, custom trust, proxy, and other provider controls remain
  capability/provider/network dependent.
- Apple URLSession H3 and trust/proxy controls remain OS/provider dependent;
  CocoaPods remains the supported Apple packaging path for RC4.
- `alphax_transform` is explicit, buffered, one-shot, native-isolate work;
  post-dispatch cancellation discards the result and does not hard-stop the
  worker. Web background execution is unsupported.
- No universal zero-copy claim or common advanced DoH, 0-RTT, migration, or
  persistent-worker API is provided.
- Signed physical-iPhone runtime validation remains limited by unavailable
  provisioning; the accepted prior device evidence and current simulator /
  no-code-sign build are retained.
- The standalone Android Gradle unit-test project limitation remains a
  non-blocking tooling issue; plugin/consumer builds are valid.

## 8. Publication warnings and incidents

- Pub.dev accepted all six packages without publish-time warnings. Pub.dev
  explicitly noted that visibility could take up to ten minutes; the version
  endpoints became available during the sequential checks.
- One hosted Dio disposable runner was initially invoked with plain `dart`
  while importing the Flutter-backed `alphax_native` package. The final
  Flutter test invocation passed; no package change was required.
- No package was partially published or skipped.

## 9. Repository state and release artifacts

The current repository HEAD at report preparation was
`ed50a657264a16211a5d51cd24eb418ff9515e5a`, and it was pushed to
`origin/main`. It includes the separate example update and current-facing
published-status documentation. Protected benchmark/mobile/signing changes,
historical evidence, raw results, and ignored logs remained unstaged and
untouched.

No Git tag or GitHub release was created. The proposed tag `v1.0.0-rc.4` and
release title `AlphaX 1.0.0-rc.4` remain pending explicit maintainer approval.

ALPHAX 1.0.0-RC.4 PUBLISHED SUCCESSFULLY

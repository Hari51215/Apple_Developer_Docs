# Combine

Medium article: ["Combine From the Demand Up: A Measured Tour of Publishers, Operators and Schedulers"](https://hari51215.medium.com/combine-from-the-demand-up-a-measured-tour-of-publishers-operators-and-schedulers-2e588030aebf)

No sample app for this topic. Combine has no interface of its own, and everything worth teaching
about it — the demand contract, operator semantics, scheduler placement, cancellation,
multicasting, buffering — is directly observable from a plain command-line Swift program. A trace
of demand travelling up a chain says more than a screenshot of a debounced text field would.

Every number, trace and table in the article was produced by running Combine from short Swift
scripts against macOS 26.7 with Swift 6.2.1 (Xcode 26.1) on an Apple-silicon Mac: the `.print()`
demand traces, the hand-written `Publisher`/`Subscriber`/`Subscription` triple, the per-family
operator output, the combineLatest/zip/merge comparison and their completion rules, the millisecond
timings for debounce/throttle/delay/timeout, `flatMap` concurrency ceilings, `switchToLatest`
cancellation, `share()`/`multicast` subscription counts, the `buffer` prefetch and overflow
combinations, retry arithmetic, `@Published`'s `willSet` timing, `assign(to:on:)` lifetime behaviour, the
async/await bridge, and the 1M-element throughput benchmark.

Two findings came out of that testing rather than the documentation:

- `Subscribers.Demand` subtraction **traps** on underflow (`.max(2) - .max(5)`, exit 133, no
  message) in both debug and optimised builds, although Apple's reference says a negative result is
  adjusted to `.max(0)`.
- `buffer(prefetch: .keepFull)` never exercises its `whenFull` policy, because that prefetch
  strategy only requests as much as it has room for. Only `.byRequest` can overflow.

Every Swift snippet in the article compiles: the ones with printed output were run, and a longer
debounce → `switchToLatest` → `URLSession` → `decode` view-model pipeline (kept out of the article
for length) was type-checked with `swiftc -typecheck` while confirming the error-mapping advice.

The article deliberately contains no tables: every measured result is shown as the output the
script actually printed, or stated in prose.

# Result

**Recommendation:** Adopt

Static F2P/P2P green for `20260925-gha-then-blacksmith` on `github-runner-then-fallback`: prefer-GHA then Blacksmith wiring
and create-github-app-token `client-id` inputs. Org `ORG_BILLING_TOKEN` +
`ACTIONS_INCLUDED_MINUTES` still required for live prefer-GHA (else
fallback-on-error → Blacksmith).

# Outcome

- Local `runs-on` work jobs go through determine-runner / fromJson where applicable.
- Thin callers map `ORG_BILLING_TOKEN`.
- App mint steps use `client-id` (no `app-id` / `installation-id` inputs).

# Blocking findings

None for the wiring claim.

# Manual verification

| Ran by hand | Observed | Automated check | Tier |
| --- | --- | --- | --- |
| None — evals kit redistribute | N/A | eval-ci result gate (PROCESS.md) | hermetic |

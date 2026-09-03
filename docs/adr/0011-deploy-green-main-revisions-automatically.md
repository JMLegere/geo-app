# ADR 0011: Deploy green main revisions automatically

- Status: Accepted
- Date: 2026-09-03
- Issue: #592 Outcome Contract amendment

Every successful CI workflow caused by a push to `main` automatically deploys that workflow's exact `head_sha` to production through `deploy-prod.yml`.

The deployment workflow listens to `workflow_run` only for the named `CI` workflow on `main`. Its job guard additionally requires `conclusion == success`, source event `push`, and source branch `main`. Pull-request CI, failed or cancelled CI, manual CI dispatch, and non-`main` branches cannot enter the automatic production job. The workflow definition is read from the default branch and does not consume artifacts from an untrusted run.

The existing release order remains controlling: deploy additive Supabase migrations and Edge Functions first, then deploy the same exact revision to the Railway production service. The serialized `deploy-prod` concurrency group remains non-cancelling.

`workflow_dispatch` and its optional `commit_sha` remain available for explicit rollback and operator recovery. This fallback does not weaken the automatic path's exact-SHA rule.

This decision supersedes only ADR 0009's manual production-delivery policy. It does not change the `local`/`prod` execution-environment model, authorize product or schema work, alter deployment targets or secrets, or restore beta as an active environment.

# services-aws-sns

Nullplatform service that provisions **AWS SNS topics** (Standard or FIFO) and connects them to applications.

## What it does

Creates one topic per service instance with the settings of the SNS console, and hands each linked application its own IAM user and access key.

| Capability | Standard | FIFO |
| :---- | :---- | :---- |
| Type | Chosen at creation and fixed afterwards | Same; the name gets `.fifo` automatically |
| Details | Name, display name (SMS sender, first 10 characters), maximum message size (1–1024 KiB, default 256) | Same, plus **high throughput** (message group scope or topic scope, fixed at creation) and **content-based deduplication** |
| Encryption | Off by default. When on: `alias/aws/sns`, or the ARN of your key or alias | Same |
| Access policy | **Basic**: publishers are the owner, everyone or the AWS accounts you list; subscribers are the owner, everyone, the accounts you list or requesters with certain endpoints. **Advanced**: your own JSON policy | Same |
| Archive policy | — | Off by default; when on, keeps messages 1–365 days (default 30) for replay |
| Delivery policy (HTTP/S) | SNS default, or a custom one: retries, delays, retry counts per phase, maximum receive rate, Content-Type, backoff function, override subscription policy | — (FIFO topics have no HTTP/S subscriptions) |
| Delivery status logging | Off by default. When on: Lambda, SQS, HTTP/S, platform application and Data Firehose, success sample rate, and a role the service creates or two roles you name | Same, for Amazon SQS only |
| Tags | Your tags plus the platform's; the agent role can only touch resources it created | Same |
| Active tracing | Off by default; when on, AWS X-Ray | Same |

Every setting except the type, the name and the FIFO throughput scope can be changed after creation.

## Links

| Link | What it does |
| :---- | :---- |
| `create-aws-sns-link` | Creates an IAM user that can publish to the topic, subscribe to it and manage its own subscriptions (plus `kms:GenerateDataKey*` and `kms:Decrypt` on the key of an encrypted topic), and exports its access key. |

## Layout

```
sns/
├── specs/
│   ├── service-spec.json.tpl      # the form the developer sees
│   ├── links/connect.json.tpl
│   └── requirements/aws/          # IAM role the agent assumes
├── deployment/                    # the topic, its access policy and the delivery logging role
├── permissions/                   # link: IAM user, policy and access key
├── scripts/aws/                   # sns_lib, context building, tofu execution, outputs
│   └── tests/aws/                 # BATS unit tests
├── utils/                         # assume role helpers
├── entrypoint/                    # action routing
├── workflows/                     # one file per action
└── values.yaml                    # static config, not exposed in the UI
nullplatform/                      # registers the service definition
nullplatform-bindings/             # routes notifications to an agent
```

## The form

The developer first picks **Standard** or **FIFO**. The FIFO-only fields (high throughput, deduplication, archive policy) appear only for FIFO; the HTTP/S delivery policy and the Lambda, HTTP/S, platform application and Firehose logging protocols appear only for Standard. Each optional section (encryption key, account lists, endpoint list, JSON policy, custom delivery policy, logging settings, existing roles, archive retention) appears only once it is turned on.

The form hides fields with JSON Forms `rule`s, some of them on layouts rather than controls. If the nullplatform renderer ever shows every field, nothing breaks: `build_context` ignores whatever does not apply to the chosen type or to a section that is off.

An **advanced** access policy is the full JSON policy, as in the console's JSON editor. Leave `Resource` empty or out, or write `{{topic_arn}}`, where the topic ARN goes: the topic ARN is filled in when the policy is applied, since the form cannot know it before the topic exists.

## Installation

**1. Create the permissions role.** Apply `sns/specs/requirements/aws` in the target AWS account:

```hcl
module "sns_requirements" {
  source            = "git::https://github.com/nullplatform/services-aws-sns.git//sns/specs/requirements/aws?ref=main"
  cluster_name      = "<nullplatform agent cluster>"
  state_bucket_name = "<existing S3 bucket for the tofu state>"
}
```

To apply it as a root module instead, copy `terraform.tfvars.example` to `terraform.tfvars` and fill it in. Set `kms_key_arns` to the keys your teams use and `delivery_logging_role_arns` to the logging roles they may name; both default to all.

**2. Publish the role.** Register `permissions_role_arn` in the nullplatform AWS IAM provider under the selector **`sns`**, and allow the agent role to assume it.

**3. Create the state bucket.** Create one S3 bucket that every SNS service shares for its tofu state, enable versioning, and pass its name to the requirements module as `state_bucket_name`. The agent must receive the same name in the environment variable `SNS_S3_STATE_BUCKET`. The service never creates or deletes this bucket: if it is missing, every action fails with a clear error.

Each service keeps its state under `services/sns/<service id>/terraform.tfstate`, and each link under `services/sns/<service id>/links/<link id>.tfstate`. Deleting a service removes that prefix and nothing else.

**4. Region.** The region comes from the account configuration (`aws.region`) or the account provider.

**5. Register the service.** Apply `nullplatform/` (service definition) and then `nullplatform-bindings/` (agent channel). Copy each `terraform.tfvars.example` to `terraform.tfvars` first; `*.tfvars` are git-ignored.

## How it works

Before any AWS call, each workflow assumes the permissions role published in the IAM provider under the selector `sns`, and every later step runs on the temporary credentials it returns. When the provider publishes no role for that selector, the agent keeps its own credentials, which is what makes local testing work.

`build_context` turns the form into a `terraform.tfvars.json` and validates it first, with a message that names the field: ranges, account IDs, role and key ARNs, the JSON policy, and the delivery policy rules the console enforces (minimum delay not above maximum delay, the three retry phases adding up to no more than the number of retries).

The topic is named `np-<name>`, or `np-<name>.fifo` for FIFO, and the name is saved in the service attributes (`topic_name`) the first time. Renaming the service or editing the form never renames or recreates the topic. The `np-` prefix is what scopes the permissions role to topics created by nullplatform.

With **Create and use new service roles**, the service creates one role, `np-sns-logs-<service id>`, that SNS assumes for both successful and failed deliveries. It can only write the topic's own log groups (`sns/<region>/<account>/<topic>` and `.../Failure`), and it is deleted with the service.

Each link user is named `np-<link slug>-<first 5 characters of the link id>-user`. Its access key is generated by Terraform, stored only in the link's state and attributes, and delivered to the application as a secret environment variable. Link users live under the `/nullplatform/sns/` path and must carry the `np-sns-link-boundary` permissions boundary (created by the requirements module), which caps them at the topic actions a link needs: the permissions role cannot create a link user without it, nor touch any IAM user outside that path.

## Connecting

nullplatform names each exported variable after the **service**: its name in upper case, with every run of other characters turned into `_`, then the attribute. For a service named `orders-events`:

| Variable | From | |
| :---- | :---- | :---- |
| `ORDERS_EVENTS_TOPIC_ARN` | service | Topic ARN to publish to |
| `ORDERS_EVENTS_AWS_REGION` | link | Region of the topic |
| `ORDERS_EVENTS_ACCESS_KEY_ID` | link | Access key of the link's IAM user |
| `ORDERS_EVENTS_SECRET_ACCESS_KEY` | link | secret |

Two services with the same name in one application (an SNS topic and an SQS queue both called `orders-events`, for example) write the same `ACCESS_KEY_ID`, `SECRET_ACCESS_KEY` and `AWS_REGION` parameters, and the application ends up with only one link's credentials. Give each service its own name.

Map them to the standard names your SDK reads (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`) and publish to the topic ARN. Publishing to a FIFO topic needs a message group ID, and a deduplication ID unless content-based deduplication is on.

An encrypted topic with a custom key also needs that key's policy to allow the link user (`kms:GenerateDataKey*`, `kms:Decrypt`). With `alias/aws/sns`, AWS services such as CloudWatch alarms or S3 event notifications cannot publish to the topic; use a customer managed key for them.

A link's KMS permissions are computed when the link is created or updated, not when the topic is. After you turn encryption on or change the key, run a link update on each link of that topic, otherwise its application gets `AccessDenied` from KMS until you do.

Active tracing needs an X-Ray resource policy that lets `sns.amazonaws.com` send traces. The console creates it for you; this service does not, so add it once per account and region if you turn tracing on.

## Local testing

Set `aws_profile` in `values.yaml`, run `aws sso login --profile <name>`, and start the agent with `np package run` (below). With no IAM provider configured, the service runs on that profile's credentials.

Unit tests run with [bats-core](https://github.com/bats-core/bats-core):

```bash
bats sns/scripts/tests/aws/ sns/utils/tests/
```

## Run locally as a package

`np package run` runs this service on your machine the way production does: a
local controlplane-agent that registers with the platform, spawns the worker
image built from this repo, and hands it every action routed to it. No cluster,
no publish. The two tasks in `mise.toml` are the whole contract with the CLI:

| Command | Runs | Does |
|---|---|---|
| `np package build --image` | `mise run build:image` | Builds `sns-worker:dev` |
| `np package run` | `mise run run` | Builds the image, then starts the local agent |

Prerequisites: **Docker** with host networking (Linux as is; on Docker Desktop
enable *host networking*), **[mise](https://mise.jdx.dev)** (`mise trust` once
here), an **`NP_API_KEY`** for the agent to register with, and `np` from the
**alpha** channel, which carries `np package run`:

```bash
curl -fsSL https://cli.nullplatform.com/install.sh | VERSION=alpha sh   # ~/.local/bin/np
np package run --help                                                   # must list --no-forward-env
```

```bash
export NP_API_KEY=...
eval "$(aws configure export-credentials --format env)"   # cloud credentials as variables
np package run --log-level DEBUG                          # Ctrl+C to stop
```

The agent is tagged `package:sns` and `local:<your user>`. It receives an
action only when the service's notification channel selects those tags, so
point a channel at `local:<your user>` to route work to your machine.

> **Tags decide who gets the work.** Never start a local agent with tags a
> production channel selects: it would receive production actions.

`np package run` forwards your shell's environment to the agent container,
minus what describes your machine (`PATH`, `HOME`, `DOCKER_*`, `KUBECONFIG`,
`AWS_PROFILE` and the other file-pointing AWS variables), and the `run` task
passes the same variables to the worker through an `NP_WORKER_RULES` entry.
Every secret in your shell crosses too, and is readable with `docker inspect`;
pass `--no-forward-env` to forward nothing.

| Variable | Default | Purpose |
|---|---|---|
| `NP_API_KEY` | required | The key the agent registers with (`--api-key` also sets it) |
| `NP_LOG_LEVEL` | `INFO` | Agent log level (`--log-level` also sets it) |
| `NP_PACKAGE_SLUG` | `sns` | The slug in the `package:<slug>` tag, when published under another slug |
| `NP_LOCAL_USER` | `$USER` | The value of the `local:<user>` tag |
| `NP_AGENT_IMAGE` | `controlplane-agent:latest` | The agent image; needs worker rules (0.11.1+) |

The local run never changes what the platform runs. To ship the change, merge
it: the release publishes the image and registers the artifact.

## CI

| Workflow | When | What |
|---|---|---|
| branch-validation | PR | branch named `feat/…`, `fix/…`, `chore/…` |
| conventional-commit | PR | commit messages (release-please reads them) |
| shellcheck | PR | every bash script |
| tests | PR | BATS unit tests, `do_tofu` version pin, `tofu validate` of the three modules |
| trivy | PR | IaC misconfiguration and image scan, to the Security tab |
| beta | push to a `beta/**` branch | publish-test-image-oci: pushes `beta/<image>:test-beta-<name>-<short sha>` and registers it as a nullplatform artifact |
| release | push to `main` | release-please → build and push `vX.Y.Z` and `latest` to ECR Public → nullplatform artifact → GitHub release |
| auto-merge-release | after release | merges the release PR |
| dependabot | daily / weekly | base image and shared workflow bumps |

## Image tags

| Image | Moved by | Use it to |
|---|---|---|
| `agent-plugins/services/<name>:vX.Y.Z` | its release, once | pin an exact version |
| `agent-plugins/services/<name>:latest` | each release | follow the last released version |
| `beta/agent-plugins/services/<name>:test-beta-<branch>-<short sha>` | each push to a `beta/**` branch (`git push origin HEAD:beta/<name>`) | deploy a change to a test scope before merging it |

Beta images live in a separate repository that the beta role can write and the production role cannot, so a beta can never overwrite a released image. Only pushes to `beta/**` branches can assume the beta role, and the tag carries the commit SHA, so two branches never overwrite each other by accident. Nothing deletes beta tags: they are ephemeral by convention. Each beta is also registered as its own nullplatform oci_image artifact (the `beta/` repository, under `NP_ARTIFACT_NRN`), separate from the release artifact, so it can be deployed to a test scope from the platform.

## Publishing

After adding the **Public ECR** service to the application, set in this repository:

| Name | Kind | Value |
|---|---|---|
| `AWS_ROLE_ARN_ECR_PUSH` | secret | the publisher role ARN the Public ECR service returns |
| `NP_ARTIFACT_NRN` | variable | the NRN of the organization that owns the artifacts |

`ARTIFACT_NP_API_KEY` comes from the organization. The release checks all three before building and fails with a clear error if one is missing. Beta images assume the role in the organization secret `AWS_BETA_ROLE_ARN` (no role is written in the workflow) and need the service's `beta/` repository in ECR Public: without it the push fails with `repository does not exist`. In this template repository neither workflow runs.

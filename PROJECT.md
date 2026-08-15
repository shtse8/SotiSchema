# Spectra Project

Spectra is a Dart code generator that transforms annotated Dart data classes into
JSON Schema, OpenAPI, and Protocol Buffers. It owns the Dart annotations, builder
logic, generated contract formats, examples, package metadata, and pub.dev
release boundary.

## Lifecycle

- Lifecycle: `active`
- Layer: `foundation`

## Goals

- Generate JSON Schema, OpenAPI, and Protobuf contracts from Dart model
  annotations.
- Support Freezed, json_serializable, and plain Dart model patterns.
- Keep generated contract outputs deterministic and owned by the Dart source
  model plus Spectra annotations.

## Non-Goals

- Do not own consuming applications' API policy, auth, persistence, deployment,
  or business semantics.
- Do not become a runtime API server or persistence framework.
- Do not publish package changes without release proof and pub.dev readback.

## Boundaries

Spectra owns Dart annotations, build integration, schema generation, package
metadata, examples, and docs. Consuming applications own their API lifecycle,
runtime validation policy, generated artifact publication, and downstream
service contracts.

## Delivery

No repo-local GitHub Actions workflow is declared at adoption time. Package
publication is a public side effect and must use explicit release evidence plus
pub.dev package readback before claiming production release.

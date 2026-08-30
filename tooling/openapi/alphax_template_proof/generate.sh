#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${OPENAPI_GENERATOR_CLI_JAR:-}" ]]; then
  echo 'Set OPENAPI_GENERATOR_CLI_JAR to the official openapi-generator-cli 7.24.0 jar.' >&2
  exit 2
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
spec="$repo_root/tooling/openapi/alphax_template_proof/spec/fixture.yaml"
templates="$repo_root/tooling/openapi/alphax_template_proof/templates"
expected="$repo_root/examples/openapi_template_proof/lib/users_api.dart"
output=$(mktemp -d /tmp/alphax-openapi-template-proof.XXXXXX)

java -jar "$OPENAPI_GENERATOR_CLI_JAR" generate \
  --generator-name dart \
  --input-spec "$spec" \
  --output "$output" \
  --template-dir "$templates" \
  --global-property 'apis,apiDocs=false,apiTests=false,models=false,modelDocs=false,modelTests=false,supportingFiles=false' \
  --additional-properties 'alphaXBaseUrl=http://127.0.0.1:45874/,alphaXModelImport=package:alphax_openapi_template_proof/fixture_models.dart'

dart format "$output/lib/api/users_api.dart" >/dev/null
diff -u "$expected" "$output/lib/api/users_api.dart"
echo 'OpenAPI AlphaX declaration matches the checked-in proof artifact.'

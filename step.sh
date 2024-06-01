#!/bin/bash
set -ex

base64_url() {
  openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
}

sign() {
  openssl dgst -binary -sha256 -sign <(echo -n "${PRIVATE_KEY}")
}

header="$(echo -n '{"alg":"RS256","typ":"JWT"}' | base64_url)"

now="$(date '+%s')"
iat="$((now - 60))"
exp="$((now + (3 * 60)))"
template='{"iss":"%s","iat":%s,"exp":%s}'
payload="$(printf "${template}" "${CLIENT_ID}" "${iat}" "${exp}" | base64_url)"

signature="$(echo -n "${header}.${payload}" | sign | base64_url)"

jwt="${header}.${payload}.${signature}"

installation_id="$(curl --location --silent --request GET \
  --url "${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/installation" \
  --header "Accept: application/vnd.github+json" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --header "Authorization: Bearer ${jwt}" \
  | jq -r '.id'
)"

token="$(curl --location --silent --request POST \
  --url "${GITHUB_API_URL}/app/installations/${installation_id}/access_tokens" \
  --header "Accept: application/vnd.github+json" \
  --header "X-GitHub-Api-Version: 2022-11-28" \
  --header "Authorization: Bearer ${jwt}" \
  | jq -r '.token'
)"

envman add --key GITHUB_API_TOKEN --value ${token}

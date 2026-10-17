#!/usr/bin/env bash
# Run the temporal CLI with a fresh OIDC access token, so a 5-minute
# Keycloak token never means logging in again. The first run (or any run
# after the refresh token expires) does the device flow in the browser;
# every later run trades the stored refresh token for a new access token
# and passes it as TEMPORAL_API_KEY.
#
#   temporal-oidc workflow list --namespace boopd
#   temporal-oidc token     # print an access token
#   temporal-oidc login     # force the device flow
#   temporal-oidc logout    # forget the refresh token
#
# Installed by home/common/temporal-oidc.nix; repos call it from their own
# recipes (e.g. boop's `just temporal`). Any Keycloak device-flow client
# whose access token Temporal accepts works; the defaults are fartlab's.
# The refresh token lives in the macOS Keychain.
# With offline_access on the client it outlives the SSO session
# (Keycloak's offline idle and max timeouts); without it, it lasts as long
# as the SSO session does.
#
# The steps (device flow, refresh grant, token store, hand the token to
# Temporal) are the ones a Go tool would take with golang.org/x/oauth2
# and the SDK's client.NewAPIKeyDynamicCredentials.
#
# Environment:
#   TEMPORAL_OIDC_ISSUER     default https://auth.fartlab.dev/realms/fartlab
#   TEMPORAL_OIDC_CLIENT_ID  default temporal-cli
#   TEMPORAL_OIDC_SCOPE      default "openid offline_access"
#   TEMPORAL_PROFILE         the temporal CLI profile; default fartlab
set -euo pipefail

issuer="${TEMPORAL_OIDC_ISSUER:-https://auth.fartlab.dev/realms/fartlab}"
client_id="${TEMPORAL_OIDC_CLIENT_ID:-temporal-cli}"
scope="${TEMPORAL_OIDC_SCOPE:-openid offline_access}"
profile="${TEMPORAL_PROFILE:-fartlab}"

oidc="${issuer}/protocol/openid-connect"
keychain_service="temporal-oidc ${client_id} ${issuer}"

die() {
  echo "temporal-oidc: $*" >&2
  exit 1
}

for tool in curl jq security temporal; do
  command -v "${tool}" >/dev/null || die "${tool} not found"
done

# Token store: one Keychain item per issuer and client.
load_refresh() {
  security find-generic-password -a "${USER}" -s "${keychain_service}" -w 2>/dev/null || true
}

# The token is in security's argv for the moment it runs; the Keychain
# CLI only reads a password from argv or an interactive prompt.
store_refresh() {
  security add-generic-password -U -a "${USER}" -s "${keychain_service}" -w "$1" >/dev/null
}

forget_refresh() {
  security delete-generic-password -a "${USER}" -s "${keychain_service}" >/dev/null 2>&1 || true
}

# post_token posts form data to the token endpoint. The secret parameter
# (name=value on stdin) is sent with --data-urlencode @-, so no token
# appears in curl's argv. Prints the JSON body, error or not.
post_token() {
  local secret_name="$1"
  shift
  curl -sS -X POST "${oidc}/token" -d "client_id=${client_id}" "$@" \
    --data-urlencode "${secret_name}@-"
}

# save_tokens stores the (possibly rotated) refresh token from a token
# response and prints its access token.
save_tokens() {
  local resp="$1" access refresh
  access="$(jq -r '.access_token // empty' <<<"${resp}")"
  [[ -n "${access}" ]] || return 1
  refresh="$(jq -r '.refresh_token // empty' <<<"${resp}")"
  [[ -z "${refresh}" ]] || store_refresh "${refresh}"
  printf '%s\n' "${access}"
}

# refresh trades the stored refresh token for an access token.
refresh() {
  local rt resp
  rt="$(load_refresh)"
  [[ -n "${rt}" ]] || return 1
  resp="$(printf '%s' "${rt}" | post_token refresh_token -d grant_type=refresh_token)" || return 1
  save_tokens "${resp}"
}

# device_login runs the device authorization grant: show the URL, wait
# for approval, store the refresh token, print the access token.
device_login() {
  local resp device_code interval expires deadline uri token err
  resp="$(curl -fsS -X POST "${oidc}/auth/device" -d "client_id=${client_id}" --data-urlencode "scope=${scope}")" ||
    die "device authorization request failed"
  device_code="$(jq -r .device_code <<<"${resp}")"
  interval="$(jq -r '.interval // 5' <<<"${resp}")"
  expires="$(jq -r '.expires_in // 600' <<<"${resp}")"
  uri="$(jq -r .verification_uri_complete <<<"${resp}")"
  echo "temporal-oidc: approve this login in the browser: ${uri}" >&2
  command -v open >/dev/null && open "${uri}" >/dev/null 2>&1 || true

  deadline=$((SECONDS + expires))
  while ((SECONDS < deadline)); do
    sleep "${interval}"
    resp="$(printf '%s' "${device_code}" |
      post_token device_code -d grant_type=urn:ietf:params:oauth:grant-type:device_code)" || continue
    if token="$(save_tokens "${resp}")"; then
      printf '%s\n' "${token}"
      return 0
    fi
    err="$(jq -r '.error // empty' <<<"${resp}")"
    case "${err}" in
      authorization_pending) ;;
      slow_down) interval=$((interval + 5)) ;;
      *) die "device login failed: ${err:-unexpected response}" ;;
    esac
  done
  die "device login timed out"
}

access_token() {
  refresh || device_login
}

case "${1:-}" in
  token)
    access_token
    ;;
  login)
    forget_refresh
    device_login >/dev/null
    echo "temporal-oidc: logged in" >&2
    ;;
  logout)
    forget_refresh
    echo "temporal-oidc: refresh token removed" >&2
    ;;
  *)
    TEMPORAL_API_KEY="$(access_token)"
    export TEMPORAL_API_KEY
    exec temporal --profile "${profile}" "$@"
    ;;
esac

#!/usr/bin/env bash

# Interact with RHSSO from the command line.

usage()
{
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}")
           [--rhsso_host_url=<url>]
           [--rhsso_realm=<realm>]
           [--help | -h] [--verbose | -v]
           <command> [<args>]

Interact with RHSSO from the command line.

Available commands:
  get_access_token    Obtain an access token

General options:
  --rhsso_host_url
      The base URL of the RHSSO API service (e.g. https://my-rhsso-service.com) (required if not otherwise provided, see below)
  --rhsso_realm
      The ID of the realm to use
  --help, -h
      Print this help and exit
  --verbose, -v
      Print script debug info

If --rhsso_host_url is not supplied, the environment variable RHSSO_CLI_RHSSO_HOST_URL will be used.
If --rhsso_realm is not supplied, the environment variable RHSSO_CLI_RHSSO_REALM will be used.

See '$(basename "${BASH_SOURCE[0]}") <command> --help' for help on a specific command.
USAGE_TEXT
}

usage_get_access_token()
{
  cat <<USAGE_TEXT
Usage: $(basename "${BASH_SOURCE[0]}") get_access_token <args>

Obtain an access token for a client from RHSSO.

get_access_token args:
  --client_id=<id>
      The client ID for which to get a token (required)

Example 1: The client secret will be prompted for:
    $ rhsso_cli --rhsso_host_url=https://my-rhsso-hostname --rhsso_realm=my_rhsso_realm get_access_token --client_id=my_client
Example2: The client secret is piped to rhsso_cli:
    $ client_secret='my_client_secret' printenv client_secret | rhsso_cli --rhsso_host_url=https://my-rhsso-hostname --rhsso_realm=my_rhsso_realm get_access_token --client_id=my_client 2>/dev/null
    $ cat my_client_secret || rhsso_cli --rhsso_host_url=https://my-rhsso-hostname --rhsso_realm=my_rhsso_realm get_access_token --client_id=my_client 2>/dev/null
USAGE_TEXT
}

main()
{
  initialize
  parse_script_params "${@}"
  RHSSO_CLI_CURL_VERBOSE=""
  if [ "${RHSSO_CLI_VERBOSE}" == "${TRUE_STRING}" ]; then
    RHSSO_CLI_CURL_VERBOSE=" -v "
  fi
  case "${RHSSO_CLI_COMMAND}" in
    get_access_token)
      handle_command_get_access_token "${@}"
      ;;
    *)
      msg "Error: Unknown command: ${RHSSO_CLI_COMMAND}"
      msg "Use --help for usage help"
      abort_script
      ;;
  esac
}

handle_command_get_access_token()
{
  parse_script_params_get_access_token "${@}"
  get_access_token
  echo "${ACCESS_TOKEN}"
}

get_client_secret()
{
  echo >&2 -n "Please enter the Client Secret for client '${RHSSO_CLI_CLIENT_ID}': "
  read -sr RHSSO_CLI_CLIENT_SECRET
  echo >&2
}

get_access_token()
{
  get_client_secret
  set +x # Temporarily switch off command logging as it alters the resulting output from the function call and breaks the functionality. 
  catch_stdouterr API_CALL_STDOUT API_CALL_STDERR curl_rhsso_get_access_token
  curl_rhsso_return_code="$?"
  if [ "${RHSSO_CLI_VERBOSE}" == "${TRUE_STRING}" ]; then
    set -x
  fi
  if [ "${curl_rhsso_return_code}" -gt 0 ]; then
    msg "Error: Failed to get an access token."
    msg "       Call to RHSSO server to get an access token failed with return code: ${curl_rhsso_return_code}"
    msg "API call response follows:"
    msg "--------"
    msg "${API_CALL_STDOUT}"
    msg "--------"
    msg "API call stderr follows:"
    msg "--------"
    msg "${API_CALL_STDERR}"
    msg "----"
    abort_script
  fi
  API_CALL_RESPONSE=${API_CALL_STDOUT}
  API_CALL_HTTP_STATUS=${API_CALL_STDERR}
  if [ "${API_CALL_HTTP_STATUS}" != "200" ]; then
    msg "Error: Failed to get an access token."
    msg "       Call to RHSSO server to get an access token responded with HTTP status code: ${API_CALL_HTTP_STATUS}"
    msg "API call response follows:"
    msg "--------"
    msg "${API_CALL_RESPONSE}"
    msg "--------"
    msg "API call HTTP Status follows:"
    msg "--------"
    msg "${API_CALL_HTTP_STATUS}"
    msg "--------"
    abort_script
  fi
  API_CALL_RESPONSE_JSON=$(echo "${API_CALL_RESPONSE}" | jq .)
  last_command_return_code="$?"
  if [ "${last_command_return_code}" -ne 0 ]; then
    msg "Error: Failed to get an access token."
    msg "       Failed to parse API call response as JSON"
    msg "API call response follows:"
    msg "--------"
    msg "${API_CALL_RESPONSE}"
    msg "--------"
    abort_script
  fi
  ACCESS_TOKEN=$(echo "${API_CALL_RESPONSE_JSON}" | jq -er '.access_token')
  last_command_return_code="$?"
  if [ "${last_command_return_code}" -ne 0 ]; then
    msg "Error: Failed to get an access token."
    msg "       Failed to select access_token pelement within response JSON"
    msg "API call response follows:"
    msg "--------"
    msg "${API_CALL_RESPONSE}"
    msg "--------"
    abort_script
  fi
}

curl_rhsso_get_access_token()
{
  curl \
      --silent \
      --write-out "%{stderr}%{http_code}" \
      --request POST \
      --header "Accept: application/json" \
      --data grant_type=client_credentials \
      --data scope=openid \
      --data client_id=${RHSSO_CLI_CLIENT_ID} \
      --data client_secret=${RHSSO_CLI_CLIENT_SECRET} \
      --url "${RHSSO_CLI_RHSSO_HOST_URL}/auth/realms/${RHSSO_CLI_RHSSO_REALM}/protocol/openid-connect/token"
}

parse_script_params()
{
  #msg "script params (${#}) are: ${@}"
  # default values of variables set from params
  RHSSO_CLI_COMMAND=""
  RHSSO_CLI_VERBOSE="${FALSE_STRING}"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --help | -h)
        usage
        exit
        ;;
      --verbose | -v)
        set -x
        RHSSO_CLI_VERBOSE="${TRUE_STRING}"
        ;;
      --rhsso_host_url=*)
        RHSSO_CLI_RHSSO_HOST_URL="${1#*=}"
        ;;
      --rhsso_realm=*)
        RHSSO_CLI_RHSSO_REALM="${1#*=}"
        ;;
      -?*)
        msg "Error: Unknown parameter: ${1}"
        msg "Use --help for usage help"
        abort_script
        ;;
      *)
        RHSSO_CLI_COMMAND="${1-}"
        break
        ;;
    esac
    shift
  done
  if [ -z "${RHSSO_CLI_RHSSO_HOST_URL}" ]; then
    msg "Error: Missing required parameter: rhsso_host_url"
    abort_script
  fi
  if [ -z "${RHSSO_CLI_RHSSO_REALM}" ]; then
    msg "Error: Missing required parameter: rhsso_realm"
    abort_script
  fi
  if [ -z "${RHSSO_CLI_COMMAND}" ]; then
    msg "Error: Missing required argument: command"
    abort_script
  fi
}

parse_script_params_get_access_token()
{
  #msg "script params (get) (${#}) are: ${@}"
  # default values of variables set from params
  RHSSO_CLI_CLIENT_ID=""
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      get_access_token)
        shift
        break
        ;;
    esac
    shift
  done
  #msg "script params (get_access_token remainder) (${#}) are: ${@}"
  while [ "${#}" -gt 0 ]
  do
    case "${1-}" in
      --client_id=*)
        RHSSO_CLI_CLIENT_ID="${1#*=}"
        ;;
      --help | -h)
        usage_get_access_token
        exit
        ;;
      -?*)
        msg "Error: Unknown get parameter: ${1}"
        msg "Use --help for usage help"
        abort_script
        ;;
    esac
    shift
  done
  if [ -z "${RHSSO_CLI_CLIENT_ID}" ]; then
    msg "Error: Missing required parameter: client_id"
    abort_script
  fi
}

catch_stdouterr()
  # Catch stdout and stderr from a command or function
  # and store the content in named variables.
  # See: https://stackoverflow.com/a/59592881
  # and: https://stackoverflow.com/a/70735935
  # Usage: catch_stdouterr stdout_var_name stderr_var_name command_or_function [ARG1 [ARG2 [... [ARGn]]]]
{
  {
      IFS=$'\n' read -r -d '' "${1}";
      IFS=$'\n' read -r -d '' "${2}";
      (IFS=$'\n' read -r -d '' _ERRNO_; return ${_ERRNO_});
  }\
  < <(
    (printf '\0%s\0%d\0' \
      "$(
        (
          (
            (
              { ${3}; echo "${?}" 1>&3-; } | tr -d '\0' 1>&4-
            ) 4>&2- 2>&1- | tr -d '\0' 1>&4-
          ) 3>&1- | exit "$(cat)"
        ) 4>&1-
      )" "${?}" 1>&2
    ) 2>&1
  )
}

initialize()
{
  set -o pipefail
  THIS_SCRIPT_PROCESS_ID=$$
  initialize_this_script_directory_variable
  initialize_abort_script_config
  initialize_true_and_false_strings
}

initialize_this_script_directory_variable()
{
  # THIS_SCRIPT_DIRECTORY where this script resides.
  # See: https://www.binaryphile.com/bash/2020/01/12/determining-the-location-of-your-script-in-bash.html
  # See: https://stackoverflow.com/a/67149152
  THIS_SCRIPT_DIRECTORY=$(cd "$(dirname -- "$BASH_SOURCE")"; cd -P -- "$(dirname "$(readlink -- "$BASH_SOURCE" || echo .)")"; pwd)
}

initialize_true_and_false_strings()
{
  # Bash doesn't have a native true/false, just strings and numbers,
  # so this is as clear as it can be, using, for example:
  # if [ "${my_boolean_var}" = "${TRUE_STRING}" ]; then
  # where previously 'my_boolean_var' is set to either ${TRUE_STRING} or ${FALSE_STRING}
  TRUE_STRING="true"
  FALSE_STRING="false"
}

initialize_abort_script_config()
{
  # Exit shell script from within the script or from any subshell within this script - adapted from:
  # https://cravencode.com/post/essentials/exit-shell-script-from-subshell/
  # Exit with exit status 1 if this (top level process of this script) receives the SIGUSR1 signal.
  # See also the abort_script() function which sends the signal.
  trap "exit 1" SIGUSR1
}

abort_script()
{
  echo >&2 "aborting..."
  kill -SIGUSR1 ${THIS_SCRIPT_PROCESS_ID}
  exit
}

msg()
{
  echo >&2 -e "${@}"
}

# Main entry into the script - call the main() function
main "${@}"

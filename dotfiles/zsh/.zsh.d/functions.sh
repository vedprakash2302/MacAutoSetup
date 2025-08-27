##############################
# Autodesk specific functions
##############################

vault_login() {
  vault_server="https://civ1.dv.adskengineer.net:8200/"
  echo This command will guide you to create AWS key and secret
  echo Please Select Vault Server to login:
  select vault_option in dev stage prod;
  do
      case $vault_option in
          "dev")
              vault_server="https://civ1.dv.adskengineer.net"
              break
              ;;
          "stage")
              vault_server="https://civ1.st.adskengineer.net"
              break
              ;;
          "prod")
              vault_server="https://civ1.pr.adskengineer.net"
              break
              ;;
      esac
  done
  export VAULT_ADDR=$vault_server
  vault login -method=oidc
}

set_aws_credentials() {
  # vault_login
  while IFS='=' read -r key value; do
    [[ -n "$key" ]] || continue
    # Remove all whitespace from the key to avoid leading spaces from jq formatting
    key="${key//[[:space:]]/}"
    echo "export $key=\"$value\""
    export "$key=$value"
  done < <(
    vault read -format=json account/$1/sts/Owner | jq -r '[
      "AWS_ACCESS_KEY_ID=\(.data.access_key)",
      "AWS_SECRET_ACCESS_KEY=\(.data.secret_key)",
      "AWS_SESSION_TOKEN=\(.data.security_token)",
      "AWS_ROLE=\(.data.arn)"
    ] | .[]'
  )
  echo "AWS_REGION: us-east-1"
  export AWS_REGION=us-east-1
}
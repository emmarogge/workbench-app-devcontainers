#!/bin/bash

# metadata-utils.sh defines helper functions for aws ec2 tags. This script is intended to be sourced from other scripts
# to retrieve or modify instance tags. It is run on the VM host. AWS CLI is not installed on Flatcar VM by default so
# we are running the AWS CLI in a container.

# Retrieves an instance tag set on the VM. If the tag is not set, it returns the default vaule.
function get_metadata_value() {
  if [[ $# -lt 2 ]]; then
    echo "usage: get_metadata_value <tag> <default-value>"
    exit 1
  fi
  local tag_key=vwbapp:"$1"

  local token
  token=$(wget --method=PUT --header "X-aws-ec2-metadata-token-ttl-seconds:600" -q -O - http://169.254.169.254/latest/api/token)
  local id
  id=$(wget --header "X-aws-ec2-metadata-token: ${token}" -q -O - http://169.254.169.254/latest/meta-data/instance-id)
  local tag_value
  tag_value="$(docker run --rm --network host \
    public.ecr.aws/aws-cli/aws-cli \
    ec2 describe-tags \
    --filters "Name=resource-id,Values=${id}" "Name=key,Values=${tag_key}" \
    --query "Tags[0].Value" --output text 2>/dev/null)"
  if [[ "${tag_value}" == "None" ]]; then
    echo "${2}"
  else
    echo "${tag_value}"
  fi
}
readonly -f get_metadata_value 

# guest attributes are not supported on EC2 instances. But to keep the interface consistent with GCP, we define a no-op function.
function get_guest_attribute() {
  get_metadata_value "${1}" "${2}"
}
readonly -f get_guest_attribute


# Sets tags on the EC2 instance with the given key and value.
function set_metadata() {
  local key="${1}"
  local value="${2}"
  
  echo "Creating tag vwbapp:${key} to ${value}"
  local token
  token=$(wget --method=PUT --header "X-aws-ec2-metadata-token-ttl-seconds:600" -q -O - http://169.254.169.254/latest/api/token)
  local id
  id=$(wget --header "X-aws-ec2-metadata-token: ${token}" -q -O - http://169.254.169.254/latest/meta-data/instance-id)

  docker run --rm --detach --network host \
    public.ecr.aws/aws-cli/aws-cli \
    ec2 create-tags \
      --resources "${id}" \
      --tags Key=vwbapp:"${key}",Value="${value}"
}
readonly -f set_metadata
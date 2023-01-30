#!/bin/bash
tags() {
  repo=$1
  gh api repos/$repo/releases --paginate | jq -r '.[].tag_name'
}

otp_tags=$(
  tags erlang/otp | \
    # OTP 23.3+, or 24
    grep -e OTP-23.3 -e OTP-24 -e OTP-25
)

echo $otp_tags
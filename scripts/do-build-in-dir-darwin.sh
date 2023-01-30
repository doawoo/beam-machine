#!/bin/bash -e
IFS="/" read -ra parts <<< "$(pwd)"
len=${#parts[@]}
cpu=${parts[$len-1]}
erlang_version=${parts[$len-3]}
erlang_version=${erlang_version/#OTP-}
erlang_version=${erlang_version/#otp-}

echo "CPU: $cpu"
echo "Version: $erlang_version"

elixir $(which mkerlang.exs) --otp-version=$erlang_version --os=darwin --arch=$cpu

if [ $? -eq 0 ]; then
    touch BUILD_OK
fi
#!/bin/bash -e
IFS="/" read -ra parts <<< "$(pwd)"
len=${#parts[@]}
abi=${parts[$len-1]}
cpu=${parts[$len-2]}
erlang_version=${parts[$len-4]}
erlang_version=${erlang_version/#OTP-}
erlang_version=${erlang_version/#otp-}

echo "ABI: $abi"
echo "CPU: $cpu"
echo "Version: $erlang_version"

elixir $(which mkerlang.exs) --otp-version=$erlang_version --os=linux --abi=$abi --arch=$cpu

if [ $? -eq 0 ]; then
    touch BUILD_OK
fi
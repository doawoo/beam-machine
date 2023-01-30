#!/bin/bash
releases=$(ls -A ./)

declare -a darwin_builds
declare -a linux_builds

for release in $releases; do
    oss=$(ls -A ./$release)
    for os in $oss; do
        cpus=$(ls -A ./$release/$os)
        for cpu in $cpus; do
            if [ "$os" = "linux" ]; then
                abis=$(ls -A ./$release/$os/$cpu)
                for abi in $abis; do
                    linux_builds+=("./$release/$os/$cpu/$abi")
                done
            else
                darwin_builds+=("./$release/$os/$cpu")
            fi
        done
    done
done

echo "Darwin Builds:" ${#darwin_builds[@]}
echo "Linux Builds:" ${#linux_builds[@]}

#### Do all linux builds

for build_path in ${linux_builds[@]}; do
    echo $build_path
    if test -f "$build_path/BUILD_OK"; then
        echo "$build_path OK [Already Built]"
    else
        orig_path=$(pwd)
        cd $build_path
        do-build-in-dir-linux.sh > build.log 2>&1
        status=$?
        [ $status -eq 0 ] && echo "$build_path OK" || echo "$build_path FAILED [Status: $status]"
        cd $orig_path
    fi
done

#### Do all MacOS builds

for build_path in ${darwin_builds[@]}; do
    if [[ -d $build_path ]]; then
        echo $build_path
        if test -f "$build_path/BUILD_OK"; then
            echo "$build_path OK [Already Built]"
        else
            orig_path=$(pwd)
            cd $build_path
            do-build-in-dir-darwin.sh > build.log 2>&1
            status=$?
            [ $status -eq 0 ] && echo "$build_path OK" || echo "$build_path FAILED [Status: $status]"
            cd $orig_path
        fi
    fi
done
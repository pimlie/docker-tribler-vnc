#!/usr/bin/env bash

dists="ubuntu
alpine"

variants="base
vnc
novnc"

function print_fail {
    echo -e "\e[31m"$1"\e[0m"
}

function print_success {
    echo -e "\e[32m"$1"\e[0m"
}


function get_github_releases {
    local releases_json=$(wget https://api.github.com/repos/Tribler/tribler/releases -O - 2>/dev/null)
    #local releases_json=$(cat releases.json)
    release_tags=$(echo $releases_json | jq -c '[ .[] | select(.prerelease == false) ] | [ .[] | .tag_name ]')
    echo ${release_tags:2:-2} | sed 's/","/\n/g'
}

function filter_releases {
    # Filter the tags we want to include in the build
    # maybe only include the latest patch version?
    all_tags=$1

    local tags=( "prerelease" )
    for tag in $all_tags; do
        _tag=${tag#v}
        major_ver=${_tag%%.*}
        _tag=${_tag#${major_ver}.}
        minor_ver=${_tag%%.*}
        _tag=${_tag#${minor_ver}.}
        patch_ver=${_tag%%.*}

        if [ $major_ver -lt 7 ]; then
            continue
        fi

        tags[${#tags[@]}]=$tag
    done

    echo "${tags[@]}"
}

function exit_on_error {
    if [ $1 -gt 0 ]; then
        echo "$2"
        exit $1
    fi

        if [ -n "$3" ]; then
        echo "$3"
    fi
}


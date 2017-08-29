#!/usr/bin/env bash

function usage {
    echo "$0 -d -v -t"
    echo "    -d    debug, dont build the images only print build commands"
    echo "    -v    verbose, show docker build output"
    echo "    -t    test image after build"
    echo ""
}

debug=false
verbose=false
runtests=false

while (( "$#" )); do
    case $1 in
        -d)
            debug=true
            shift
            ;;
        -v)
            verbose=true
            shift
            ;;
        -t)
            runtests=true
            shift
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

. functions.sh

echo -n "Retrieving releases from github"
all_tags=$(get_github_releases)
echo ", found $(echo "$all_tags" | wc -l) releases"

tags=( $(filter_releases "$all_tags") )
echo "will only build ${#tags[@]} releases (due to filtering):"
echo ${tags[@]}

echo -n "Creating docker build commands"
build_cmds=()
for dist in $dists; do
    latest=true
    for variant in $variants; do
        tags_seen=""
        img_name="tribler"
        if [ -n "$variant" ] && [ "$variant" != "base" ]; then
            img_name=$img_name"-"$variant
        fi

        for i in `seq 0 $((${#tags[@]} - 1))`; do
            tag=${tags[$i]}
            tag=${tag#v}
            minor_tag=${tag%.*}
            major_tag=${tag%%.*}

            # check that we have a numerical version and not eg a prerelease or dev version
            if [ "$tag" != "$minor_tag" ]; then
                img_tags=( $img_name":"$tag"-"$dist )

                # Also tag the latest patch release of a minor version with that version
                # e.g. if latest is v6.5.2 will also be tagged as v6.5
                if [ -z "$tags_seen" ] || [ "${tags_seen/|$minor_tag|/}" = "$tags_seen" ]; then
                    tags_seen="${tags_seen}|$minor_tag|"
                    img_tags[${#img_tags[@]}]=$img_name":"$minor_tag"-"$dist
                fi

                # Also tag the latest minor release of a major version with that version
                # e.g. if latest is v6.5.2 will also be tagged as v6
                if [ "${tags_seen/|$major_tag|/}" = "$tags_seen" ]; then
                    tags_seen="${tags_seen}|$major_tag|"
                    img_tags[${#img_tags[@]}]=$img_name":"$major_tag"-"$dist
                fi
            else
                img_tags=( $img_name":"$dist"-"$tag )
            fi

            # the github list is ordered by date, this probably means
            # the first release we encouter should be the latest
            if [ $latest = true ]; then
                if [ "$dist" = "ubuntu" ]; then
                    img_tags[${#img_tags[@]}]=$img_name":latest"
                fi
                img_tags[${#img_tags[@]}]=$img_name":"$dist"-latest"
                img_tags[${#img_tags[@]}]=$img_name":"$dist
                latest=false
            fi

            build_cmd="docker build -f Dockerfile.$dist"

            if [ "$tag" = "prerelease" ]; then
                build_cmd="$build_cmd --build-arg prerelease=true"
            else
                build_cmd="$build_cmd --build-arg tag=${tags[$i]}"
            fi

            # use empty build-args so no ports are exposed when they shouldnt
            if [ -n "$variant" ] && [ "$variant" != "base" ]; then
                build_cmd="$build_cmd --build-arg $variant=yes"

                if [ "$variant" = "vnc" ]; then
                    build_cmd="$build_cmd --build-arg NOVNC_PORT="
                fi
            else
                build_cmd="$build_cmd --build-arg VNC_PORT="
                build_cmd="$build_cmd --build-arg NOVNC_PORT="
            fi

            for j in `seq 0 $((${#img_tags[@]} - 1))`; do
                img_tag=${img_tags[$j]}    
                build_cmd="$build_cmd -t $img_tag"
            done

            build_cmd="$build_cmd ."
            build_cmds[${#build_cmds[@]}]=$build_cmd
        done
    done
done
echo ".done"

for i in `seq 0 $((${#build_cmds[@]} - 1))`; do
    cmd=${build_cmds[$i]}
    echo -n $cmd

    img_id=""
    if [ $debug = false ]; then
        if [ $verbose = true ]; then
            img_id=$($cmd)
        else
            img_id=$($cmd -q)
        fi

        exit_on_error $? "exiting, docker-build returned an error"
        echo ", image created with id $img_id"
    else
        tag=$(echo $cmd | sed -re 's/^.*?-t\s([a-z:\-]+)(.*)$/\1/')
        img_id=$(docker images -q $tag)
        echo ", image found with id $img_id"
    fi

    if [ $runtests = true ] && [ -n "$img_id" ]; then
        echo -n "Starting container"
        container_id=$(docker run --rm -it -d --init "$img_id")
        echo ".created with id $container_id"

        echo -n "Waiting 5 seconds for container to start"
        sleep 5
        echo ""

        # Doesnt work with .deb's:
        #triblerVersion=$(docker exec -it $container_id ls -alF /usr/share/tribler/Tribler/)
        #echo "Found Tribler version: $triblerVersion"

        psa="$(docker exec -it $container_id ps a)"

        failed_any_tests=false
        if [[ "$psa" != *"tribler"* ]]; then
            print_fail "Test failed, tribler not running!"
            failed_any_tests=true
        fi

        # Tests for vnc containers
        if [[ "$cmd" = *"vnc"* ]]; then
            if [[ "$psa" != *"Xvfb"* ]]; then
                print_fail "Test failed, Xvfb not running!"
                failed_any_tests=true
            fi
            if [[ "$psa" != *"openbox"* ]]; then
                print_fail "Test failed, openbox not running!"
                failed_any_tests=true
            fi
            if [[ "$psa" != *"x11vnc"* ]]; then
                print_fail "Test failed, x11vnc not running!"
                failed_any_tests=true
            fi
        fi

        # Tests for novnc containers
        if [[ "$cmd" = *"novnc"* ]]; then
            if [[ "$psa" != *"websockify"* ]]; then
                print_fail "Test failed, noVNC/websockify not running!"
                failed_any_tests=true
            fi
            if [[ "$psa" != *"nginx"* ]]; then
                print_fail "Test failed, nginx not running!"
                failed_any_tests=true
            fi
        fi

        if [ $failed_any_tests = true ]; then
            print_fail "Some tests failed, please check"
        else
            print_success "All tests succeeded"
        fi

        echo -n "Stopping container $container_id"
        docker stop $container_id
        echo ""
    fi
done

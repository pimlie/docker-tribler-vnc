#!/usr/bin/env bash

APP_NAME="Tribler"
INSTALL_PATH="/usr/share"
RELEASES_URL="https://api.github.com/repos/Tribler/tribler/releases"
PRERELEASE=$(printenv prerelease || echo "false")
TAG=""
DRYRUN=0

function usage() {
    echo "Usage: $0 -c -p TRUE/FALSE -t TAG"
    echo "    -c    Check for new version only, dont install it"
    echo "    -p    Use prerelease version, use 0 or false to disable"
    echo "    -t    Specify which tag version to install"
    echo ""
}

while (( "$#" )); do
    case $1 in
        -p)
            OPTARG=""
            if [ "${2:0:1}" != "-" ]; then
                OPTARG=$2
                shift
            fi

            if [ "$OPTARG" = "false" ] || [ "$OPTARG" = "0" ]; then
                PRERELEASE="false"
            else
                PRERELEASE="true"
            fi
            shift
            ;;
        -t)
            if [ -z "$2" ]; then
                usage
                exit 1
            fi
            TAG=$2
            shift
            shift
            ;;
        -c)
            DRYRUN=1
            shift
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

# taken from: https://unix.stackexchange.com/questions/6345
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    OS=suse
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS=redhat
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

# force OS lowercase
OS=`echo "$OS" | tr '[:upper:]' '[:lower:]'`

function os_not_supported {
    echo "$OS is not (yet) supported (by this script)"
    exit 1
}

case "$OS" in
    ubuntu|debian|alpine) echo "Detected OS: $OS $VER" ;;
    *) os_not_supported ;;
esac

function exit_on_error {
    if [ $1 -gt 0 ]; then
        echo "$2"
        exit $1
    fi

        if [ -n "$3" ]; then
        echo "$3"
    fi
}

function pkg_install {
    cmd=""
    case "$OS" in
        ubuntu|debian)
            if [ "${1:${#1}-4}" = ".deb" ]; then
                cmd="dpkg -i"
            else
                cmd="apt-get -y install"
            fi
            ;;
        alpine)        cmd="apk add --allow-untrusted" ;;
        *) os_not_supported ;;
    esac

    if [ -n "$cmd" ]; then
        $cmd $1
        return $?
        fi
    return 1
}

jq=`which jq`
retval=$?

if [ $retval -eq 1 ]; then
    echo -n "jq not found, installing."
    pkg_install jq
    exit_on_error $? "failed, exiting" "done"
fi

tmp_folder=`mktemp -d`
releases_file=$tmp_folder"/releases.json"

wget -q "$RELEASES_URL" -O "$releases_file"
exit_on_error $? "Exiting, could not retrieve releases url from github: $RELEASES_URL"

release_file=$tmp_folder"/release.json"

if [ -n "$TAG" ]; then
    cat "$releases_file" | jq -c '[ .[] | select(.tag_name == "'$TAG'") ] | first' > "$release_file"
else
    cat "$releases_file" | jq -c '[ .[] | select(.prerelease == '$PRERELEASE') ] | first' > "$release_file"
fi

if [ ! -s "$release_file" ] || [ "$(cat $release_file)" = "null" ]; then
    echo "Could not find a release for tag $TAG"
    rm -Rf "$tmp_folder"
    exit 1
fi

release_version=$(cat "$release_file" | jq -r '.tag_name' )
echo "Found $APP_NAME release "$release_version
# TODO: Compare with installed version?

if [ $DRYRUN -eq 1 ]; then
    rm -Rf "$tmp_folder"
    exit 0
fi

file_extension=""
case "$OS" in
    ubuntu|debian)
        file_extension=".deb"
        ;;
    alpine) 
        file_extension=".tar.xz"
        ;;
    *) os_not_supported ;;
esac

IFS=', ' read -r -a pkg_data <<< $(cat "$release_file" | jq -c '.assets | [ .[] | select(.name | endswith("'$file_extension'")) ] | first | [ .name, .browser_download_url ]' | awk -F\" '{print $2", "$4}')

if [ -z "${pkg_data[0]}" ]; then
    echo "Could not extract $file_extension asset from latest release"
    exit 1
fi

pkg_file=$tmp_folder"/"${pkg_data[0]}
echo -n "Retrieving ${pkg_data[0]} from github"
wget -q "${pkg_data[1]}" -O "$pkg_file"
exit_on_error $? "Exiting, could not retrieve package file from github" " done"

if [ "$file_extension" = ".tar.xz" ]; then
    echo -n "Removing old $INSTALL_PATH folder"
    rm -Rf "$INSTALL_PATH/tribler"
    mkdir -p "$INSTALL_PATH"
    echo ""

    echo -n "Extracting archive to $INSTALL_PATH"
    tar -xJ -C "$INSTALL_PATH" -f "$pkg_file"
    exit_on_error $? "Could not extract archive" "succes"

    if [ ! -L "/usr/bin/tribler" ]; then
        rm -f "/usr/bin/tribler"
    fi
    ln -s /usr/share/tribler/tribler.sh /usr/bin/tribler
else
    echo "Installing ${pkg_data[0]}"
    pkg_install "$pkg_file"
    exit_on_error $? "Exiting, could not install $APP_NAME package"
    echo "done"
fi

rm -Rf "$tmp_folder"

echo "Succesfully installed $APP_NAME "$release_version

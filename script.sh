#!/usr/bin/env bash
#shellcheck disable=SC2016
set -euo pipefail

case "$(tr "[:upper:]" "[:lower:]" <<<"${DEBUG:-}")" in
true | yes | on | 1)
    set -x
    EFD="/dev/stderr"
    ;;
esac

##region Global variable declaration(s) - constant default values

declare -r AC_VERSION="2.8.1"
declare -r AC_FILE="build/uno-choice_v$AC_VERSION-fixed.hpi"

declare -r JENKINS_HOST="http://localhost:8080"

declare -r EFD="${EFD:-/dev/null}"

##endregion

##region Help message function definition(s)

help() {
    printf "%s\n" \
        "" \
        "Jenkins Active Choices plugin parameter rendering bug Fix script" \
        "" \
        "This script is used to build, test and apply the fix for the" \
        "Jenkins Active Choices plugin parameter rendering bug." \
        "" \
        "Make sure to also check each command's help message" \
        "for more information on its usage instructions." \
        "" \
        "Usage: $0 [OPTS] {CMD}" \
        "" \
        "Options:" \
        "" \
        "  -h, --help               Show this help message and exit." \
        "" \
        "Commands:" \
        "" \
        '  build                    Build the fixed version of the AC plugin.' \
        "" \
        "                           This will build the version of the plugin" \
        "                           with the necessary changes applied to fix" \
        "                           the parameter rendering bug." \
        "" \
        "  clean                    Clean the AC plugin build artifact(s)." \
        "" \
        "                           This will remove the build artifact(s)" \
        "                           of the plugin." \
        "" \
        "  install                  Install the fixed version of the AC plugin." \
        "" \
        "                           This will install the fixed version of the" \
        "                           plugin to the Jenkins instance provided." \
        ""
}

help_build() {
    printf "%s\n" \
        "" \
        'Build the fixed version of the Active Choices plugin.' \
        "" \
        "To see additional info, check the global help message." \
        "" \
        "Usage: $0 build [OPTS]" \
        "" \
        "Options:" \
        "" \
        "  -h, --help               Show this help message and exit." \
        "" \
        "  -v, --version VER        Active Choices plugin version to build." \
        "                           [default: $AC_VERSION]" \
        ""
}

help_clean() {
    printf "%s\n" \
        "" \
        'Clean the Active Choices plugin build artifact(s).' \
        "" \
        "To see additional info, check the global help message." \
        "" \
        "Usage: $0 clean [OPTS]" \
        "" \
        "Options:" \
        "" \
        "  -h, --help               Show this help message and exit." \
        ""
}

help_install() {
    printf "%s\n" \
        "" \
        'Install the fixed version of the Active Choices plugin.' \
        "" \
        "To see additional info, check the global help message." \
        "" \
        "Usage: $0 install [OPTS]" \
        "" \
        "Options:" \
        "" \
        "  -h, --help               Show this help message and exit." \
        "" \
        "  -a, --auth AUTH          Jenkins authentication credentials." \
        "" \
        "                           If not provided, no authentication will" \
        "                           be used." \
        "" \
        "  -f, --file FILE          Active Choices plugin HPI file to install." \
        "                           [default: $AC_FILE]" \
        "" \
        "  -H, --host HOST          Jenkins host to install the plugin to." \
        "                           [default: $JENKINS_HOST]" \
        "" \
        "  -r, --restart            Restart Jenkins after installing the plugin." \
        ""
}

##endregion

##region Command function definition(s)

build() {
    ##region Local variable declaration(s)
    local version="$AC_VERSION"
    ##endregion

    ##region Named argument(s) parsing

    while [ "$#" -gt 0 ]; do
        case "$1" in
        -h | --help)
            help_build
            return
            ;;
        -v | --version)
            version="${2:?}"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*)
            printf "%s\n" \
                "Unknown option: \`$1\`" \
                'Use `--help` for more information.' \
                >&2
            return 1
            ;;
        *)
            break
            ;;
        esac
    done

    ##endregion

    ##region Positional argument(s) parsing

    if [ "$#" -gt 0 ]; then
        printf "%s\n" \
            "Unknown argument(s): \`$*\`" \
            'Use `--help` for more information.' \
            >&2
        return 1
    fi

    ##endregion

    ##region Named argument(s) validation

    if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        printf "%s\n" \
            "Invalid version: \`$version\`" \
            'Use `--help` for more information.' \
            >&2
        return 1
    fi

    ##endregion

    ##region Positional argument(s) validation
    ##endregion

    ##region Command logic

    DOCKER_BUILDKIT=1 docker build \
        -f "Dockerfile" \
        -o "build" \
        --build-arg "VERSION=$version" \
        . 2>"$EFD"

    ##endregion
}

clean() {
    ##region Local variable declaration(s)
    ##endregion

    ##region Named argument(s) parsing

    while [ "$#" -gt 0 ]; do
        case "$1" in
        -h | --help)
            help_clean
            return
            ;;
        --)
            shift
            break
            ;;
        -*)
            printf "%s\n" \
                "Unknown option: \`$1\`" \
                'Use `--help` for more information.' \
                >&2
            return 1
            ;;
        *)
            break
            ;;
        esac
    done

    ##endregion

    ##region Positional argument(s) parsing

    if [ "$#" -gt 0 ]; then
        printf "%s\n" \
            "Unknown argument(s): \`$*\`" \
            'Use `--help` for more information.' \
            >&2
        return 1
    fi

    ##endregion

    ##region Named argument(s) validation
    ##endregion

    ##region Positional argument(s) validation
    ##endregion

    ##region Command logic

    rm -rf build/* 2>"$EFD"

    ##endregion
}

install() {
    ##region Local variable declaration(s)
    local auth=""
    local file="$AC_FILE"
    local host="$JENKINS_HOST"
    local -i restart
    ##endregion

    ##region Named argument(s) parsing

    while [ "$#" -gt 0 ]; do
        case "$1" in
        -h | --help)
            help_install
            return
            ;;
        -a | --auth)
            auth="${2:?}"
            shift 2
            ;;
        -f | --file)
            file="${2:?}"
            shift 2
            ;;
        -H | --host)
            host="${2:?}"
            shift 2
            ;;
        -r | --restart)
            restart=1
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            printf "%s\n" \
                "Unknown option: \`$1\`" \
                'Use `--help` for more information.' \
                >&2
            return 1
            ;;
        *)
            break
            ;;
        esac
    done

    ##endregion

    ##region Positional argument(s) parsing

    if [ "$#" -gt 0 ]; then
        printf "%s\n" \
            "Unknown argument(s): \`$*\`" \
            'Use `--help` for more information.' \
            >&2
        return 1
    fi

    ##endregion

    ##region Named argument(s) validation

    if [ -n "$auth" ] && ! [[ "$auth" =~ ^[^:]+:.+$ ]]; then
        printf "%s\n" \
            "Invalid auth: \`$auth\`" \
            'Use `--help` for more information.' \
            >&2
        return 1
    fi

    if [ ! -s "$file" ]; then
        printf "%s\n" \
            "Invalid file: \`$file\`" \
            'Use `--help` for more information.' \
            >&2
        return 1
    fi

    if ! [[ "$host" =~ ^https?://[^/]+$ ]]; then
        printf "%s\n" \
            "Invalid host: \`$host\`" \
            'Use `--help` for more information.' \
            >&2
        return 1
    fi

    ##endregion

    ##region Positional argument(s) validation
    ##endregion

    ##region Command logic

    docker run \
        --rm -i \
        -w "/srv" \
        "eclipse-temurin:17-jdk" \
        bash -c "
            set -euo pipefail
            ${DEBUG:+set -x}
            curl -fsSLO '$host/jnlpJars/jenkins-cli.jar'
            err_log=\"\$(mktemp)\"
            if ! java -jar 'jenkins-cli.jar' \
                -s '$host' \
                ${auth:+-auth "$auth"} \
                install-plugin = \
                    -deploy \
                    ${restart:+-restart} \
                    2>\"\$err_log\"
            then
                if grep -q '^jenkins\.RestartRequiredException' \
                    \"\$err_log\" || [ -n \"$restart\" ];
                then
                    java -jar 'jenkins-cli.jar' \
                        -s '$host' \
                        ${auth:+-auth "$auth"} \
                        restart
                else
                    cat \"\$err_log\" >&2
                    return 1
                fi
            fi
        " <"$file" 2>"$EFD"
}

##endregion

##region Entry point function definition

main() {
    ##region Named argument(s) parsing

    while [ "$#" -gt 0 ]; do
        case "$1" in
        -h | --help)
            help
            return
            ;;
        --)
            shift
            break
            ;;
        -*)
            printf "%s\n" \
                "Unknown option: \`$1\`" \
                'Use `--help` for more information.' \
                >&2
            return 1
            ;;
        *)
            break
            ;;
        esac
    done

    ##endregion

    ##region Positional argument(s) parsing

    local command="${1:-}"

    case "$command" in
    build | clean | install)
        command="${command//-/_}"
        ;;
    "")
        help >&2
        return 1
        ;;
    *)
        printf "%s\n" \
            "Unknown command: \`$command\`" \
            'Use `--help` for more information.' \
            >&2
        return 1
        ;;
    esac
    ##endregion

    ##region Named argument(s) validation
    ##endregion

    ##region Positional argument(s) validation
    ##endregion

    "$command" "${@:2}"
}

##endregion

##region Execution

main "$@"

##endregion

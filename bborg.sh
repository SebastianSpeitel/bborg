#!/bin/bash
VERSION=1.3.1

function create(){
    
    local command="borg create"
    if [[ -n ${BACKUP[compression]} ]];
    then
        command="$command --compression ${BACKUP[compression]}"
    fi
    
    if [[ ${BACKUP[progress]} == "yes" ]];
    then
        command="$command --progress"
    fi
    
    local ignorefile="${BACKUP[ignorefile]}"
    if [[ -n $ignorefile ]]; then
        if [[ $ignorefile != /* ]];
        then
            ignorefile="${BACKUP[path]}/$ignorefile"
        fi
        
        local realignorefile=$(eval echo $ignorefile)
        
        if [[ -f $realignorefile ]];
        then
            command="$command --exclude-from $ignorefile"
        fi
    fi
    
    if [[ -n ${BACKUP[extraargs]} ]];
    then
        command="$command ${BACKUP[extraargs]}"
    fi
    
    if [[ -n ${BACKUP[passphrase]} ]];
    then
        export BORG_PASSPHRASE="${BACKUP[passphrase]}"
    fi
    
    if [[ -n ${BACKUP[passcommand]} ]];
    then
        export BORG_PASSPHRASE="$(eval ${BACKUP[passcommand]})"
    fi
    
    
    command="$command ${BACKUP[repo]}::${BACKUP[archive]} ${BACKUP[path]}"
    
    echo "Creating backup ${BACKUP[name]}"
    
    if [[ -z "$DRYRUN" ]];
    then
        eval "$command" || exit
    fi
    [[ -n "$DRYRUN" ]] && echo "[DRYRUN] $command"
    
}

function list(){
    local command="borg list"
    
    if [[ -n ${BACKUP[passphrase]} ]];
    then
        export BORG_PASSPHRASE="${BACKUP[passphrase]}"
    fi
    
    if [[ -n ${BACKUP[passcommand]} ]];
    then
        export BORG_PASSPHRASE="$(eval ${BACKUP[passcommand]})"
    fi
    
    command="$command ${BACKUP[repo]}"
    
    echo "Listing archives for ${BACKUP[name]}"
    
    if [[ -z "$DRYRUN" ]];
    then
        eval "$command" || exit
    fi
    [[ -n "$DRYRUN" ]] && echo "[DRYRUN] $command"
}

function read_config(){
    
    local -A BACKUP
    [[ -n $BORG_REPO ]] && GLOBAL_OPTIONS[repo]=$BORG_REPO
    GLOBAL_OPTIONS[path]="~"
    GLOBAL_OPTIONS[archive]=$(date -I)
    [[ -n $BORG_COMPRESSION ]] && GLOBAL_OPTIONS[compression]=$BORG_COMPRESSION
    [[ -n $BORG_PASSPHRASE ]] && GLOBAL_OPTIONS[passphrase]=$BORG_PASSPHRASE
    [[ -n $BORG_PASSCOMMAND ]] && GLOBAL_OPTIONS[passcommand]=$BORG_PASSCOMMAND
    GLOBAL_OPTIONS[ignorefile]=".borgignore"
    
    reset(){
        for opt in "${!BACKUP[@]}"; do
            unset BACKUP["$opt"]
        done
        for opt in "${!GLOBAL_OPTIONS[@]}"; do
            BACKUP["$opt"]=${GLOBAL_OPTIONS["$opt"]}
        done
    }
    
    backup(){
        case "$COMMAND" in
            create)
                create
            ;;
            list)
                list
            ;;
            *)
                echo "Unknown command: $COMMAND" >&2
                exit 1
            ;;
        esac
    }
    
    reset
    
    cat $1 <(echo "End") | while read line; do
        
        if [[ $line =~ ^\s*(\#.*)?$ ]];
        then
            continue
            
        elif [[ $line =~ ^\s*Backup\  ]];
        then
            if [[ -z ${BACKUP[name]} ]];
            then
                # Set options globaly
                for opt in "${!BACKUP[@]}"; do
                    GLOBAL_OPTIONS["$opt"]=${BACKUP["$opt"]}
                done
            else
                backup
            fi
            reset
            BACKUP[name]=${line#*Backup }
            
        elif [[ $line == "End" ]];
        then
            if [[ -z ${BACKUP[name]} ]];
            then
                BACKUP[name]=default
            fi
            backup
            break
            
        elif [[ $line =~ ^\s*Repo\  ]];
        then
            BACKUP[repo]=${line#*Repo }
            
        elif [[ $line =~ ^\s*Path\  ]];
        then
            BACKUP[path]=${line#*Path }
            
        elif [[ $line =~ ^\s*Archive\  ]];
        then
            BACKUP[archive]=${line#*Archive }
            
        elif [[ $line =~ ^\s*Compression\  ]];
        then
            BACKUP[compression]=${line#*Compression }
            
        elif [[ $line =~ ^\s*Passphrase\  ]];
        then
            BACKUP[passphrase]=${line#*Passphrase }
            
        elif [[ $line =~ ^\s*PassCommand\  ]];
        then
            BACKUP[passcommand]=${line#*PassCommand }
            
        elif [[ $line =~ ^\s*IgnoreFile\  ]];
        then
            BACKUP[ignorefile]=${line#*IgnoreFile }
            
        elif [[ $line =~ ^\s*Progress\  ]];
        then
            BACKUP[progress]=${line#*Progress }
            
        elif [[ $line =~ ^\s*ExtraArgs\  ]];
        then
            BACKUP[extraargs]=${line#*ExtraArgs }
            
            # Append global extra args
            if [[ -n ${GLOBAL_OPTIONS[extraargs]} ]];
            then
                BACKUP[extraargs]="${BACKUP[extraargs]} ${GLOBAL_OPTIONS[extraargs]}"
            fi
            
        else
            echo "Unknown option: $line" >&2
        fi
    done
    
}

function parse_options(){
    if getopt --test > /dev/null; then
        echo "GNU getopt not installed" >&2
        exit 1
    fi
    
    local SHORT_OPTIONS=vh
    local LONG_OPTIONS=dry-run,verbose,help,version
    local opts=$(getopt -o $SHORT_OPTIONS -l $LONG_OPTIONS -n "$0" -- "$@")
    eval set -- "$opts"
    while [ $# -gt 0 ]; do
        case "$1" in
            -v|--verbose)
                VERBOSE=1
                shift
            ;;
            -h|--help)
                echo "Usage: $0 [--dry-run] [--verbose] [--help] [<command>]"
                exit 0
            ;;
            --version)
                echo "bborg $VERSION"
                exit 0
            ;;
            --dry-run)
                DRYRUN=1
                shift
            ;;
            --)
                shift
                
                case "$1" in
                    create|c)
                        COMMAND=create
                        shift
                    ;;
                    list|l)
                        COMMAND=list
                        shift
                    ;;
                    *)
                        COMMAND=create
                    ;;
                esac
                
                GLOBAL_OPTIONS[extraargs]=${@}
                break
            ;;
            *)
                echo "Unknown option $1" >&2
                exit 1
            ;;
        esac
    done
}


declare -A GLOBAL_OPTIONS

parse_options "$@"


if [[ -n "$BORG_CONFIG_DIR" ]];
then
    CONFIG_PATH="$BORG_CONFIG_DIR/backups"
elif [[ -n "$BORG_BASE_DIR" ]];
then
    CONFIG_PATH="$BORG_BASE_DIR/.config/borg/backups"
else
    CONFIG_PATH="$HOME/.config/borg/backups"
fi

read_config $CONFIG_PATH

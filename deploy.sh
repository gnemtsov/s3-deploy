#! /bin/bash

# This script is used for deployment
# It uploads files to the bucket, corrects timestamps of files included in HTML,
# bundles js scripts.

# To use this script you need a config file:
#    .service/deploy.config :
#              bucket=mybucket
#          exclude=.git/*,.service/*,secret_file    # files and directories to exclude from uploading
#          bundle=script1.js,script2.js,script3.js  # scripts listed here would be removed from HTML files
#                                                   # and bundeled into a single file, which will be minified
#                                                   # A separate bundle is created for every HTML file

# You also need to install babel-cli and babel-preset-minify from npm:
#     npm install --save-dev babel-cli
#     npm install --save-dev babel-preset-minify

# If you want this script to correct timestamps in HTML,
# you should include them with a ?v=<number> :
# <link rel="apple-touch-icon" sizes="180x180" href="/apple.png?ver=v123">

# You can use following options:
#     -v,--verbose   - for detailed output
#     -n,--no-upload - do not upload result into bucket

VERBOSE=false
NO_UPLOAD=false
PACKAGE="package"
TMP="$PACKAGE/.temp"
CONFIG=".service/deploy.config"
PATH="$PATH:./node_modules/.bin"

function log() {
        local message=$1
        if [ "$VERBOSE" = true ] ; then
                echo $message
        fi
}

function error() {
        echo "$1"
}

bundle_n=0
function create_bundle() {
        local html_source_file=$1
        echo "Creating bundle for \"$html_source_file\"..."

        #this is a grep command
        local grep0="$BUNDLE_GREP $html_source_file"
        #name before babel
        local bundle_before_babel="$TMP/ab.doc.bundle$bundle_n.js"
        #name to be used in html
        local bundle_after_babel_src="scripts/ab.doc.bundle$bundle_n.min.js"
        #name after babel
        local bundle_after_babel="$PACKAGE/$bundle_after_babel_src"
        $grep0 | while read -r x; do
                log "Adding \"$x\" to bundle"
                echo -en "//$x\n" >> $bundle_before_babel
                cat $x >> $bundle_before_babel
                echo -en "\n" >> $bundle_before_babel
        done

        # if files for bundling were found in html
        if [ -f $bundle_before_babel ]
        then
                #putting bundle through babel
                log "\"$bundle_before_babel\" >===(babel)===> \"$bundle_after_babel\""
                npx --no-install babel "$bundle_before_babel" --out-file "$bundle_after_babel" --presets=minify

                #removing bundeled scripts from file
                log "Removing old scripts from \"$html_source_file\"..."
                sed="sed -i.bak -e \""
                grep1="$BUNDLE_GREP -n $html_source_file"
                lines=($($grep1 | cut -f1 -d:))
                for ln in ${lines[*]}
                do
                        sed="$sed$ln d;"
                done
                sed="$sed\" $html_source_file"
                eval $sed

                #adding bundle instead of old scripts
                log "Adding bundle to \"$html_source_file\"..."
                current_time=$(stat -c %Y .$filename)
                sed -i.bak -e "${lines[0]}i<script src=\"/$bundle_after_babel_src?ver=v$current_time\"></script>" $html_source_file
                rm $html_source_file.bak

                bundle_n=$(expr $bundle_n + 1)
        fi
}

function update_versions() {
        local html_source_file=$1
    local found=0
    local modified=0
    #set file versions according to modify timestamp
    echo "Updating file versions in \"$html_source_file\"..."
    grep -oE "\"[^\"]+\?ver=v[^\"]+\"" $html_source_file | while read -r href ; do
        ((found++))
        local href="${href//\"/}"
        local current_timestamp=$(echo $href | grep -oE "[0-9]+$")
        local filename="${href/?ver=v[0-9]*/}"
        local new_timestamp=$(stat -c %Y $PACKAGE$filename)
        log $new_timestamp
        if [ "$current_timestamp" != "$new_timestamp" ]
        then
            ((modified++))
            sed -i "s|$filename?ver=v[0-9]*|$filename?ver=v$new_timestamp|g" $html_source_file
        fi
        log "Found $found, modified $modified"
    done

}

function init_directory() {
        local path=$1
        log "Creating empty directory \"$path\""
        if [ -d "$path" ]; then
                log "\"$path\" already exists. Removing \"$path\""
                rm -rf "$path"
        fi
        mkdir "$path"
}

echo "==== Initialization ===="

# check flags
while [[ $# -gt 0 ]]
do
        key="$1"

        case $key in
                -v|--verbose)
                        VERBOSE=true
                        shift
                        ;;
                -n|--no-upload)
                        NO_UPLOAD=true
                        shift
                        ;;
                *)
                        shift
                        ;;
        esac
done

if [ ! -f $CONFIG ]; then
        error "Could not load config \"$CONFIG\"."
        exit -1
fi
. $CONFIG
exclude=${exclude//,/ }

if ! npm list babel-preset-minify > /dev/null ; then
        error "babel-preset-minify is not installed"
        exit -2
fi

if ! npm list babel-cli > /dev/null ; then
        error "babel-cli is not installed"
        exit -3
fi

if [ -v bundle ]; then
        log "Using bundle"
        bundle=${bundle//,/ }

        BUNDLE_GREP="grep "
        for b in $bundle
        do
                BUNDLE_GREP="$BUNDLE_GREP -o -e $b "
        done
else
        log "Not using bundle"
fi

# create package and tmp directories
echo "==== Creating temporary directories ===="
init_directory "$PACKAGE"
init_directory "$TMP"

# copying everything into package excluding files listed in $exclude
copy="tar -c --exclude \"$PACKAGE\" "
files_to_exclude="$exclude $bundle" #( "${exclude[@]}" "${bundle[@]}" )
for e in $files_to_exclude
do
        log "Excluding $e"
        copy="$copy --exclude \"$e\""
done
copy="$copy . | tar -x -C $PACKAGE"
eval $copy

echo "==== Working with HTML files ===="
for f in $(find $PACKAGE -name '*.html')
do
        if [ -v bundle ]; then
                create_bundle $f
    fi
        update_versions $f
done

rm -rf $TMP

if [ "$NO_UPLOAD" = false ] ; then
        echo "==== S3 upload ===="  #upload to S3
        aws s3 sync $PACKAGE s3://"$bucket"/ --delete --acl public-read --exclude "*.html"
        aws s3 sync $PACKAGE s3://"$bucket"/ --delete --acl public-read --cache-control max-age=0 --exclude "*" --include "*.html"
fi

echo "==== Cleaning up ===="
rm -rf $PACKAGE

exit 0

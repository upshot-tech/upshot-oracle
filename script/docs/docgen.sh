#!/usr/bin/env bash 
set -e
[ -d "forgedocs" ] && rm -r forgedocs && echo "Removed old forgedocs directory"
[ -d "forgedocs2" ] && rm -r forgedocs2 && echo "Removed old forgedocs2 directory"


# generate the docs
echo -e "Generating documentation via forge...\n"
forge doc --build --out forgedocs
# clean up and minimize the docs we want to publish
echo -e "Cleaning up unnecessary files and folders\n"
mv forgedocs/src/contracts forgedocs2
rm -r forgedocs/
mv forgedocs2 forgedocs
find forgedocs -name "README.md" -exec rm {} \;
rm -r forgedocs/test

# I checked there are no duplicate files. So we can take the name of the page to be the name of the file
echo -e "Prepping forgedocs2 directory\n"
mkdir -p forgedocs2/oracle

function modifyFile() {
    # set up variables
    read -r -d '' HEADER << EOM
---
title: TITLE
category: CATEGORY
parentDoc: SUBCATEGORY
---
EOM
    ORACLE_CATEGORY="645a9ad75e485f0635d9bf33"

    FILE_NAME=$(basename "$1" | sed "s#.md##" | sed -E "s#(contract|interface|struct|error|enum|function|abstract|library)\.##")
    echo $FILE_NAME
    echo "Modifying $FILE_NAME in oracle category"

    # prepend the file with the appropriate readme.io header
    FILLED_IN_HEADER=$(echo "$HEADER" | sed "s#TITLE#$FILE_NAME#" | sed "/parentDoc: SUBCATEGORY/d" | sed "s#CATEGORY#$ORACLE_CATEGORY#" );
    OUT_FILE_PATH="forgedocs2/oracle/$FILE_NAME.md"
    echo "$FILLED_IN_HEADER" > "$OUT_FILE_PATH"
    tail -n +2 "$1" >> "$OUT_FILE_PATH"
    sed -i -e 's/^#//' "$OUT_FILE_PATH"
    sed -i -r 's#\[([a-zA-Z0-9]+)\]\(\/forgedocs\/([a-zA-Z0-9\.\/\_\-]+).md\)#[\1](/reference/\L\1)#g' "$OUT_FILE_PATH"
}

echo -e "Modifying each file and copying result to forgedocs2\n\n"
export -f modifyFile
find forgedocs -type f -exec bash -c "modifyFile \"{}\"" \;

echo -e "\n Done! \n"

#!/bin/bash

RELEASE_VERSION="$1"

# Delete the first 8 lines from temp_change.md
sed -i '1,8d' temp_change.md
# Reverse the order of lines in the file (last line becomes first, etc.)
sed -i '1h;1d;$!H;$!d;G' temp_change.md
# Convert "**Full Changelog**: URL" format to markdown link format "[Full Changelog](URL)"
sed -i -re 's/\*\*Full Changelog\*\*: (.*)/\[Full Changelog\]\(\1\)\n/' temp_change.md
# Delete everything from "## New Contributors" line to the end of file
sed -i '/## New Contributors/,$d' temp_change.md
# Convert GitHub changelog entries from "* description by @username in pull/URL/number" 
# to "- description [#number](pull/URL/number) ([username](https://github.com/username))" format
sed -i -re 's/^\*(.*)\sby\s@(.*)\sin\s(.*\/pull\/)(.*)/-\1 [\\#\4](\3\4) ([\2](https:\/\/github.com\/\2))/' temp_change.md

cp temp_change.md changelog_temp.txt
# Append existing CHANGELOG.md content (excluding first line) to temp_change.md
cat CHANGELOG.md | sed '1d' >> temp_change.md
# Create new CHANGELOG.md with header containing version and date, followed by processed changes
printf "# Changelog\n\n## [v$RELEASE_VERSION](https://github.com/Musholic/LastEpochPlanner/tree/v$RELEASE_VERSION) ($(date +'%Y/%m/%d'))\n\n" | cat - temp_change.md > CHANGELOG.md
# Convert changelog entries from markdown link format to simplified "* description (username)" format
sed -i -re 's/^- (.*) \[.*\) \(\[(.*)\]\(.*/* \1 (\2)/' changelog_temp.txt
# Create new changelog format: add version header, remove lines 2-3, format section headers, remove ## headers with following line, prepend to existing changelog
echo "VERSION[$RELEASE_VERSION][\`$(date +'%Y/%m/%d')\`]" | cat - changelog_temp.txt | sed '2,3d' | sed -re 's/^### (.*)\r/--- \1 ---/' | sed -e '/^##.*/,+1 d' | cat - changelog.txt > changelog_new.txt
rm temp_change.md
rm changelog_temp.txt
mv changelog_new.txt changelog.txt
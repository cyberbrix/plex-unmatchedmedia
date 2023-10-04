# Plex Unmatched Media Detection


This script will check the Plex DB for the following issues:

1. Video files not found in Plex
2. Plex conent missing a file
3. Missing Plex metadata - movies or shows without a proper title.

Requirements: sqlite3

Run this with a '-s' to use in a script. Only found issues will be displayed.

Options:

-s  use in a script. Only found issues will be displayed.

-y find content missing year. Otherwise only title/sort title issues will be found

-L list libraries for single library look up

-l=N only run aginast a specific library (N). use -L to list library numbers

Caveats:

It checks for video files over 2 MB at the moment. May be upped to 10 MB


#!/bin/bash
## upload
echo RSYNC
rsync -avze ssh ~/rec user@host:~/Share
## do something
# here
echo DONE
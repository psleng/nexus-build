# REPO MAINTENANCE

This directory contains programs useful for repository maintenance.

### merge-from-upstream.py

This will automatically merge all vyos upstream repositories
used by package-build-iGOS that are in use into our "current"
branch (for the most part).  If all merges succeed, which they
normally should because that branch should effectively be a copy
of the vyos branch, it will tell you which got updated so you have
a chance to go each one of them and do the `git commit` and `git push`.

# REPO MAINTENANCE

This directory contains programs useful for repository maintenance.

### merge-from-upstream

This will automatically merge all vyos upstream repositories
used by package-build-iGOS that are in use into our "current"
branch (for the most part).  If all merges succeed, which they
normally should because that branch should effectively be a copy
of the vyos branch, it will tell you which got updated so you have
a chance to go each one of them and do the `git commit` and
then switch to `psl-master` (typically) and do a `git merge current`
(typically).

However, see below before doing a `git push` on them.

NOTE: There will be a a `work/TODO` file created that contains
these instructions.

### tomldiff

After running `merge-from-upstream` this will compare all
package.toml files used by package-build-iGOS to the corresponding
vyos-build/scripts/package-build version so you can check
if VyOS has changed anything.  Hopefully the only difference you
will see is that the URL "/vyos/" part has changed to "/psleng/".

This should be done *before* actually pushing upstream changes
to make sure nothing breaks.

### gitserv

Type `./gitserv` to start a local git server for the repositories.
It will display a url that you can use for cloning.

You can then temporarily hack the corresponding package.toml files
under ../package-build-iGOS/ to use that url instead.

The idea is that you can do a "make clean all" and confirm that
the build is not broken without having to push all the changes
to github first, risking broken builds for everyone.

For example, ../package-build-iGOS/libvyosconfig/package.toml
could be hacked like this (the 10.10.x.x will be the address
of your Mac VM indicated above, or maybe a lab address):

	# TODO HACK
	#scm_url = "https://github.com/psleng/libvyosconfig"
	scm_url = "git://10.10.200.53/libvyosconfig"

Be sure to restore the files when done.

#!/usr/bin/python3
'''
Merge from upstream on all iGOS packages.
'''
import os
from subprocess import run
from pathlib import Path
try:
    import tomli
except ModuleNotFoundError:
    os.system('sudo apt install python3-tomli')
    import tomli


# All the repository merging takes place under this directory.
WORKDIR = 'work'


def findup(targ: str) -> (Path | None):
    '''
    Look upwards from the current directory until a file or
    directory "targ" is found.  Returns resulting path or None
    '''
    dirpath = Path('.')
    root = Path('/')
    while dirpath.resolve() != root:
        dst = Path(dirpath, targ)
        if dst.exists():
            return dst
        dirpath = dirpath.joinpath('..')
    return None


def merge_from_upstream(dpkg: dict) -> (str | None):
    '''
    Do the merge from upstream work.
    '''
    workdir = Path(WORKDIR, dpkg['name'])
    if os.path.exists(workdir):
        print(f' I: directory "{workdir}" already exists; skipping')
        return str(workdir)

    name = dpkg['name']
    url = dpkg['scm_url']

    # We *could* use the python "git" module here, but it is likely
    # easier for humans to understand what is going on by using
    # git cli directly.

    # Clone ours (psleng)
    if 'psleng' not in url:
        print(f' W: Cannot merge {url} for {name} because'
              ' it is not a psleng repo')
        return None

    print(f' I: Cloning {url} for {name}')
    run(['git', 'clone', '-q', url, workdir], check=True)

    cwd = os.getcwd()
    try:
        os.chdir(workdir)
        # Add the corresponding upstream, defaulting to vyos
        upstream = dpkg.get('scm_url_upstream',
                            f'https://github.com/vyos/{name}.git')

        run(['git', 'remote', 'add', 'upstream', upstream], check=True)
        run(['git', 'fetch', '-q', '--tags', '--all'], check=True)
        r = run(['git', 'branch', '--show-current'],
                capture_output=True, check=True)
        origbranch = r.stdout.decode().strip()

        # Decide on the name of the upstream branch.
        # Prefer "current" if available remotely, otherwise use existing.
        # This happens for packages like libmnl
        branch = 'current'
        r = run(['git', 'branch', '--list', '--remotes'],
                capture_output=True, check=True)
        if f'upstream/{branch}' not in r.stdout.decode():
            # Use existing psleng branch if upstream has it
            print(f' I: Cannot find upstream/{branch}')
            r = run(['git', 'branch', '--show-current'],
                    capture_output=True, check=True)
            branch = r.stdout.decode().strip()
            if branch == 'psl-master':
                # Will not exist upstream.  Pick master or first upstream.
                upstreams = os.listdir('.git/refs/remotes/upstream')
                print(f' I: available upstream branches: {upstreams}')
                if 'master' in upstreams:
                    branch = 'master'
                else:
                    branch = upstreams[0]
            print(f' I: Using {branch} as the upstream')

        # Make the branch if not already in place
        if not Path(f'.git/refs/heads/{branch}').exists():
            print(f' I: No "{branch}" branch; making it')
            r = run(['git', 'checkout', '-q',
                     '--track', f'origin/{branch}'])
            if r.returncode:
                print(f' I: Failed; falling back to {origbranch}')
                branch = origbranch

        if branch == 'psl-master':
            # No branch found
            print(' E: Cannot find a reasonable upstream branch to merge')
            exit(1)

        # Finally, do the merge from upstream
        run(['git', 'merge', '-q', '--no-commit', f'upstream/{branch}'],
            check=True)
        print(' I: Merge succeeded!')

    finally:
        os.chdir(cwd)

    return str(workdir)


################################

# Find top level directory
topdir = findup('.git')
if not topdir:
    raise FileNotFoundError('.git')
topdir = topdir.parent

# .defs.mk should be there
defsmk = topdir.joinpath('.defs.mk')
if not Path(defsmk).exists():
    print('E: Cannot locate .defs.mk')
    exit(1)

# Parse IGOS_PKGS from .defs.mk
igos_pkgs = []
with open(defsmk) as fp:
    for i in fp.readlines():
        if not i.startswith('IGOS_PKGS'):
            continue
        # Take value portion, remove leading/trailing "'", listify
        igos_pkgs = i.split('=', 1)[-1].strip().strip("'").split()

if not igos_pkgs:
    print(f'E: Cannot find IGOS_PKGS in {defsmk}')
    exit(1)

# The directory containing packages with package.toml files
IGOSPATH = Path(topdir, 'package-build-iGOS')

# Create the new workdir
if Path(WORKDIR).exists():
    print(f'E: Directory "{WORKDIR}" already exists from a previous run.')
    print('E: Examine it and either push the changes in it or remove it.')
    exit(1)
os.mkdir(WORKDIR)

# Try to merge from upstream all the repos listed in the packages
workdirs = []
for pkg in igos_pkgs:
    print(f'\nI: Processing {pkg}')

    pkgtoml = Path(IGOSPATH, pkg, 'package.toml')
    if not pkgtoml.exists():
        print(f'E: {pkgtoml} not found but is in {defsmk}!')
        exit(1)

    # Parse the toml
    toml = tomli.load(open(pkgtoml, 'rb'))
    pkgs: dict = toml['packages']
    for dpkg in pkgs:
        d = merge_from_upstream(dpkg)
        if d:
            workdirs.append(d)

# Special case: vyos-build (does not use package.toml)
# Cook up what the parsed package.toml part would look like.
dpkg = {'name': 'vyos-build',
        'scm_url': 'git@github.com:psleng/vyos-build'}
print(f'\nI: Processing {dpkg["name"]}')
d = merge_from_upstream(dpkg)
if d:
    workdirs.append(d)

# It all worked.  Print a list of directories needing to be committed/pushed.
topush = []
for workdir in workdirs:
    if Path(workdir, '.git', 'MERGE_HEAD').exists():
        topush.append(workdir)

print('==============')
if topush:
    print('The following directories need to be committed and pushed '
          'via "push --all":\n')
    for i in topush:
        print(f'\t{i}')

    print('\nThis will bring us up to date with the VyOS upstream.')
    print('After that, you can go into each and try merging that')
    print('into the corresponding psleng branch.')
    print()
    print('WARNING: before doing this, make sure that VyOS is actually')
    print('managing to make a daily build or you will be pulling broken code.')
    print('Look here:')
    print('\thttps://vyos.net/get/nightly-builds/')
    print()
    print('NOTE you should also manually examine all package.toml files under')
    print(IGOSPATH, 'to see if they have changed on the corresponding')
    print('VyOS side:')
    print('\tvyos-build/scripts/package-build')

else:
    print('No changes needs to be committed/pushed.')

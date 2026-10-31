# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security problem. Email **contact@yakupbulbul.com** with:

- what you found and which version of Vervain you used,
- steps to reproduce it,
- what you think the impact is.

I will reply as soon as I can, usually within a few days, and I will tell you when a fix is released. If you prefer, you can also use GitHub's private vulnerability reporting on the Security tab of this repository.

## What counts

Vervain moves files to the Trash, so the issues I care about most are the ones that could make it:

- remove something the user did not select, or something in a protected location,
- follow a symlink out of the folder that was scanned,
- run a command built from text read from disk or from the network,
- make a network request other than the update check.

## Supported versions

Only the latest release gets security fixes. Update with `brew upgrade vervain` or download the newest DMG from the [releases page](https://github.com/yakupbulbul/Vervain/releases/latest).

# VS Code Server CentOS 7 glibc compatibility bundle

A self-contained, user-space compatibility runtime for using the current VS Code Remote-SSH server on CentOS 7 x86_64 systems without root access. It keeps its glibc, dynamic loader, and patching tool under your home directory; it does not replace system libraries or require Conda.

## Install

Extract this repository or the release archive, then run:

    tar -xzf vscode-server-centos7-glibc-compat.tar.gz
    cd vscode-server-centos7-glibc-compat
    bash install.sh

The installer places the runtime in `~/.vscode-server/centos7-glibc`, backs up an existing `.bashrc`, and adds one line to load the runtime settings for SSH sessions. It also safely migrates already-downloaded VS Code Server Node executables. Run it again after a VS Code update if needed. Restart the Remote-SSH connection after installation.

The matching VS Code Server is downloaded by VS Code Remote-SSH and is not included here. Network access for that download is still required.

## Portability and scope

The archive includes the runtime payload and `install.sh`; it does not depend on the machine where it was assembled, a Conda environment, or files outside the extracted directory. It is intended for x86_64 Linux with CentOS 7's kernel and shell environment. This is a compatibility workaround, not an official Microsoft-supported installation path. It does not modify system glibc, system-wide configuration, or `LD_LIBRARY_PATH`.

To remove it, delete `~/.vscode-server/centos7-glibc` and remove the corresponding source line from `~/.bashrc`.

## Third-party components

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for component and license information. Before redistributing the bundled binaries publicly, review and satisfy the applicable source and notice obligations.

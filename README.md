# Ansible role: rhsso_cli

Configures a command line script that facilitates interacting with RHSSO, providing the ability for such things as getting access tokens.

## rhsso_cli usage

### Get an access token

Example:
```
$ rhsso_cli --rhsso_host_url=https://my-rhsso-server-hostname --rhsso_realm=my_realm get_access_token --client_id=my_client
```
Without having any relevant environment variables set, this will prompt the user for the client secret.

## Requirements

* This role requires root access by default (unless configured to install into a directory owned by the ansible user - see Role Variables section), so either run it in a playbook with a global `become: true`, or invoke the role with `become: true`.

## Role Variables

**install_bin_dir**

    adrianjuhl__rhsso_cli__install_bin_dir: "/usr/local/bin"

The directory where rhsso_cli is to be installed.

rhsso_cli could alternatively be installed into a user's directory, for example: `adrianjuhl__rhsso_cli__install_bin_dir: "{{ ansible_env.HOME }}/.local/bin"`, in which case the role will not need root access.

**rhsso_cli_executable_name**

    adrianjuhl__rhsso_cli__rhsso_cli_executable_name: "rhsso_cli"

The name that the executable is to be installed as.

## Dependencies

None.

## Example Playbook
```
- hosts: servers
  roles:
    - { role: adrianjuhl.rhsso_cli, become: true }

or

- hosts: servers
  tasks:
    - name: Install rhsso_cli
      include_role:
        name: adrianjuhl.rhsso_cli
        apply:
          become: true

or (install into the user's ~/.local/bin directory)

- hosts: servers
  tasks:
    - name: Install rhsso_cli
      include_role:
        name: adrianjuhl.rhsso_cli
      vars:
        adrianjuhl__rhsso_cli__install_bin_dir: "{{ ansible_env.HOME }}/.local/bin"
```

## Extras

### Install script

For convenience, a bash script is also supplied that facilitates easy installation of rhsso_cli on localhost (the script executes ansible-galaxy to install the role and then executes ansible-playbook to run a playbook that includes the rhsso_cli role).

The script can be run like this:
```
$ git clone git@github.com:adrianjuhl/ansible-role-rhsso-cli.git
$ cd ansible-role-rhsso-cli
$ .extras/bin/install_rhsso_cli.sh
```

## License

MIT

## Author Information

[Adrian Juhl](http://github.com/adrianjuhl)

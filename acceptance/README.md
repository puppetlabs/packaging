# Acceptance Testing

## Running Them

At this point, we're only testing public build servers. We're testing
that they install correctly by running installation & using some
simple smoke tests against them.

To run them, just run rake (in the acceptance directory). The default
task points to our public testing, which will run automatically with
the defaults. If you'd like to change any settings, checkout the next
section.

## Customizing a Run

There are two values that are customizable in the public testing rake
task. Those are included below as sub-sections. If you'd like to
customize more than that, please run beaker itself rather than using
rake.

### Beaker Hosts

By default, beaker will use the `ubuntu1604-64a` beaker-hostgenerator
string. This will generate a beaker hosts file using the vmpooler to
provision the host.

To change this, use the `BEAKER_HOSTS` environment variable. Whatever
you have as that value will be used as the value to beaker's `--hosts`
command line option. For more information on beaker's hosts files,
checkout our
[Creating a Test Environment doc](https://github.com/puppetlabs/beaker/blob/master/docs/tutorials/creating_a_test_environment.md).

### Tests

By default, beaker will use the `tests` folder in this directory. This
means it will run all tests in that folder.

To change this, you can specify either the `TESTS` or `TEST` environment
variable. Whatever you enter here will be used for beaker's `--tests`
argument.

### Keyfile

This is the keyfile that beaker will use to ssh to the Systems Under
Test (SUTs). If you don't provide one, then this argument won't be
passed to beaker. You can set this using the `BEAKER_KEYFILE`
environment variable.

### Log Level

This is beaker's log output level. If you don't provide a setting,
beaker's default will be used as the option won't be provided. You
can set this with the `BEAKER_LOG_LEVEL` environment variable.

## Public Test Customization: Installation

These values are ones used by the public builds server tests,
specifically to control the versions of our software installed on the
Systems Under Test (SUTs).

### Puppet-Agent Version

By default, the public test pre-suite uses '1.8.0' as the puppet-agent
version. To change this, use the `PUPPET_AGENT_VERSION` environment
variable.

### Puppet Version

By default, the public test pre-suite uses '4.8.0' as the puppet 
version. To change this, use the `PUPPET_VERSION` environment variable.

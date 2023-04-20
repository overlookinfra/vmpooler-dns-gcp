# vmpooler-dns-gcp

- [vmpooler-dns-gcp](#vmpooler-dns-gcp)
  - [Requirements](#requirements)
  - [Usage](#usage)
  - [Update the Gemfile Lock](#update-the-gemfile-lock)
  - [Submitting Issues](#submitting-issues)
  - [Releasing](#releasing)
  - [License](#license)

## Requirements

1. A Google Cloud Project with the [Cloud DNS](https://cloud.google.com/dns/) enabled.
2. A custom IAM role with the permissions listed in `util/vmpooler-dns-gcp-role.yaml`.
3. A service account assigned to the custom role above.
4. A service account key, using the account above, exported as `GOOGLE_APPLICATION_CREDENTIALS` where VMPooler is run.

## Usage

Example dns config setup:

```yaml
:dns_configs:
  :example:
    dns_class: gcp
    project: vmpooler-example
    domain: vmpooler.example.com
    zone_name: vmpooler-example-com
```

Examples of deploying VMPooler with dns configs can be found in the [puppetlabs/vmpooler-deployment](https://github.com/puppetlabs/vmpooler-deployment) repository.

## Update the Gemfile Lock

To update the `Gemfile.lock` run `./update-gemfile-lock`.

Verify, and update if needed, that the docker tag in the script and GitHub action workflows matches what is used in the [vmpooler-deployment Dockerfile](https://github.com/puppetlabs/vmpooler-deployment/blob/main/docker/Dockerfile).

## Submitting Issues

Please file any issues or requests in Jira at <https://puppet.atlassian.net/jira/software/c/projects/POOLER/issues> where project development is tracked across all VMPooler related components.

## Releasing

Follow these steps to publish a new GitHub release, and build and push the gem to <https://rubygems.org>.

1. Bump the "VERSION" in `lib/vmpooler-dns-gcp/version.rb` appropriately based on changes in `CHANGELOG.md` since the last release.
2. Run `./release-prep` to update `Gemfile.lock` and `CHANGELOG.md`.
3. Commit and push changes to a new branch, then open a pull request against `main` and be sure to add the "maintenance" label.
4. After the pull request is approved and merged, then navigate to Actions --> Release Gem --> run workflow --> Branch: main --> Run workflow.

## License

vmpooler-dns-gcp is distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html). See the [LICENSE](LICENSE) file for more details.

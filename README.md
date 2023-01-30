# vmpooler-dns-google-clouddns

- [vmpooler-dns-google-clouddns](#vmpooler-dns-google-clouddns)
  - [Usage](#usage)
  - [Update the Gemfile Lock](#update-the-gemfile-lock)
  - [Releasing](#releasing)
  - [License](#license)

## Usage

Examples of deploying VMPooler with extra providers can be found in the [puppetlabs/vmpooler-deployment](https://github.com/puppetlabs/vmpooler-deployment) repository.

## Update the Gemfile Lock

To update the `Gemfile.lock` run `./update-gemfile-lock`.

Verify, and update if needed, that the docker tag in the script and GitHub action workflows matches what is used in the [vmpooler-deployment Dockerfile](https://github.com/puppetlabs/vmpooler-deployment/blob/main/docker/Dockerfile).

## Releasing

Follow these steps to publish a new GitHub release, and build and push the gem to <https://rubygems.org>.

1. Bump the "VERSION" in `lib/vmpooler-dns-google-clouddns/version.rb` appropriately based on changes in `CHANGELOG.md` since the last release.
2. Run `./update-gemfile-lock` to update `Gemfile.lock`.
3. Run `./update-changelog` to update `CHANGELOG.md`.
4. Commit and push changes to a new branch, then open a pull request against `main` and be sure to add the "maintenance" label.
5. After the pull request is approved and merged, then navigate to Actions --> Release Gem --> run workflow --> Branch: main --> Run workflow.

## License

vmpooler-dns-google-clouddns is distributed under the [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html). See the [LICENSE](LICENSE) file for more details.

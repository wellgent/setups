# Wellgent setups

The files of the setups on [wellgent.ai](https://wellgent.ai/setups).

A setup is a list of steps, and each step has a prompt for your agent.
Some steps come with files, such as a shell config or an agent's settings.
This repo holds those files, one folder per setup.

## Setups

- [Terminal setup](terminal/) - An opinionated terminal setup to use across machines, Mac or Linux. Steps on [wellgent.ai/setups/terminal](https://wellgent.ai/setups/terminal).
- [Coordinate agentic work with wayfinder](wayfinder/) - Take complex work from a loose idea to done, across as many sessions and agents as it takes. Steps on [wellgent.ai/setups/wayfinder](https://wellgent.ai/setups/wayfinder).

## Layout

A setup's folder sorts its files by where they go.

- `home/` - files that go under your home folder, at the same path. `terminal/home/.zshrc` goes to `~/.zshrc`.
- `repo/` - files that go into the repo the setup configures, at the same path.

The `README.md` in a setup's folder lists every file with its destination.

## Using the files

Follow a setup's steps on wellgent.ai. Each step's prompt tells your agent what to do with the step's files.
Your agent merges a file into what you already have and keeps your own lines.

Every file comes from a setup in daily use, with private and machine-specific parts left out.

## Changes

A change to a setup arrives as one commit, so a folder's history shows what changed in that setup.
The files are published from the setups themselves, and nobody edits them in this repo.

Found a problem? [Open an issue](https://github.com/wellgent/setups/issues).
A pull request is closed with a note, since a fix is made in the setup and arrives with the next publish.

## License

[MIT](LICENSE)

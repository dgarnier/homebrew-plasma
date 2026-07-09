# Darren's  Plasma Homebrew Tap


## How do I install these formulae?

Just install from the tap, or use the whole tap.  Given recent changes in brew, you will also need to "trust" this repository.


```sh
brew install dgarnier/plasma/<formula>
brew trust dgarnier/plasmas/<formula>
```

Or 

```sh
brew tap dgarnier/plasma
brew trust dgarnier/plasma
brew install <formula>
```

Or, in a `brew bundle` `Brewfile`:

```ruby
tap "dgarnier/plasma"
brew "<formula>"
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).

## Development

To check for new upstream versions do:
```sh
brew livecheck --tap dgarnier/plasma
```

To bump the version of these formulas do:
```sh
brew bump --open-pr <formula>
```
and then follow up by changing the created pr to have the label "pr-pull".

### Bumping fidasim (manual)

FIDASIM has had no tagged release since 2020, so the formula pins a master
commit and `brew livecheck`/`brew bump` deliberately skip it. To bump it:

1. Find the new commit on [D3DEnergetic/FIDASIM](https://github.com/D3DEnergetic/FIDASIM/commits/master)
   and note its full SHA and commit date.
2. Get the tarball checksum:
   ```sh
   curl -sL https://github.com/D3DEnergetic/FIDASIM/archive/<full-sha>.tar.gz | shasum -a 256
   ```
3. In `Formula/fidasim.rb` update three lines:
   - `url` — the new full SHA
   - `version` — `3.0.0.devYYYYMMDD` from the commit date (also names the Python wheel)
   - `sha256` — from step 2
4. Sanity check and build:
   ```sh
   brew style dgarnier/plasma/fidasim && brew audit dgarnier/plasma/fidasim
   brew reinstall --build-from-source dgarnier/plasma/fidasim && brew test fidasim
   ```
5. Open a PR and label it "pr-pull" so CI builds the bottle.




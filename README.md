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




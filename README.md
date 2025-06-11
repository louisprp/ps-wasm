# PS-WASM: Rendering PostScript in browsers using Ghostscript.

This little wrapper allows Ghostscript to be run with WebAssembly in browser,
and thus allows PostScript files to be opened with modern browsers directly.

## Usage

1. Set up the EMScripten environmen following [this tutorial](https://webassembly.org/getting-started/developers-guide/).

2. If compiling from latest git repo: set up `git`, `autoconf` and `automake`.

3. Run `./compile.sh` with the following parameters:

```
./compile.sh (--version=[latest|version.number]) (--browser=[chrome]) (--debug) (--skip_compile)
```
where the parameters are as follows:
* `--version`: specify `latest` to compile from latest [git source](https://github.com/ArtifexSoftware/ghostpdl), or a specific version number such as `10.05.0`.
    * Note: some versions (such as `10.05.1`) do compile but have bugs that prevent the program from running on certain files. Commit `dedddcb` of the git repo is the version used for the web store version of `v0.4` of this extension.
* `--browser`: specify the target browser. Currently only `chrome` is supported.
* `--debug`: compile the debug version, which prints a lot more info to the console.
* `--skip_compile`: tell the script to assume the `.wasm` and `.js` files are already there and just pack the plugin. Useful for debugging.

4. The plugin is then located at `extension/(browser)/ps-wasm`.

## License

Ocha 2025. Code licensed under AGPLv3.

Ghostscript is released by Artifex under AGPLv3 and can be found [here](https://www.ghostscript.com/).

Pako is written by Andrey Tupitsin and Vitaly Puzrin and can found [here](https://github.com/nodeca/pako).

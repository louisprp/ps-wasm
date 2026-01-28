# PS-WASM: Ghostscript compiled to WebAssembly

This project compiles Ghostscript to WebAssembly, allowing PostScript and PDF processing directly in the browser or other JavaScript environments.

## Features

- Render PostScript files
- Convert PostScript to PDF (pdfwrite driver included)
- ES6 module output for easy integration

## Building

### Prerequisites

1. Set up the Emscripten environment following [this tutorial](https://webassembly.org/getting-started/developers-guide/).
2. If compiling from latest git repo: install `git`, `autoconf`, and `automake`.

### Compile

```bash
./compile.sh [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--version=<version>` | Specify `latest` to compile from the latest [git source](https://github.com/ArtifexSoftware/ghostpdl), or a specific version number (e.g., `10.05.0`). Default: `latest` |
| `--debug` | Compile the debug version with additional console output and source maps. |

**Note:** Some versions (such as `10.05.1`) compile but have bugs that prevent correct operation on certain files.

### Output

After compilation, the following files are generated in the `dist/` directory:

- `gs.wasm` - The WebAssembly binary
- `gs.js` - ES6 module loader

## License

Ocha 2025. louisprp 2026. Code licensed under AGPLv3.

Ghostscript is released by Artifex under AGPLv3 and can be found [here](https://www.ghostscript.com/).
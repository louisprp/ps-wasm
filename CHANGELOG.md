# Changelog

## v2.0 - January 2026
### Updates
* Refactored from browser extension to standalone WebAssembly library.
* Output is now an ES6 module with `createGS` factory function.
* Added pdfwrite driver for PDF output support.
* Simplified build script (removed `--browser` and `--skip_compile` flags).
* Removed bundled Pako dependency.

## v1.0 - June 2025
### Updates
* Fixed a bug that prevented gzips from being unzipped correctly.
* Upgrading to Ghostscript 10.
* Added a script for compiling from ghostscript source.
* Cleaning up git repo.

## v0.31 - May 2023
### Updates
* Making manifest file compatible with Chrome's v3 standard.

## v0.21 - May 2020
### Updates
* Fixed manifest file.

## v0.2 - August 2019
### Updates
* Large files now supported.
* PDF files can now be saved.
* Improved URL and title display.
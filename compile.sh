#!/bin/bash

supported_browsers=("chrome")
ghostscript_version="latest"
tar_location="ghostscript-source-${ghostscript_version}.tar.gz"
source_folder="ghostscript-source"
gs_source_folder="${source_folder}/ghostpdl-${ghostscript_version}"
extension_folder_name="ps-wasm"

default_browser="chrome"
browser="$default_browser"

output_base="extension"
debug=false
skip_compile=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            ghostscript_version="$2"
            shift 2
            ;;
        --version=*)
            ghostscript_version="${1#*=}"
            shift
            ;;
        --browser)
            browser="$2"
            shift 2
            ;;
        --browser=*)
            browser="${1#*=}"
            shift
            ;;
        --debug)
            debug=true
            shift
            ;;
        --skip_compile)
            skip_compile=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [ "$debug" = true ] ; then
    export CMAKE_BUILD_TYPE="Debug"
fi

valid_browser=false
for val in "${supported_browsers[@]}"; do
    if [[ "$browser" == "$val" ]]; then
        valid_browser=true
        break
    fi
done


if [[ "$valid_browser" != true ]]; then
    echo "Invalid browser choice: $browser" >&2
    echo "Allowed values: ${supported_browsers[*]} (default: ${default_browser})" >&2
    exit 1
fi


if [ -z $(which emconfigure) ] ; then
    echo "EMScripten environment not set up."
    exit 1
fi

echo "GS version: ${ghostscript_version}"

if [ ! -d "$source_folder" ]; then
    # download source code if source is not there
    mkdir -p "$source_folder"
    if [ "$ghostscript_version" = "latest" ]; then
        if [ -z $(which git) ] ; then
            echo "Git not available; cannot clone the latest source code."
            exit 1
        elif [ -z $(which autoconf) ] ; then
            echo "Autoconf not available; make sure you have it set up."
            exit 1
        fi
        if [ ! -d "$gs_source_folder" ]; then
            if ! git clone https://github.com/ArtifexSoftware/ghostpdl.git "$gs_source_folder"; then
                echo "Could not clone the latest source code."
                exit 1
            fi
        fi
        (
            cd "$gs_source_folder" || exit 1
            NOCONFIGURE=1 ./autogen.sh
        )
        if [ $? -ne 0 ]; then
            echo "Autogen failed"
            exit 1
        fi
    else
        source_url="https://github.com/ArtifexSoftware/ghostpdl/archive/refs/tags/ghostpdl-${ghostscript_version}.tar.gz"
        echo "Downloading GhostSciprt ver ${ghostscript_version} from ${source_url}"
        if ! $(curl $source_url -L -f -o "$tar_location"); then
            echo "Could not download GhostScript source. Please check the URL."
            exit 1
        fi
        if [ ! -d "$gs_source_folder" ]; then
            if ! tar -xzf "$tar_location" -C "$source_folder" || [ ! -d "$gs_source_folder" ]; then
                echo "Source extraction failed." >&2
                exit 1
            fi
        fi
    fi
fi



# apply patch
cp -a "code_patch/common/" "${gs_source_folder}"
if [ -d "code_patch/${ghostscript_version}" ]; then
    cp -a "code_patch/${ghostscript_version}/" "${gs_source_folder}"
fi

if [ "$skip_compile" != true ] ; then # allows for skipping compiling for debugging
    # core compiling commands
    echo "Running emconfigure"
    (
        cd "$gs_source_folder" || exit 1
        emconfigure ./configure --disable-threading --disable-cups --disable-dbus --disable-gtk --with-drivers=PS CC=emcc CCAUX=gcc --with-arch_h=arch/wasm.h --without-tesseract
    )
    if [ $? -ne 0 ]; then
        echo "Configure run failed"
        exit 1
    fi

    echo "Patching Makefile"
    # ghostscript makes a wrong assumption that linker for the host and target should accept the same flags
    awk '{ if ($0 == "LDFLAGSAUX=$(LDFLAGS)") print "#" $0; else print $0 }' "$gs_source_folder/Makefile" > "$gs_source_folder/Makefile.tmp" && mv "$gs_source_folder/Makefile.tmp" "$gs_source_folder/Makefile"

    echo "Running emmake"
    (
        # need to suppress "warning: undefined symbol: TIFFClientOpen"
        # compare:
        # https://github.com/emscripten-core/emscripten/blob/74b3512cc22bbbb9b63e202ea4ddd49d4a17ca3f/test/test_browser.py#L3282
        cd "$gs_source_folder" || exit 1
        if [ "$debug" = true ] ; then
            XCFLAGS="-g -Wbad-function-cast -Wcast-function-type" XLDFLAGS="-sERROR_ON_UNDEFINED_SYMBOLS=0 -sALLOW_MEMORY_GROWTH=1 -sEXIT_RUNTIME=1 -sASSERTIONS=1 -o gs.js --emit-symbol-map -g3" emmake make debug
        else
            XLDFLAGS="-sERROR_ON_UNDEFINED_SYMBOLS=0 -sALLOW_MEMORY_GROWTH=1 -sEXIT_RUNTIME=1 -o gs.js" emmake make
        fi
    )
    if [ $? -ne 0 ]; then
        echo "Compiling failed"
        exit 1
    else
        echo "Compiling finished"
    fi
fi

if [ "$debug" = true ] ; then
    output_location="$gs_source_folder/debugbin"
else
    output_location="$gs_source_folder/bin"
fi

if [ ! -f "$output_location/gs.wasm" ]; then
    echo "Cannot find compiled files"
    exit 1
fi

extension_output_folder="$output_base/$browser/$extension_folder_name"
mkdir -p "$extension_output_folder"
cp "$output_location/gs.wasm" "$extension_output_folder"
cp "$output_location/gs" "$extension_output_folder/gs.js"
cp -a "src/$browser/" "$extension_output_folder"
if [ "$debug" = true ] ; then
    awk '{if ($0 == "DEBUG_FLAG = \"\";") print "DEBUG_FLAG = \"true\";"; else print $0}' "$extension_output_folder/viewer.js" > "$extension_output_folder/viewer.js.tmp" && mv "$extension_output_folder/viewer.js.tmp" "$extension_output_folder/viewer.js"
fi

echo "Extension is located in: $extension_output_folder"
exit 0

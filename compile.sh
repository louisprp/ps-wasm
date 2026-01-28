#!/bin/bash

ghostscript_version="latest"
tar_location="ghostscript-source-${ghostscript_version}.tar.gz"
source_folder="ghostscript-source"
gs_source_folder="${source_folder}/ghostpdl-${ghostscript_version}"

output_base="dist"
debug=false

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
        --debug)
            debug=true
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

if [ -z $(which emconfigure) ] ; then
    echo "Emscripten environment not set up."
    exit 1
fi

echo "GS version: ${ghostscript_version}"

if [ ! -d "$source_folder" ]; then
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
        echo "Downloading Ghostscript ver ${ghostscript_version} from ${source_url}"
        if ! $(curl $source_url -L -f -o "$tar_location"); then
            echo "Could not download Ghostscript source. Please check the URL."
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
if [ -d "code_patch/common" ]; then
    cp -a "code_patch/common/" "${gs_source_folder}"
fi
if [ -d "code_patch/${ghostscript_version}" ]; then
    cp -a "code_patch/${ghostscript_version}/" "${gs_source_folder}"
fi

echo "Running emconfigure"
(
    cd "$gs_source_folder" || exit 1
    emconfigure ./configure \
        --disable-threading \
        --disable-cups \
        --disable-dbus \
        --disable-gtk \
        --with-drivers=PS,pdfwrite \
        CC=emcc \
        CCAUX=gcc \
        --with-arch_h=arch/wasm.h \
        --without-tesseract
)
if [ $? -ne 0 ]; then
    echo "Configure failed"
    exit 1
fi

echo "Patching Makefile"
awk '{ if ($0 == "LDFLAGSAUX=$(LDFLAGS)") print "#" $0; else print $0 }' "$gs_source_folder/Makefile" > "$gs_source_folder/Makefile.tmp" && mv "$gs_source_folder/Makefile.tmp" "$gs_source_folder/Makefile"

echo "Running emmake"
(
    cd "$gs_source_folder" || exit 1
    if [ "$debug" = true ] ; then
        XCFLAGS="-g -Wbad-function-cast -Wcast-function-type" \
        XLDFLAGS="-sERROR_ON_UNDEFINED_SYMBOLS=0 \
            -sALLOW_MEMORY_GROWTH=1 \
            -sEXIT_RUNTIME=0 \
            -sMODULARIZE=1 \
            -sEXPORT_NAME='createGS' \
            -sEXPORTED_RUNTIME_METHODS=['FS','callMain'] \
            -sINVOKE_RUN=0 \
            -sEXPORT_ES6=1 \
            -sASSERTIONS=1 \
            -o gs.js \
            --emit-symbol-map \
            -g3" \
        emmake make debug
    else
        XLDFLAGS="-sERROR_ON_UNDEFINED_SYMBOLS=0 \
            -sALLOW_MEMORY_GROWTH=1 \
            -sEXIT_RUNTIME=0 \
            -sMODULARIZE=1 \
            -sEXPORT_NAME='createGS' \
            -sEXPORTED_RUNTIME_METHODS=['FS','callMain'] \
            -sINVOKE_RUN=0 \
            -sEXPORT_ES6=1 \
            -o gs.js" \
        emmake make
    fi
)
if [ $? -ne 0 ]; then
    echo "Compile failed"
    exit 1
else
    echo "Compile finished"
fi

if [ "$debug" = true ] ; then
    build_output="$gs_source_folder/debugbin"
else
    build_output="$gs_source_folder/bin"
fi

if [ ! -f "$build_output/gs.wasm" ]; then
    echo "Cannot find compiled files"
    exit 1
fi

mkdir -p "$output_base"
cp "$build_output/gs.wasm" "$output_base/"
cp "$build_output/gs" "$output_base/gs.js"

echo "Build output: $output_base/"
exit 0
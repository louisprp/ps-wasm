DEBUG_FLAG = "";

function pullData(data_url, progressCallback, messageCallback, readyCallback) {
    function reportReady(buffer) {
        var psData = new Uint8Array(buffer);
        var headerView = new DataView(buffer, 0, 2);
        var header = headerView.getUint16(0, false); // big endian
        if (header == 0x1F8B) {
            // some servers don't have gzip support turned on, which means we have to manually inflate
            let oldLength = psData.length;
            psData = pako.ungzip(psData);
            messageCallback(`Unpacked gzip; size: ${oldLength} -> ${psData.length}`)
        }
        else {
            messageCallback(`Header = ${header}, No need to unpack gzip`);
        }
        var blob = new Blob([psData], { type: "application/octet-stream" });
        var psDataURL = window.URL.createObjectURL(blob);
        readyCallback({ psDataURL: psDataURL, url: data_url });
    }
    fetch(data_url).then((response) => {
        const contentLength = response.headers.get("content-length");
        if (!contentLength) {
            return response.arrayBuffer().then((buffer) => {
                reportReady(buffer);
            });
        }

        const total = parseInt(contentLength, 10);
        let loaded = 0;
        const chunks = [];

        const progressStream = new TransformStream({
            transform(chunk, controller) {
                loaded += chunk.length;
                progressCallback(loaded, total);
                chunks.push(chunk);
                controller.enqueue(chunk);
            }
        });

        const streamed = response.body.pipeThrough(progressStream);

        return new Response(streamed).arrayBuffer().then((buffer) => { reportReady(buffer); });
    }).catch(console.error);
}


function loadPDFData(response) {
    fetch(response.pdfDataURL).then((response) => response.arrayBuffer()).then((buffer) => {
        window.URL.revokeObjectURL(response.pdfDataURL);
        var blob = new Blob([buffer], { type: "application/pdf" });
        var pdfURL = window.URL.createObjectURL(blob);
        var filename = new URL(response.url).pathname.split('/').pop();
        document.getElementById('wrapper').remove();
        var frame = document.getElementById('the_frame');
        frame.width = '100%';
        frame.style.height = '100vh';
        frame.style.border = '0px';
        frame.src = pdfURL;
        document.title = filename;
    });
}

window.onload = function () {
    var frame = document.getElementById('the_frame');
    frame.width = '0';
    frame.height = '0';
    frame.style.margin = '0';

    var loaderNode = document.getElementById("downloader");
    var search = window.location.search.substring(1);
    var incoming = JSON.parse('{"' + decodeURI(search).replace(/"/g, '\\"').replace(/&/g, '","').replace(/=/g, '":"') + '"}');
    var inputURL = incoming.url;
    if (inputURL.startsWith('chrome-extension')) // hack to support reloading
    {
        var program_id = chrome.runtime.id;
        inputURL = inputURL.substring(inputURL.indexOf(program_id) + program_id.length + 1);
    }
    loaderNode.innerHTML = `Downloading from ${inputURL}...`;
    var dlProgressNode = document.getElementById('dl_progress');
    var dlProgressMsgNode = document.getElementById('dl_progress_msg');
    var convProgressNode = document.getElementById('conv_progress');
    pullData(
        inputURL,
        function (loaded, total) { // display progress (if possible)
            dlProgressNode.innerHTML = `Download progress: ${loaded} / ${total}`;
        },
        function (message) {
            dlProgressMsgNode.innerHTML += message;
            if (DEBUG_FLAG === "true") {
                console.log(message);
            }
        },
        function (requestData) {
            _GSPS2PDF(
                requestData,
                function (replyData) { loadPDFData(replyData); },
                function (is_done, value, max_val) {
                    if (max_val != 0) {
                        convProgressNode.innerHTML = `Conversion progress: ${value} / ${max_val}`;
                    }
                },
                function (status) {
                    var statusElement = document.getElementById('conv_status');
                    if (status) {
                        statusElement.innerHTML += status + '<br>';
                    }
                }
            )
        });
};

function loadScript(url, onLoadCallback) {
    // Adding the script tag to the head as suggested before
    var head = document.head;
    var script = document.createElement('script');
    script.type = 'text/javascript';
    script.src = url;

    // Then bind the event to the callback function.
    // There are several events for cross browser compatibility.
    //script.onreadystatechange = callback;
    script.onload = onLoadCallback;

    // Fire the loading
    head.appendChild(script);
}

var Module;

function _GSPS2PDF(dataStruct, responseCallback, progressCallback, statusUpdateCallback) {
    // first download the ps data
    fetch(dataStruct.psDataURL).then((response) => response.arrayBuffer()).then((buffer) => {
        // release the URL
        window.URL.revokeObjectURL(dataStruct.psDataURL);
        //set up EMScripten environment
        let arguments = [
            '-sDEVICE=pdfwrite', '-dBATCH', '-dNOPAUSE',
            '-q',
            '-sOutputFile=output.pdf',
            '-f', 'input.ps'];
        if (DEBUG_FLAG === "true") {
            arguments = ['-dDEBUG'].concat(arguments);
        }
        Module = {
            preRun: [function () {
                var data = FS.writeFile('input.ps', new Uint8Array(buffer));
            }],
            postRun: [function () {
                var uarray = FS.readFile('output.pdf', { encoding: 'binary' }); //Uint8Array
                var blob = new Blob([uarray], { type: "application/octet-stream" });
                var pdfDataURL = window.URL.createObjectURL(blob);
                responseCallback({ pdfDataURL: pdfDataURL, url: dataStruct.url });
            }],
            arguments: arguments,
            print: function (text) {
                statusUpdateCallback(text);
                if (DEBUG_FLAG === "true") {
                    console.log(text);
                }
            },
            printErr: function (text) {
                statusUpdateCallback('Error: ' + text);
                console.error(text);
            },
            setStatus: function (text) {
                if (!Module.setStatus.last) Module.setStatus.last = { time: Date.now(), text: '' };
                if (text === Module.setStatus.last.text) return;
                var m = text.match(/([^(]+)\((\d+(\.\d+)?)\/(\d+)\)/);
                var now = Date.now();
                if (m && now - Module.setStatus.last.time < 30) // if this is a progress update, skip it if too soon
                    return;
                Module.setStatus.last.time = now;
                Module.setStatus.last.text = text;
                if (m) {
                    text = m[1];
                    progressCallback(false, parseInt(m[2]) * 100, parseInt(m[4]) * 100);
                } else {
                    progressCallback(true, 0, 0);
                }
                statusUpdateCallback(text);
            },
            totalDependencies: 0
        };
        Module.setStatus('Loading Postscript Converter...');
        loadScript('gs.js', null);
    });
}
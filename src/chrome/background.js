function getHeaderFromHeaders(headers, headerName) {
    for (var i = 0; i < headers.length; ++i) {
        var header = headers[i];
        if (header.name.toLowerCase() === headerName) {
            return header;
        }
    }
}

function getRedirectURL() {
	return chrome.runtime.getURL('viewer.html') + "?url=";
}

chrome.declarativeNetRequest.updateDynamicRules({
    removeRuleIds: [1001],
    addRules: [{
        'id': 1001,
        'priority': 1,
        'action': {
            'type': 'redirect',
            'redirect': {
                'regexSubstitution': getRedirectURL() + '\\0'
            }
        },
        'condition': {
            'regexFilter': ".*\\.ps(\\.gz)?$",
            'resourceTypes': ['main_frame']
        }
    }]
});